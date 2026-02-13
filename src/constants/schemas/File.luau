local InstanceSchema = require("./Instance")
local Serde = require("./Serde")
local struct = Serde.struct
local array = Serde.array
local number = Serde.number

return struct({
	number, -- roblox version id

	array(InstanceSchema),
})
