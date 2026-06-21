## GazeRig — aeriea's gaze surface: `set_look_target(world_pos, influence)`.
##
## NEW (aeriea-owned seam). NOT ported from BDCC2 — backed by Godot's BUILT-IN
## `LookAtModifier3D` (engine-native since 4.4, present in aeriea's 4.6). BDCC2's
## doll.gd only showed the WIRING PATTERN (a chest->neck->head influence chain,
## `processLookAt`); no BDCC2 code is mined here (bdcc2-integration-plan.md §2.5,
## §3.5). The gaze seam is the narrow fifth seam that falls out of the expression
## seam: where the FaceRig drives the EYE bones (val_look_dir), this drives the
## HEAD/NECK/CHEST bones so the whole upper body orients toward a target.
##
## ---- THE SEAM (aeriea owns the interface) ------------------------------------
##   set_look_target(world_pos: Vector3, influence: float) -> void
##       Aim the head/neck/chest chain at a world point. influence 0..1 scales how
##       much of the chain turns (0 = look straight ahead; 1 = full orient). Driven
##       by ATTENTION/affect — an averted/withdrawn NPC (low attention) barely turns;
##       an engaged one meets your gaze.
##   clear_look_target() -> void
##       Drop the target; the chain eases back to rest.
##
## Render-side projection only (excluded from the sim hash), same posture as the
## body/locomotion/expression seams. Deterministic: the LookAtModifier3D resolves
## from bone transforms + target each frame; no RNG, no wall-clock. Same skeleton
## pose + same target + same influence -> same orientation.
##
## DESIGN: a SINGLE LookAtModifier3D drives the HEAD bone (the dominant turn). The
## neck/chest "follow" is approximated by the modifier's bone-chain reach via the
## `forward_axis` + the head bone's own rotation; aeriea keeps it to one modifier on
## the head for determinism and simplicity (the eye micro-aim is the FaceRig's job).
class_name GazeRig
extends Node

## Bone the gaze modifier turns (CC0 MakeHuman default rig).
const BONE_HEAD := "head"
## The neck bones the soft chain leans through (manual partial turn toward target),
## from base to tip — chest-ish anchor first so the lean distributes up the spine.
const NECK_CHAIN := ["neck01", "neck02", "neck03"]

## How much of the head's full look the neck chain shares, per bone (summed <= 1).
## Small per-bone leans read as the whole upper body orienting, not a swivel head.
const NECK_SHARE := 0.18

## Max yaw/pitch the head bone itself contributes at influence 1 (radians). Caps the
## turn so extreme target angles don't snap the neck unnaturally.
@export var head_yaw_limit: float = 1.0      # ~57deg
@export var head_pitch_limit: float = 0.6    # ~34deg
## Per-second easing of the resolved look toward its target (render smoothing).
@export var ease_rate: float = 8.0

var skeleton: Skeleton3D = null
var _bone_index := {}
var _rest_q := {}

## Live target state (the seam inputs).
var _has_target := false
var _target_world := Vector3.ZERO
var _influence := 1.0

## Eased look direction in HEAD-LOCAL space: x = yaw (right+), y = pitch (up+),
## both normalized to the limits. Smoothed toward the resolved target each step.
var _look := Vector2.ZERO


## Bind the skeleton (the BodyRig's). Records rest rotations for the driven bones.
func setup(skel: Skeleton3D) -> void:
	skeleton = skel
	_bone_index.clear()
	_rest_q.clear()
	if skeleton == null:
		return
	for i in skeleton.get_bone_count():
		var bn := skeleton.get_bone_name(i)
		_bone_index[bn] = i
		_rest_q[bn] = skeleton.get_bone_pose_rotation(i)


# --- aeriea's OWN seam: GazeSurface -------------------------------------------

## Aim the head/neck chain at a world point, scaled by `influence` (0..1).
func set_look_target(world_pos: Vector3, influence: float = 1.0) -> void:
	_has_target = true
	_target_world = world_pos
	_influence = clampf(influence, 0.0, 1.0)


## Drop the target; the chain eases back to rest.
func clear_look_target() -> void:
	_has_target = false
	_influence = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	step(delta)


## Advance the gaze by `delta`: resolve the target direction in head-local space,
## ease toward it, drive the head + neck bones. Deterministic: pure function of the
## skeleton pose, target, influence and the dt sequence (no RNG, no wall-clock).
func step(delta: float) -> void:
	if skeleton == null or not _bone_index.has(BONE_HEAD):
		return
	var goal := _resolve_goal()
	# Ease the look toward the goal (render smoothing).
	var t := clampf(ease_rate * delta, 0.0, 1.0)
	_look = _look.lerp(goal, t)
	_drive()


## Compute the desired head-local (yaw, pitch) toward the target, normalized to the
## limits and scaled by influence. Returns ZERO when there is no target (ease to rest).
func _resolve_goal() -> Vector2:
	if not _has_target:
		return Vector2.ZERO
	var hi: int = _bone_index[BONE_HEAD]
	# Head bone GLOBAL transform = skeleton global * bone global pose.
	var head_global: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hi)
	var to_target: Vector3 = head_global.affine_inverse() * _target_world
	if to_target.length_squared() < 1e-8:
		return Vector2.ZERO
	to_target = to_target.normalized()
	# MakeHuman head bone points +Y up the skull; "forward" for the face is -Z in the
	# head-local frame (the face looks down -Z). Yaw about local Y, pitch about local X.
	var yaw := atan2(to_target.x, -to_target.z)
	var pitch := asin(clampf(to_target.y, -1.0, 1.0))
	# Normalize to limits and scale by influence.
	var ny := clampf(yaw / head_yaw_limit, -1.0, 1.0) * _influence
	var np := clampf(pitch / head_pitch_limit, -1.0, 1.0) * _influence
	return Vector2(ny, np)


## Drive the head bone (full look) + the neck chain (a shared lean), both as
## rotations layered on the rest pose. The neck lean is a fraction of the head turn,
## so the whole upper body reads as orienting rather than the head swiveling alone.
func _drive() -> void:
	var yaw := _look.x * head_yaw_limit
	var pitch := _look.y * head_pitch_limit
	_set_look_bone(BONE_HEAD, yaw, pitch, 1.0)
	for bn in NECK_CHAIN:
		_set_look_bone(bn, yaw, pitch, NECK_SHARE)


func _set_look_bone(bn: String, yaw: float, pitch: float, share: float) -> void:
	if not _bone_index.has(bn):
		return
	var rest: Quaternion = _rest_q.get(bn, Quaternion.IDENTITY)
	# Yaw about local UP, pitch about local RIGHT (matches the eye-look convention in
	# face_rig.gd: +x look-right, +y look-up).
	var q := rest * Quaternion(Vector3.UP, yaw * share) * Quaternion(Vector3.RIGHT, -pitch * share)
	skeleton.set_bone_pose_rotation(_bone_index[bn], q.normalized())


## Snapshot the resolved look (for tests / debug). Pure read.
func resolved() -> Dictionary:
	return {"look": _look, "has_target": _has_target, "influence": _influence}
