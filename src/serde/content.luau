--!strict
--!native
--!optimize 2

local roblox = require("@src/robloxDatatypes")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

local Content = roblox.Content
local ContentSourceType = roblox.Enum.ContentSourceType

-- Content.Object (an Instance reference) needs the instance-graph ref-fixup
-- system from a later phase, so this leaf codec only covers None and Uri.
local content: types.Codec<Content> = {
	write = function(writer: Writer.Writer, value: Content)
		if value.SourceType == ContentSourceType.Uri then
			writer:u8(1)
			writer:string(value.Uri)
		elseif value.SourceType == ContentSourceType.None then
			writer:u8(0)
		else
			error(`content codec: unsupported SourceType '{value.SourceType}'`)
		end
	end,

	read = function(reader: Reader.Reader): Content
		local tag = reader:u8()
		if tag == 1 then
			return Content.fromUri(reader:string())
		end
		return Content.none
	end,
}

return content
