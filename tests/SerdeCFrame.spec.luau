local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local roblox = require("@lune/roblox")
local CFrameCodec = require("@src/serde/cframe")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")

local function roundTrip(cf: roblox.CFrame): roblox.CFrame
	local w = Writer.new()
	CFrameCodec.write(w, cf)
	local r = Reader.new(w:toBuffer())
	return CFrameCodec.read(r)
end

return function()
	test.suite("serde.cframe", function()
		test.case("identity CFrame round trips exactly", function()
			local cf = roblox.CFrame.new()
			local out = roundTrip(cf)
			check.equal(out == cf, true)
		end)

		test.case("position-only CFrame round trips exactly", function()
			local cf = roblox.CFrame.new(roblox.Vector3.new(12.5, -7, 300))
			local out = roundTrip(cf)
			check.equal(out == cf, true)
		end)

		test.case("axis-aligned 90-degree rotation round trips exactly", function()
			local cf = roblox.CFrame.new(roblox.Vector3.new(1, 2, 3)) * roblox.CFrame.Angles(math.rad(90), 0, 0)
			local out = roundTrip(cf)
			check.equal(out == cf, true)
		end)

		test.case("arbitrary non-axis-aligned rotation round trips within tolerance", function()
			local cf = roblox.CFrame.new(roblox.Vector3.new(4, -5, 6))
				* roblox.CFrame.Angles(math.rad(37), math.rad(12), math.rad(58))
			local out = roundTrip(cf)

			local ox, oy, oz, or00, or01, or02, or10, or11, or12, or20, or21, or22 = out:GetComponents()
			local ex, ey, ez, er00, er01, er02, er10, er11, er12, er20, er21, er22 = cf:GetComponents()

			local components = {
				{ ox, ex },
				{ oy, ey },
				{ oz, ez },
				{ or00, er00 },
				{ or01, er01 },
				{ or02, er02 },
				{ or10, er10 },
				{ or11, er11 },
				{ or12, er12 },
				{ or20, er20 },
				{ or21, er21 },
				{ or22, er22 },
			}

			for _, pair in components do
				check.equal(math.abs(pair[1] - pair[2]) < 1e-4, true)
			end
		end)
	end)
end
