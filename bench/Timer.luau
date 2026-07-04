--!strict
--!native
--!optimize 2

export type Result = {
	iterations: number,
	seconds: number,
	opsPerSecond: number,
}

local function run(iterations: number, fn: () -> ()): Result
	local start = os.clock()
	for _ = 1, iterations do
		fn()
	end
	local elapsed = os.clock() - start
	return {
		iterations = iterations,
		seconds = elapsed,
		opsPerSecond = if elapsed > 0 then iterations / elapsed else math.huge,
	}
end

return { run = run }
