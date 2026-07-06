--!strict
-- Standalone smoke test for src/parallel/Worker.luau. Not wired into
-- scripts/RunTests.luau/frktest: it spawns a real `lune` child process, which doesn't
-- fit frktest's synchronous in-process unit-test model (it also depends on `lune` being
-- on PATH and the darklua @alias resolution working for a spawned script, both true in
-- dev but an awkward fit for the "pesde run test" contract). Run directly instead:
--   lune run scripts/SmokeTestWorker.luau

local process = require("@lune/process")

local BufferWriter = require("@src/buffer/Writer")
local format = require("@src/format")
local serde = require("@src/serde")

local function fail(msg: string): never
	print("SMOKE TEST FAILED: " .. msg)
	process.exit(1)
end

-- Hand-built payload for one class ("Part", classId = 1) with two columns:
--   Anchored (bool, codecId 2): 3 instances, values [true, false, true] -> not all
--     default, not all same -> should end up encoded as raw or RLE by ColumnEncoder.
--   Transparency (f32, codecId 0): 3 instances, all default (skipped) -> AllDefault.
local instanceCount = 3

-- Fake-but-plausible GLOBAL propertyNameIndex values (as the parent would have
-- precomputed from its own global string table before spawning this worker) - chosen
-- to be != the old local 1,2,3 counter the worker used to invent, to prove the
-- passthrough of the real global index actually works.
local ANCHORED_GLOBAL_INDEX = 12
local TRANSPARENCY_GLOBAL_INDEX = 5

local payload = BufferWriter.new()
payload:string("Part")
payload:varint(1) -- classId
payload:varint(instanceCount)
payload:varint(2) -- columnCount

-- Column 1: Anchored (bool), bitmask = [true, false, true] -> non-default all 3
do
	payload:string("Anchored")
	payload:varint(ANCHORED_GLOBAL_INDEX)
	payload:varint(2) -- codecId for bool
	-- bitmask: bit0=1 (nondefault), bit1=1 (nondefault), bit2=1 (nondefault)
	-- (in this smoke test every instance is "non-default" so we exercise codec.read
	-- for all 3 values; default-elision itself is tested elsewhere)
	local maskByte = bit32.bor(bit32.lshift(1, 0), bit32.lshift(1, 1), bit32.lshift(1, 2))
	payload:u8(maskByte)
	local boolCodec = serde.codecIdToModule[2]
	boolCodec.write(payload, true)
	boolCodec.write(payload, false)
	boolCodec.write(payload, true)
end

-- Column 2: Transparency (f32), all default -> bitmask all zero, no values
do
	payload:string("Transparency")
	payload:varint(TRANSPARENCY_GLOBAL_INDEX)
	payload:varint(0) -- codecId for f32
	payload:u8(0) -- bitmask byte, all default
end

local payloadBuf = payload:toBuffer()
local payloadStr = buffer.tostring(payloadBuf)

-- process.create's ChildProcessWriter:close() does not reliably signal EOF on stdin
-- to the child in this Lune version (verified: even a bare `cat` hangs forever on
-- stdout:readToEnd() after stdin:write() + stdin:close()) - use the blocking
-- process.exec with the stdio.stdin option instead, which writes-then-closes-then-waits
-- correctly under the hood.
local result = process.exec("lune", { "run", "src/parallel/Worker.luau" }, {
	stdio = { stdin = payloadStr },
})

local stdoutStr = result.stdout
local stderrStr = result.stderr

if not result.ok then
	fail("worker exited with code " .. tostring(result.code) .. ", stderr: " .. stderrStr)
end

if #stdoutStr == 0 then
	fail("worker produced no stdout output. stderr: " .. stderrStr)
end

-- Wrap the worker's single length-prefixed class block in a minimal full v4 buffer
-- so we can parse it back with the project's real format.read (byte-for-byte the
-- same class-block body layout the sequential Writer.luau produces).
--
-- The string table here must be built so that stringTable[ANCHORED_GLOBAL_INDEX] and
-- stringTable[TRANSPARENCY_GLOBAL_INDEX] resolve correctly, proving the worker passed
-- the real global indices straight through rather than emitting its own local 1/2
-- counter. format.read expects a dense 1..N array (real V4 files always have a
-- contiguous global string table - the sparse table is only an internal worker detail),
-- so pad the gaps with placeholder entries.
local GLOBAL_STRING_TABLE_COUNT = math.max(ANCHORED_GLOBAL_INDEX, TRANSPARENCY_GLOBAL_INDEX)
local globalStringTable = table.create(GLOBAL_STRING_TABLE_COUNT)
for i = 1, GLOBAL_STRING_TABLE_COUNT do
	globalStringTable[i] = "_unused" .. tostring(i)
end
globalStringTable[ANCHORED_GLOBAL_INDEX] = "Anchored"
globalStringTable[TRANSPARENCY_GLOBAL_INDEX] = "Transparency"

local wrapper = BufferWriter.new()
wrapper:u8(0x4C)
wrapper:u8(0x41)
wrapper:u8(0x54)
wrapper:u8(0x46)
wrapper:u16(4) -- version
wrapper:varint(GLOBAL_STRING_TABLE_COUNT)
for i = 1, GLOBAL_STRING_TABLE_COUNT do
	wrapper:string(globalStringTable[i])
end
wrapper:varint(1) -- class block count
wrapper:bytes(buffer.fromstring(stdoutStr))

local mockArtifact = {
	version = 1,
	classes = {},
	classByName = {},
	classById = {
		[1] = {
			id = 1,
			name = "Part",
			properties = {
				{ name = "Anchored", codecId = 2, codec = serde.codecIdToModule[2], default = false },
				{ name = "Transparency", codecId = 0, codec = serde.codecIdToModule[0], default = 0 },
			},
		},
	},
}

local decoded = format.read(wrapper:toBuffer(), mockArtifact :: any)

assert(decoded.version == 4, "expected decoded version 4")
assert(#decoded.classBlocks == 1, "expected exactly 1 class block")

local cb = decoded.classBlocks[1]
assert(cb.classId == 1, "expected classId 1")
assert(cb.instanceCount == instanceCount, "expected instanceCount " .. tostring(instanceCount))
assert(#cb.columns == 2, "expected 2 columns")

local anchoredCol, transparencyCol
for _, col in cb.columns do
	local propName = decoded.stringTable[col.propertyNameIndex]
	if propName == "Anchored" then
		anchoredCol = col
	elseif propName == "Transparency" then
		transparencyCol = col
	end
end

assert(anchoredCol ~= nil, "missing Anchored column")
assert(transparencyCol ~= nil, "missing Transparency column")

-- The core assertion for this bug fix: the worker must pass the REAL global
-- propertyNameIndex straight through into the bytes it writes, not invent its own local
-- 1/2/3 counter (which would not match either global index chosen here).
assert(
	anchoredCol.propertyNameIndex == ANCHORED_GLOBAL_INDEX,
	"expected Anchored column propertyNameIndex to be the real global index "
		.. tostring(ANCHORED_GLOBAL_INDEX)
		.. ", got "
		.. tostring(anchoredCol.propertyNameIndex)
)
assert(
	transparencyCol.propertyNameIndex == TRANSPARENCY_GLOBAL_INDEX,
	"expected Transparency column propertyNameIndex to be the real global index "
		.. tostring(TRANSPARENCY_GLOBAL_INDEX)
		.. ", got "
		.. tostring(transparencyCol.propertyNameIndex)
)

assert(transparencyCol.encoding == 3, "expected Transparency to be AllDefault (encoding 3)")

-- Anchored: all 3 non-default with values [true, false, true]. Reconstruct via bitmask +
-- values/dictIndices depending on whichever encoding ColumnEncoder picked.
local reconstructed = {}
if anchoredCol.encoding == 2 then
	-- Dictionary
	local dictIndices = anchoredCol.dictIndices :: { number }
	for _, idx in dictIndices do
		table.insert(reconstructed, anchoredCol.values[idx + 1])
	end
elseif anchoredCol.encoding == 1 then
	-- RLE: values already expanded by the reader into per-instance order in this codebase? No -
	-- Reader expands RLE runs into `values` in Reader/V4 (see readClassBlockBody), so values is
	-- already per-non-default-instance here.
	reconstructed = anchoredCol.values
else
	reconstructed = anchoredCol.values
end

assert(#reconstructed == 3, "expected 3 reconstructed Anchored values, got " .. tostring(#reconstructed))
assert(reconstructed[1] == true, "Anchored[1] should be true")
assert(reconstructed[2] == false, "Anchored[2] should be false")
assert(reconstructed[3] == true, "Anchored[3] should be true")

print("SMOKE TEST PASSED: worker round-trip produced correct, parseable v4 class block bytes")
process.exit(0)
