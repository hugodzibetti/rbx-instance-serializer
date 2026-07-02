--!strict
--!native
--!optimize 2

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

-- Lune's Enum has no `FromValue` lookup, so we build one lazily per enum and
-- cache it on the closure. `.Value` is Roblox's own backward-compatibility
-- anchor for enum items: it's guaranteed stable across API-dump changes.
local function enumItem(enum: Enum): types.Codec<EnumItem>
	local byValue: { [number]: EnumItem }? = nil

	local function cache(): { [number]: EnumItem }
		local existing = byValue
		if existing then
			return existing
		end
		local built = {}
		for _, item in enum:GetEnumItems() do
			built[item.Value] = item
		end
		byValue = built
		return built
	end

	return {
		write = function(writer: Writer.Writer, value: EnumItem)
			writer:varint(value.Value)
		end,
		read = function(reader: Reader.Reader): EnumItem
			return cache()[reader:varint()]
		end,
	}
end

return enumItem
