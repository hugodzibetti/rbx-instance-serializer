--!strict

local process = require("@lune/process")
local Stats = require("@cli/Stats")
local Dump = require("@cli/Dump")
local Diff = require("@cli/Diff")

local function printUsage()
	print("Usage: lune run cli/Main.luau -- <stats|dump|diff> <args>")
	print("  stats <file>          -- size/class/encoding breakdown")
	print("  dump <file>           -- per-column structural dump")
	print("  diff <before> <after> -- property-level diff between two files")
end

local rawArgs = process.args
local startIdx = 1
if rawArgs[1] == "--" then
	startIdx = 2
end
local args = {}
for i = startIdx, #rawArgs do
	table.insert(args, rawArgs[i])
end

local subcommand = args[1]

if subcommand == "stats" then
	local filePath = args[2]
	if not filePath then
		printUsage()
		process.exit(1)
	end
	Stats.run(filePath)
elseif subcommand == "dump" then
	local filePath = args[2]
	if not filePath then
		printUsage()
		process.exit(1)
	end
	Dump.run(filePath)
elseif subcommand == "diff" then
	local rest = {}
	for i = 2, #args do
		table.insert(rest, args[i])
	end
	Diff.run(rest)
else
	printUsage()
	process.exit(1)
end
