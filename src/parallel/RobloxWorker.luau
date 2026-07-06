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

actor:BindToMessageParallel("Encode", function(coordinator, index, payload)
	local result = Payload.encode(payload)
	coordinator:SendMessage("Result", index, result)
end)

actor:BindToMessageParallel("Decode", function(coordinator, index, payload)
	local result = Payload.decode(payload)
	coordinator:SendMessage("Result", index, result)
end)