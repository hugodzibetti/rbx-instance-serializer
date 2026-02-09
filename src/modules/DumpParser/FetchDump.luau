--!strict
--[=[
	@class FetchDump
	@private

	An internal module that handles fetching the Roblox API dump
	from the Roblox API. It is accessed by the [`fetchDump`][Dump.fetchDump]
	function on the [`Dump`][Dump] class.
]=]
local HttpService = game:GetService("HttpService")

local T = require("@src/modules/DumpParser/init.d")

local URL_DEPLOY_HISTORY = "https://s3.amazonaws.com/setup.roblox.com/DeployHistory.txt"
local URL_CURRENT_VERSION = "https://s3.amazonaws.com/setup.roblox.com/versionQTStudio"

local function HttpRequest(url: string, json: boolean?): string | T.APIDump?
	local response = HttpService:RequestAsync({
		Url = url,
		Compress = Enum.HttpCompression.Gzip,
	})

	local body = response.Body
	if body and json then
		return HttpService:JSONDecode(body) :: T.APIDump
	end

	return body
end

--[=[
	@function fetchLatestVersionHash
	@within FetchDump
	@return string

	Fetches the latest Roblox version hash from the Roblox API.
]=]
local function FetchLatestVersionHash(): string
	local versionHash = HttpRequest(URL_CURRENT_VERSION)
	assert(versionHash, "Could not fetch latest version hash")

	local hash = versionHash:match("version%-(%x+)")
	assert(hash, "Could not extract version hash from response")

	return hash
end

--[=[
	@function fetchVersionHash
	@within FetchDump
	@param version string?
	@return string

	Fetches the Roblox version hash for the given version from the
	Roblox API. If no version is provided, it will default to the
	current version.
]=]
local function FetchVersionHash(version: string?): string
	if not version then
		return FetchLatestVersionHash()
	end

	local deployHistory = HttpRequest(URL_DEPLOY_HISTORY)
	assert(deployHistory, "Could not fetch deployment history")

	local deployments = deployHistory:split("\n")
	local versionHash: string? = nil

	for lineNumber = #deployments, 1, -1 do
		local line = deployments[lineNumber]

		if line:find(version) then
			versionHash = line:match("version%-(%x+)")
			break
		end

		if lineNumber >= 128 then
			error(`Could not find version hash for version {version}`)
		end
	end

	assert(versionHash, `Could not find version hash for version {version}`)
	return versionHash
end

--[=[
	@function fetchVersionHashWithFallback
	@within FetchDump
	@param version string?
	@return string

	Fetches the Roblox version hash for the given version from the
	Roblox API. If no version is provided, it will default to the
	current version. If the version hash cannot be found within the
	deployment history, it will fallback to the latest version hash
	on the server.
]=]
local function FetchVersionHashWithFallback(version: string?): string
	local ok, versionHash = pcall(FetchVersionHash, version)

	if not ok then
		versionHash = FetchLatestVersionHash()
	end

	assert(versionHash, "Could not fetch version hash")
	return versionHash
end

--[=[
	@function fetchDump
	@within FetchDump
	@param hashOrVersion string?
	@return (APIDump, versionHash)

	Fetches the API dump for the current version of Roblox from the
	Roblox API. If a hash or version is provided, it will attempt to
	fetch the dump for that hash or version.
]=]
local function FetchDump(hashOrVersion: string?): (T.APIDump, string)
	local isVersionString = hashOrVersion and hashOrVersion:match("%d+%.") ~= nil

	if hashOrVersion == nil then
		isVersionString = true
	end

	if isVersionString then
		hashOrVersion = FetchVersionHashWithFallback(hashOrVersion)
	end

	local versionHash = hashOrVersion :: string
	local apiDump = HttpRequest(`https://s3.amazonaws.com/setup.roblox.com/version-{versionHash}-API-Dump.json`, true)
	assert(apiDump and typeof(apiDump) == "table", "Could not fetch API dump")

	return apiDump :: T.APIDump, versionHash
end

return {
	fetchDump = FetchDump,
	fetchLatestVersionHash = FetchLatestVersionHash,
	fetchVersionHash = FetchVersionHash,
	fetchVersionHashWithFallback = FetchVersionHashWithFallback,
}
