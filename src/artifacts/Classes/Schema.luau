local Serde = require(script.Parent.Parent.Parent:FindFirstChild('modules'):FindFirstChild('Serde'))

local PropertyEntry = Serde.struct({
	name = Serde.string,
	typeName = Serde.string,
})

local InstanceRefEntry = Serde.struct({
	name = Serde.string,
})

local ClassEntry = Serde.struct({
	binaryId = Serde.number,
	name = Serde.string,
	properties = Serde.array(PropertyEntry),
	instanceReferences = Serde.array(InstanceRefEntry),
})

return Serde.array(ClassEntry)
