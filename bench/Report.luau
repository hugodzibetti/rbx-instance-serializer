--!strict

export type Entry = {
	name: string,
	writeOpsPerSecond: number,
	readOpsPerSecond: number,
	totalBytes: number,
	avgBytesPerValue: number,
	sampleCount: number,
}

local function formatOps(n: number): string
	if n == math.huge then
		return "       --"
	elseif n >= 1e6 then
		return string.format("%8.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%8.1fK", n / 1e3)
	else
		return string.format("%9.0f", n)
	end
end

local function formatBytes(n: number): string
	if n >= 1e6 then
		return string.format("%10.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%10.1fK", n / 1e3)
	else
		return string.format("%11.0f", n)
	end
end

local function printTable(entries: { Entry })
	local nameWidth = 24
	print(string.format("%-" .. tostring(nameWidth) .. "s %9s %9s %11s %11s %7s", "codec", "write/s", "read/s", "avg bytes", "total", "samples"))
	print(string.rep("-", nameWidth + 9 + 9 + 11 + 11 + 7 + 5))

	for _, e in entries do
		print(string.format("%-" .. tostring(nameWidth) .. "s %9s %9s %11s %11s %7d",
			e.name,
			formatOps(e.writeOpsPerSecond),
			formatOps(e.readOpsPerSecond),
			formatBytes(e.avgBytesPerValue),
			formatBytes(e.totalBytes),
			e.sampleCount
		))
	end
end

return { printTable = printTable }
