local DumpParser = require("DumpParser")

export type GenericFilter<T> = DumpParser.GenericFilter<T>
export type Property = DumpParser.Property
export type Function = DumpParser.Function
export type Event = DumpParser.Event
export type Callback = DumpParser.Callback
export type APIDump = DumpParser.APIDump
export type Member = DumpParser.Member
export type Class = DumpParser.Class
export type ClassWithInheritance = DumpParser.ClassWithInheritance
export type Item = DumpParser.Item

local APIDump = DumpParser.fetchFromServer()

return APIDump
