local Store = require("@self/Store")
local Deleted = require("@self/Deleted")
local privateKey = require("@self/privateKey")
local StrictTable = require("@self/StrictTable")
local getTraceback = require("@self/getTraceback")

local inext = ipairs({})
local namePrivateKey = StrictTable[privateKey][1]
local tracebackPrivateKey = StrictTable[privateKey][2]

export type Store<T, K> = Store.Store<T, K>
export type Deleted<T> = Deleted.Deleted<T>

--[=[
	@class tableHelper
	@prop Store
	@prop Deleted

	# [table-helper-luau](https://pesde.dev/packages/caveful_games/table_helper)
	A collection of helpful table utility functions extending [TableUtil](https://sleitnick.github.io/RbxUtil/api/TableUtil/) from [RbxUtil](https://github.com/Sleitnick/RbxUtil) for luau

	Many of these functions are carried over from JavaScript or
	Python that are not present in Lua.

	Tables that only work specifically with arrays or dictionaries are marked as such in the documentation.

	:::info Immutability
	All functions (_except_ `swapRemove`, `swapRemoveFirstValue`, and `lock`) treat tables as immutable and will return
	copies of the given table(s) with the operations performed on the copies.
	:::
]=]
local tableHelper = {}

--[=[
	@within tableHelper

	Creates a table where each key is also a value. This is useful for creating a map where the keys are also the values.

	```lua
	local keyMap = tableHelper.createKeyMap(function(key)
		return {
			yourKey = key -- key is "yourKey"
		}
	end)
	```
]=]
function tableHelper.createKeyMap<T, K, V>(builder: (key: K) -> T & { [K]: V }): T
	if type(builder) ~= "function" then
		error("First argument must be a function")
	end
	local t = builder(true :: any)
	for key, _ in t :: any do
		(t :: any)[key] = key
	end

	return t
end

--[=[
	@within tableHelper

	Creates a table where each key is also a value. This is useful for creating a map where the keys are also the values.

	```lua
	local nameMap = tableHelper.createNameMap(function(name)
		return {
			yourName = name -- name is "yourName"
		}
	end)
	```
]=]
function tableHelper.createNameMap<T>(builder: (name: string) -> T & { [string]: string }): T
	if type(builder) ~= "function" then
		error("First argument must be a function")
	end
	local t = builder(true :: any)
	for key, _ in t :: any do
		(t :: any)[key] = key
	end

	return t
end

--[=[
	@within tableHelper

	Converts a set (a table where the keys are the values and the values are `true`) into an array.

	```lua
	local set = {A = true, B = true, C = true}
	local arr = tableHelper.setToArray(set)
	print(arr) --> {"A", "B", "C"}
	```
]=]
function tableHelper.setToArray<K>(set: { [K]: boolean }): { K }
	local arr = {}
	for k, v in set do
		if v then
			table.insert(arr, k)
		end
	end
	return arr
end

--[=[
	@within tableHelper

	Converts an array into a set (a table where the keys are the values and the values are `true`).

	```lua
	local arr = {"A", "B", "C"}
	local set = tableHelper.arrayToSet(arr)
	print(set) --> {A = true, B = true, C = true}
	```
]=]
function tableHelper.arrayToSet<K>(arr: { K }): { [K]: boolean }
	local set: { [K]: boolean } = {}
	for _, v: K in inext :: any, arr do
		set[v] = true
	end
	return set
end

--[=[
	@within tableHelper

	Sets a value at a given path in a table. If the path does not exist, it will create the path.

	```lua
	local t = {}
	tableHelper.set(t, {"a", "b", "c"}, 10)
	print(t) --> {a = {b = {c = 10}}}
	```
]=]
function tableHelper.set(t: {}, path: { any }, value: any)
	local current = t
	for i = 1, #path - 1 do
		local key = path[i]
		if not current[key] then
			current[key] = {}
		end
		current = current[key]
	end
	current[path[#path] ] = value
end

--[=[
	@within tableHelper

	Gets a value at a given path in a table. If the path does not exist, it will return `nil`.

	```lua
	local t = {a = {b = {c = 10}}}
	local value = tableHelper.get(t, {"a", "b", "c"})
	print(value) --> 10
	```
]=]
function tableHelper.get(t: {}, path: { any }): any?
	local current = t
	for i = 1, #path - 1 do
		local key = path[i]
		if not current[key] then
			return nil
		end
		current = current[key]
	end
	return current[path[#path] ]
end

--[=[
	@within tableHelper

	You can disable strict tables by setting this to `false`.

	Recommended to use with `_G.__DEV__`.

	```lua
	tableHelper.strictEnabled = false
	tableHelper.strictEnabled = _G.__DEV__ -- To disable strict tables in production
	```
]=]
tableHelper.strictEnabled = true

--[=[
	@within tableHelper

	Creates a strict table immutable by default.

	```lua
	tableHelper.strictEnabled = _G.__DEV__ -- To disable strict tables in production
	local t = tableHelper.strict({
		count = 0,
		message = tableHelper.mut("hello") :: string,
	})

	t.count += 1 -- Not allowed
	t.message = "world" -- Ok
	t.message = 10 -- Not allowed
	```
]=]
function tableHelper.strict<T>(tbl: T, name: string?): T
	if type(tbl) ~= "table" then
		error(`First argument must be a table, got {typeof(tbl)}`)
	end
	if name ~= nil and type(name) ~= "string" then
		error(`Second argument must be a string or nil, got {typeof(name)}`)
	end
	-- selene: allow(shadowing)
	local name = name or "*no-name*"
	-- if getmetatable(tbl) ~= nil then
	-- 	error("A table with a metatable cannot be a strict table")
	-- end

	if not tableHelper.strictEnabled then
		return tbl
	end

	-- 	local traceback = debug.traceback()
	-- 	local err = function()
	-- 		return error(
	-- 			`Attempted to access the strict table '{name}' incorrectly.\
	-- This strict table was created at '{traceback}'.\
	-- Ensure you are not trying to mutate an immutable field or access an invalid key.`,
	-- 			2
	-- 		)
	-- 	end

	return setmetatable({
		[privateKey] = tbl,
		[namePrivateKey] = name :: any,
		[tracebackPrivateKey] = getTraceback(nil, 2) :: any,
	}, StrictTable) :: any -- lying to the type checker :D
end

type TypeNameOrChecker = (
	"string"
	| "number"
	| "boolean"
	| "table"
	| "function"
	| "nil"
	| "thread"
	| "userdata"
	| "buffer"
	| "vector"
	| string
	| ((value: any) -> boolean
))?

--[=[
	@within tableHelper

	Marks a value as mutable in a strict table. This is useful for strict tables where you want to allow certain values to be mutated.

	```lua
	local t = tableHelper.strict({
		count = 0,
		message = tableHelper.mut("hello"),
		notInitializedThing = tableHelper.mut(nil, "string") :: string,
		cave = tableHelper.mut(Cave.new(), Cave.is) :: Cave,
	})

	t.message = "world" -- You can mutate this now!
	```
]=]
tableHelper.mut = function(value: any, typeNameOrChecker: TypeNameOrChecker): any
	if not tableHelper.strictEnabled then
		return value
	end
	if typeNameOrChecker ~= nil and type(typeNameOrChecker) ~= "string" and type(typeNameOrChecker) ~= "function" then
		error(`Second argument must be a string or function or nil, got {typeof(value)}`)
	end
	-- selene: allow(shadowing)
	local typeNameOrChecker = typeNameOrChecker or typeof(value)
	return {
		[privateKey] = typeNameOrChecker,
		v = value,
	}
end :: (<T>(value: T, typeNameOrChecker: nil) -> T) & ((value: any, typeNameOrChecker: TypeNameOrChecker) -> any)

-- TableUtil
-- Stephen Leitnick
-- September 13, 2017
-- Modified by jiwonz

--[=[
	@within tableHelper

	Creates a copy of the given table. By default, a shallow copy is
	performed. For deep copies, a second boolean argument must be
	passed to the function.

	:::caution No cyclical references

	Deep copies are _not_ protected against cyclical references. Passing
	a table with cyclical references _and_ the `deep` parameter set to
	`true` will result in a stack-overflow.

	:::
]=]













































































local function copy<T>(t: T, deep: boolean?): T
	if not deep then
		return (table.clone(t :: any) :: any) :: T
	end
	local function deepCopy(tbl: { any })
		local tCopy = table.clone(tbl)
		for k, v in tCopy do
			if type(v) == "table" then
				tCopy[k] = deepCopy(v)
			end
		end
		return tCopy
	end
	return deepCopy(t :: any) :: T
end

--[=[
	@within tableHelper

	Synchronizes the `srcTbl` based on the `templateTbl`. This will make
	sure that `srcTbl` has all of the same keys as `templateTbl`, including
	removing keys in `srcTbl` that are not present in `templateTbl`. This
	is a _deep_ operation, so any nested tables will be synchronized as
	well.

	```lua
	local template = {kills = 0, deaths = 0, xp = 0}
	local data = {kills = 10, experience = 12}
	data = tableHelper.sync(data, template)
	print(data) --> {kills = 10, deaths = 0, xp = 0}
	```

	:::caution Data Loss Warning

	This is a two-way sync, so the source table will have data
	_removed_ that isn't found in the template table. This can
	be problematic if used for player data, where there might
	be dynamic data added that isn't in the template.

	For player data, use `tableHelper.reconcile` instead.

	:::
]=]
local function sync<S, T>(srcTbl: S, templateTbl: T): T
	if type(srcTbl) ~= "table" then
		error(`First argument must be a table, got {typeof(srcTbl)}`)
	end
	if type(templateTbl) ~= "table" then
		error(`Second argument must be a table, got {typeof(templateTbl)}`)
	end

	local tbl = table.clone(srcTbl)

	-- If 'tbl' has something 'templateTbl' doesn't, then remove it from 'tbl'
	-- If 'tbl' has something of a different type than 'templateTbl', copy from 'templateTbl'
	-- If 'templateTbl' has something 'tbl' doesn't, then add it to 'tbl'
	for k, v in tbl do
		local vTemplate = templateTbl[k]

		-- Remove keys not within template:
		if vTemplate == nil then
			tbl[k] = nil

			-- Synchronize data types:
		elseif type(v) ~= type(vTemplate) then
			if type(vTemplate) == "table" then
				tbl[k] = copy(vTemplate, true)
			else
				tbl[k] = vTemplate
			end

			-- Synchronize sub-tables:
		elseif type(v) == "table" then
			tbl[k] = sync(v, vTemplate)
		end
	end

	-- Add any missing keys:
	for k, vTemplate in templateTbl do
		local v = tbl[k]

		if v == nil then
			if type(vTemplate) == "table" then
				tbl[k] = copy(vTemplate, true)
			else
				tbl[k] = vTemplate
			end
		end
	end

	return (tbl :: any) :: T
end

--[=[
	@within tableHelper

	Performs a one-way sync on the `source` table against the
	`template` table. Any keys found in `template` that are
	not found in `source` will be added to `source`. This is
	useful for syncing player data against data template tables
	to ensure players have all the necessary keys, while
	maintaining existing keys that may no longer be in the
	template.

	This is a deep operation, so nested tables will also be
	properly reconciled.

	```lua
	local template = {kills = 0, deaths = 0, xp = 0}
	local data = {kills = 10, abc = 20}
	local correctedData = tableHelper.reconcile(data, template)

	print(correctedData) --> {kills = 10, deaths = 0, xp = 0, abc = 20}
	```
]=]
local function reconcile<S, T>(src: S, template: T): S & T
	if type(src) ~= "table" then
		error(`First argument must be a table, got {typeof(src)}`)
	end
	if type(template) ~= "table" then
		error(`Second argument must be a table, got {typeof(template)}`)
	end

	local tbl = table.clone(src)

	for k, v in template do
		local sv = src[k]
		if sv == nil then
			if type(v) == "table" then
				tbl[k] = copy(v, true)
			else
				tbl[k] = v
			end
		elseif type(sv) == "table" then
			if type(v) == "table" then
				tbl[k] = reconcile(sv, v)
			else
				tbl[k] = copy(sv, true)
			end
		end
	end

	return (tbl :: any) :: S & T
end

--[=[
	@within tableHelper

	Removes index `i` in the table by swapping the value at `i` with
	the last value in the array, and then trimming off the last
	value from the array.

	This allows removal of the value at `i` in `O(1)` time, but does
	not preserve array ordering. If a value needs to be removed from
	an array, but ordering of the array does not matter, using
	`SwapRemove` is always preferred over `table.remove`.

	In the following example, we remove "B" at index 2. SwapRemove does
	this by moving the last value "E" over top of "B", and then trimming
	off "E" at the end of the array:
	```lua
	local t = {"A", "B", "C", "D", "E"}
	tableHelper.swapRemove(t, 2) -- Remove "B"
	print(t) --> {"A", "E", "C", "D"}
	```

	:::note Arrays only

	This function works on arrays, but not dictionaries.

	:::
]=]
local function swapRemove<T>(t: { T }, i: number)
	local n = #t
	t[i] = t[n]
	t[n] = nil
end

--[=[
	@within tableHelper

	Performs `table.find(tbl, v)` to find the index of the given
	value, and then performs `tableHelper.swapRemove` on that index.

	```lua
	local t = {"A", "B", "C", "D", "E"}
	tableHelper.swapRemoveFirstValue(t, "C")
	print(t) --> {"A", "B", "E", "D"}
	```

	:::note Arrays only

	This function works on arrays, but not dictionaries.

	:::
]=]
local function swapRemoveFirstValue<T>(t: { T }, v: T): number?
	local index: number? = table.find(t, v)
	if index then
		swapRemove(t, index)
	end
	return index
end

--[=[
	@within tableHelper

	Performs a map operation against the given table, which can be used to
	map new values based on the old values at given keys/indices.

	For example:

	```lua
	local t = {A = 10, B = 20, C = 30}
	local t2 = tableHelper.map(t, function(value)
		return value * 2
	end)
	print(t2) --> {A = 20, B = 40, C = 60}
	```
]=]
local function map<T, M>(t: { T }, f: (T, number, { T }) -> M): { M }
	if type(t) ~= "table" then
		error(`First argument must be a table, got {typeof(t)}`)
	end
	if type(f) ~= "function" then
		error(`Second argument must be a function, got {typeof(f)}`)
	end

	local newT = table.create(#t)
	for k, v in t do
		newT[k] = f(v, k, t)
	end

	return newT
end

--[=[
	@within tableHelper

	Performs a filter operation against the given table, which can be used to
	filter out unwanted values from the table.

	For example:

	```lua
	local t = {A = 10, B = 20, C = 30}
	local t2 = tableHelper.filter(t, function(value, key)
		return value > 15
	end)
	print(t2) --> {B = 40, C = 60}
	```
]=]
local function filter<T>(t: { T }, predicate: (T, any, { T }) -> boolean): { T }
	if type(t) ~= "table" then
		error(`First argument must be a table, got {typeof(t)}`)
	end
	if type(predicate) ~= "function" then
		error(`Second argument must be a function, got {typeof(predicate)}`)
	end

	local newT = table.create(#t)
	if #t > 0 then
		local n = 0
		for i, v in t do
			if predicate(v, i, t) then
				n += 1
				newT[n] = v
			end
		end
	else
		for k, v in t do
			if predicate(v, k, t) then
				newT[k] = v
			end
		end
	end

	return newT
end

--[=[
	@within tableHelper

	Performs a reduce operation against the given table, which can be used to
	reduce the table into a single value. This could be used to sum up a table
	or transform all the values into a compound value of any kind.

	For example:

	```lua
	local t = {10, 20, 30, 40}
	local result = tableHelper.reduce(t, function(accum, value)
		return accum + value
	end)
	print(result) --> 100
	```
]=]
local function reduce<T, R>(t: { T }, predicate: (R, T, any, { T }) -> R, init: R): R
	if type(t) ~= "table" then
		error(`First argument must be a table, got {typeof(t)}`)
	end
	if type(predicate) ~= "function" then
		error(`Second argument must be a function, got {typeof(predicate)}`)
	end

	local result = init :: R
	if #t > 0 then
		local start = 1
		if init == nil then
			result = (t[1] :: any) :: R
			start = 2
		end
		for i = start, #t do
			result = predicate(result, t[i], i, t)
		end
	else
		local start = nil
		if init == nil then
			result = (next(t) :: any) :: R
			start = result
		end
		for k, v in next, t, start :: any? do
			result = predicate(result, v, k, t)
		end
	end

	return result
end

--[=[
	@within tableHelper

	Copies all values of the given tables into the `target` table.

	```lua
	local t = {A = 10}
	local t2 = {B = 20}
	local t3 = {C = 30, D = 40}
	local newT = tableHelper.assign(t, t2, t3)
	print(newT) --> {A = 10, B = 20, C = 30, D = 40}
	```
]=]
local function assign<T>(target: { T }, ...: { any }): { T } & { any }
	local tbl = table.clone(target)
	for _, src in { ... } do
		for k, v in src do
			tbl[k] = v
		end
	end
	return tbl
end

--[=[
	@within tableHelper

	Extends the target array with the extension array.

	```lua
	local t = {10, 20, 30}
	local t2 = {30, 40, 50}
	local tNew = tableHelper.extend(t, t2)
	print(tNew) --> {10, 20, 30, 30, 40, 50}
	```

	:::note Arrays only

	This function works on arrays, but not dictionaries.

	:::
]=]
local function extend<T, E>(target: { T }, extension: { E }): { T } & { E }
	local tbl = table.clone(target) :: { any }
	for _, v in extension do
		table.insert(tbl, v)
	end
	return tbl
end

--[=[
	@within tableHelper

	Reverses the array.

	```lua
	local t = {1, 5, 10}
	local tReverse = tableHelper.reverse(t)
	print(tReverse) --> {10, 5, 1}
	```

	:::note Arrays only

	This function works on arrays, but not dictionaries.

	:::
]=]
local function reverse<T>(tbl: { T }): { T }
	local n = #tbl
	local tblRev = table.create(n)
	for i = 1, n do
		tblRev[i] = tbl[n - i + 1]
	end
	return tblRev
end

--[=[
	@within tableHelper

	Shuffles the table.

	```lua
	local t = {1, 2, 3, 4, 5, 6, 7, 8, 9}
	local shuffled = tableHelper.shuffle(t)
	print(shuffled) --> e.g. {9, 4, 6, 7, 3, 1, 5, 8, 2}
	```

	:::note Arrays only

	This function works on arrays, but not dictionaries.

	:::
]=]
local function shuffle<T>(tbl: { T }): { T }
	if type(tbl) ~= "table" then
		error(`First argument must be a table, got {typeof(tbl)}`)
	end

	local shuffled = table.clone(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	return shuffled
end

--[=[
	@within tableHelper

	Returns a random sample of the table.

	```lua
	local t = {1, 2, 3, 4, 5, 6, 7, 8, 9}
	local sample = tableHelper.sample(t, 3)
	print(sample) --> e.g. {6, 2, 5}
	```

	:::note Arrays only

	This function works on arrays, but not dictionaries.

	:::
]=]
local function sample<T>(tbl: { T }, size: number): { T }
	if type(tbl) ~= "table" then
		error(`First argument must be a table, got {typeof(tbl)}`)
	end
	if type(size) ~= "number" then
		error(`Second argument must be a number, got {typeof(size)}`)
	end

	-- If given table is empty, just return a new empty table:
	local len = #tbl
	if len == 0 then
		return {}
	end

	local shuffled = table.clone(tbl)
	local sampleTbl = table.create(size)

	-- Clamp sample size to be no larger than the given table size:
	size = math.clamp(size, 1, len)

	for i = 1, size do
		local j = math.random(i, len)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	table.move(shuffled, 1, size, 1, sampleTbl)

	return sampleTbl
end

--[=[
	@within tableHelper

	Returns a new table where all sub-arrays have been
	bubbled up to the top. The depth at which the scan
	is performed is dictated by the `depth` parameter,
	which is set to `1` by default.

	```lua
	local t = {{10, 20}, {90, 100}, {30, 15}}
	local flat = tableHelper.flat(t)
	print(flat) --> {10, 20, 90, 100, 30, 15}
	```

	:::note Arrays only

	This function works on arrays, but not dictionaries.

	:::
]=]
local function flat<T>(tbl: { T }, depth: number?): { T }
	local maxDepth: number = if type(depth) == "number" then depth else 1
	local flatTbl = table.create(#tbl)
	local function Scan(t: { any }, d: number)
		for _, v in t do
			if type(v) == "table" and d < maxDepth then
				Scan(v, d + 1)
			else
				table.insert(flatTbl, v)
			end
		end
	end
	Scan(tbl, 0)
	return flatTbl
end

--[=[
	@within tableHelper

	Calls `TableUtil.Map` on the given table and predicate, and then
	calls `TableUtil.Flat` on the result from the map operation.

	```lua
	local t = {10, 20, 30}
	local result = tableHelper.flatMap(t, function(value)
		return {value, value * 2}
	end)
	print(result) --> {10, 20, 20, 40, 30, 60}
	```

	:::note Arrays only

	This function works on arrays, but not dictionaries.

	:::
]=]
local function flatMap<T, M>(tbl: { T }, callback: (T, number, { T }) -> M): { M }
	return flat(map(tbl, callback))
end

--[=[
	@within tableHelper

	Returns an array with all the keys in the table.

	```lua
	local t = {A = 10, B = 20, C = 30}
	local keys = tableHelper.keys(t)
	print(keys) --> {"A", "B", "C"}
	```

	:::caution Ordering

	The ordering of the keys is never guaranteed. If order is imperative, call
	`table.sort` on the resulting `keys` array.
	```lua
	local keys = tableHelper.keys(t)
	table.sort(keys)
	```

	:::
]=]
local function keys<K, V>(tbl: { [K]: V }): { K }
	local keysTbl = table.create(#tbl)
	for k in tbl do
		table.insert(keysTbl, k)
	end
	return keysTbl
end

--[=[
	@within tableHelper

	Returns an array with all the values in the table.

	```lua
	local t = {A = 10, B = 20, C = 30}
	local values = tableHelper.values(t)
	print(values) --> {10, 20, 30}
	```

	:::caution Ordering

	The ordering of the values is never guaranteed. If order is imperative, call
	`table.sort` on the resulting `values` array.
	```lua
	local values = tableHelper.values(t)
	table.sort(values)
	```

	:::
]=]
local function values<K, V>(tbl: { [K]: V }): { V }
	local valuesTbl = table.create(#tbl)
	for _, v in tbl do
		table.insert(valuesTbl, v)
	end
	return valuesTbl
end

--[=[
	@within tableHelper

	Performs a linear scan across the table and calls `callback` on
	each item in the array. Returns the value and key of the first
	pair in which the callback returns `true`.

	```lua
	local t = {
		{Name = "Bob", Age = 20};
		{Name = "Jill", Age = 30};
		{Name = "Ann", Age = 25};
	}

	-- Find first person who has a name starting with J:
	local firstPersonWithJ = tableHelper.find(t, function(person)
		return person.Name:sub(1, 1):lower() == "j"
	end)

	print(firstPersonWithJ) --> {Name = "Jill", Age = 30}
	```

	:::caution Dictionary Ordering

	While `find` can also be used with dictionaries, dictionary ordering is never
	guaranteed, and thus the result could be different if there are more
	than one possible matches given the data and callback function.

	:::
]=]
local function find<K, V>(tbl: { [K]: V }, callback: (V, K, { [K]: V }) -> boolean): (V?, K?)
	for k, v in tbl do
		if callback(v, k, tbl) then
			return v, k
		end
	end
	return nil, nil
end

--[=[
	@within tableHelper

	Returns `true` if the `callback` also returns `true` for _every_
	item in the table.

	```lua
	local t = {10, 20, 40, 50, 60}

	local allAboveZero = tableHelper.every(t, function(value)
		return value > 0
	end)

	print("All above zero:", allAboveZero) --> All above zero: true
	```
]=]
local function every<K, V>(tbl: { [K]: V }, callback: (V, K, { [K]: V }) -> boolean): boolean
	for k, v in tbl do
		if not callback(v, k, tbl) then
			return false
		end
	end
	return true
end

--[=[
	@within tableHelper

	Returns `true` if the `callback` also returns `true` for _at least
	one_ of the items in the table.

	```lua
	local t = {10, 20, 40, 50, 60}

	local someBelowTwenty = tableHelper.some(t, function(value)
		return value < 20
	end)

	print("Some below twenty:", someBelowTwenty) --> Some below twenty: true
	```
]=]
local function some<K, V>(tbl: { [K]: V }, callback: (V, K, { [K]: V }) -> boolean): boolean
	for k, v in tbl do
		if callback(v, k, tbl) then
			return true
		end
	end
	return false
end

--[=[
	@within tableHelper

	Returns a new table truncated to the length of `length`. Any length
	equal or greater than the current length will simply return a
	shallow copy of the table.

	```lua
	local t = {10, 20, 30, 40, 50, 60, 70, 80}
	local tTruncated = tableHelper.truncate(t, 3)
	print(tTruncated) --> {10, 20, 30}
	```
]=]
local function truncate<T>(tbl: { T }, len: number): { T }
	local n = #tbl
	len = math.clamp(len, 1, n)
	return if len == n then table.clone(tbl) else table.move(tbl, 1, len, 1, table.create(len))
end

--[=[
	@within tableHelper

	Returns an iterator that can scan through multiple tables at the same time side-by-side, matching
	against shared keys/indices.

	```lua
	local t1 = {10, 20, 30, 40, 50}
	local t2 = {60, 70, 80, 90, 100}

	for key,values in tableHelper.zip(t1, t2) do
		print(key, values)
	end

	--[[
		Outputs:
		1 {10, 60}
		2 {20, 70}
		3 {30, 80}
		4 {40, 90}
		5 {50, 100}
	--]]
	```
]=]
local function zip(...: { [any]: any }): ((t: { any }, k: any) -> (any, any), { any }, any)
	if select("#", ...) <= 0 then
		error("Must supply at least 1 table")
	end

	local function zipIteratorArray(all: { any }, k: number): (number?, { any }?)
		k += 1
		local valuesTbl = {}
		for i, t in all do
			local v = t[k]
			if v ~= nil then
				valuesTbl[i] = v
			else
				return nil, nil
			end
		end
		return k, valuesTbl
	end

	local function zipIteratorMap(all: { [any]: any }, k: any): (number?, { any }?)
		local valuesTbl = {}
		for i, t in all do
			local v = next(t, k)
			if v ~= nil then
				valuesTbl[i] = v
			else
				return nil, nil
			end
		end
		return k, valuesTbl
	end

	local all = { ... }
	if #all[1] > 0 then
		return zipIteratorArray, all, 0
	else
		return zipIteratorMap, all, nil
	end
end

--[=[
	@within tableHelper

	Locks the table using `table.freeze`, as well as any
	nested tables within the given table. This will lock
	the whole deep structure of the table, disallowing any
	further modifications.

	```lua
	local tbl = {xyz = {abc = 32}}
	tbl.xyz.abc = 28 -- Works fine
	tableHelper.lock(tbl)
	tbl.xyz.abc = 64 -- Will throw an error (cannot modify readonly table)
	```
]=]
local function lock<T>(tbl: T): T
	local function freeze(t: { [any]: any })
		for k, v in pairs(t) do
			if type(v) == "table" then
				t[k] = freeze(v)
			end
		end
		return table.freeze(t)
	end
	return freeze(tbl :: any)
end

--[=[
	@within tableHelper

	Returns `true` if the given table is empty. This is
	simply performed by checking if `next(tbl)` is `nil`
	and works for both arrays and dictionaries. This is
	useful when needing to check if a table is empty but
	not knowing if it is an array or dictionary.

	```lua
	tableHelper.isEmpty({}) -- true
	tableHelper.isEmpty({"abc"}) -- false
	tableHelper.isEmpty({abc = 32}) -- false
	```
]=]
local function isEmpty(tbl: { any }): boolean
	return next(tbl) == nil
end

tableHelper.Store = Store
tableHelper.Deleted = Deleted
tableHelper.copy = copy
tableHelper.sync = sync
tableHelper.reconcile = reconcile
tableHelper.swapRemove = swapRemove
tableHelper.swapRemoveFirstValue = swapRemoveFirstValue
tableHelper.map = map
tableHelper.filter = filter
tableHelper.reduce = reduce
tableHelper.assign = assign
tableHelper.extend = extend
tableHelper.reverse = reverse
tableHelper.shuffle = shuffle
tableHelper.sample = sample
tableHelper.flat = flat
tableHelper.flatMap = flatMap
tableHelper.keys = keys
tableHelper.values = values
tableHelper.find = find
tableHelper.every = every
tableHelper.some = some
tableHelper.truncate = truncate
tableHelper.zip = zip
tableHelper.lock = lock
tableHelper.isEmpty = isEmpty

return tableHelper
