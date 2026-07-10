--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

-- BrickColor's `.Number` is a stable palette index (small, usually 1-2 bytes
-- as a varint) that round-trips exactly through the numeric constructor.
local function write(writer: Writer.Writer, value: BrickColor)
	writer:varint(value.Number)
end

-- Note: BrickColor.new(n) falls back to "Medium stone grey" for
-- unrecognized palette indices rather than erroring. Treat unexpected
-- colors after deserialization as a sign of a corrupt/mismatched buffer.
local function read(reader: Reader.Reader): BrickColor
	return roblox.BrickColor.new(reader:varint())
end

return {
	write = write,
	read = read,
} :: types.Codec<BrickColor>
