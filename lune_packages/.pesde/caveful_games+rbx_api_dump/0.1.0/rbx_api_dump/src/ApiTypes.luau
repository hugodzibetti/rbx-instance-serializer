type Array<T> = { [number]: T }

type ValueType = {
	Category: string,
	Name: string,
}

export type Property = {
	Category: string,
	MemberType: "Property",
	Name: string,
	Security: { Read: string, Write: string },
	Serialization: {
		CanLoad: boolean,
		CanSave: boolean,
	},
	ValueType: ValueType,

	Tags: Array<string>?,
}

export type Function = {
	MemberType: "Function",
	Name: string,
	Parameters: Array<{
		Name: string,
		Type: ValueType,
	}>,
	ReturnType: ValueType,
	Security: string,

	Tags: Array<string>?,
}

export type Event = {
	MemberType: "Event",
	Name: string,
	Parameters: Array<{
		Name: string,
		Type: ValueType,
	}>,
	Security: string,

	Tags: Array<string>?,
}

export type Callback = {
	MemberType: "Callback",
	Name: string,
	Parameters: Array<{
		Name: string,
		Type: ValueType,
	}>,
	ReturnType: ValueType,
	Security: string,

	Tags: Array<string>?,
}

export type Member = Property | Function | Event | Callback

export type Class = {
	Members: Array<Member>,
	MemoryCategory: string,
	Name: string,
	Superclass: string,
	Tags: Array<string>?,
}

export type Enum = {
	Items: Array<{ Name: string, Value: string }>,
	Name: string,
	Tags: Array<string>?,
}

export type API = {
	Classes: Array<Class>,
	Enums: Array<Enum>,
	Version: number,
}

return {}
