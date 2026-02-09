local GET_VERSION_URL = "https://setup.rbxcdn.com/versionQTStudio"
local GET_API_JSON_URL = "https://setup.rbxcdn.com/%s-API-Dump.json"

local REQUEST_FAILED_MESSAGE = "Request to fetch `%s` failed because: %s"
local BAD_RESULT_MESSAGE = "Request to fetch `%s` returned bad status code `%i` (expected `200`)"
local JSON_DECODE_FAILURE_MESSAGE = "Failed to decode API dump because: %s"

-- selene: allow(unused_variable)
local ApiTypes = require("./ApiTypes")
local net = require("@lune/net")
local serde = require("@lune/serde")

--- Sends a GET request to `url`. If the result is invalid, uses `what` to throw an appropriate error.
--- Otherwise, returns the body of the result.
local function fetch(url: string, what: string): string
	local result = net.request(url)

	if not result.ok then
		error(string.format(REQUEST_FAILED_MESSAGE, what, result.statusMessage), 3)
	elseif result.statusCode ~= 200 then
		error(string.format(BAD_RESULT_MESSAGE, what, result.statusCode), 3)
	end

	return result.body
end

--- Fetches the API dump directly from Roblox. If the request is unsuccessful, an error is thrown.
local function fetchAPI(): ApiTypes.API
	local versionGuid = fetch(GET_VERSION_URL, "Roblox version GUID")
	local dump = fetch(string.format(GET_API_JSON_URL, versionGuid), "API dump")

	local decoded, apiDump = pcall(serde.decode, "json" :: "json", dump)
	if not decoded then
		error(string.format(JSON_DECODE_FAILURE_MESSAGE, apiDump), 2)
	end

	return apiDump
end

return fetchAPI
