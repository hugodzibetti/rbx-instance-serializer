local t = require(script.Parent:FindFirstChild('types'))
local string = require(script.Parent:FindFirstChild('string'))
local enumItem = require(script.Parent:FindFirstChild('enumItem'))
local bool = require(script.Parent:FindFirstChild('bool'))

local font: t.Converter<Font> = {}

function font.read()
    local fnt = Font.new(string.read(), enumItem.read(), enumItem.read())
    fnt.Bold = bool.read()
    
    return fnt
end

function font.write(v: Font)
    string.write(v.Family)
    enumItem.write(v.Weight)
    enumItem.write(v.Style)
    bool.write(v.Bold)

    return
end

function font.getLengthOf(v: Font)
    return string.getLengthOf(v.Family) +
        enumItem.getLengthOf(v.Weight) +
        enumItem.getLengthOf(v.Style) +
        bool.getLengthOf(v.Bold)
end

return font