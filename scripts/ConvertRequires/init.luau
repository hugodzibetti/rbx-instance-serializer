local process = require("@lune/process")
local fs = require("@lune/fs")
if type(process) ~= "table" or type(process.cwd) ~= "string" then
	error("ConvertRequires requires Lune. Run with: lune run scripts/ConvertRequires/init.luau")
end
local projectRoot = process.cwd:gsub("\\", "/")

local function join(...)
	return table.concat({ ... }, "/")
end

local function normalize(p: string): string
	return p:gsub("\\", "/")
end

local IGNORE_PREFIXES = {
	[join(projectRoot, "luau_packages")] = true,
	[join(projectRoot, "lune_packages")] = true,
	[join(projectRoot, "node_modules")] = true,
	[join(projectRoot, ".git")] = true,
	[join(projectRoot, "scripts", "ConvertRequires")] = true,
}

local function shouldProcess(filePath: string): boolean
	local normalized = normalize(filePath)
	for prefix in pairs(IGNORE_PREFIXES) do
		if normalized:sub(1, #prefix) == prefix then
			return false
		end
	end
	return true
end

local function collectFiles(dir: string, files: { string })
	local entries = fs.readDir(dir)
	for _, entry in entries do
		local fullPath = join(dir, entry)
		if fs.isDir(fullPath) then
			if shouldProcess(fullPath) then
				collectFiles(fullPath, files)
			end
		elseif entry:match("%.luau$") or entry:match("%.lua$") then
			if shouldProcess(fullPath) then
				table.insert(files, fullPath)
			end
		end
	end
end

local function processFile(filePath: string, configPath: string): (boolean, string?)
	local tempPath = filePath .. ".darklua_tmp"
	local result = process.exec("darklua", {
		"process",
		"--config",
		configPath,
		filePath,
		tempPath,
	}, {
		cwd = projectRoot,
	})

	if not result.ok then
		return false, result.stderr or result.stdout or "unknown error"
	end

	if fs.isFile(tempPath) then
		fs.move(tempPath, filePath, true)
	end

	return true
end

local configPath = join(projectRoot, "scripts", "ConvertRequires", ".darklua.json")

if not fs.isFile(configPath) then
	error("Config not found at scripts/ConvertRequires/.darklua.json")
end

local files: { string } = {}
collectFiles(join(projectRoot, "src"), files)
collectFiles(join(projectRoot, "tests"), files)

local runTestsPath = join(projectRoot, "RunTests.server.luau")
if fs.isFile(runTestsPath) then
	table.insert(files, runTestsPath)
end

print(`[ConvertRequires] Processing {#files} files...`)

local failed = 0
for _, filePath in files do
	local ok, err = processFile(filePath, configPath)
	if ok then
		print(`  OK  {filePath}`)
	else
		warn(`  FAIL {filePath}: {err}`)
		failed += 1
	end
end

if failed > 0 then
	error(`[ConvertRequires] {failed} file(s) failed.`)
end

print("[ConvertRequires] Done.")
