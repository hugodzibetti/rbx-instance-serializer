local t = require("./types")
local string = require("./string")
local enumItem = require("./enumItem")
local bool = require("./bool")

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