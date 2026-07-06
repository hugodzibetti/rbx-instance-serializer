--!strict

local fs = require("@lune/fs")
local FormatReader = require("@src/format/Reader")
local FormatTypes = require("@src/format/types")
local ArtifactTypes = require("@src/artifacts/types")
local Artifact = require("@src/artifacts/Artifact")
local CostEstimator = require("@src/format/CostEstimator")
local cliFormat = require("@cli/format")

type ArtifactData = ArtifactTypes.ArtifactData
type ClassBlock = FormatTypes.ClassBlock
type PropertyColumn = FormatTypes.PropertyColumn

local function columnCost(col: PropertyColumn, effectiveCount: number, codec: any): number
	if col.encoding == 3 then -- AllDefault
		return 0
	elseif col.encoding == 4 then -- AllNonDefault
		return CostEstimator.sizeAllNonDefault(codec, col.values)
	elseif col.encoding == 2 then -- Dictionary
		return CostEstimator.sizeDictionary(codec, col.values, col.dictIndices)
	elseif col.encoding == 1 then -- RLE
		local nonDefaultValues = {}
		for _, v in col.values do
			table.insert(nonDefaultValues, v)
		end
		local size = CostEstimator.sizeRle(codec, effectiveCount, nonDefaultValues)
		return size
	elseif col.encoding == 0 then -- Raw
		return CostEstimator.sizeRaw(codec, effectiveCount, col.values)
	end
	return 0
end

local function getPropertyMetadata(artifact: ArtifactData, classId: number, propName: string)
	local classMeta = artifact.classById[classId]
	if not classMeta then
		return nil
	end
	for _, pm in classMeta.properties do
		if pm.name == propName then
			return pm
		end
	end
	return nil
end

local function classBlockEffectiveCount(cb: ClassBlock): number
	if not cb.templateRefs then
		return cb.instanceCount
	end
	local count = 0
	for _, ref in cb.templateRefs do
		if ref == 0 then
			count += 1
		end
	end
	return count
end

local function runWithArtifact(filePath: string, artifact: ArtifactData)
	local fileBuf = buffer.fromstring(fs.readFile(filePath))
	local formatData = FormatReader.read(fileBuf, artifact)

	print("File: " .. filePath)
	print("Format version: " .. tostring(formatData.version))
	print("Total size: " .. cliFormat.commaNumber(buffer.len(fileBuf)) .. " bytes")
	print("String table: " .. cliFormat.commaNumber(#formatData.stringTable) .. " entries")
	print("")

	local headers = { "Class", "Instances", "Bytes", "Avg/inst", "Dedup" }
	local rows: { { string } } = {}

	for _, cb in formatData.classBlocks do
		local classMeta = artifact.classById[cb.classId]
		local className = if classMeta then classMeta.name else ("classId=" .. tostring(cb.classId))

		local effectiveCount = classBlockEffectiveCount(cb)

		local totalBytes = 0
		for _, col in cb.columns do
			local propName = formatData.stringTable[col.propertyNameIndex]
			local pm = if propName then getPropertyMetadata(artifact, cb.classId, propName) else nil
			local codec = if pm then pm.codec else nil
			if codec then
				totalBytes += columnCost(col, effectiveCount, codec)
			end
		end

		local avgPerInst = if cb.instanceCount > 0 then totalBytes / cb.instanceCount else 0

		local dedupStr = "none"
		if cb.templateRefs then
			local uniqueCount = effectiveCount
			local pct = math.floor((uniqueCount / cb.instanceCount) * 100 + 0.5)
			dedupStr = string.format(
				"%s unique / %s (%d%%)",
				cliFormat.commaNumber(uniqueCount),
				cliFormat.commaNumber(cb.instanceCount),
				pct
			)
		end

		table.insert(rows, {
			className,
			cliFormat.commaNumber(cb.instanceCount),
			cliFormat.commaNumber(totalBytes),
			string.format("%.1f", avgPerInst),
			dedupStr,
		})
	end

	cliFormat.printTable(headers, rows)
end

local function run(filePath: string, artifactPath: string?)
	local artifactBuf = buffer.fromstring(fs.readFile(artifactPath or "data/artifact.bin"))
	local artifact = Artifact.load(artifactBuf)
	runWithArtifact(filePath, artifact)
end

return {
	run = run,
	runWithArtifact = runWithArtifact,
	columnCost = columnCost,
}
