--!strict

local Writer = require("@src/buffer/Writer")
local Reader = require("@src/buffer/Reader")
local Serde = require("@src/serde")
local Types = require("@src/types")
local Artifact = require("@src/artifacts/Artifact")
local Serializer = require("@src/instance/Serializer")
local Deserializer = require("@src/instance/Deserializer")
local ArtifactTypes = require("@src/artifacts/types")

export type Codec<T> = Types.Codec<T>
export type Writer = Writer.Writer
export type Reader = Reader.Reader
export type SerdeRegistry = Serde.SerdeRegistry

export type ArtifactData = ArtifactTypes.ArtifactData
export type ClassMetadata = ArtifactTypes.ClassMetadata
export type PropertyMetadata = ArtifactTypes.PropertyMetadata

return {
	Writer = Writer,
	Reader = Reader,
	Serde = Serde,

	loadArtifact = Artifact.load,
	serialize = Serializer.serialize,
	deserialize = Deserializer.deserialize,
}
