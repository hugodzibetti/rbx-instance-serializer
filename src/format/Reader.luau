--!strict
--!native
--!optimize 2

local Types = require("@src/format/types")
local ArtifactTypes = require("@src/artifacts/types")
local BufferReader = require("@src/buffer/Reader")
local compat = require("@src/compat")
local V1 = require("@src/format/readers/V1")
local V2 = require("@src/format/readers/V2")
local V3 = require("@src/format/readers/V3")
local V4 = require("@src/format/readers/V4")

local function read(artifactBuffer: buffer, artifact: ArtifactTypes.ArtifactData): Types.FormatData
	local r = BufferReader.new(artifactBuffer)

	-- Magic bytes: "LATF"
	local m0 = r:u8()
	local m1 = r:u8()
	local m2 = r:u8()
	local m3 = r:u8()
	assert(m0 == 0x4C and m1 == 0x41 and m2 == 0x54 and m3 == 0x46, "Invalid format magic bytes")

	-- Version
	local version = r:u16()

	local raw: Types.FormatData
	if version == 1 then
		raw = V1.readV1Body(r, artifact)
	elseif version == 2 then
		raw = V2.readV2Body(r, artifact)
	elseif version == 3 then
		raw = V3.readV3Body(r, artifact)
	elseif version == 4 then
		raw = V4.readV4Body(r, artifact)
	else
		error("Unsupported format version: " .. tostring(version))
	end

	return (compat.migrate(compat.defaultRegistry, raw, version) :: any) :: Types.FormatData
end

return {
	read = read,
}
