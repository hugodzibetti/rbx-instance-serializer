# Lattice Docs

Start here: **[how-it-works.md](how-it-works.md)** — the pipeline, the four
layers, and why columnar+bitmask layout is the core trick. Has diagrams.

Then:

- [glossary.md](glossary.md) — every term (varint, bitmask, RLE, artifact, codec...) with definitions
- [examples/](examples/) — byte-level walkthroughs (varint, bitmask, RLE, columnar-vs-row, full format binary)
- [superpowers/specs/](superpowers/specs/) — original design docs for the artifact system, format layer, and codec benchmarks

For build commands and code style, see [../CLAUDE.md](../CLAUDE.md).
