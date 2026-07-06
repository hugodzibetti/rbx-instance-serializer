--!strict
--!native
--!optimize 2

-- Pure per-column encoding-choice logic, extracted from src/instance/Serializer.luau
-- so both the sequential serialize path and a future parallel worker process
-- (see docs/superpowers/specs/2026-07-05-parallel-encoding-design.md) can call
-- the exact same encoding decision without duplicating the cost math.

local Types = require("@src/types")
local FormatTypes = require("@src/format/types")
local BufferWriter = require("@src/buffer/Writer")
local CostEstimator = require("@src/format/CostEstimator")

type Codec<T> = Types.Codec<T>
type Encoding = FormatTypes.Encoding

export type ColumnEncoderResult = {
	encoding: Encoding,
	bitmask: { boolean },
	values: { any },
	dictIndices: { number }?,
}

-- serializedVals/isDefaults are parallel arrays of length effectiveCount holding
-- each instance's already-codec-serialized value and whether it equals the
-- artifact default. Chooses the cheapest of raw/RLE/Dictionary/AllDefault/
-- AllNonDefault encodings for the column, matching CostEstimator's byte math.
local function encodeColumn(
	codec: Codec<any>,
	serializedVals: { any },
	isDefaults: { boolean },
	effectiveCount: number
): ColumnEncoderResult
	local allValues = table.create(effectiveCount)
	local bitmask = table.create(effectiveCount)
	local nonDefaultValues = {}
	local nonDefaultCount = 0

	for i = 1, effectiveCount do
		local serializedVal = serializedVals[i]
		local isDefault = isDefaults[i]

		allValues[i] = serializedVal
		bitmask[i] = not isDefault

		if not isDefault then
			table.insert(nonDefaultValues, serializedVal)
			nonDefaultCount += 1
		end
	end

	local encoding: Encoding = 0
	local colValues = nonDefaultValues

	if nonDefaultCount == 0 then
		return {
			encoding = 3,
			bitmask = table.create(effectiveCount, false),
			values = {},
			dictIndices = nil,
		}
	end

	local minSize = CostEstimator.sizeRaw(codec, effectiveCount, nonDefaultValues)

	local rleCost = CostEstimator.sizeRle(codec, effectiveCount, nonDefaultValues)
	if rleCost < minSize then
		minSize = rleCost
		encoding = 1
		colValues = nonDefaultValues
	end

	-- Dictionary cost: unique values (first-occurrence order) + per-instance index.
	-- Keyed by the value's actual serialized bytes (via the column's own codec),
	-- not tostring(v): tostring truncates float precision for Vector3/CFrame/etc,
	-- so numerically distinct values can print identically and get wrongly
	-- collapsed into one dictionary entry (silent data corruption on read-back).
	-- Serialized bytes are exactly what will be written to the wire, so this
	-- keying is collision-safe by construction.
	local uniqueValues = {}
	local dictIndexOf = {}
	local dictIndices = table.create(nonDefaultCount)
	for _, v in nonDefaultValues do
		local keyW = BufferWriter.new()
		codec.write(keyW, v)
		local key = buffer.tostring(keyW:toBuffer())
		local idx = dictIndexOf[key]
		if not idx then
			table.insert(uniqueValues, v)
			idx = #uniqueValues - 1 -- 0-based
			dictIndexOf[key] = idx
		end
		table.insert(dictIndices, idx)
	end

	local sizeDict = math.ceil(effectiveCount / 8) + CostEstimator.varintSize(#uniqueValues)
	for _, v in uniqueValues do
		sizeDict += CostEstimator.getValueSize(codec, v)
	end
	for _, idx in dictIndices do
		sizeDict += CostEstimator.varintSize(idx)
	end

	local dictIndicesResult: { number }? = nil
	if sizeDict < minSize then
		minSize = sizeDict
		encoding = 2
		colValues = uniqueValues
		dictIndicesResult = dictIndices
	end

	-- AllNonDefault cost
	if nonDefaultCount == effectiveCount then
		local allNonDefaultCost = CostEstimator.sizeAllNonDefault(codec, allValues)
		if allNonDefaultCost < minSize then
			minSize = allNonDefaultCost
			encoding = 4
			colValues = allValues
			bitmask = table.create(effectiveCount, true)
			dictIndicesResult = nil
		end
	end

	return {
		encoding = encoding,
		bitmask = bitmask,
		values = colValues,
		dictIndices = dictIndicesResult,
	}
end

return {
	encodeColumn = encodeColumn,
}
