--!strict
-- Buffer Writer - optimized with closure-based methods

export type BufferWriter = {
	buf: buffer,
	Skip: (v: number) -> (),
	GetPos: () -> (),
	writeboolean: (v: boolean) -> (),
	writeu8: (v: number) -> (),
	writeu16: (v: number) -> (),
	writeu32: (v: number) -> (),
	writei8: (v: number) -> (),
	writei16: (v: number) -> (),
	writei32: (v: number) -> (),
	writef32: (v: number) -> (),
	writef64: (v: number) -> (),
	writestring: (v: string) -> (),
}

local function new(size: number): BufferWriter
	local buf = buffer.create(size)
	local pos = 0
	
	return {
		buf = buf,

		Skip = function(v: number)
			pos += v
		end,
		
		GetPos = function()
			return pos
		end,

		writeboolean = function(v: boolean)
			buffer.writeu8(buf, pos, if v then 1 else 0)
			pos += 1
		end,
		
		writeu8 = function(v: number)
			buffer.writeu8(buf, pos, v)
			pos += 1
		end,
		
		writeu16 = function(v: number)
			buffer.writeu16(buf, pos, v)
			pos += 2
		end,
		
		writeu32 = function(v: number)
			buffer.writeu32(buf, pos, v)
			pos += 4
		end,
		
		writei8 = function(v: number)
			buffer.writei8(buf, pos, v)
			pos += 1
		end,
		
		writei16 = function(v: number)
			buffer.writei16(buf, pos, v)
			pos += 2
		end,
		
		writei32 = function(v: number)
			buffer.writei32(buf, pos, v)
			pos += 4
		end,
		
		writef32 = function(v: number)
			buffer.writef32(buf, pos, v)
			pos += 4
		end,
		
		writef64 = function(v: number)
			buffer.writef64(buf, pos, v)
			pos += 8
		end,
		
		writestring = function(v: string)
			buffer.writestring(buf, pos, v)
			pos += #v
		end,
	}
end

return {
	new = new
}