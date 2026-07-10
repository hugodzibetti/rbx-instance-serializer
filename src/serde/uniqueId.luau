--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

local UniqueId = roblox.UniqueId

-- UniqueId only exposes itself opaquely: `tostring()` gives a 32-character
-- hex string, and `.fromString()` expects the raw 16-byte decoding of that
-- hex, not the hex string itself. We store the 16 raw bytes on the wire
-- (not the 32-char hex) since that's the actual entropy.
local function hexToBytes(hex: string): buffer
	local raw = buffer.create(16)
	for i = 0, 15 do
		local byte = tonumber(hex:sub(i * 2 + 1, i * 2 + 2), 16) :: number
		buffer.writeu8(raw, i, byte)
	end
	return raw
end

local uniqueId: types.Codec<UniqueId> = {
	write = function(writer: Writer.Writer, value: UniqueId)
		writer:bytes(hexToBytes(tostring(value)), 16)
	end,

	read = function(reader: Reader.Reader): UniqueId
		local raw = reader:bytes(16)
		return UniqueId.fromString(buffer.tostring(raw))
	end,
}

return uniqueId
