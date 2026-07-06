local frktest = require("@packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local compat = require("@src/compat")

return function()
	test.suite("compat.migrate", function()
		test.case("no-ops when fromVersion equals currentVersion", function()
			local registry: compat.CompatRegistry = {
				currentVersion = 1,
				migrations = {},
			}
			local data = { foo = "bar" }
			local result = compat.migrate(registry, data, 1)
			check.equal(result, data)
		end)

		test.case("errors when fromVersion is newer than currentVersion", function()
			local registry: compat.CompatRegistry = {
				currentVersion = 1,
				migrations = {},
			}
			local success, err = pcall(function()
				compat.migrate(registry, {}, 2)
			end)
			check.equal(success, false)
			check.is_true(string.find(tostring(err), "1", 1, true) ~= nil)
			check.is_true(string.find(tostring(err), "2", 1, true) ~= nil)
		end)

		test.case("errors identifying the missing migration step", function()
			local registry: compat.CompatRegistry = {
				currentVersion = 3,
				migrations = {},
			}
			local success, err = pcall(function()
				compat.migrate(registry, {}, 1)
			end)
			check.equal(success, false)
			check.is_true(string.find(tostring(err), "1", 1, true) ~= nil)
		end)

		test.case("chains multiple registered migrations in order", function()
			local registry: compat.CompatRegistry = {
				currentVersion = 3,
				migrations = {
					[1] = function(data)
						data.steps = { "v1_to_v2" }
						return data
					end,
					[2] = function(data)
						table.insert(data.steps, "v2_to_v3")
						return data
					end,
				},
			}

			local result = compat.migrate(registry, { v = 1 }, 1)

			check.equal(result.v, 1)
			check.equal(#result.steps, 2)
			check.equal(result.steps[1], "v1_to_v2")
			check.equal(result.steps[2], "v2_to_v3")
		end)

		test.case("migrates real FormatData-shaped input via defaultRegistry to currentVersion", function()
			local data = {
				version = 1,
				stringTable = { "Anchored" },
				classBlocks = {
					{
						classId = 1,
						instanceCount = 2,
						columns = {},
						templateRefs = { 0, 0 },
					},
				},
			}

			local result = compat.migrate(compat.defaultRegistry, data, 1)

			check.equal(compat.defaultRegistry.currentVersion, 3)
			check.equal(#result.stringTable, 1)
			check.equal(result.stringTable[1], "Anchored")
			check.equal(#result.classBlocks, 1)
			check.equal(result.classBlocks[1].instanceCount, 2)
		end)
	end)
end
