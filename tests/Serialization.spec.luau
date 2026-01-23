return function()
	local lib = require(game.ServerScriptService.lib)

	describe("SerializeRecursive()", function()
		it("should serialize a instance", function()
            local part = Instance.new("Part", game.ReplicatedFirst)
            part.Size = Vector3.new(3, 3, 3)
            part.Material = Enum.Material.Wood
            part.Shape = Enum.PartType.Ball
            part.Orientation = Random.new():NextUnitVector()
            part.Anchored = true

			local buf = lib.SerializeRecursive(part)
			buf = buffer.tostring(buf)
			print(buf)

			expect(lib).to.be.ok()
		end)
	end)
end
