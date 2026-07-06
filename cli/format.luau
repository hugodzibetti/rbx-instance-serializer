--!strict

local function humanBytes(n: number): string
	if n < 1024 then
		return string.format("%d B", n)
	elseif n < 1024 * 1024 then
		return string.format("%.1f KB", n / 1024)
	elseif n < 1024 * 1024 * 1024 then
		return string.format("%.1f MB", n / (1024 * 1024))
	else
		return string.format("%.1f GB", n / (1024 * 1024 * 1024))
	end
end

-- Formats an integer with thousands separators, e.g. 12345 -> "12,345".
local function commaNumber(n: number): string
	local s = string.format("%d", n)
	local sign = ""
	if s:sub(1, 1) == "-" then
		sign = "-"
		s = s:sub(2)
	end
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	out = out:gsub("^,", "")
	return sign .. out
end

local encodingNames: { [number]: string } = {
	[0] = "Raw",
	[1] = "RLE",
	[2] = "Dictionary",
	[3] = "AllDefault",
	[4] = "AllNonDefault",
}

local function encodingName(encoding: number): string
	return encodingNames[encoding] or ("Unknown(" .. tostring(encoding) .. ")")
end

-- Prints simple left-aligned columns given a header row and body rows.
local function printTable(headers: { string }, rows: { { string } })
	local widths = table.create(#headers, 0)
	for i, h in headers do
		widths[i] = #h
	end
	for _, row in rows do
		for i, cell in row do
			if #cell > widths[i] then
				widths[i] = #cell
			end
		end
	end

	local function printRow(row: { string })
		local parts = {}
		for i, cell in row do
			table.insert(parts, cell .. string.rep(" ", widths[i] - #cell))
		end
		print(table.concat(parts, "  "))
	end

	printRow(headers)
	local dashRow = {}
	for i, w in widths do
		dashRow[i] = string.rep("-", w)
	end
	printRow(dashRow)

	for _, row in rows do
		printRow(row)
	end
end

return {
	humanBytes = humanBytes,
	commaNumber = commaNumber,
	encodingName = encodingName,
	printTable = printTable,
}
