## FaceValue — the rig's continuous face-channel vocabulary.
##
## PORTED (Path A) from BDCC2 `Game/Doll/FaceAnimator/Util/FaceValue.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
## This is the FIRST implementation behind aeriea's OWN `apply_expression`
## (ExprState) seam — NOT a public seam itself. aeriea's ExprState (the affect
## vocabulary) is the seam; these are the rig's internal compositing channels.
##
## Unchanged from BDCC2 except: trimmed to the conversational-relevant channels
## (the NSFW EyesSexy / MouthPanting / MouthBlep channels are retained as enum
## slots so ported gestures compile, but no conversational gesture drives them).
class_name FaceValue
extends Object

enum {
	EyesClosed,
	EyesSexy,

	BrowsShy,
	BrowsAngry,

	MouthOpen,
	MouthPanting,
	MouthBlep,
	MouthSmile,
	MouthSad,
	MouthSnarl,

	LookDir,    # Vector2
	LookCross,

	Talking,
}

const FACE_VALUE_FLOAT := 0
const FACE_VALUE_VEC2 := 1


static func get_all() -> Array:
	return [EyesClosed, EyesSexy, BrowsShy, BrowsAngry, MouthOpen, MouthPanting,
		MouthBlep, MouthSmile, MouthSad, MouthSnarl, LookDir, LookCross, Talking]


static func get_all_texts() -> Array:
	return ["EyesClosed", "EyesSexy", "BrowsShy", "BrowsAngry", "MouthOpen",
		"MouthPanting", "MouthBlep", "MouthSmile", "MouthSad", "MouthSnarl",
		"LookDir", "LookCross", "Talking"]


static func get_type(face_val: int) -> int:
	if face_val == LookDir:
		return FACE_VALUE_VEC2
	return FACE_VALUE_FLOAT


static func get_name(face_val: int) -> String:
	var texts := get_all_texts()
	if face_val < 0 or face_val >= texts.size():
		return "ERROR"
	return texts[face_val]
