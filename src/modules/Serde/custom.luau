local buff = require(script.Parent:FindFirstChild('buff'))
local t = require(script.Parent:FindFirstChild('types'))

export type CursorController = {
    getBuffer: () -> buffer,
    getCursor: () -> number,
    incrementCursor: (integer: number) -> (),
    allocateBytes: (bytes: number) -> (),
}

local CursorController: CursorController = {}
CursorController.getBuffer = buff.get
CursorController.getCursor = buff.getCursor
CursorController.incrementCursor = buff.push
CursorController.allocateBytes = buff.alloc

export type CustomController<T> = {
    read: (cursor: CursorController) -> T,
    write: (cursor: CursorController, value: T) -> (),
    getLengthOf: (value: T) -> number
}

return function<T>(controller: CustomController<T>): t.Converter<T>
    local custom: t.Converter<T> = {}
    
    function custom.read()
        return controller.read(CursorController)
    end
    
    function custom.write(v)
        return controller.write(CursorController, v)
    end
    
    function custom.getLengthOf(v)
        return controller.getLengthOf(v)
    end
    
    return custom
end