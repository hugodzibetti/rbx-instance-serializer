local t = require(script.Parent:FindFirstChild('types'))
local number = require(script.Parent:FindFirstChild('f64'))

local dateTime: t.Converter<DateTime> = {}

function dateTime.read()
    return DateTime.fromUnixTimestampMillis(number.read())
end

function dateTime.write(v: DateTime)
    number.write(v.UnixTimestampMillis)
    return
end

function dateTime.getLengthOf(v: DateTime)
    return number.getLengthOf(v.UnixTimestampMillis)
end

return dateTime