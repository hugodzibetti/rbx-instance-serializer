local t = require("./types")
local buff = require("./buff")
local string = require("./string")
local enum = require("./enum")

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