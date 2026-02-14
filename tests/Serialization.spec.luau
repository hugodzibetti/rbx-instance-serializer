return function()
	describe("Serialization", function()
		it("serializes a Part instance", function()
			local part = Instance.new("Part")
			part.Name = "TestPart"
			part.Anchored = true
			part.Position = Vector3.new(0, 5, 0)

			local result = BrickPack.Serialize(part)
			expect(result).to.be.ok()
			expect(type(result)).to.equal("table")

			part:Destroy()
		end)
	end)
end
