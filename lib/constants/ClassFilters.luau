local APIDump = require(script.Parent.Parent.modules.APIDump)
local Filter = APIDump.Filter
local HasTags = Filter.HasTags

return {
    APIDump.Filter.Scriptable,
    Filter.Invert(HasTags("NotCreatable")),
    Filter.Invert(HasTags("ReadOnly")),
    Filter.Invert(Filter.Deprecated),
    Filter.Invert(Filter.Service)
}