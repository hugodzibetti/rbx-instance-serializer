--!strict
--!native
--!optimize 2

local roblox = require("@lune/roblox")

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local types = require("@src/types")

type PhysicalProperties = roblox.PhysicalProperties

local PhysicalPropertiesCodec: types.Codec<PhysicalProperties> = {
	write = function(writer: Writer.Writer, value: PhysicalProperties)
		writer:f32(value.Density)
		writer:f32(value.Friction)
		writer:f32(value.Elasticity)
		writer:f32(value.FrictionWeight)
		writer:f32(value.ElasticityWeight)
	end,
	read = function(reader: Reader.Reader): PhysicalProperties
		local density = reader:f32()
		local friction = reader:f32()
		local elasticity = reader:f32()
		local frictionWeight = reader:f32()
		local elasticityWeight = reader:f32()
		return roblox.PhysicalProperties.new(density, friction, elasticity, frictionWeight, elasticityWeight)
	end,
}

return PhysicalPropertiesCodec
