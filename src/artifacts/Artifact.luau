--!strict
--!native
--!optimize 2

local Reader = require("@src/buffer/Reader")
local Types = require("@src/artifacts/types")
local getCodec = require("@src/artifacts/getCodec")

type PropertyMetadata = Types.PropertyMetadata
type ClassMetadata = Types.ClassMetadata
type ArtifactData = Types.ArtifactData

local CURRENT_VERSION = 1

local function load(artifactBuffer: buffer): ArtifactData
	local r = Reader.new(artifactBuffer)

	-- Magic bytes: "LATA"
	local m0 = r:u8()
	local m1 = r:u8()
	local m2 = r:u8()
	local m3 = r:u8()
	assert(m0 == 0x4C and m1 == 0x41 and m2 == 0x54 and m3 == 0x41, "Invalid artifact magic bytes")

	-- Version
	local version = r:u16()
	assert(version >= 1 and version <= CURRENT_VERSION, "Unsupported artifact version: " .. tostring(version))

	local classCount = r:varint()
	local classes: { ClassMetadata } = {}
	local classByName: { [string]: ClassMetadata } = {}
	local classById: { [number]: ClassMetadata } = {}

	local seenClassIds = {}

	for _ = 1, classCount do
		local classId = r:varint()
		assert(not seenClassIds[classId], "Duplicate class ID in artifact: " .. tostring(classId))
		seenClassIds[classId] = true

		local className = r:string()
		local propCount = r:varint()
		local properties: { PropertyMetadata } = {}

		for _ = 1, propCount do
			local propName = r:string()
			local codecId = r:varint()
			local paramCount = r:varint()
			local codecParams: { number }? = nil
			if paramCount > 0 then
				codecParams = {}
				for __ = 1, paramCount do
					table.insert(codecParams :: { number }, r:varint())
				end
			end

			local codec = getCodec(codecId, codecParams)
			local defaultLen = r:varint()
			local defaultVal: any? = nil
			if defaultLen > 0 then
				local defaultBytes = r:bytes(defaultLen)
				if codec then
					local ok, val = pcall(function()
						local dr = Reader.new(defaultBytes)
						return codec.read(dr)
					end)
					if ok then
						defaultVal = val
					else
						warn(string.format("Failed to decode default value for property %s in class %s: %s", propName, className, tostring(val)))
					end
				else
					warn(string.format("Codec not found for property %s in class %s", propName, className))
				end
			end

			table.insert(properties, {
				name = propName,
				codecId = codecId,
				codecParams = codecParams,
				default = defaultVal,
				codec = codec,
			})
		end

		local cm: ClassMetadata = {
			id = classId,
			name = className,
			properties = properties,
		}
		table.insert(classes, cm)
		classByName[className] = cm
		classById[classId] = cm
	end

	return {
		version = version,
		classes = classes,
		classByName = classByName,
		classById = classById,
	}
end

return {
	load = load,
}
