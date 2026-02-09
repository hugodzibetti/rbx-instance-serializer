local APIDump = require("@src/modules/APIDump")
local Filter = APIDump.Filter

return {
	Filter.MemberType("Property"),
	Filter.HasSecurity("None"),
	Filter.Scriptable,
    Filter.Invert(Filter.ReadOnly),
}
