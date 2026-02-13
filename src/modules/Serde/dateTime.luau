local t = require("./types")
local number = require("./f64")

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