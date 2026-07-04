--!strict
--!native
--!optimize 2

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local Timer = require("./Timer")
local Fixtures = require("./Fixtures")
local Report = require("./Report")

local ITERATIONS = 50

local function measureWrite(codec: any, samples: {any}): { totalBytes: number, opsPerSecond: number }
	local bytes = 0
	local fn = function()
		local w = Writer.new()
		for _, sample in samples do
			codec.write(w, sample)
		end
		bytes = w:len()
	end
	local result = Timer.run(ITERATIONS, fn)
	return {
		totalBytes = bytes,
		opsPerSecond = result.opsPerSecond * #samples,
	}
end

local function measureRead(codec: any, samples: {any}): number
	local w = Writer.new()
	for _, sample in samples do
		codec.write(w, sample)
	end
	local data = w:toBuffer()

	local fn = function()
		local r = Reader.new(data)
		for _ = 1, #samples do
			codec.read(r)
		end
	end
	local result = Timer.run(ITERATIONS, fn)
	return result.opsPerSecond * #samples
end

local function run()
	local results = {}

	for _, entry in Fixtures.entries do
		local n = #entry.samples
		if n == 0 then
			print("WARNING: no samples for codec: " .. entry.name)
			continue
		end

		local writeResult = measureWrite(entry.codec, entry.samples)
		local readOps = measureRead(entry.codec, entry.samples)

		table.insert(results, {
			name = entry.name,
			writeOpsPerSecond = writeResult.opsPerSecond,
			readOpsPerSecond = readOps,
			totalBytes = writeResult.totalBytes * ITERATIONS,
			avgBytesPerValue = writeResult.totalBytes / n,
			sampleCount = n,
		})
	end

	Report.printTable(results)
end

run()
