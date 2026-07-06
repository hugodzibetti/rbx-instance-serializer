--!strict

export type Encoding = number
-- 0 = raw (bitmask + raw values)
-- 1 = RLE (bitmask + runCount + runs)
-- 2 = Dictionary (bitmask + uniqueCount + unique values + per-instance dict indices)
-- 3 = AllDefault (no bitmask, no values - all are default)
-- 4 = AllNonDefault (no bitmask, all raw values)
-- delta (future numeric-stride encoding) will take the next free id (5+) if built.

export type PropertyColumn = {
	propertyNameIndex: number, -- references string table for robustness
	encoding: Encoding,
	bitmask: { boolean },
	values: { any }, -- for Dictionary (encoding == 2): the unique-value list, first-occurrence order
	dictIndices: { number }?, -- only set when encoding == 2: parallel to non-default instances, 0-based index into values
}

export type ClassBlock = {
	classId: number,
	instanceCount: number,
	columns: { PropertyColumn },
	templateRefs: { number }?, -- backward-compat only: populated when reading v1/v2 files with whole-instance dedup. Never set by v3+ serialization.
}

export type FormatData = {
	version: number,
	stringTable: { string },
	classBlocks: { ClassBlock },
}

return {}
