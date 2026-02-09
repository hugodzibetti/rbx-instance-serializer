local getTraceback = require("./getTraceback")

export type Deleted<T> = typeof(setmetatable(
	{} :: {
		_mt: {}?,
		impl: { __index: any? },
		name: string,
		traceback: string	
},
	{} :: DeletedImpl
))

--[=[
	@class Deleted

	Makes an object that throws an error when a method is called on it.

	Heavily inspired by `errorTable` in [ffrostfall's luausignal](https://github.com/ffrostfall/luausignal/blob/77d6d8ace5809c5f3bd8b3417472a7130fd82c80/src/init.luau#L213)

	```lua
	local Class = {}
	Class.__index = Class

	local deleted = Deleted.new(Class, "Class")

	function Class.new()
		return setmetatable({}, Class)
	end

	function Class.doSomething(self)
		-- do something
	end

	function Class.delete(self)
		deleted:setmetatable(self)
	end

	local class = Class.new()
	class:doSomething() -- works
	Class:delete()
	class:doSomething() -- error
	```
]=]
type DeletedImpl = {
	__index: DeletedImpl,
	--[=[
		@within Deleted

		Creates a new deleted object.

		```lua
		local deleted = Deleted.new(ClassImpl, "ClassName") :: Deleted<ClassType>
		```
	]=]
	new: (impl: { __index: any }, name: string) -> Deleted<any>,
	--[=[
		@within Deleted

		Sets the metatable of an object to the deleted object.

		```lua
		deleted:setmetatable(object)
		```
	]=]
	setmetatable: <T>(self: Deleted<T>, constructed: T) -> ()
}

local Deleted = {} :: DeletedImpl
Deleted.__index = Deleted

function Deleted.new(impl, name)
	return setmetatable({
		impl = impl,
		name = name,
		traceback = getTraceback(nil, 2),
	}, Deleted)
end

function Deleted.setmetatable(self, constructed)
	local mt = self._mt
	if not mt then
		local newMt = table.clone(self.impl)
		local traceback = getTraceback(nil, 2)
		local err = function()
			return error(
				`Attempt to call a method of a deleted object '{self.name}'\n'{self.name}' was deleted in '{traceback}' and this tableHelper.Deleted was declared in '{self.traceback}'`,
				2
			)
		end

		for key, value in newMt do
			if type(value) == "function" then
				newMt[key] = err
			else
				newMt[key] = nil
			end
		end
		newMt.__index = newMt

		mt = newMt
	end

	setmetatable(constructed, mt)
end

return Deleted
