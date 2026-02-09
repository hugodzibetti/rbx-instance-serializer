local privateKey = require("./privateKey")

local namePrivateKey = function() end
local tracebackPrivateKey = function() end

local function errorUnauthorizedUse(self: StrictTable)
	local name = self[namePrivateKey]
	return error(
		`Unauthorized use of strict table '{name}'\nThis strict table({name}) was declared in '{tracebackPrivateKey}'`,
		2
	)
end

export type StrictTable = typeof(setmetatable(
	{} :: {
		[typeof(namePrivateKey)]: any		-- [typeof(privateKey)]: { [any]: any }, -- original table
	
},
	{} :: StrictTableImpl
))

type StrictTableImpl = {
	__index: (self: StrictTable, key: any) -> any,
	__newindex: (self: StrictTable, key: any, value: any) -> (),
	__tostring: (self: StrictTable) -> string,
	__iter: typeof(errorUnauthorizedUse),
	__metatable: typeof(errorUnauthorizedUse),
	__len: typeof(errorUnauthorizedUse)
}

local StrictTable = {} :: StrictTableImpl

StrictTable[privateKey] = {
	namePrivateKey,
	tracebackPrivateKey,
} -- exporting name private key and traceback private key

function StrictTable.__index(self, key)
	local name = self[namePrivateKey]
	local tbl = self[privateKey]
	local indexed: any = tbl[key]
	if indexed == nil then
		error(
			`Attempt to index an invalid member '{key}' of {name}\nThis strict table({name}) was declared in '{tracebackPrivateKey}'`,
			2
		)
	end
	if type(indexed) == "table" and indexed[privateKey] then
		return indexed.v
	end
	return indexed
end

function StrictTable.__newindex(self, key, value)
	local name = self[namePrivateKey]
	local tbl = self[privateKey]
	local indexed = tbl[key]
	if indexed == nil then
		error(
			`'{key}' is not a valid member of {name}\nThis strict table({name}) was declared in '{self[tracebackPrivateKey]}'`,
			2
		)
	end
	if type(indexed) ~= "table" then
		error(
			`Unable to mutate immutable property '{name}.{key}', as property '{key}' is not declared as mutable in {name}\nThis strict table({name}) was declared in '{self[tracebackPrivateKey]}'`,
			2
		)
	end
	local mutableTypeNameOrTypeChecker = indexed[privateKey]
	if mutableTypeNameOrTypeChecker then
		local mutableTypeNameOrTypeCheckerType = type(mutableTypeNameOrTypeChecker)
		if mutableTypeNameOrTypeCheckerType == "string" and typeof(value) ~= mutableTypeNameOrTypeChecker then
			error(
				`Unable to mutate mutable property '{name}.{key}'. {mutableTypeNameOrTypeCheckerType} expected, got {typeof(
					value
				)}\nThis strict table({name}) was declared in '{self[tracebackPrivateKey]}'`,
				2
			)
		end
		if mutableTypeNameOrTypeCheckerType == "function" and not mutableTypeNameOrTypeChecker(value) then
			error(
				`TypeError while mutating property '{key}' of {name}, got {typeof(value)}\nThis strict table({name}) was declared in '{self[tracebackPrivateKey]}'`,
				2
			)
		end
		indexed.v = value
	else
		error(
			`Unable to mutate immutable property '{name}.{key}', as property '{key}' is not declared as mutable in {name}\nThis strict table({name}) was declared in '{self[tracebackPrivateKey]}'`,
			2
		)
	end
end

function StrictTable.__tostring(self)
	return `{self[privateKey]}[strict table "{self[namePrivateKey]}"]`
end

StrictTable.__iter = errorUnauthorizedUse
StrictTable.__metatable = errorUnauthorizedUse
StrictTable.__len = errorUnauthorizedUse

return StrictTable
