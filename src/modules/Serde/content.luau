local t = require("./types")
local enumItem = require("./enumItem")
local string = require("./string")

local content: t.Converter<Content> = {}

function content.read()
	local sourceType = enumItem.read()
	if sourceType == Enum.ContentSourceType.None then
		return Content.none
	end

	return Content.fromUri(string.read())
end

function content.write(v: Content)
	if v.Object or v.SourceType == Enum.ContentSourceType.None then
		-- An `object` cannot be created directly
		enumItem.write(Enum.ContentSourceType.None)
	elseif v.Uri then
		enumItem.write(Enum.ContentSourceType.Uri)
		string.write(v.Uri)
	end

	return
end

function content.getLengthOf(v: Content)
	if v.Object or v.SourceType == Enum.ContentSourceType.None then
		return enumItem.getLengthOf(Enum.ContentSourceType.None)
	elseif v.Uri then
		return enumItem.getLengthOf(Enum.ContentSourceType.Uri) + string.getLengthOf(v.Uri)
	end
end

return content
