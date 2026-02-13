local t = require("./types")
local buff = require("./buff")
local string = require("./string")
local enumItem = require("./enumItem")
local number = require("./f64")
local bool = require("./bool")

local overlapParams: t.Converter<OverlapParams> = {}

function overlapParams.read()
    local params = OverlapParams.new()
    params.FilterType = enumItem.read()
    params.MaxParts = number.read()
    params.CollisionGroup = string.read()
    params.RespectCanCollide = bool.read()
    params.BruteForceAllSlow = bool.read()
    
    return params
end

function overlapParams.write(v: OverlapParams)
    enumItem.write(v.FilterType)
    number.write(v.MaxParts)
    string.write(v.CollisionGroup)
    bool.write(v.RespectCanCollide)
    bool.write(v.BruteForceAllSlow)

    return
end

function overlapParams.getLengthOf(v: OverlapParams)
    return enumItem.getLengthOf(v.FilterType) +
        number.getLengthOf(v.MaxParts) +
        string.getLengthOf(v.CollisionGroup) +
        bool.getLengthOf(v.RespectCanCollide) +
        bool.getLengthOf(v.BruteForceAllSlow)
end

return overlapParams