--!strict
-- Standalone Lune script (NOT a module) - run as a child process via
-- `lune run src/parallel/Worker.luau`, per the "Worker protocol > Serialize" section of
-- docs/superpowers/specs/2026-07-05-parallel-encoding-design.md (steps 5-6).
--
-- Stage B (parallel, pure data) of parallel serialize: reads one class block's raw
-- column data from stdin, decides final per-column encoding (raw/RLE/Dictionary/
-- AllDefault/AllNonDefault) via ColumnEncoder, writes the finished v4 length-prefixed
-- class block to stdout.
--
-- ## Wire payload (stdin), all multi-byte ints are varints unless noted:
--
-- className: string                 -- worker has no artifact file; this + the
--                                        per-column property names below let the
--                                        worker build a minimal synthetic ArtifactData
--                                        with just enough shape to satisfy
--                                        writeClassBlock's getPropertyMetadata lookup
--                                        (artifact.classById[classId].properties[].name/.codec)
-- classId: varint
-- instanceCount: varint
-- columnCount: varint
-- for each column:
--   propertyName: string            -- sent directly so the worker can build the
--                                        synthetic per-class property metadata
--                                        writeClassBlock's getPropertyMetadata needs;
--                                        NOT used as the wire propertyNameIndex (see
--                                        below)
--   propertyNameIndex: varint       -- the REAL global index into the parent's
--                                        precomputed global string table (built once,
--                                        before any worker is spawned, per "Worker
--                                        protocol > Serialize" step 2 of the parallel-
--                                        encoding design doc). The worker threads this
--                                        value straight through into the PropertyColumn
--                                        it writes - it never invents its own local
--                                        numbering.
--   codecId: varint                 -- looked up in serde.codecIdToModule; no artifact
--                                        needed to resolve a codec by id
--   bitmask: ceil(instanceCount / 8) bytes, packed LSB-first (same layout as
--            Writer.luau/Reader.luau use for raw/RLE/Dictionary columns)
--   for each bit set in the bitmask (i.e. each non-default instance), in order:
--     value via codec.write             -- today's "raw" transport encoding; NOT
--                                            necessarily the final on-disk encoding,
--                                            that choice is made here by ColumnEncoder
--
-- ## Wire payload (stdout):
--
-- The finished, length-prefixed v4 class block bytes, exactly as produced by
-- Writer.writeClassBlock (varint byte-length prefix + block body). Because the
-- propertyNameIndex values threaded through above are the parent's REAL global string
-- table indices (not a local per-worker counter), these bytes are directly suitable for
-- concatenation by the parent into the final buffer after the header + string table, in
-- classId order (this IS the final on-disk bytes for this block, no rewriting needed).
--
-- On any decode/encode error: writes a descriptive message to stderr and exits 1.

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local BufferReader = require("@src/buffer/Reader")
local BufferWriter = require("@src/buffer/Writer")
local serde = require("@src/serde")
local ColumnEncoder = require("@src/instance/ColumnEncoder")
local FormatWriter = require("@src/format/Writer")

local function run()
	local input = stdio.readToEnd()
	local buf = buffer.fromstring(input)
	local r = BufferReader.new(buf)

	local className = r:string()
	local classId = r:varint()
	local instanceCount = r:varint()
	local columnCount = r:varint()

	-- Minimal synthetic ArtifactData: just enough shape for writeClassBlock's
	-- getPropertyMetadata(artifact, classId, propName) to resolve {name, codec}.
	-- No real artifact file is available (or needed) in a worker process.
	local properties = table.create(columnCount)
	local artifact = {
		classes = {},
		classByName = {},
		classById = {
			[classId] = {
				id = classId,
				name = className,
				properties = properties,
			},
		},
	}

	-- Sparse: keyed by the REAL global propertyNameIndex the parent computed, not a
	-- contiguous 1..columnCount local counter. Gaps are fine - writeClassBlock only
	-- ever indexes it at the exact propertyNameIndex values this worker itself wrote.
	local stringTable = {}
	local columns = table.create(columnCount)

	for i = 1, columnCount do
		local propName = r:string()
		local propertyNameIndex = r:varint()
		local codecId = r:varint()

		local codec = serde.codecIdToModule[codecId]
		assert(codec, "Worker: unknown codecId " .. tostring(codecId) .. " for property " .. propName)

		properties[i] = {
			name = propName,
			codecId = codecId,
			codec = codec,
		}
		stringTable[propertyNameIndex] = propName

		local numBytes = math.ceil(instanceCount / 8)
		local maskBytes = if numBytes > 0 then r:bytes(numBytes) else buffer.create(0)

		local isDefaults = table.create(instanceCount)
		local k = 1
		for byteIdx = 0, numBytes - 1 do
			local byteVal = buffer.readu8(maskBytes, byteIdx)
			local limit = math.min(8, instanceCount - k + 1)
			for bitIdx = 0, limit - 1 do
				local isNonDefault = bit32.band(byteVal, bit32.lshift(1, bitIdx)) ~= 0
				isDefaults[k] = not isNonDefault
				k += 1
			end
		end

		local serializedVals = table.create(instanceCount)
		for j = 1, instanceCount do
			if not isDefaults[j] then
				serializedVals[j] = codec.read(r)
			end
		end

		local result = ColumnEncoder.encodeColumn(codec, serializedVals, isDefaults, instanceCount)

		columns[i] = {
			propertyNameIndex = propertyNameIndex,
			encoding = result.encoding,
			bitmask = result.bitmask,
			values = result.values,
			dictIndices = result.dictIndices,
		}
	end

	local classBlock = {
		classId = classId,
		instanceCount = instanceCount,
		columns = columns,
	}

	local blockWriter = BufferWriter.new()
	FormatWriter.writeClassBlock(blockWriter, classBlock, artifact :: any, stringTable)

	local outer = BufferWriter.new()
	outer:varint(blockWriter:len())
	outer:bytes(blockWriter:toBuffer())

	stdio.write(buffer.tostring(outer:toBuffer()))
end

local ok, err = pcall(run)
if not ok then
	stdio.ewrite("Worker error: " .. tostring(err) .. "\n")
	process.exit(1)
end
