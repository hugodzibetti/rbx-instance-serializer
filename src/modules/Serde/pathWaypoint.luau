local t = require(script.Parent:FindFirstChild('types'))
local buff = require(script.Parent:FindFirstChild('buff'))
local vec3 = require(script.Parent:FindFirstChild('vec3'))
local string = require(script.Parent:FindFirstChild('string'))
local enumItem = require(script.Parent:FindFirstChild('enumItem'))
local option = require(script.Parent:FindFirstChild('option'))

local optionString = option(string)

local pathWaypoint: t.Converter<PathWaypoint> = {}

function pathWaypoint.read()
    return PathWaypoint.new(vec3.read(), enumItem.read(), optionString.read())
end

function pathWaypoint.write(v: PathWaypoint)
    vec3.write(v.Position)
    enumItem.write(v.Action)
    optionString.write(v.Label)

    return
end

function pathWaypoint.getLengthOf(v: PathWaypoint)
    return vec3.getLengthOf(v.Position) +
        enumItem.getLengthOf(v.Action) +
        optionString.getLengthOf(v.Label)
end

return pathWaypoint