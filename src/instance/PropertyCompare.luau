--!strict
--!native
--!optimize 2

-- Shared Enum/Referent-aware property comparison helper.
--
-- Extracted from src/instance/Serializer.luau's Pass A (previously
-- lines ~159-198) so both the full serializer and src/patch/diff.luau can
-- compute a "comparable serialized form" for a property value without
-- duplicating the Enum (.Value) and Referent (target-id resolution)
-- special cases.

local ArtifactTypes = require("@src/artifacts/types")

type PropertyMetadata = ArtifactTypes.PropertyMetadata

-- Reads `inst[pm.name]`, returning a value directly comparable across
-- instances/snapshots (Enum -> .Value, Referent -> resolved target id via
-- globalIdMap, everything else -> raw value) plus whether that value is the
-- artifact-declared default.
--
-- `globalIdMap` maps `inst:GetDebugId()` -> assigned global id, used only to
-- resolve Referent-typed properties. Pass an empty table if the caller has
-- no id assignment yet (referent values will then resolve to 0 == default).
local function computeSerializedValue(
	inst: any,
	pm: PropertyMetadata,
	globalIdMap: { [string]: number }
): (any, boolean)
	local ok, val = pcall(function()
		return inst[pm.name]
	end)
	if not ok then
		val = nil
	end

	local serializedVal = val
	local isDefault = false

	if pm.codecId == 25 then -- Enum
		if typeof(val) == "EnumItem" then
			serializedVal = val.Value
		elseif type(val) == "number" then
			serializedVal = val
		end
		isDefault = (serializedVal == pm.default)
	elseif pm.codecId == 26 then -- Referent
		local targetId = 0
		if val then
			targetId = globalIdMap[val:GetDebugId()] or 0
		end
		serializedVal = targetId
		isDefault = (serializedVal == 0)
	else
		isDefault = (val == pm.default)
	end

	return serializedVal, isDefault
end

return {
	computeSerializedValue = computeSerializedValue,
}
