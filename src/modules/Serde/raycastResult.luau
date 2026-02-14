local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local string = require(script.Parent:FindFirstChild('string'))
local enumItem = require(script.Parent:FindFirstChild('enumItem'))
local number = require(script.Parent:FindFirstChild('f64'))
local vec3 = require(script.Parent:FindFirstChild('vec3'))

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