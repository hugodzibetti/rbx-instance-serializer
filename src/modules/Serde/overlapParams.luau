local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local string = require(script.Parent:FindFirstChild('string'))
local enumItem = require(script.Parent:FindFirstChild('enumItem'))
local number = require(script.Parent:FindFirstChild('f64'))
local bool = require(script.Parent:FindFirstChild('bool'))

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