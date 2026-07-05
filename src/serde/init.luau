--!strict

local Types = require("@src/types")

local f32 = require("@src/serde/f32")
local f64 = require("@src/serde/f64")
local bool = require("@src/serde/bool")
local stringCodec = require("@src/serde/string")
local array = require("@src/serde/array")
local option = require("@src/serde/option")
local cframe = require("@src/serde/cframe")
local color3 = require("@src/serde/color3")
local brickColor = require("@src/serde/brickColor")
local colorSequence = require("@src/serde/colorSequence")
local colorSequenceKeypoint = require("@src/serde/colorSequenceKeypoint")
local numberRange = require("@src/serde/numberRange")
local numberSequence = require("@src/serde/numberSequence")
local numberSequenceKeypoint = require("@src/serde/numberSequenceKeypoint")
local udim = require("@src/serde/udim")
local udim2 = require("@src/serde/udim2")
local vector2 = require("@src/serde/vector2")
local vector3 = require("@src/serde/vector3")
local rect = require("@src/serde/rect")
local axes = require("@src/serde/axes")
local faces = require("@src/serde/faces")
local physicalProperties = require("@src/serde/physicalProperties")
local font = require("@src/serde/font")
local content = require("@src/serde/content")
local uniqueId = require("@src/serde/uniqueId")
local enumItem = require("@src/serde/enumItem")
local referent = require("@src/serde/referent")
local ray = require("@src/serde/ray")

type Codec<T> = Types.Codec<T>
type CodecFactory = (Codec<any>) -> Codec<any>

local codecIdToModule: { [number]: Codec<any> } = {
	[0] = f32 :: Codec<any>,
	[1] = f64 :: Codec<any>,
	[2] = bool :: Codec<any>,
	[3] = stringCodec :: Codec<any>,
	[6] = cframe :: Codec<any>,
	[7] = color3 :: Codec<any>,
	[8] = brickColor :: Codec<any>,
	[9] = colorSequence :: Codec<any>,
	[10] = colorSequenceKeypoint :: Codec<any>,
	[11] = numberRange :: Codec<any>,
	[12] = numberSequence :: Codec<any>,
	[13] = numberSequenceKeypoint :: Codec<any>,
	[14] = udim :: Codec<any>,
	[15] = udim2 :: Codec<any>,
	[16] = vector2 :: Codec<any>,
	[17] = vector3 :: Codec<any>,
	[18] = rect :: Codec<any>,
	[19] = axes :: Codec<any>,
	[20] = faces :: Codec<any>,
	[21] = physicalProperties :: Codec<any>,
	[22] = font :: Codec<any>,
	[23] = content :: Codec<any>,
	[24] = uniqueId :: Codec<any>,
	[25] = enumItem :: Codec<any>,
	[26] = referent :: Codec<any>,
	[27] = ray :: Codec<any>,
}

local codecIdToFactory: { [number]: CodecFactory } = {
	[4] = array :: CodecFactory,
	[5] = option :: CodecFactory,
}

local codecNameToId: { [string]: number } = {
	f32 = 0,
	f64 = 1,
	bool = 2,
	string = 3,
	array = 4,
	option = 5,
	cframe = 6,
	color3 = 7,
	brickColor = 8,
	colorSequence = 9,
	colorSequenceKeypoint = 10,
	numberRange = 11,
	numberSequence = 12,
	numberSequenceKeypoint = 13,
	udim = 14,
	udim2 = 15,
	vector2 = 16,
	vector3 = 17,
	rect = 18,
	axes = 19,
	faces = 20,
	physicalProperties = 21,
	font = 22,
	content = 23,
	uniqueId = 24,
	enumItem = 25,
	referent = 26,
	ray = 27,
}

export type SerdeRegistry = {
	codecIdToModule: { [number]: Codec<any> },
	codecIdToFactory: { [number]: CodecFactory },
	codecNameToId: { [string]: number },
}

return {
	codecIdToModule = codecIdToModule,
	codecIdToFactory = codecIdToFactory,
	codecNameToId = codecNameToId,
} :: SerdeRegistry
