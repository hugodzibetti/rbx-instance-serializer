local t = require("./types")
local buff = require("./buff")
local number = require("./f64")
local enumItem = require("./enumItem")
local bool = require("./bool")

local tweenInfo: t.Converter<TweenInfo> = {}

function tweenInfo.read()
    return TweenInfo.new(
        number.read(),
        enumItem.read(),
        enumItem.read(),
        number.read(),
        bool.read(),
        number.read()
    )
end

function tweenInfo.write(v: TweenInfo)
    number.write(v.Time)
    enumItem.write(v.EasingStyle)
    enumItem.write(v.EasingDirection)
    number.write(v.RepeatCount)
    bool.write(v.RepeatCount)
    number.write(v.DelayTime)

    return
end

function tweenInfo.getLengthOf(v: TweenInfo)
    return number.getLengthOf(v.Time) +
        enumItem.getLengthOf(v.EasingStyle) +
        enumItem.getLengthOf(v.EasingDirection) +
        number.getLengthOf(v.RepeatCount) +
        bool.getLengthOf(v.RepeatCount) +
        number.getLengthOf(v.DelayTime)
end

return tweenInfo