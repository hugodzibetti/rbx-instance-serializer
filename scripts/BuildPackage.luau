--!strict
--- Builds a standalone Roblox-importable package by running darklua over
--- `src/`, converting `@src/...` requires into relative paths, and writing
--- the result to `dist/lattice/`.
---
--- Requires a Rojo sourcemap of default.project.json for darklua's `roblox`
--- require target to compute correct instance paths (see .darklua.json), so
--- this runs in three passes:
---   1. Raw copy src/ -> dist/lattice/ (unconverted) so the Rojo project's
---      $path actually resolves to real files with the right names/shape.
---   2. `rojo sourcemap` over default.project.json, now that dist/lattice
---      exists, to capture how that shape maps onto the DataModel.
---   3. Re-run darklua over the raw copy, in place, with convert_require now
---      pointed at that sourcemap.

local process = require("@lune/process")
local fs = require("@lune/fs")

local OUTPUT_DIR = "dist/lattice"
-- Must live at the project root, NOT under dist/: darklua resolves each
-- sourcemap entry's file path relative to the sourcemap file's own directory,
-- while `rojo sourcemap` always writes paths relative to its invocation cwd
-- (the project root here) regardless of -o's location. Nesting this under
-- dist/ silently broke every lookup (every require came out unconverted,
-- with no build error - only a WARN per require).
local SOURCEMAP_PATH = "sourcemap.json"

if fs.isDir(OUTPUT_DIR) then
  fs.removeDir(OUTPUT_DIR)
end

fs.copy("src", OUTPUT_DIR)

local sourcemapResult = process.exec("rojo", { "sourcemap", "default.project.json", "-o", SOURCEMAP_PATH }, {
  stdio = "forward",
})

if not sourcemapResult.ok then
  print(`[BuildPackage] rojo sourcemap failed with exit code {sourcemapResult.code}`)
  process.exit(1)
end

local result = process.exec("darklua", { "process", OUTPUT_DIR, OUTPUT_DIR, "--config", ".darklua.json" }, {
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
