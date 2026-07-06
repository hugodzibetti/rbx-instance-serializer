--!strict
-- Standalone Lune script (NOT a module) - run as a child process via
-- `lune run src/parallel/Worker.luau` (encode mode, default) or
-- `lune run src/parallel/Worker.luau -- decode` (decode mode), per the "Worker
-- protocol" section of docs/superpowers/specs/2026-07-05-parallel-encoding-design.md.
--
-- Mode selection: pass "decode" as a CLI arg (e.g. `lune run src/parallel/Worker.luau
-- -- decode`) to select decode mode. No "decode" arg present means encode mode,
-- preserving the original behavior and wire format exactly for existing callers
-- (src/instance/Serializer.luau's serializeParallel). Lune does not strip the `--`
-- separator from process.args, so Worker.luau scans all of process.args for the
-- literal string "decode" rather than assuming a fixed index.
--
-- ============================================================================
-- ENCODE MODE (default, no CLI arg)
-- ============================================================================
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
--
-- ============================================================================
-- DECODE MODE (`-- decode` CLI arg)
-- ============================================================================
--
-- Stage B (parallel, pure data) of parallel deserialize: reads one class block's
-- already-length-prefixed v4 bytes from stdin (plus enough artifact shape to resolve
-- codecs), parses it via the same readClassBlockBody logic V4.luau uses for the
-- sequential path, and writes the decoded PropertyColumns back to stdout in a generic
-- self-describing form (encoding + bitmask + values-via-codec.write + dictIndices).
--
-- ## Wire payload (stdin), all multi-byte ints are varints unless noted:
--
-- classId: varint
-- className: string                 -- for error messages only
-- propertyCount: varint
-- for each property (this class's full property list, in artifact order):
--   propertyName: string
--   codecId: varint
-- stringTableCount: varint          -- the parent's FULL global string table (cheap:
--                                        strings only), so the worker can resolve
--                                        whichever propertyNameIndex values the block
--                                        body references without the parent needing to
--                                        know in advance which subset a given block uses
-- for each string table entry:
--   value: string
-- blockLength: varint               -- the v4 length-prefix value (byte length of the
--                                        block body that follows)
-- blockBody: blockLength bytes      -- the raw class block body bytes (NOT including
--                                        the length prefix itself), exactly as sliced
--                                        by the parent out of the original buffer
--
-- ## Wire payload (stdout):
--
-- instanceCount: varint            -- the class block's instanceCount, echoed once up
--                                        front (not per-column) so the parent can
--                                        recover it even for a zero-column class
-- columnCount: varint
-- for each column, in the same order as parsed from the block:
--   propertyNameIndex: varint
--   encoding: varint                -- 0=raw, 1=RLE, 2=Dictionary, 3=AllDefault, 4=AllNonDefault
--   bitmask: ceil(instanceCount / 8) bytes, packed LSB-first (always present, even for
--            encoding 3/4, for wire uniformity - parent ignores it in those cases)
--   valueCount: varint              -- number of entries in `values` below (differs by
--                                        encoding: nonDefaultCount for raw, run-count
--                                        collapsed back to per-instance for RLE i.e. same
--                                        as instanceCount... see note) -- for simplicity
--                                        this worker always re-expands RLE runs into a
--                                        flat per-non-default-instance value list before
--                                        sending, so valueCount == nonDefaultCount for
--                                        encodings 0/1/2, or instanceCount for encoding 4,
--                                        or 0 for encoding 3
--   for each value: value via codec.write
--   hasDictIndices: u8 (0 or 1)
--   if hasDictIndices == 1:
--     dictIndexCount: varint (== valueCount above, since Dictionary's `values` list in
--                              PropertyColumn is unique-value list; see note below)
--     for each: dictIndex via varint
--
-- Note on Dictionary (encoding 2): PropertyColumn.values for Dictionary is the UNIQUE
-- value list (not per-instance), with dictIndices mapping each non-default instance to
-- an index into it. This worker preserves that shape on the wire (does NOT re-expand
-- Dictionary), since re-expanding would lose the reason Dictionary is cheaper. RLE,
-- by contrast, arrives from readClassBlockBody already re-expanded into a flat
-- non-default-value list, so it's forwarded as-is as encoding 1 with a flat values list.
--
-- On any decode error: writes a descriptive message to stderr and exits 1.

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local BufferReader = require("@src/buffer/Reader")
local BufferWriter = require("@src/buffer/Writer")
local serde = require("@src/serde")
local ColumnEncoder = require("@src/instance/ColumnEncoder")
local FormatWriter = require("@src/format/Writer")
local V4 = require("@src/format/readers/V4")

local function runEncode()
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

local function runDecode()
	local input = stdio.readToEnd()
	local buf = buffer.fromstring(input)
	local r = BufferReader.new(buf)

	local classId = r:varint()
	local className = r:string()
	local propertyCount = r:varint()

	local properties = table.create(propertyCount)
	for i = 1, propertyCount do
		local propName = r:string()
		local codecId = r:varint()
		local codec = serde.codecIdToModule[codecId]
		assert(codec, "Worker(decode): unknown codecId " .. tostring(codecId) .. " for property " .. propName)
		properties[i] = {
			name = propName,
			codecId = codecId,
			codec = codec,
		}
	end

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

	local stringTableCount = r:varint()
	local stringTable = table.create(stringTableCount)
	for i = 1, stringTableCount do
		stringTable[i] = r:string()
	end

	local blockLength = r:varint()
	local blockStart = r:pos()

	local classBlock = V4.readClassBlockBody(r, artifact :: any, stringTable)

	local bytesRead = r:pos() - blockStart
	assert(
		bytesRead == blockLength,
		"Worker(decode): class block length mismatch for class "
			.. className
			.. ": expected "
			.. tostring(blockLength)
			.. " bytes, read "
			.. tostring(bytesRead)
	)

	local w = BufferWriter.new()
	w:varint(classBlock.instanceCount)
	w:varint(#classBlock.columns)

	for _, col in classBlock.columns do
		w:varint(col.propertyNameIndex)
		w:varint(col.encoding)

		local numBytes = math.ceil(classBlock.instanceCount / 8)
		local maskBuf = buffer.create(numBytes)
		local byteIdx = 0
		local acc = 0
		local bitIdx = 0
		for i = 1, classBlock.instanceCount do
			if col.bitmask[i] then
				acc = bit32.bor(acc, bit32.lshift(1, bitIdx))
			end
			bitIdx += 1
			if bitIdx == 8 then
				buffer.writeu8(maskBuf, byteIdx, acc)
				byteIdx += 1
				acc = 0
				bitIdx = 0
			end
		end
		if bitIdx > 0 then
			buffer.writeu8(maskBuf, byteIdx, acc)
		end
		w:bytes(maskBuf)

		-- Resolve the codec for this column's property via propertyNameIndex.
		local propName = stringTable[col.propertyNameIndex]
		assert(propName, "Worker(decode): property name index out of bounds in string table")
		local pm = nil
		for _, p in properties do
			if p.name == propName then
				pm = p
				break
			end
		end
		assert(pm, "Worker(decode): property metadata not found for " .. propName)
		local codec = pm.codec

		w:varint(#col.values)
		for _, v in col.values do
			codec.write(w, v)
		end

		if col.dictIndices then
			w:u8(1)
			w:varint(#col.dictIndices)
			for _, idx in col.dictIndices do
				w:varint(idx)
			end
		else
			w:u8(0)
		end
	end

	stdio.write(buffer.tostring(w:toBuffer()))
end

-- `lune run script -- decode` (both directly and via process.exec's args array)
-- surfaces the literal "--" as process.args[1] and "decode" as process.args[2] -
-- Lune does not strip the separator. Scan for "decode" anywhere in args rather than
-- assuming a fixed index, so this keeps working regardless of how the separator is
-- represented.
local mode = "encode"
for _, arg in process.args do
	if arg == "decode" then
		mode = "decode"
		break
	end
end

local ok, err = pcall(function()
	if mode == "decode" then
		runDecode()
	else
		runEncode()
	end
end)
if not ok then
	stdio.ewrite("Worker error: " .. tostring(err) .. "\n")
	process.exit(1)
end
