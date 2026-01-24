return function()
	local lib = require(game.ServerScriptService.lib)

	local function MeasureSerialization(lib, instance: Instance, compressed: boolean?)
		print("total instances:", 1 + #instance:GetDescendants())
	
		local started = os.clock()
		local output = lib[if compressed then "SerializeCompressed" else "Serialize"](instance)
		local finished = os.clock()
		local elapsed = finished - started
		print("time elapsed:", elapsed)
		print("lenght:", #output)
	
		return output
	end
	
	local function SimplePartSerializationTest(lib, compressed: boolean?)
		local part = game.ReplicatedFirst:WaitForChild("Part")
	
		local output = MeasureSerialization(lib, part, compressed)
		expect(output).to.be.ok()
	end
	
	local function HeavyModelSerializationTest(lib, compressed: boolean?)
		local model = game.ReplicatedFirst:FindFirstChildOfClass("Model")
	
		local output = MeasureSerialization(lib, model, compressed)
		expect(output).to.be.ok()
	end

	describe("Serialize()", function()
		it("should serialize a simple Part", function()
			SimplePartSerializationTest(lib)
		end)

		it("should serialize a heavy model", function()
			HeavyModelSerializationTest(lib)
		end)
	end)

	describe("SerializeCompressed()", function()
		it("should serialize a simple Part", function()
			SimplePartSerializationTest(lib, true)
		end)

		it("should serialize a heavy model", function()
			HeavyModelSerializationTest(lib, true)
		end)
	end)
end
