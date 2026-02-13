export type Converter<T> = {
    read: () -> T,
    write: (v: T) -> (),
    getLengthOf: (v: T) -> number,
}

export type CastConverter<T, C> = {
    read: () -> C,
    write: (v: T) -> (),
    getLengthOf: (v: T) -> number,
}

export type Primitive = number | boolean | string | Vector3 | Vector2 | Color3 | CFrame | {Primitive} | {[Primitive]: Primitive}

return nil