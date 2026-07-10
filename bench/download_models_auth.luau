--!strict
--!native

local net = require("@lune/net")
local fs = require("@lune/fs")
local process = require("@lune/process")

local ASSET_IDS = {
	18417434485,
	132810230805035,
	119923183258507,
	102667935150963,
	8767718758,
}

local MODEL_NAMES = {
	"haunted-mansion-bear-alpha",
	"the-big-house",
	"big-town-map",
	"gm-big-city",
	"minecraft-map",
}

local OUTPUT_DIR = "bench/models"
local COOKIE = process.env.ROBLOX_COOKIE or ""

if COOKIE == "" then
	print("ERROR: Set ROBLOX_COOKIE environment variable")
	process.exit(1)
end

local function downloadModel(assetId: number, name: string): boolean
	local filename = `{OUTPUT_DIR}/{name}.rbxl`

	if fs.isFile(filename) then
		local size = #fs.readFile(filename)
		if size > 1000 then
			print(`✓ {name} already exists`)
			return true
		end
	end

	print(`⬇ {name}...`)

	local url = `https://assetdelivery.roblox.com/v1/asset/?id={assetId}`

	local success, response = pcall(function()
		return net.request({
			url = url,
			method = "GET",
			headers = {
				["Cookie"] = `.ROBLOSECURITY={COOKIE}`,
				["User-Agent"] = "Mozilla/5.0",
			},
		})
	end)

	if not success then
		print(`✗ Request failed`)
		return false
	end

	if not response.ok then
		print(`✗ HTTP {response.statusCode}`)
		return false
	end

	fs.writeFile(filename, response.body)
	local size = #response.body

	if size < 1000 then
		print(`✗ File too small ({size} bytes)`)
		return false
	end

	print(`✓ {size} bytes`)
	return true
end

print("\n" .. string.rep("=", 70))
print("DOWNLOADING REAL ROBLOX MODELS")
print(string.rep("=", 70) .. "\n")

if not fs.isDir(OUTPUT_DIR) then
	fs.writeDir(OUTPUT_DIR)
end

local downloaded = 0
for i, assetId in ASSET_IDS do
	if downloadModel(assetId, MODEL_NAMES[i]) then
		downloaded += 1
	end
end

print("\n" .. string.rep("=", 70))
print(`{downloaded}/{#ASSET_IDS} downloaded`)
print(string.rep("=", 70))

process.exit(if downloaded == #ASSET_IDS then 0 else 1)
