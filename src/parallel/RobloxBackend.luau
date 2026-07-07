--!strict
-- Roblox Actor + Parallel Luau backend for per-class-block payload encode/decode.
-- Mirrors the Lune `src/parallel/Worker.luau` child-process MVP shape (one worker
-- per class block, no pooling), but uses real Roblox Actors + `task.desynchronize`
-- for use when this code runs inside the actual Roblox engine (where `@lune/process`
-- doesn't exist).
--
-- Lune tests exercise ONLY the fallback path (isActorParallelAvailable() == false),
-- which calls Payload.encode/decode directly - byte-identical to the Actor path
-- since both run the same Payload calls. The Actor-spawning branch is guarded and
-- never runs under Lune.

local Payload = require("@src/parallel/Payload")

export type RobloxBackend = {
	isActorParallelAvailable: () -> boolean,
	encodeClassBlocksParallel: (payloads: { buffer }) -> { buffer },
	decodeClassBlocksParallel: (payloads: { buffer }) -> { buffer },
}

-- Returns true if running inside the real Roblox engine (where `task` is a global
-- with a `desynchronize` field), false otherwise (e.g. under Lune, where `task`
-- isn't a global at all - only available via `require("@lune/task")` - so indexing
-- it would raise "attempt to index nil"; pcall turns that into a clean `false`).
local function isActorParallelAvailable(): boolean
	local ok, hasDesynchronize = pcall(function()
		return (task :: any).desynchronize ~= nil
	end)
	return ok and hasDesynchronize == true
end

local function runFallback(payloads: { buffer }, mode: "encode" | "decode"): { buffer }
	local results = table.create(#payloads)
	for i, p in payloads do
		results[i] = if mode == "encode" then Payload.encode(p) else Payload.decode(p)
	end
	return results
end

-- Actor-spawning path: runs ONLY when isActorParallelAvailable() is true, i.e.
-- inside the real Roblox engine. References to `script`/`game` are confined to
-- this function body so the module loads cleanly under Lune.
local function runActorParallel(payloads: { buffer }, mode: "encode" | "decode"): { buffer }
	local n = #payloads
	if n == 0 then
		return {}
	end

	-- `script` here is this RobloxBackend ModuleScript; RobloxWorker/Payload are
	-- expected to be its sibling Instances in the deployed tree. Cloning Payload
	-- alongside RobloxWorker into each worker Actor keeps them siblings after the
	-- clone too, so RobloxWorker.luau's `require(script.Parent.Payload)` still
	-- resolves once it's living under the new Actor instead of its original parent.
	local workerTemplate = script.Parent.RobloxWorker :: Script
	local payloadTemplate = script.Parent.Payload :: ModuleScript

	local coordinator = Instance.new("Actor")
	coordinator.Name = "ParallelCoordinator"
	coordinator.Parent = workspace

	local results: { buffer? } = table.create(n)
	local errors: { string? } = table.create(n)
	local doneEvent = Instance.new("BindableEvent")
	local remaining = n

	coordinator:BindToMessage("Result", function(index: number, result: buffer)
		results[index] = result
		remaining -= 1
		if remaining == 0 then
			doneEvent:Fire()
		end
	end)

	coordinator:BindToMessage("Error", function(index: number, message: string)
		errors[index] = message
		remaining -= 1
		if remaining == 0 then
			doneEvent:Fire()
		end
	end)

	-- Ready handshake: each worker replies "Ready" only once its parallel message
	-- handlers are actually bound, closing the race where an "Encode"/"Decode"
	-- message sent immediately after cloning could otherwise be dropped.
	local readyRemaining = n
	local readyEvent = Instance.new("BindableEvent")
	coordinator:BindToMessage("Ready", function(_workerActor: Actor)
		readyRemaining -= 1
		if readyRemaining == 0 then
			readyEvent:Fire()
		end
	end)

	local workerActors = table.create(n)
	for index, _ in payloads do
		local workerActor = Instance.new("Actor")
		workerActor.Name = "ParallelWorker_" .. tostring(index)
		workerActor.Parent = coordinator

		payloadTemplate:Clone().Parent = workerActor

		local workerScript = workerTemplate:Clone()
		workerScript.Parent = workerActor
		workerScript.Enabled = true

		workerActors[index] = workerActor
		workerActor:SendMessage("Init", coordinator)
	end

	if readyRemaining > 0 then
		readyEvent.Event:Wait()
	end
	readyEvent:Destroy()

	for index, payload in payloads do
		workerActors[index]:SendMessage(mode, coordinator, index, payload)
	end

	if remaining > 0 then
		doneEvent.Event:Wait()
	end
	doneEvent:Destroy()

	for i = 1, n do
		if errors[i] then
			coordinator:Destroy()
			error(string.format("Roblox Actor parallel %s failed at index %d: %s", mode, i, errors[i] :: string))
		end
	end

	local out: { buffer } = table.create(n)
	for i = 1, n do
		out[i] = results[i] :: buffer
	end

	coordinator:Destroy()
	return out
end

local function dispatch(payloads: { buffer }, mode: "encode" | "decode"): { buffer }
	if isActorParallelAvailable() then
		return runActorParallel(payloads, mode)
	end
	return runFallback(payloads, mode)
end

local RobloxBackend: RobloxBackend = {
	isActorParallelAvailable = isActorParallelAvailable,
	encodeClassBlocksParallel = function(payloads: { buffer }): { buffer }
		return dispatch(payloads, "encode")
	end,
	decodeClassBlocksParallel = function(payloads: { buffer }): { buffer }
		return dispatch(payloads, "decode")
	end,
}

return RobloxBackend