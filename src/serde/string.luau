--!strict
--!native
--!optimize 2

local Types = require("@src/types")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")

local codec: Types.Codec<string> = {
	write = function(writer: Writer.Writer, value: string)
		writer:string(value)
	end,
	read = function(reader: Reader.Reader): string
		return reader:string()
	end,
}

return codec
