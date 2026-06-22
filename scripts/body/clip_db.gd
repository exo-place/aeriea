## ClipDB — committed library of BDCC2 animation clips RETARGETED onto aeriea's
## 169-bone MakeHuman rig.
##
## Provenance: the per-frame bone rotations are MINED from BDCC2's actual GLB
## animation clips (Anims/Raw/*.glb, by alexofp / Rahi — MIT, "use as a base";
## see NOTICE.md). aeriea does NOT vendor BDCC2's animation ARCHITECTURE (its
## LayeredAnimPlayer addon / AnimationTree / GlobalRegistry); only the CLIP DATA
## is mined and re-expressed as MH-bone-local quaternions. The clips are driven by
## aeriea's OWN clip layer in BodyRig (a plain pose stamp), not BDCC2's player.
##
## This is the BUILT artifact (like base_body.res / locomotion_mm.res): a compact,
## byte-deterministic Resource produced by tools/bdcc2_clip_ingest.gd and COMMITTED,
## so the runtime needs neither BDCC2 nor an editor import step. Regeneration path:
##   godot4 --path . res://tools/bdcc2_clip_ingest.tscn --quit-after 6000
##
## RENDER-SIDE + DETERMINISTIC: clip playback is a pure function of (clip, phase)
## and never touches the seeded sim — same discipline as the cosmetic / MM layers.
##
## RETARGET: BDCC2 and MakeHuman are both anatomically-equivalent A-pose humanoids
## but with DIFFERENT per-bone local axis frames, so a naive local-quat copy would
## scramble the limbs. We transfer the GLOBAL bone orientation RELATIVE TO each
## skeleton's bind (Godot's own FK gives both), de-yaw by the root, then convert to
## an MH-bone-LOCAL rotation via the MH parent's target global. Because the relative
## rotation is taken in WORLD space, the differing local axis conventions cancel —
## the limbs move correctly regardless of how each rig frames its bones. Stored as
## mh_local = mh_rest_q * delta, applied the same way the MM poses are.
##
## Layout (flat PackedArrays for deterministic load + cheap stamp):
##   poses      : frame_count * bone_count*4  (MH-bone-local quats xyzw, rest-relative)
##   clip_first : per clip — first frame index into `poses`
##   clip_len   : per clip — number of frames
##   clip_fps   : per clip — sampled frames per second (for phase -> frame)
##   clip_names : per clip — the BDCC2 clip name (provenance)
##   clip_ids   : per clip — aeriea's stable id for binding (e.g. "wave", "idle_long")
##   bone_names : bone_count — MH target bone order the poses index
class_name ClipDB
extends Resource

@export var frame_count: int = 0
@export var bone_count: int = 0
@export var bone_names: PackedStringArray = PackedStringArray()
@export var poses: PackedFloat32Array = PackedFloat32Array()
@export var clip_first: PackedInt32Array = PackedInt32Array()
@export var clip_len: PackedInt32Array = PackedInt32Array()
@export var clip_fps: PackedFloat32Array = PackedFloat32Array()
@export var clip_names: PackedStringArray = PackedStringArray()
@export var clip_ids: PackedStringArray = PackedStringArray()
@export var source: String = ""


## Clip index for an aeriea id, or -1.
func clip_index(id: String) -> int:
	return clip_ids.find(id)


## Number of clips.
func clip_count() -> int:
	return clip_ids.size()


## Read the MH-bone-local rotation for (global frame index, bone) as a Quaternion.
func pose_quat(frame: int, bone: int) -> Quaternion:
	var b := frame * bone_count * 4 + bone * 4
	return Quaternion(poses[b + 0], poses[b + 1], poses[b + 2], poses[b + 3])


## Resolve a clip-local phase in [0,1) to a global frame index (loops within clip).
func frame_at_phase(clip: int, phase: float) -> int:
	if clip < 0 or clip >= clip_len.size():
		return -1
	var n := clip_len[clip]
	if n <= 0:
		return -1
	var local := int(floor(fposmod(phase, 1.0) * n))
	local = clampi(local, 0, n - 1)
	return clip_first[clip] + local


## Resolve a clip-local time in seconds to a global frame index (loops).
func frame_at_time(clip: int, t: float) -> int:
	if clip < 0 or clip >= clip_len.size():
		return -1
	var fps := clip_fps[clip] if clip < clip_fps.size() else 15.0
	var n := clip_len[clip]
	if n <= 0 or fps <= 0.0:
		return -1
	var local := int(floor(t * fps)) % n
	if local < 0:
		local += n
	return clip_first[clip] + local
