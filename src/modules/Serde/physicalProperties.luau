local t = require("./types")
local number = require("./f64")

local physicalProperties: t.Converter<PhysicalProperties> = {}

function physicalProperties.read()
    return PhysicalProperties.new(
        number.read(),
        number.read(),
        number.read(),
        number.read(),
        number.read()
    )
end

function physicalProperties.write(v: PhysicalProperties)
    number.write(v.Density)
    number.write(v.Friction)
    number.write(v.Elasticity)
    number.write(v.FrictionWeight)
    number.write(v.ElasticityWeight)

    return
end

function physicalProperties.getLengthOf(v: PhysicalProperties)
    return number.getLengthOf(v.Density) +
        number.getLengthOf(v.FrictionWeight) +
        number.getLengthOf(v.Elasticity) +
        number.getLengthOf(v.FrictionWeight) +
        number.getLengthOf(v.ElasticityWeight)
end

return physicalProperties