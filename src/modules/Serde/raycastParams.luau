local t = require("./types")
local buff = require("./buff")
local string = require("./string")
local enumItem = require("./enumItem")
local number = require("./f64")
local bool = require("./bool")

local raycastParams: t.Converter<RaycastParams> = {}

function raycastParams.read()
    local params = RaycastParams.new()
    params.FilterType = enumItem.read()
    params.IgnoreWater = bool.read()
    params.CollisionGroup = string.read()
    params.RespectCanCollide = bool.read()
    params.BruteForceAllSlow = bool.read()
    
    return params
end

function raycastParams.write(v: RaycastParams)
    enumItem.write(v.FilterType)
    bool.write(v.IgnoreWater)
    string.write(v.CollisionGroup)
    bool.write(v.RespectCanCollide)
    bool.write(v.BruteForceAllSlow)

    return
end

function raycastParams.getLengthOf(v: RaycastParams)
    return enumItem.getLengthOf(v.FilterType) +
        bool.getLengthOf(v.IgnoreWater) +
        string.getLengthOf(v.CollisionGroup) +
        bool.getLengthOf(v.RespectCanCollide) +
        bool.getLengthOf(v.BruteForceAllSlow)
end

return raycastParams