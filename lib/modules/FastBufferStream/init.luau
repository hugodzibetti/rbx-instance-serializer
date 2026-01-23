local Reader = require(script.Reader)
local Writer = require(script.Writer)
export type BufferReader = Reader.BufferReader
export type BufferWriter = Writer.BufferWriter

return {
    newReader = Reader.new,
    newWriter = Writer.new
}