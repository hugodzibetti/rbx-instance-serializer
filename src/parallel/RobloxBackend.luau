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

-- Returns true if running inside the real Roblox engine (where `task.desynchronize`
-- exists), false otherwise (e.g. under Lune, where it is nil). Pure existence
-- check on `task`; does NOT reference `script` or `game` here since those globals
-- don't exist when this module is required under Lune.
local function isActorParallelAvailable(): boolean
	return (task :: any).desynchronize ~= nil
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

	-- `script` here is this RobloxBackend ModuleScript; RobloxWorker is expected
	-- to be its sibling Instance in the deployed tree.
	local workerTemplate = script.Parent.RobloxWorker :: Script

	local coordinator = Instance.new("Actor")
	coordinator.Name = "ParallelCoordinator"
	coordinator.Parent = workspace

	local results: { buffer? } = table.create(n)
	local doneEvent = Instance.new("BindableEvent")
	local remaining = n

	coordinator:BindToMessage("Result", function(index: number, result: buffer)
		results[index] = result
		remaining -= 1
		if remaining == 0 then
			doneEvent:Fire()
		end
	end)

	local workers = table.create(n)
	for index, payload in payloads do
		local workerActor = Instance.new("Actor")
		workerActor.Name = "ParallelWorker_" .. tostring(index)
		workerActor.Parent = coordinator

		local workerScript = workerTemplate:Clone()
		workerScript.Parent = workerActor
		workerScript.Enabled = true

		workers[index] = workerActor
		workerActor:SendMessage(mode, coordinator, index, payload)
	end

	if remaining > 0 then
		doneEvent.Event:Wait()
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