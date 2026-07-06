--!strict
-- Shared cost-estimation helpers for choosing/analyzing column encodings.
-- Extracted from src/instance/Serializer.luau so cli/Stats.luau and
-- cli/Dump.luau can recompute per-column byte costs without duplicating
-- the estimator logic (and without depending on --!native for CLI use).

local BufferWriter = require("@src/buffer/Writer")

local function getValueSize(codec: any, val: any): number
	local tempW = BufferWriter.new()
	local ok = pcall(function()
		codec.write(tempW, val)
	end)
	if ok then
		return buffer.len(tempW:toBuffer())
	else
		return 0
	end
end

local function varintSize(val: number): number
	local size = 0
	local temp = val
	repeat
		size += 1
		temp = bit32.rshift(temp, 7)
	until temp == 0
	return size
end

local function runLengthEncode(values: { any }): { { value: any, count: number } }
	local runs = {}
	if #values == 0 then
		return runs
	end
	local currentVal = values[1]
	local currentCount = 1
	for i = 2, #values do
		if values[i] == currentVal then
			currentCount += 1
		else
			table.insert(runs, { value = currentVal, count = currentCount })
			currentVal = values[i]
			currentCount = 1
		end
	end
	table.insert(runs, { value = currentVal, count = currentCount })
	return runs
end

-- Bytes for an "AllDefault"-style bitmask-only column (bitmask stored, but
-- callers doing raw/RLE math still need the ceil(count/8) bitmask prefix).
local function bitmaskBytes(effectiveCount: number): number
	return math.ceil(effectiveCount / 8)
end

-- Cost of encoding=0 (Raw): bitmask + raw values for the non-default entries.
local function sizeRaw(codec: any, effectiveCount: number, nonDefaultValues: { any }): number
	local size = bitmaskBytes(effectiveCount)
	for _, v in nonDefaultValues do
		size += getValueSize(codec, v)
	end
	return size
end

-- Cost of encoding=1 (RLE): bitmask + run count + (runLength varint + value) per run.
-- Returns both the byte size and the computed runs so callers (dump) can
-- also report run count without re-running RLE separately.
local function sizeRle(codec: any, effectiveCount: number, nonDefaultValues: { any }): (number, { { value: any, count: number } })
	local runs = runLengthEncode(nonDefaultValues)
	local size = bitmaskBytes(effectiveCount) + varintSize(#runs)
	for _, run in runs do
		size += varintSize(run.count) + getValueSize(codec, run.value)
	end
	return size, runs
end

-- Cost of encoding=4 (AllNonDefault): no bitmask, every value stored raw.
local function sizeAllNonDefault(codec: any, allValues: { any }): number
	local size = 0
	for _, v in allValues do
		size += getValueSize(codec, v)
	end
	return size
end

return {
	getValueSize = getValueSize,
	varintSize = varintSize,
	runLengthEncode = runLengthEncode,
	bitmaskBytes = bitmaskBytes,
	sizeRaw = sizeRaw,
	sizeRle = sizeRle,
	sizeAllNonDefault = sizeAllNonDefault,
}
