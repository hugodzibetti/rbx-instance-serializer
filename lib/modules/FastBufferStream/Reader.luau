--!strict
-- Buffer Reader - optimized with closure-based methods

export type BufferReader = {
	buf: buffer,
	Skip: (v: number) -> (),
	GetPos: () -> (),
	readu8: () -> number,
	readu16: () -> number,
	readu32: () -> number,
	readi8: () -> number,
	readi16: () -> number,
	readi32: () -> number,
	readf32: () -> number,
	readf64: () -> number,
	readstring: (len: number) -> string,
}

local function new(buf: buffer): BufferReader
	local pos = 0

	return {
		buf = buf,

		Skip = function(v: number)
			pos += v
		end,

		GetPos = function()
			return pos
		end,

		readu8 = function(): number
			local v = buffer.readu8(buf, pos)
			pos += 1
			return v
		end,

		readu16 = function(): number
			local v = buffer.readu16(buf, pos)
			pos += 2
			return v
		end,

		readu32 = function(): number
			local v = buffer.readu32(buf, pos)
			pos += 4
			return v
		end,

		readi8 = function(): number
			local v = buffer.readi8(buf, pos)
			pos += 1
			return v
		end,

		readi16 = function(): number
			local v = buffer.readi16(buf, pos)
			pos += 2
			return v
		end,

		readi32 = function(): number
			local v = buffer.readi32(buf, pos)
			pos += 4
			return v
		end,

		readf32 = function(): number
			local v = buffer.readf32(buf, pos)
			pos += 4
			return v
		end,

		readf64 = function(): number
			local v = buffer.readf64(buf, pos)
			pos += 8
			return v
		end,

		readstring = function(len: number): string
			local v = buffer.readstring(buf, pos, len)
			pos += len
			return v
		end,
	}
end

return {
	new = new,
}
