local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local Diff = require("@cli/Diff")

-- Dummy instance stand-in: matchInstances only reads `.UniqueId`, so a plain
-- table is sufficient -- no need for @lune/roblox instances here.
local function mkInst(uniqueId: string?): any
	return { UniqueId = uniqueId }
end

return function()
	test.suite("cli.Diff.matchInstances", function()
		test.case("matches identical UniqueIds across before/after", function()
			local before = { mkInst("uid-a"), mkInst("uid-b") }
			local after = { mkInst("uid-b"), mkInst("uid-a") }

			local result = Diff.matchInstances(before, after)

			check.equal(#result.matched, 2)
			check.equal(#result.added, 0)
			check.equal(#result.removed, 0)
			for _, pair in result.matched do
				check.equal(pair.strategy, "uniqueId")
			end
		end)

		test.case("reports removed instances present only in before", function()
			local before = { mkInst("uid-a"), mkInst("uid-b") }
			local after = { mkInst("uid-a") }

			local result = Diff.matchInstances(before, after)

			check.equal(#result.matched, 1)
			check.equal(#result.removed, 1)
			check.equal(#result.added, 0)
		end)

		test.case("reports added instances present only in after", function()
			local before = { mkInst("uid-a") }
			local after = { mkInst("uid-a"), mkInst("uid-c") }

			local result = Diff.matchInstances(before, after)

			check.equal(#result.matched, 1)
			check.equal(#result.added, 1)
			check.equal(#result.removed, 0)
		end)

		test.case("falls back to positional matching when UniqueId absent", function()
			local before = { mkInst(nil), mkInst(nil) }
			local after = { mkInst(nil), mkInst(nil) }

			local result = Diff.matchInstances(before, after)

			check.equal(#result.matched, 2)
			for _, pair in result.matched do
				check.equal(pair.strategy, "position")
			end
		end)

		test.case("positional fallback flags extras as added/removed when tree shape differs", function()
			local before = { mkInst(nil), mkInst(nil), mkInst(nil) }
			local after = { mkInst(nil) }

			local result = Diff.matchInstances(before, after)

			check.equal(#result.matched, 1)
			check.equal(#result.removed, 2)
			check.equal(#result.added, 0)
		end)

		test.case("mixes UniqueId matches with positional fallback in the same list", function()
			local before = { mkInst("uid-a"), mkInst(nil) }
			local after = { mkInst(nil), mkInst("uid-a") }

			local result = Diff.matchInstances(before, after)

			check.equal(#result.matched, 2)
			local strategies = {}
			for _, pair in result.matched do
				strategies[pair.strategy] = (strategies[pair.strategy] or 0) + 1
			end
			check.equal(strategies["uniqueId"], 1)
			check.equal(strategies["position"], 1)
		end)
	end)

	test.suite("cli.smoke", function()
		test.case("stats and dump run against a known fixture without error", function()
			local fs = require("@lune/fs")
			local roblox = require("@lune/roblox")
			local serde = require("@src/serde")
			local instance = require("@src/instance")
			local Stats = require("@cli/Stats")
			local Dump = require("@cli/Dump")

			-- Same mockArtifact shape used by tests/Instance.spec.luau and
			-- tests/Format.spec.luau -- avoids depending on the gitignored,
			-- locally-built data/artifact.bin for this smoke test.
			local mockArtifact = {
				version = 1,
				classes = {},
				classByName = {},
				classById = {
					[1] = {
						id = 1,
						name = "Part",
						properties = {
							{
								name = "Anchored",
								codecId = 2,
								codec = serde.codecIdToModule[2],
								default = false,
							},
							{
								name = "Position",
								codecId = 17,
								codec = serde.codecIdToModule[17],
								default = roblox.Vector3.new(0, 0, 0),
							},
						},
					},
				},
			}
			mockArtifact.classByName["Part"] = mockArtifact.classById[1]

			local p1 = roblox.Instance.new("Part")
			p1.Anchored = true
			p1.Position = roblox.Vector3.new(1, 2, 3)

			local p2 = roblox.Instance.new("Part")
			p2.Anchored = false
			p2.Position = roblox.Vector3.new(4, 5, 6)

			local buf = instance.serialize({ p1, p2 }, mockArtifact :: any)

			local tmpPath = "data/_cli_smoke_fixture.lattice"
			fs.writeFile(tmpPath, buffer.tostring(buf))

			check.should_not_error(function()
				Stats.runWithArtifact(tmpPath, mockArtifact :: any)
			end)
			check.should_not_error(function()
				Dump.runWithArtifact(tmpPath, mockArtifact :: any)
			end)

			fs.removeFile(tmpPath)
		end)
	end)
end
