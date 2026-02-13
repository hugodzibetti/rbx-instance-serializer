local t = require("@self/types")
local buff = require("@self/buff")
local custom = require("@self/custom")

local serde = {}

serde.bool = require("@self/bool")
serde.string = require("@self/string")
serde.number = require("@self/f64")
serde.vector3 = require("@self/vec3")
serde.vector2 = require("@self/vec2")
serde.cframe = require("@self/cframe")
serde.array = require("@self/array")
serde.dictionary = require("@self/dict")
serde.enumItem = require("@self/enumItem")
serde.option = require("@self/option")
serde.struct = require("@self/struct")
serde.color3 = require("@self/col3")
serde.instance = require("@self/instance")
serde.buffer = require("@self/buffer")
serde.axes = require("@self/axes")
serde.brickColor = require("@self/brickColor")
serde.catalogSearchParams = require("@self/catalogSearchParams")
serde.colorSequenceKeypoint = require("@self/colorSequenceKeypoint")
serde.colorSequence = require("@self/colorSequence")
serde.content = require("@self/content")
serde.dateTime = require("@self/dateTime")
serde.enums = require("@self/enums")
serde.faces = require("@self/faces")
serde.floatCurveKey = require("@self/floatCurveKey")
serde.font = require("@self/font")
serde.numberRange = require("@self/numberRange")
serde.numberSequenceKeypoint = require("@self/numberSequenceKeypoint")
serde.numberSequence = require("@self/numberSequence")
serde.overlapParams = require("@self/overlapParams")
serde.udim = require("@self/udim")
serde.udim2 = require("@self/udim2")
serde.path2dControlPoint = require("@self/path2dControlPoint")
serde.pathWaypoint = require("@self/pathWaypoint")
serde.physicalProperties = require("@self/physicalProperties")
serde.random = require("@self/random")
serde.ray = require("@self/ray")
serde.raycastParams = require("@self/raycastParams")
serde.raycastResult = require("@self/raycastResult")
serde.rbxScriptConnection = require("@self/rbxScriptConnection")
serde.rect = require("@self/rect")
serde.region3 = require("@self/region3")
serde.rotationCurveKey = require("@self/rotationCurveKey")
serde.tweenInfo = require("@self/tweenInfo")
serde.tuple = require("@self/tuple")

serde.custom = custom

export type CustomController<T> = custom.CustomController<T>
export type CursorController = custom.CursorController

--[[
    Serializes a value or set of values using the provided `Converter`.
    
    <strong>@generic <code>T</code></strong> ~ The value or set of values to be serialized.
    <strong>@param <code>converter</code></strong> ~ An object implementing the `Converter` interface for type `T`. Must provide a `.write(...)` method that writes to an internal buffer.
    <strong>@param <code>...T</code></strong> ~ One or more values of type `T` to serialize.
    <strong>@returns <code>buffer</code></strong> ~ A binary string representing the serialized data.
]]
function serde.serialize<T>(converter: t.Converter<T>, ...: T): buffer
    buff.release()
    converter.write(...)
    
    return buff.get()
end

--[[
    Deserializes data from a buffer into a value of type `T` using the provided `Converter`.
    
    <strong>@generic <code>T</code></strong> ~ The value or set of values to be serialized.
    <strong>@param <code>converter</code></strong> ~ An object implementing the `Converter` interface for type `T`. Must provide a `.read()` method that reconstructs the value from the internal buffer.
    <strong>@param <code>b</code></strong> ~ A binary string previously produced by `serde.serialize`.
    <strong>@returns <code>T</code></strong> ~ The deserialized value of type `T`.
]]
function serde.deserialize<T>(converter: t.Converter<T>, b: buffer): T
    buff.load(b)
    return converter.read()
end

return serde