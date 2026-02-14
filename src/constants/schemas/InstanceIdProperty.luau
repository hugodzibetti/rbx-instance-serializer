local Serde = require(script.Parent.Parent.Parent:FindFirstChild('modules'):FindFirstChild('Serde'))
local struct = Serde.struct
local number = Serde.number

return struct({
	number,
	Serde.buffer,
})
