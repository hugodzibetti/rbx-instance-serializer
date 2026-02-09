export type Store<T, K = any> = ((key: K) -> T) & {
	[K]: T,
	constructor: () -> T,
	filter: ((key: K) -> K?)?
}

--[=[
	@class Store

	Simple key-value store that lazily initializes a table.

	```lua
	local Store = require("Store")

	local store = Store.new(function()
		return {
			key = "value"
		}
	end)

	local value = store("storeKey") -- { key = "value" }
	```
]=]
type StoreImpl = {
	__index: StoreImpl,
	--[=[
		@within Store

		Constructs a new value for the given key. Gets the value if it already exists.

		```lua
		local value = store("storeKey")
		```
	]=]
	__call: <T, K>(self: Store<T, K>, key: K) -> T,
	--[=[
		@within Store

		Creates a new store.

		```lua
		local store = Store.new(function()
			return {
				key = "value"
			}
		end)
		```
	]=]
	new: <T, K>(constructor: () -> T) -> Store<T, K>
}

local Store = {} :: StoreImpl

function Store.new(constructor)
	if type(constructor) ~= "function" then
		error("Store.new expects a constructor function")
	end
	local store = setmetatable({
		constructor = constructor,
	}, Store)
	table.freeze(store)
	return store :: any
end

function Store.__call(self, key)
	if self.filter then
		local filteredKey = self.filter(key)
		if not filteredKey then
			error(`Store filter returned 'nil', which means the key('{key}') is invalid`)
		end
		key = filteredKey
	end
	local value = (self :: any)[key]
	if value then
		return value
	end
	value = self.constructor();
	(self :: any)[key] = value
	return value
end

return Store
