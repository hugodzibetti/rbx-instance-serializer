--!strict
-- Emits a Luau `buffer.fromstring("...")` literal for an artifact.bin file, so it
-- can be pasted directly into a Roblox_Studio MCP execute_luau call without any
-- Rojo sync step. Usage: lune run scripts/EmitArtifactLiteral.luau [path]

local fs = require("@lune/fs")
local process = require("@lune/process")

local path = process.args[1] or "data/artifact.bin"
if not fs.isFile(path) then
	print(`ERROR: {path} not found. Run: pesde run artifact`)
	process.exit(1)
end

local data = fs.readFile(path)
local parts = table.create(#data)
for i = 1, #data do
	parts[i] = string.format("\\%d", string.byte(data, i))
end

print('buffer.fromstring("' .. table.concat(parts) .. '")')
