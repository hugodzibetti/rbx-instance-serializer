local t = require("./types")
local array = require("./array")
local colorSequenceKeypoint = require("./colorSequenceKeypoint")

local arraySeq = array(colorSequenceKeypoint)

local colorSequence: t.Converter<ColorSequence> = {}

function colorSequence.read()
    return arraySeq.read()
end

function colorSequence.write(v: ColorSequence)
    arraySeq.write(v.Keypoints)

    return
end

function colorSequence.getLengthOf(v: ColorSequence)
    return arraySeq.getLengthOf(v)
end

return colorSequence