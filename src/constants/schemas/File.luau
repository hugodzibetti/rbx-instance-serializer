local InstanceSchema = require(script.Parent:FindFirstChild('Instance'))
local Serde = require(script.Parent.Parent.Parent:FindFirstChild('modules'):FindFirstChild('Serde'))
local struct = Serde.struct
local array = Serde.array
local number = Serde.number

return struct({
	number, -- roblox version id

	array(InstanceSchema),
})
