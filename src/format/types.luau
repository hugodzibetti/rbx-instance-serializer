--!strict

export type Encoding = number
-- 0 = raw (bitmask + raw values)
-- 1 = RLE (bitmask + runCount + runs)
-- 2 = delta (reserved)
-- 3 = AllDefault (no bitmask, no values - all are default)
-- 4 = AllNonDefault (no bitmask, all raw values)

export type PropertyColumn = {
	propertyNameIndex: number, -- references string table for robustness
	encoding: Encoding,
	bitmask: { boolean },
	values: { any },
}

export type ClassBlock = {
	classId: number,
	instanceCount: number,
	columns: { PropertyColumn },
	templateRefs: { number }?, -- parallel array, length instanceCount. 0 = not a duplicate (or is a template leader). k>0 = this instance duplicates the instance at 1-based position k within this block (k must itself have templateRefs[k] == 0).
}

export type FormatData = {
	version: number,
	stringTable: { string },
	classBlocks: { ClassBlock },
}

return {}
