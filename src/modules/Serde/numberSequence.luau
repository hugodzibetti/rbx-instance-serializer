local t = require(script.Parent:FindFirstChild('types'))
local array = require(script.Parent:FindFirstChild('array'))
local numberSequenceKeypoint = require(script.Parent:FindFirstChild('numberSequenceKeypoint'))

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