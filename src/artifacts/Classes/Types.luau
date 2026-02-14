local Serde = require(script.Parent.Parent.Parent:FindFirstChild('modules'):FindFirstChild('Serde'))

export type SerdeConverter = typeof(Serde.vector3)
export type ApiValueType = { Category: string, Name: string }

export type PropertyMember = {
	binaryId: number,
	name: string,
	converter: SerdeConverter,
}

export type InstanceMember = {
	binaryId: number,
	name: string,
}

export type ClassData = {
	binaryId: number,
	name: string,
	properties: { PropertyMember },
	instanceReferences: { InstanceMember },
}

return nil