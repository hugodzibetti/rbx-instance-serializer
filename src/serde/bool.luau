--!strict
--!native
--!optimize 2

local Types = require("@src/types")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")

local codec: Types.Codec<boolean> = {
	write = function(writer: Writer.Writer, value: boolean)
		writer:bool(value)
	end,
	read = function(reader: Reader.Reader): boolean
		return reader:bool()
	end,
}

return codec
