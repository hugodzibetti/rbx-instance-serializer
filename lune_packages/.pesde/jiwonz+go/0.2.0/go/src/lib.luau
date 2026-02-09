--!native

-- source credit to https://github.com/lukadev-0/util.luau/blob/main/packages/threadpool/init.luau

local task = require("@pkg/task")

local freeThreads: { thread } = {}

local function run<A...>(f: (A...) -> (), thread: thread, ...)
	f(...)
	table.insert(freeThreads, thread)
end

local function yielder()
	while true do
		run(coroutine.yield())
	end
end

--[=[
	Executes the given function in a separate thread, threads are pooled and reused.

	```lua
	local t: thread = go(function()
		task.wait(2)
		print("Hello, World!")
	end)
	```
]=]
return function<A...>(f: (A...) -> (), ...: A...): thread
	local thread
	if #freeThreads > 0 then
		thread = freeThreads[#freeThreads]
		freeThreads[#freeThreads] = nil
	else
		thread = coroutine.create(yielder)
		coroutine.resume(thread)
	end

	return task.spawn(thread, f, thread, ...)
end
