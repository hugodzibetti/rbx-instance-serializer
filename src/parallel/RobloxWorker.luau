--!strict
-- Actor worker Script template: parent this under an `Actor` instance in a Roblox
-- place (NOT a ModuleScript). Follows the standard Roblox "Actor worker" pattern:
-- https://create.roblox.com/docs/scripting/multithreading
--
-- Uses Instance-relative require (`script.Parent.Payload`) rather than the `@src`
-- alias because darklua rewrites `@src` requires inside ModuleScripts that are
-- required as modules, but this Script is cloned into an Actor (not required as a
-- module), so darklua won't rewrite requires inside it the same way. At Roblox
-- runtime `RobloxWorker` and `Payload` are sibling Instances after conversion, so
-- `script.Parent.Payload` resolves correctly.

local actor = script:GetActor()
if actor == nil then
	return
end

local Payload = require(script.Parent.Payload)

-- Ready handshake: RobloxBackend sends "Init" with the coordinator reference right
-- after cloning/parenting this script, but the clone needs a moment to reach this
-- point and register its BindToMessageParallel handlers below. Replying "Ready"
-- only once those handlers exist closes the race where an "Encode"/"Decode"
-- message sent too early would otherwise be dropped (event bindings don't queue
-- messages sent before a handler is bound).
actor:BindToMessage("Init", function(coordinator)
	coordinator:SendMessage("Ready", actor)
end)

actor:BindToMessageParallel("Encode", function(coordinator, index, payload)
	local ok, result = pcall(Payload.encode, payload)
	if ok then
		coordinator:SendMessage("Result", index, result)
	else
		coordinator:SendMessage("Error", index, tostring(result))
	end
end)

actor:BindToMessageParallel("Decode", function(coordinator, index, payload)
	local ok, result = pcall(Payload.decode, payload)
	if ok then
		coordinator:SendMessage("Result", index, result)
	else
		coordinator:SendMessage("Error", index, tostring(result))
	end
end)