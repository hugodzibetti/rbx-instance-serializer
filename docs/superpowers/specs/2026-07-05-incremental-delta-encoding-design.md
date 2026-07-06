# Incremental / Delta Encoding — Design

## Context

This is the most architecturally open-ended item on the roadmap, and the one
most likely to be over-built if scoped loosely. `CLAUDE.md` describes it as
"encode only changed properties per instance" for "patch-based workflows
(store baseline + N deltas instead of N full snapshots)." This spec commits
to a concrete, bounded MVP rather than a general diff/patch framework, and
calls out explicitly what's deferred.

**This spec shares a hard dependency with the CLI Tooling spec
(`2026-07-05-cli-tooling-design.md`)'s `lattice diff` command**: both need to
solve the same underlying problem — matching instances between two
independently-serialized trees when Lattice has no built-in stable identity
across serialize calls. `lattice diff` needs this to report changes;
Incremental Encoding needs it to *compute* a patch in the first place. **If
these two are built in separate chats, whichever lands second should reuse
the matching function from whichever lands first** rather than
re-implementing it — check for `cli/Diff.luau`'s matching function before
writing a new one.

### The identity problem (shared with CLI diff)

Lattice assigns `globalId`s freshly on every `serialize()` call, derived from
traversal order (`Serializer.luau:105-114`), not from anything stable across
calls. The only Roblox-native candidate for cross-call stable identity is
`UniqueId` (`src/serde/uniqueId.luau`, codec 24) — but it's not guaranteed
present on every class, and isn't currently required or validated by
Lattice. Both this spec and CLI diff need to:
1. Prefer `UniqueId` for matching where present.
2. Fall back to positional/structural matching (same parent, same
   ClassName, same traversal index) where absent — and be explicit that this
   fallback breaks if instances were reordered, added, or removed near the
   unmatched instance.

## Goal (MVP scope)

Given a **baseline** `.lattice` file and a **current** live instance tree,
produce a **patch** buffer containing only:
- Changed property values, per instance matched by the identity strategy
  above.
- Added instances (full encode, same as a normal serialize, tagged as new).
- Removed instances (just the identity reference, no property data).

And given a baseline + a patch, reconstruct the current tree (apply).

Explicitly **not** in MVP scope (see Non-goals): chained/multi-hop patches,
patch compaction, conflict resolution, moving an instance to a new parent
without re-encoding it fully, delta-encoding within a single property's
value (e.g. only the changed axis of a Vector3) rather than at the
whole-property level.

## Non-goals

- **Chained patch history** (baseline + patch1 + patch2 + ... applied in
  sequence). MVP is baseline + exactly one patch. Multi-patch chains are a
  natural extension once the single-patch case is proven, but chaining
  introduces its own questions (do you replay all patches every load, or
  periodically re-baseline?) that don't need answering yet.
- **Patch compaction / squashing** multiple patches into one.
- **Conflict resolution** for concurrent edits (this is a single-writer,
  single-timeline diff/patch tool, not a CRDT or merge system).
- **Reparenting detection**: if an instance moves to a different parent, MVP
  treats this as "the `Parent` property changed" (a normal property delta via
  the `Referent` codec, id 26) — no special "moved subtree" optimization.
  This fits naturally since `Parent` is already just a property with codec
  26; no new mechanism needed for this case specifically.
- **Sub-property delta encoding** (e.g. storing only the changed component of
  a Vector3/CFrame). Property-level granularity only — if any part of a
  compound value changed, the whole value is re-encoded. This is consistent
  with how codecs are already leaf/opaque (`Codec<T>` has no notion of
  "partial write") and keeps this spec from requiring codec-level changes.

## Architecture

### Patch format

New sibling format to `src/format/`, e.g. `src/patch/`, with its own magic
bytes (e.g. `"LATP"`) and version, distinct from the full-snapshot format —
a patch is not a valid standalone `.lattice` file and must not be
misinterpreted as one.

```
[4 bytes]  magic: "LATP"
[2 bytes]  version
[varint]   baselineInstanceCount   -- sanity check against the baseline file being applied to
[varint]   changedCount
for each changed instance:
  [identity]        -- UniqueId (16 bytes) if present, else a positional reference (varint path/index — see Open Decisions)
  [varint]          classId
  [varint]          changedPropertyCount
  for each changed property:
    [varint]        propertyNameIndex  -- into a patch-local string table, same interning idea as the main format
    [codec bytes]   -- new value, written via that property's existing codec

[varint]   addedCount
for each added instance:
  -- identical shape to a ClassBlock entry for exactly one instance, reusing
  -- the existing per-instance encode path (not a new code path)

[varint]   removedCount
for each removed instance:
  [identity]        -- UniqueId or positional reference, no property data
```

### Computing a patch (`src/patch/diff.luau`)

1. Load baseline as `FormatData` (`Format.read`) and deserialize to instances
   (`Lattice.deserialize`) — or, more efficiently, keep the identity-matching
   logic working at the resolved-instance level, same as CLI diff, since
   property comparison ultimately needs actual values, not raw column bytes.
2. Build the identity map for baseline instances (UniqueId → instance, with
   a documented fallback for instances lacking one).
3. Walk the current live tree; for each instance, look up its baseline match:
   - Found + any property differs → emit a changed-instance entry (only the
     differing properties).
   - Found + nothing differs → omit entirely (this is the actual saving).
   - Not found (new UniqueId, or falls outside fallback matching) → emit as
     added.
4. Any baseline instance with no corresponding current instance → emit as
   removed.
5. Property-level comparison reuses the exact `isDefault`/`serializedVal`
   logic already in `Serializer.luau`'s Pass A (lines ~159-198) — that code
   already knows how to pull a comparable serialized form per property
   (handling Enum's `.Value` and Referent's target-id resolution specially).
   Extract that into a shared helper both the normal serializer and the
   patch differ can call, rather than duplicating the Enum/Referent special
   cases a second time.

### Applying a patch (`src/patch/apply.luau`)

1. Load baseline the normal way.
2. For each changed-instance entry: find the matching baseline instance (same
   identity strategy), overwrite only the listed properties.
3. For each added-instance entry: construct it directly (same decode path as
   a normal `ClassBlock` single-instance entry) and attach to its `Parent`
   (which is itself one of the "changed"/"added" properties — Parent
   resolution needs added instances to be creatable before their children
   are attached, so process in a parent-before-child order, mirroring how
   the existing `Deserializer.luau` must already handle tree construction
   order — reuse that logic rather than re-deriving it).
4. For each removed-instance entry: find and delete/detach it.
5. Return the resulting instance tree — same return shape as
   `Lattice.deserialize`.

## Size expectations (why this is worth building)

Not yet measured (no implementation exists to measure), but the expected
win is straightforward: for a workflow with N instances where only K change
between snapshots (K << N), current cost is a full re-serialize of all N
every time; patch cost is proportional to K plus a small per-instance
identity tag, independent of N. This is the same shape of win column
Dictionary encoding demonstrated for repeated *values* (see
`2026-07-05-column-dictionary-encoding-design.md`) — here it's repeated
*whole instances across time* instead of repeated values across a column.
**Recommend building a benchmark fixture simulating a realistic edit session
(e.g. 1000 instances, 10 moved, 5 added, 2 removed) as part of this work,
and capturing the actual size/time comparison in the PR** — don't claim the
win, measure it, same discipline applied to the Dictionary Encoding spec.

## Testing

- Round-trip: baseline + no changes → patch is empty (0 changed, 0 added,
  0 removed) → applying it returns a tree equal to baseline.
- Single property change on one instance → patch contains exactly one
  changed-instance entry with exactly one changed property → apply
  reconstructs correctly, other properties untouched.
- Add + remove + change in the same patch, applied together, in one test —
  covers ordering (added instances must exist before any changed-instance
  entry that reparents onto them).
- Instances lacking `UniqueId` — verify the positional fallback matches
  correctly when tree shape is unchanged, and verify the patch/diff clearly
  reports (not silently guesses) when fallback matching had to be used, same
  transparency requirement as CLI diff.
- A fixture reused directly from CLI diff's test suite if that lands first —
  the identity-matching function should have one test suite, not two.

## Open decisions for the implementer

1. **Positional identity reference encoding**: this doc hand-waves "varint
   path/index" for instances without `UniqueId`. Needs a concrete scheme —
   likely a stable path from a root (sequence of child-indices, sorted by
   some deterministic key since Roblox doesn't guarantee `GetChildren()`
   order) rather than a raw traversal index, since traversal index shifts if
   *any* earlier sibling is added/removed. Work this out concretely before
   implementing; don't ship "index into GetChildren()" as-is, it's fragile.
2. **Where does the shared Enum/Referent-aware property-comparison helper
   live?** This doc recommends extracting it from `Serializer.luau`'s Pass A
   into something both `src/instance/Serializer.luau` and
   `src/patch/diff.luau` import — exact module location is an implementation
   call.
3. **Confirm against CLI Tooling's `lattice diff`** before starting: if that
   spec's matching function already exists by the time this is picked up,
   import and reuse it rather than re-solving the identity problem
   independently. If this spec is picked up first, its matching function
   should be written in a location CLI tooling can later import from (not
   buried inside `src/patch/` internals).
