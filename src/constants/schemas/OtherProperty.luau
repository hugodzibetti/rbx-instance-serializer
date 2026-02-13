local Serde = require("./Serde")
local struct = Serde.struct
local number = Serde.number

return struct({
	number, -- id
	Serde.buffer, -- value
})
