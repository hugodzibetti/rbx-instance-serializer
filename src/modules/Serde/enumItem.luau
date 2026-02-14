local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local string = require(script.Parent:FindFirstChild('string'))
local enum = require(script.Parent:FindFirstChild('enum'))

local enumItem: t.Converter<EnumItem> = {}

function enumItem.read()
    return enum.read()[string.read()]
end

function enumItem.write(v: EnumItem)
    enum.write(v.EnumType)
    string.write(v.Name)

    return
end

function enumItem.getLengthOf(v: EnumItem)
    return #v.Name + 4 + enum.getLengthOf(v.EnumType)
end

return enumItem