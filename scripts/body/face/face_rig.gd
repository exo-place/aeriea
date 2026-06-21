## FaceRig — aeriea's expression surface. The FIRST implementation behind aeriea's
## OWN `apply_expression(ExprState)` seam (bdcc2-integration-plan.md §2.1).
##
## PORTED (Path A) from BDCC2 `Game/Doll/FaceAnimator/face_animator.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
##
## What is ported (the reusable RIG): the continuous FaceValue channel set, the
## live `val_*` channel buffer, the priority gesture STACK + influence blend, and
## the per-frame resolve loop (resetVals -> each gesture composites -> apply).
##
## Path-A cuts (per §3.1):
##   - DELETED the `dollPart.getDoll()/getCharacter()` chain. Affect is PUSHED in
##     via `apply_expression(ExprState)`; the rig is a SINK, not a Doll puller.
##   - DELETED the AnimationTree/AnimationPlayer + FacialAnimTree.tres path.
##     BDCC2 drove named BLENDSHAPE CLIPS baked into ITS head GLB; aeriea's CC0
##     MakeHuman head has NO expression blendshapes (see BLENDSHAPE-COVERAGE note
##     below) — so the sink drives the available face BONES instead.
##   - SWAPPED BDCC2's global `RNG` autoload + `createTween` for a SEEDED
##     RandomNumberGenerator handed to each gesture + per-frame integration. Same
##     seed + same dt sequence -> same resolved face (determinism invariant).
##
## ---- BLENDSHAPE COVERAGE (the real unknown, RESOLVED) --------------------------
## aeriea's CC0 head (assets/body/base_body.res) declares ONLY 9 MACRO BODY
## blendshapes (age/gender/muscle/weight/height/proportions). It has ZERO facial
## EXPRESSION blendshapes (no Eyes_Close, Mouth_Smile, Brows_*, etc.). MakeHuman
## DOES ship `data/targets/expression/*` (CC0) but they are not imported into
## aeriea's mesh pipeline yet (Slice B/C work).
##
## So the channels split into:
##   DRIVABLE NOW via face BONES present in the CC0 default rig:
##     - MouthOpen   -> `jaw` pitch (jaw drop; skin follows via LBS)
##     - LookDir     -> `eye.L`/`eye.R` yaw+pitch (eyes track)
##     - EyesClosed  -> `orbicularis03/04.L/R` (orbital sphincter -> lid closure)
##   NOT DRIVABLE (no blendshape, no dedicated bone) — reported as the GAP:
##     - MouthSmile, MouthSad, MouthSnarl, BrowsShy, BrowsAngry,
##       MouthBlep, MouthPanting, EyesSexy, LookCross, Talking(viseme detail)
## The resolved values for the gap channels are still COMPUTED and exposed (tests
## assert on them, and a future expression-blendshape import wires them with zero
## rig change) — they simply have no geometry to move on today's head.
class_name FaceRig
extends Node

const FaceGesture := preload("res://scripts/body/face/face_gesture.gd")
const FaceOverrideProfile := preload("res://scripts/body/face/face_override_profile.gd")
const AffectExpression := preload("res://scripts/body/face/gestures/affect_expression.gd")
const Blinking := preload("res://scripts/body/face/gestures/blinking.gd")
const LookWander := preload("res://scripts/body/face/gestures/look_wander.gd")
const Talking := preload("res://scripts/body/face/gestures/talking.gd")

# --- the live face-channel buffer (BDCC2 valXxx, snake_cased) ------------------
var val_eyes_closed: float = 0.0
var val_eyes_sexy: float = 0.0
var val_brows_shy: float = 0.0
var val_brows_angry: float = 0.0
var val_mouth_open: float = 0.0
var val_mouth_panting: float = 0.0
var val_mouth_blep: float = 0.0
var val_mouth_smile: float = 0.0
var val_mouth_sad: float = 0.0
var val_mouth_snarl: float = 0.0
var val_talking: float = 0.0
var val_look_dir: Vector2 = Vector2.ZERO
var val_look_cross: float = 0.0

var gestures: Array = []
var face_override := FaceOverrideProfile.new()
var rng := RandomNumberGenerator.new()

## The base affect layer (kept as a typed ref so apply_expression can push to it).
var _affect: FaceGesture = null

## The skeleton driven by the bone-sink. Set by the host (the BodyRig's skeleton).
var skeleton: Skeleton3D = null
var _bone_index := {}

## Bone names (CC0 MakeHuman default rig).
const BONE_JAW := "jaw"
const BONE_EYE_L := "eye.L"
const BONE_EYE_R := "eye.R"
const ORBI_L := ["orbicularis03.L", "orbicularis04.L"]
const ORBI_R := ["orbicularis03.R", "orbicularis04.R"]

## Sink tuning (radians at full channel weight). Render-side only.
@export var jaw_open_rad: float = 0.32
@export var eye_yaw_rad: float = 0.35
@export var eye_pitch_rad: float = 0.22
@export var lid_close_rad: float = 0.18

var _rest_q := {}   # bone name -> rest local quaternion


## Seed the rig's RNG and build the gesture stack. Call once after the node is in
## the tree (or explicitly in tests). `seed` makes blink/look-wander replayable.
func setup(seed: int = 0, skel: Skeleton3D = null) -> void:
	rng.seed = seed
	skeleton = skel
	if skeleton != null:
		for i in skeleton.get_bone_count():
			var bn := skeleton.get_bone_name(i)
			_bone_index[bn] = i
			_rest_q[bn] = skeleton.get_bone_pose_rotation(i)
	_build_gestures()


func _build_gestures() -> void:
	gestures.clear()
	_affect = AffectExpression.new()
	_add_gesture(_affect)
	_add_gesture(Blinking.new())
	_add_gesture(LookWander.new())
	_add_gesture(Talking.new())
	_sort_gestures()


func _add_gesture(g: FaceGesture) -> void:
	g.rng = rng
	gestures.append(g)


func _sort_gestures() -> void:
	gestures.sort_custom(func(a, b): return a.get_priority() < b.get_priority())


# --- aeriea's OWN seam: ExpressionSurface -------------------------------------

## Push the affect/intent for this frame. The rig is a SINK — this is the only
## affect input. (Replaces BDCC2's pull from the Doll/BaseCharacter hub.)
func apply_expression(e: ExprState) -> void:
	if _affect != null:
		_affect.target = e


## Transient speech pulse (BDCC2 doTalk). Fires the Talking gesture.
func do_talk(length: float = 3.0) -> void:
	for g in gestures:
		g.on_event("talk", [length])


# --- per-frame resolve (BDCC2 updateFaceExpression) ---------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	step(delta)


## Advance the rig by `delta`: reset channels, composite the gesture stack in
## priority order, apply overrides, then drive the head. Deterministic: pure
## function of (seed, the dt sequence, the pushed ExprStates).
func step(delta: float) -> void:
	_reset_vals()
	for g in gestures:
		g.process_influence(delta)
		g.process_values(self, delta)
	_apply_overrides()
	_drive_head()


func _reset_vals() -> void:
	val_eyes_closed = 0.0
	val_eyes_sexy = 0.0
	val_brows_shy = 0.0
	val_brows_angry = 0.0
	val_mouth_open = 0.0
	val_mouth_panting = 0.0
	val_mouth_blep = 0.0
	val_mouth_smile = 0.0
	val_mouth_sad = 0.0
	val_mouth_snarl = 0.0
	val_talking = 0.0
	val_look_dir = Vector2.ZERO
	val_look_cross = 0.0


func _apply_overrides() -> void:
	for field in face_override.fields:
		match field:
			FaceValue.EyesClosed: val_eyes_closed = face_override.get_override(field)
			FaceValue.MouthOpen: val_mouth_open = face_override.get_override(field)
			FaceValue.MouthSmile: val_mouth_smile = face_override.get_override(field)
			FaceValue.MouthSad: val_mouth_sad = face_override.get_override(field)
			FaceValue.MouthSnarl: val_mouth_snarl = face_override.get_override(field)
			FaceValue.BrowsShy: val_brows_shy = face_override.get_override(field)
			FaceValue.BrowsAngry: val_brows_angry = face_override.get_override(field)
			FaceValue.Talking: val_talking = face_override.get_override(field)
			FaceValue.LookDir: val_look_dir = face_override.get_override(field, Vector2.ZERO)


## The SINK: map the resolved channels onto the head's available BONES. Channels
## with no geometry (the gap) are intentionally not driven here (see class doc).
func _drive_head() -> void:
	if skeleton == null:
		return
	# MouthOpen + a fraction of Talking -> jaw drop.
	var jaw_amt := clampf(maxf(val_mouth_open, val_talking * 0.6), 0.0, 1.0)
	_set_bone_pitch(BONE_JAW, -jaw_amt * jaw_open_rad)
	# EyesClosed -> orbital sphincter bones squeeze toward the lid line.
	var lid := clampf(val_eyes_closed, 0.0, 1.0)
	for bn in ORBI_L + ORBI_R:
		_set_bone_pitch(bn, lid * lid_close_rad)
	# LookDir -> eye yaw (x) + pitch (y).
	_set_eye_look(BONE_EYE_L, val_look_dir)
	_set_eye_look(BONE_EYE_R, val_look_dir)


func _set_bone_pitch(bn: String, angle: float) -> void:
	if not _bone_index.has(bn):
		return
	var rest: Quaternion = _rest_q.get(bn, Quaternion.IDENTITY)
	var q := rest * Quaternion(Vector3.RIGHT, angle)
	skeleton.set_bone_pose_rotation(_bone_index[bn], q.normalized())


func _set_eye_look(bn: String, dir: Vector2) -> void:
	if not _bone_index.has(bn):
		return
	var rest: Quaternion = _rest_q.get(bn, Quaternion.IDENTITY)
	# +x look-right (yaw about UP), +y look-up (pitch about RIGHT).
	var q := rest * Quaternion(Vector3.UP, -dir.x * eye_yaw_rad) \
		* Quaternion(Vector3.RIGHT, -dir.y * eye_pitch_rad)
	skeleton.set_bone_pose_rotation(_bone_index[bn], q.normalized())


## Snapshot the resolved channels (for tests / debug). Pure read.
func resolved() -> Dictionary:
	return {
		"eyes_closed": val_eyes_closed, "eyes_sexy": val_eyes_sexy,
		"brows_shy": val_brows_shy, "brows_angry": val_brows_angry,
		"mouth_open": val_mouth_open, "mouth_panting": val_mouth_panting,
		"mouth_blep": val_mouth_blep, "mouth_smile": val_mouth_smile,
		"mouth_sad": val_mouth_sad, "mouth_snarl": val_mouth_snarl,
		"talking": val_talking, "look_dir": val_look_dir, "look_cross": val_look_cross,
	}


## Which resolved channels have real geometry on today's CC0 head, and which are
## the gap (computed but not rendered). Reported by the demo + asserted by tests.
static func channel_coverage() -> Dictionary:
	return {
		"driven_by_bone": ["mouth_open", "look_dir", "eyes_closed"],
		"gap_no_geometry": ["mouth_smile", "mouth_sad", "mouth_snarl", "brows_shy",
			"brows_angry", "mouth_blep", "mouth_panting", "eyes_sexy", "look_cross",
			"talking"],
	}
