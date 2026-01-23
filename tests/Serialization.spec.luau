local function MeasureSerialization(lib, instance: Instance)
	print("total instances:", 1 + #instance:GetDescendants())

	local started = os.clock()
	local buf = lib.SerializeRecursive(instance)
	local finished = os.clock()
	local elapsed = finished - started
	print("time elapsed:", elapsed)

	local lenght = buffer.len(buf)
	print("lenght:", lenght)

	return buf
end

return function()
	local lib = require(game.ServerScriptService.lib)

	describe("SerializeRecursive()", function()
		it("should serialize a simple Part", function()
			local part = Instance.new("Part", game.ReplicatedFirst)
			part.Size = Vector3.new(3, 3, 3)
			part.Material = Enum.Material.Wood
			part.Shape = Enum.PartType.Ball
			part.Orientation = Random.new():NextUnitVector()
			part.Anchored = true

			local buf = MeasureSerialization(lib, part)
			expect(buf).to.be.ok()
		end)

		it("should serialize a heavy model", function()
			local model = game.ReplicatedFirst:FindFirstChildOfClass("Model")

			local buf = MeasureSerialization(lib, model)
			expect(buf).to.be.ok()
		end)
	end)
end
