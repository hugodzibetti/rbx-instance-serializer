--!strict

local fs = require("@lune/fs")
local FormatReader = require("@src/format/Reader")
local FormatTypes = require("@src/format/types")
local ArtifactTypes = require("@src/artifacts/types")
local Artifact = require("@src/artifacts/Artifact")
local cliFormat = require("@cli/format")

type ArtifactData = ArtifactTypes.ArtifactData
type ClassBlock = FormatTypes.ClassBlock

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
	print("Total size: " .. cliFormat.humanBytes(buffer.len(fileBuf)))
	print("")

	for i, cb in formatData.classBlocks do
		local classMeta = artifact.classById[cb.classId]
		local className = if classMeta then classMeta.name else ("classId=" .. tostring(cb.classId))
		local effectiveCount = classBlockEffectiveCount(cb)

		local header = string.format("ClassBlock #%d: %s (%s instances", i, className, cliFormat.commaNumber(cb.instanceCount))
		if cb.templateRefs then
			header ..= string.format(", %s unique via templateRefs)", cliFormat.commaNumber(effectiveCount))
		else
			header ..= ")"
		end
		print(header)

		for _, col in cb.columns do
			local propName = formatData.stringTable[col.propertyNameIndex] or "?"
			local encodingLabel = cliFormat.encodingName(col.encoding)

			local nonDefaultCount = 0
			for _, b in col.bitmask do
				if b then
					nonDefaultCount += 1
				end
			end

			local detail = ""
			if col.encoding == 1 then -- RLE
				local runs = 1
				for k = 2, #col.values do
					if col.values[k] ~= col.values[k - 1] then
						runs += 1
					end
				end
				if #col.values == 0 then
					runs = 0
				end
				detail = string.format("%d run%s, ", runs, if runs == 1 then "" else "s")
			end

			print(string.format(
				"  %-18s encoding=%-13s %sbitmask: %d/%d non-default",
				propName,
				encodingLabel,
				detail,
				nonDefaultCount,
				#col.bitmask
			))
		end
		print("")
	end
end

local function run(filePath: string, artifactPath: string?)
	local artifactBuf = buffer.fromstring(fs.readFile(artifactPath or "data/artifact.bin"))
	local artifact = Artifact.load(artifactBuf)
	runWithArtifact(filePath, artifact)
end

return {
	run = run,
	runWithArtifact = runWithArtifact,
}
