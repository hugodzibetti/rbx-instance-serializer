local Process = require("@self/Process")
local Schema = require("@self/Schema")
local Processed = require("@self/Processed")
local Serde = require(script.Parent.Parent:FindFirstChild('modules'):FindFirstChild('serde'))

return Serde.deserialize(Schema, Processed):: typeof(Process)