--!strict

export type Migration = (data: any) -> any

export type CompatRegistry = {
	currentVersion: number,
	migrations: { [number]: Migration }, -- keyed by fromVersion; transforms fromVersion's data shape into (fromVersion + 1)'s shape
}

return {}
