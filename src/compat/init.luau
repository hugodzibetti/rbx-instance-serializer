--!strict

local Types = require("@src/compat/types")

export type Migration = Types.Migration
export type CompatRegistry = Types.CompatRegistry

local defaultRegistry: CompatRegistry = {
	currentVersion = 4, -- keep in lockstep with src/format/Writer.luau's version constant
	migrations = {
		-- v1 -> v2: pure wire-format change (templateRefs raw varints -> RLE),
		-- fully resolved by src/format/readers/V1.luau vs V2.luau producing the
		-- same FormatData shape. No semantic transformation needed.
		[1] = function(data) return data end,
		-- v2 -> v3: removed templateRefs entirely. FormatData shape unchanged
		-- (templateRefs field no longer present in ClassBlock).
		[2] = function(data) return data end,
		-- v3 -> v4: purely additive wire-format change (varint length prefix
		-- before each class block's contents). FormatData/ClassBlock shape is
		-- unchanged; src/format/readers/V4.luau already produces identical
		-- output to V3's, so no semantic transformation needed.
		[3] = function(data) return data end,
	},
}

local function migrate(registry: CompatRegistry, data: any, fromVersion: number): any
	if fromVersion == registry.currentVersion then
		return data
	end

	if fromVersion > registry.currentVersion then
		error(
			"Cannot migrate from version "
				.. tostring(fromVersion)
				.. ": newer than the current known version "
				.. tostring(registry.currentVersion)
		)
	end

	for v = fromVersion, registry.currentVersion - 1 do
		local step = registry.migrations[v]
		if not step then
			error("Missing migration for version " .. tostring(v) .. " -> " .. tostring(v + 1))
		end
		data = step(data)
	end

	return data
end

return {
	defaultRegistry = defaultRegistry,
	migrate = migrate,
}
