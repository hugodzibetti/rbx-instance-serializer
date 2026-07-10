--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

-- Roblox colors are 8-bit-per-channel under the hood, so quantizing each
-- component to a u8 loses no perceptible precision while cutting the wire
-- size from 12 bytes (3 f32s) to 3. Components are clamped since Color3
-- doesn't enforce [0, 1] itself (e.g. values authored via tools/HDR tints).
local function quantize(component: number): number
	return math.clamp(math.round(component * 255), 0, 255)
end

local function write(writer: Writer.Writer, value: Color3)
	writer:u8(quantize(value.R))
	writer:u8(quantize(value.G))
	writer:u8(quantize(value.B))
end

local function read(reader: Reader.Reader): Color3
	local r = reader:u8()
	local g = reader:u8()
	local b = reader:u8()
	return roblox.Color3.new(r / 255, g / 255, b / 255)
end

return {
	write = write,
	read = read,
} :: types.Codec<Color3>
