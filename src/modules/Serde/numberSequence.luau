local t = require("./types")
local array = require("./array")
local numberSequenceKeypoint = require("./numberSequenceKeypoint")

local arraySeq = array(numberSequenceKeypoint)

local numberSequence: t.Converter<NumberSequence> = {}

function numberSequence.read()
    return arraySeq.read()
end

function numberSequence.write(v: NumberSequence)
    arraySeq.write(v.Keypoints)

    return
end

function numberSequence.getLengthOf(v: NumberSequence)
    return arraySeq.getLengthOf(v)
end

return numberSequence