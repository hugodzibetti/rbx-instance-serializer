--!strict
--!native
--!optimize 2

local Types = require("@src/types")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")

local codec: Types.Codec<number> = {
	write = function(writer: Writer.Writer, value: number)
		writer:f32(value)
	end,
	read = function(reader: Reader.Reader): number
		return reader:f32()
	end,
}

return codec
