local process = require("@lune/process")
local fs = require("@lune/fs")

local projectRoot = process.cwd
local function join(...)
	return table.concat({ ... }, "/")
end

local function RunPesdeInstall()
	print("[InstallPackages] Running pesde install...")
	local result = process.exec("pesde", { "install" }, {
		cwd = projectRoot,
	})

	if not result.ok then
		error(`pesde install failed: {result.stderr or result.stdout or "unknown error"}`)
	end
	print("[InstallPackages] pesde install completed.")
end

local function EnsurePackagesDir()
	local packagesDir = join(projectRoot, "packages")
	if not fs.isDir(packagesDir) then
		fs.writeDir(packagesDir)
		print("[InstallPackages] Created packages/ directory.")
	end
	return packagesDir
end

local function MoveFolder(src: string, dest: string)
	if not fs.isDir(src) then
		warn(`[InstallPackages] Skipping {src}: not found or not a directory`)
		return
	end

	if fs.isDir(dest) then
		fs.removeDir(dest)
	end

	fs.move(src, dest)
	print(`[InstallPackages] Moved {src} -> {dest}`)
end

RunPesdeInstall()
local packagesDir = EnsurePackagesDir()

MoveFolder(join(projectRoot, "lune_packages"), join(packagesDir, "lune"))
MoveFolder(join(projectRoot, "luau_packages"), join(packagesDir, "luau"))

print("[InstallPackages] Done.")
