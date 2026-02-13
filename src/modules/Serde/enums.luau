local t = require("./types")

local random: t.Converter<Random> = {}

function random.read()
    return Random
end

function random.write(v: Random)
    return
end

function random.getLengthOf(v: Random)
    return 0
end

return random