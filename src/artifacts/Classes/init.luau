local Process = require("@self/Process")
local Schema = require("@self/Schema")
local Processed = require("@self/Processed")
local Serde = require("@src/modules/serde")

return Serde.deserialize(Schema, Processed):: typeof(Process)