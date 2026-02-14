local TestEZ = require(script.Parent:FindFirstChild("testez"):FindFirstChild("init"))
local TextReporter = TestEZ.Reporters.TextReporter

local root = script.Parent.Parent
local src = root:FindFirstChild("src")

local BrickPack = require(src:WaitForChild("init"))

TestEZ.TestBootstrap.run(
	{ script.Parent },
	TextReporter,
	{
		showTimingInfo = false,
		extraEnvironment = {
			BrickPack = BrickPack,
		},
	}
)
