local t = require(script.Parent:FindFirstChild('types'))
local bool = require(script.Parent:FindFirstChild('bool'))

local rbxScriptConnection: t.Converter<RBXScriptConnection> = {}

function rbxScriptConnection.read()
    return {
        Connected = bool.read()
    }
end

function rbxScriptConnection.write(v: RBXScriptConnection)
    bool.write(v.Connected)

    return
end

function rbxScriptConnection.getLengthOf(v: RBXScriptConnection)
    return bool.getLengthOf(v.Connected)
end

return rbxScriptConnection