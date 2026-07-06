--!strict
--- Builds a standalone Roblox-importable package by running darklua over
--- `src/`, converting `@src/...` requires into relative paths, and writing
--- the result to `dist/lattice/`.

local process = require("@lune/process")
local fs = require("@lune/fs")

local OUTPUT_DIR = "dist/lattice"

if fs.isDir(OUTPUT_DIR) then
	fs.removeDir(OUTPUT_DIR)
end

local result = process.exec("darklua", { "process", "src", OUTPUT_DIR, "--config", ".darklua.json" }, {
	stdio = "forward",
})

if not result.ok then
	print(`[BuildPackage] darklua failed with exit code {result.code}`)
	process.exit(1)
end

local function countLuauFiles(dir: string): number
	local count = 0
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			count += countLuauFiles(path)
		elseif name:match("%.luau$") then
			count += 1
		end
	end
	return count
end

local fileCount = countLuauFiles(OUTPUT_DIR)

print(`[BuildPackage] success: wrote {fileCount} .luau file(s) to {OUTPUT_DIR}`)
process.exit(0)
