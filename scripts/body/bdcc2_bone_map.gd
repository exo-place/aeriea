## BDCC2 → aeriea (MakeHuman) bone-name mapping table — DATA, not code.
##
## The keystone of the BDCC2 clip mine (and the eventual core-body part retarget):
## a single authored table mapping BDCC2's Blender/Rigify-derived deform rig bone
## names onto aeriea's 169-bone MakeHuman rig. Reused by tools/bdcc2_clip_ingest.gd
## today; reusable as-is for any future BDCC2→MH skeletal-data transfer (parts that
## ship their own posed skeletons, etc.) — that is why it lives in its own data file
## rather than being inlined in the ingest tool.
##
## NOTE ON THE "DEF-*" ASSUMPTION: the brief expected BDCC2 to use Rigify DEF-*
## names. That is true of BDCC2's PART GLBs (tails/ears: DEF-Tail1.., handled by
## part_library.gd) but NOT of its ANIMATION clips — the anim rig uses clean Blender
## names (hips, thigh.L, shin.L, upper_arm.L, forearm.L, ...). This table maps those.
##
## COVERAGE: the core locomotion/gesture skeleton — hips, the spine chain, neck,
## head, both arms (clavicle/upper/lower) and both legs (thigh/shin/foot/toe). This
## is every bone the SFW clips meaningfully animate. BDCC2's helper bones
## (twist/breast/butt/finger/genital/eyes_look_at) are intentionally UNMAPPED: they
## either have no MH counterpart that the gross clip needs, drive cosmetic secondary
## motion aeriea owns via its own spring-bones, or are NSFW rig aids. Fingers are
## left unmapped for now (the SFW gesture set reads fine from wrist-level pose); they
## are a clean future extension of this same table.
##
## SPINE: BDCC2 has a 3-segment torso (waist, chest, upper_chest) above hips; MH has
## a 5-segment spine (spine05 lowest .. spine01 highest). We map BDCC2's three torso
## joints onto MH's spine04 / spine02 / spine01 (skipping spine05/spine03), spreading
## the captured torso bend across the longer MH chain at the anatomically-closest
## segments. The unmapped MH spine joints keep rest (the bend reads correctly).
extends RefCounted

## key = MakeHuman (aeriea) bone name ; value = BDCC2 anim-rig bone name.
const MAP := {
	"root":          "hips",
	"spine04":       "waist",
	"spine02":       "chest",
	"spine01":       "upper_chest",
	"neck01":        "neck",
	"head":          "head",
	"clavicle.L":    "shoulder.L",
	"upperarm01.L":  "upper_arm.L",
	"lowerarm01.L":  "forearm.L",
	"wrist.L":       "hand.L",
	"clavicle.R":    "shoulder.R",
	"upperarm01.R":  "upper_arm.R",
	"lowerarm01.R":  "forearm.R",
	"wrist.R":       "hand.R",
	"upperleg01.L":  "thigh.L",
	"lowerleg01.L":  "shin.L",
	"foot.L":        "foot.L",
	"toe1-1.L":      "toe.L",
	"upperleg01.R":  "thigh.R",
	"lowerleg01.R":  "shin.R",
	"foot.R":        "foot.R",
	"toe1-1.R":      "toe.R",
}

## Nearest MAPPED MH ancestor for each mapped bone — used to convert per-bone target
## GLOBAL rotations into chain-correct MH-LOCAL rotations. "" = driven in the de-yawed
## root frame (no mapped parent).
const MH_PARENT := {
	"root":          "",
	"spine04":       "root",
	"spine02":       "spine04",
	"spine01":       "spine02",
	"neck01":        "spine01",
	"head":          "neck01",
	"clavicle.L":    "spine01",
	"upperarm01.L":  "clavicle.L",
	"lowerarm01.L":  "upperarm01.L",
	"wrist.L":       "lowerarm01.L",
	"clavicle.R":    "spine01",
	"upperarm01.R":  "clavicle.R",
	"lowerarm01.R":  "upperarm01.R",
	"wrist.R":       "lowerarm01.R",
	"upperleg01.L":  "root",
	"lowerleg01.L":  "upperleg01.L",
	"foot.L":        "lowerleg01.L",
	"toe1-1.L":      "foot.L",
	"upperleg01.R":  "root",
	"lowerleg01.R":  "upperleg01.R",
	"foot.R":        "lowerleg01.R",
	"toe1-1.R":      "foot.R",
}


## The set of MH bones this map covers, in a stable (sorted) order for deterministic
## DB layout.
static func target_bones() -> PackedStringArray:
	var keys := MAP.keys()
	keys.sort()
	var out := PackedStringArray()
	for k in keys:
		out.append(k)
	return out
