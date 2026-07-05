--!strict

-- Maps Roblox type names to codec metadata.
-- Returns ResolvedType | nil (nil = unresolvable, caller skips).

export type ResolvedType = {
	codecId: number,
	codecParams: { number }?,
}

-- Codec IDs from src/serde/init.luau:
-- f32=0, f64=1, bool=2, string=3, array=4, option=5,
-- cframe=6, color3=7, brickColor=8, colorSequence=9, colorSequenceKeypoint=10,
-- numberRange=11, numberSequence=12, numberSequenceKeypoint=13,
-- udim=14, udim2=15, vector2=16, vector3=17, rect=18, axes=19, faces=20,
-- physicalProperties=21, font=22, content=23, uniqueId=24, enumItem=25,
-- referent=26, ray=27

local LEAF_MAP: { [string]: number } = {
	float = 0,
	double = 1,
	int64 = 1,
	int = 1,
	bool = 2,
	boolean = 2,
	string = 3,
	CFrame = 6,
	Color3 = 7,
	BrickColor = 8,
	ColorSequence = 9,
	NumberRange = 11,
	NumberSequence = 12,
	UDim = 14,
	UDim2 = 15,
	Vector2 = 16,
	Vector3 = 17,
	Rect = 18,
	Axes = 19,
	Faces = 20,
	PhysicalProperties = 21,
	Font = 22,
	Content = 23,
	UniqueId = 24,
	Enum = 25,
	ProtectedString = 3,
	ContentId = 3,
	Ray = 27,
}

local function resolveLeaf(typeName: string): number?
	return LEAF_MAP[typeName]
end

local function resolveType(prop: { valueType: string, valueTypeParams: { string }? }, classNamesSet: { [string]: boolean }?): ResolvedType?
	local valueType = prop.valueType
	local params = prop.valueTypeParams

	if valueType == "Array" or valueType == "Optional" then
		if not params or #params == 0 then
			return nil
		end
		local innerId = resolveLeaf(params[1])
		if not innerId then
			return nil
		end
		local factoryId: number
		if valueType == "Array" then
			factoryId = 4
		else
			factoryId = 5
		end
		return { codecId = factoryId, codecParams = { innerId } }
	end

	local codecId = resolveLeaf(valueType)
	if codecId then
		return { codecId = codecId }
	end

	if valueType == "Instance" or (classNamesSet and classNamesSet[valueType]) then
		return { codecId = 26 }
	end

	return nil
end

return resolveType
