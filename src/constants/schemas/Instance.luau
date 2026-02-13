local InstanceIdProperty = require("./InstanceIdProperty")
local OtherProperty = require("./OtherProperty")
local Serde = require("./Serde")
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
