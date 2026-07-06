--!strict
--!native
--!optimize 2

-- Shared LATP patch buffer parsing: header + identity decoding, mirroring
-- src/patch/diff.luau's writeIdentity exactly. Used by src/patch/apply.luau.

local BufferReader = require("@src/buffer/Reader")

local MAGIC = { 0x4C, 0x41, 0x54, 0x50 } -- "LATP"

export type PathSegment = { className: string, siblingIndex: number }

export type PatchIdentity = {
	kind: "uniqueId" | "path",
	uniqueIdBytes: buffer?,
	path: { PathSegment }?,
}

export type ChangedProperty = {
	propertyName: string,
	-- deferred: raw bytes aren't captured; caller must read via codec at
	-- decode time since codec depends on class/property metadata. See
	-- readChangedInstance below, which reads inline against the artifact.
}

local function readIdentity(r: BufferReader.Reader, stringTable: { string }): PatchIdentity
	local kind = r:u8()
	if kind == 0 then
		local raw = r:bytes(16)
		return { kind = "uniqueId", uniqueIdBytes = raw }
	elseif kind == 1 then
		local segCount = r:varint()
		local path = table.create(segCount)
		for i = 1, segCount do
			local classNameIdx = r:varint()
			local siblingIndex = r:varint()
			local className = stringTable[classNameIdx]
			assert(className, "Patch: class name index out of bounds in patch string table")
			path[i] = { className = className, siblingIndex = siblingIndex }
		end
		return { kind = "path", path = path }
	else
		error("Patch: unknown identity kind byte: " .. tostring(kind))
	end
end

export type ParsedHeader = {
	reader: BufferReader.Reader,
	version: number,
	stringTable: { string },
	baselineInstanceCount: number,
}

local function readHeader(buf: buffer): ParsedHeader
	local r = BufferReader.new(buf)

	local m0 = r:u8()
	local m1 = r:u8()
	local m2 = r:u8()
	local m3 = r:u8()
	assert(
		m0 == MAGIC[1] and m1 == MAGIC[2] and m2 == MAGIC[3] and m3 == MAGIC[4],
		"Invalid patch magic bytes (expected LATP)"
	)

	local version = r:u16()
	assert(version == 1, "Unsupported patch version: " .. tostring(version))

	local stringTableCount = r:varint()
	local stringTable = table.create(stringTableCount)
	for i = 1, stringTableCount do
		stringTable[i] = r:string()
	end

	local baselineInstanceCount = r:varint()

	return {
		reader = r,
		version = version,
		stringTable = stringTable,
		baselineInstanceCount = baselineInstanceCount,
	}
end

return {
	readHeader = readHeader,
	readIdentity = readIdentity,
}
