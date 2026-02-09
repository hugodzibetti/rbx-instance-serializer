return function(msg: string?, level: number?): string
	return debug.traceback(msg, level and level + 1 or 2):sub(1, -2)
end
