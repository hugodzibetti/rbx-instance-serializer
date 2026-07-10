--!strict
-- Single guarded require() for Lune's roblox-datatype bindings, shared by every
-- serde/patch/instance module that needs Vector3.new/CFrame.new/Enum/etc.
-- Lune doesn't expose these as globals (only real Roblox does), so under Lune
-- this pulls them from `@lune/roblox`; under real Roblox the pcall fails
-- (there's no "@lune" alias) and it falls back to the engine's own globals.
-- Centralizing this means only this one file references "@lune/roblox" -
-- every codec just does `local roblox = require("@src/robloxDatatypes")` and
-- keeps working unchanged in both environments.

local ok, roblox = pcall(require, "@lune/roblox")

local datatypes = if ok and roblox
	then roblox
	else {
		Axes = Axes,
		BrickColor = BrickColor,
		CFrame = CFrame,
		Color3 = Color3,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		Content = Content,
		Enum = Enum,
		Faces = Faces,
		Font = Font,
		Instance = Instance,
		NumberRange = NumberRange,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		PhysicalProperties = PhysicalProperties,
		Ray = Ray,
		Rect = Rect,
		UDim = UDim,
		UDim2 = UDim2,
		UniqueId = UniqueId,
		Vector2 = Vector2,
		Vector3 = Vector3,
	}

return datatypes :: any
