local SAVE_SNAPSHOTS = true

local tiniest = require("@packages/tiniest").configure({
	snapshot_path = "./test/__snapshots__",
	save_snapshots = SAVE_SNAPSHOTS
})

local require: any = require

local tests = tiniest.collect_tests(function()
	local describe = tiniest.describe

	local function describe_from_file(name: string)
		describe(name, function()
			require(`./{name}.spec`)(tiniest)
		end)
	end

	describe_from_file("Serialization")
end)

tiniest.run_tests(tests, {})