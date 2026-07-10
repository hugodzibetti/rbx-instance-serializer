--!strict
--!native
--!optimize 2

-- CFrame codec. Roblox's own file formats special-case the 24 axis-aligned
-- (90-degree-multiple) rotations down to a single index byte instead of a
-- full 3x3 matrix, since unrotated/axis-rotated parts are overwhelmingly
-- common. We do the same: 1 flag byte + 1 index byte + position for the
-- common case, vs. 1 flag byte + 9 matrix floats + position otherwise.

local roblox = require("@src/robloxDatatypes")
local Types = require("@src/types")
local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")

type CFrame = roblox.CFrame

-- The 24 axis-aligned rotation matrices are exactly the signed permutation
-- matrices with determinant +1 (proper rotations, not reflections). Rather
-- than hand-transcribe 24 3x3 matrices, generate them: every permutation of
-- columns combined with every sign choice per row, kept when the resulting
-- determinant is +1. Matrix entries are stored row-major as
-- { r00, r01, r02, r10, r11, r12, r20, r21, r22 }.
local SPECIAL_ROTATIONS: { { number } } = (function()
	local perms = {
		{ 1, 2, 3 },
		{ 1, 3, 2 },
		{ 2, 1, 3 },
		{ 2, 3, 1 },
		{ 3, 1, 2 },
		{ 3, 2, 1 },
	}

	local function permSign(perm: { number }): number
		local inversions = 0
		for i = 1, 3 do
			for j = i + 1, 3 do
				if perm[i] > perm[j] then
					inversions += 1
				end
			end
		end
		return if inversions % 2 == 0 then 1 else -1
	end

	local rotations = {}
	for _, perm in perms do
		local pSign = permSign(perm)
		for s1 = -1, 1, 2 do
			for s2 = -1, 1, 2 do
				for s3 = -1, 1, 2 do
					if pSign * s1 * s2 * s3 == 1 then
						local signs = { s1, s2, s3 }
						local m = table.create(9, 0)
						for row = 1, 3 do
							m[(row - 1) * 3 + perm[row]] = signs[row]
						end
						table.insert(rotations, m)
					end
				end
			end
		end
	end
	return rotations
end)()

assert(#SPECIAL_ROTATIONS == 24, "expected exactly 24 axis-aligned rotations")

-- Returns the 0-based index into SPECIAL_ROTATIONS, or nil if the matrix
-- isn't one of the 24 axis-aligned rotations.
local function findSpecialIndex(
	r00: number,
	r01: number,
	r02: number,
	r10: number,
	r11: number,
	r12: number,
	r20: number,
	r21: number,
	r22: number
): number?
	local abs = math.abs
	for index, m in SPECIAL_ROTATIONS do
		if
			abs(m[1] - r00) < 1e-5
			and abs(m[2] - r01) < 1e-5
			and abs(m[3] - r02) < 1e-5
			and abs(m[4] - r10) < 1e-5
			and abs(m[5] - r11) < 1e-5
			and abs(m[6] - r12) < 1e-5
			and abs(m[7] - r20) < 1e-5
			and abs(m[8] - r21) < 1e-5
			and abs(m[9] - r22) < 1e-5
		then
			return index - 1
		end
	end
	return nil
end

local CFrameCodec: Types.Codec<CFrame> = {
	write = function(writer: Writer.Writer, value: CFrame)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
		local index = findSpecialIndex(r00, r01, r02, r10, r11, r12, r20, r21, r22)

		if index then
			writer:u8(1)
			writer:u8(index)
			writer:f32(x)
			writer:f32(y)
			writer:f32(z)
		else
			writer:u8(0)
			writer:f32(r00)
			writer:f32(r01)
			writer:f32(r02)
			writer:f32(r10)
			writer:f32(r11)
			writer:f32(r12)
			writer:f32(r20)
			writer:f32(r21)
			writer:f32(r22)
			writer:f32(x)
			writer:f32(y)
			writer:f32(z)
		end
	end,

	read = function(reader: Reader.Reader): CFrame
		local flag = reader:u8()

		if flag == 1 then
			local index = reader:u8()
			local x = reader:f32()
			local y = reader:f32()
			local z = reader:f32()
			local m = SPECIAL_ROTATIONS[index + 1]
			return roblox.CFrame.new(x, y, z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
		else
			local r00 = reader:f32()
			local r01 = reader:f32()
			local r02 = reader:f32()
			local r10 = reader:f32()
			local r11 = reader:f32()
			local r12 = reader:f32()
			local r20 = reader:f32()
			local r21 = reader:f32()
			local r22 = reader:f32()
			local x = reader:f32()
			local y = reader:f32()
			local z = reader:f32()
			return roblox.CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
		end
	end,
}

return CFrameCodec
