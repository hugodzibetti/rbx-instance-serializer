local t = require("./types")
local number = require("./f64")

local numberSequenceKeypoint: t.Converter<NumberSequenceKeypoint> = {}

function numberSequenceKeypoint.read()
    return NumberSequenceKeypoint.new(
        number.read(),
        number.read(),
        number.read()
    )
end

function numberSequenceKeypoint.write(v: NumberSequenceKeypoint)
    number.write(v.Time)
    number.write(v.Value)
    number.write(v.Envelope)
    
    return
end

function numberSequenceKeypoint.getLengthOf(v: NumberSequenceKeypoint)
    return number.getLengthOf(v.Time) +
        number.getLengthOf(v.Value) +
        number.getLengthOf(v.Envelope)
end

return numberSequenceKeypoint