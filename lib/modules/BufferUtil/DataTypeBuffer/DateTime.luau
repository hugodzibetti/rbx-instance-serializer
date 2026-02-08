--!native

local Types = require(script.Parent.Parent.Types)

return {
	write = function(b: Types.BufferWriter, dt: DateTime)
		b:WriteFloat64(dt.UnixTimestampMillis)
	end,
	read = function(b: Types.BufferReader)
		local millis = b:ReadFloat64()
		return DateTime.fromUnixTimestampMillis(millis)
	end,
}
