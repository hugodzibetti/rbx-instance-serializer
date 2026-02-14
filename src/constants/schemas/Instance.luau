local InstanceIdProperty = require(script.Parent:FindFirstChild('InstanceIdProperty'))
local OtherProperty = require(script.Parent:FindFirstChild('OtherProperty'))
local Serde = require(script.Parent.Parent.Parent:FindFirstChild('modules'):FindFirstChild('Serde'))
local struct = Serde.struct
local array = Serde.array
local number = Serde.number

return struct({
	number, -- class id

	-- other properties array
	array(OtherProperty),

	-- instace valued properties array
	array(InstanceIdProperty),
})
