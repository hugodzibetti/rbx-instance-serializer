local t = require("./types")
local buff = require("./buff")
local string = require("./string")
local enumItem = require("./enumItem")
local number = require("./f64")
local vec3 = require("./vec3")

local raycastResult: t.Converter<RaycastResult> = {}

function raycastResult.read()
    return {
        Distance = number.read(),
        Material = enumItem.read(),
        Position = vec3.read(),
        Normal = vec3.read()
    }
end

function raycastResult.write(v: RaycastResult)
    number.write(v.Distance)
    enumItem.write(v.Material)
    vec3.write(v.Position)
    vec3.write(v.Normal)

    return
end

function raycastResult.getLengthOf(v: RaycastResult)
    return number.getLengthOf(v.Distance) +
        enumItem.getLengthOf(v.Material) +
        vec3.getLengthOf(v.Position) +
        vec3.getLengthOf(v.Normal)
end

return raycastResult