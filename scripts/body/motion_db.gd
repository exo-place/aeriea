## MotionDB — the committed Motion-Matching feature database (Slice 4 of
## docs/decisions/body-and-locomotion-slice.md).
##
## This is the BUILT artifact (like base_body.res): a compact, byte-deterministic
## Resource produced by tools/motion_ingest.gd from the 100STYLE BVH locomotion
## subset (CC BY 4.0, Ian Mason — Zenodo 8127870). Saved to
## res://assets/body/locomotion_mm.res and COMMITTED, so the runtime and
## end-users need neither the raw dataset nor nix; the derivation (nix build
## .#motion-assets) is the regeneration path.
##
## Layout (all flat PackedArrays for deterministic load + cheap search):
##   features    : frame_count * feature_dim  (z-normalized MM feature vectors)
##   feature_mean/std : feature_dim            (the normalization stats, so a live
##                                              query is normalized the same way)
##   poses       : frame_count * bone_count*4  (per-frame target-bone-local quats
##                                              xyzw to apply to the Skeleton3D)
##   clip_id     : frame_count                 (which clip each frame belongs to;
##                                              MM avoids matching past a clip end)
##   bone_names  : bone_count                  (MakeHuman target bone order)
##   clip_names/clip_tags : per clip           (provenance + intent tag)
class_name MotionDB
extends Resource

@export var frame_count: int = 0
@export var feature_dim: int = 0
@export var bone_count: int = 0

@export var bone_names: PackedStringArray = PackedStringArray()
@export var features: PackedFloat32Array = PackedFloat32Array()
@export var feature_mean: PackedFloat32Array = PackedFloat32Array()
@export var feature_std: PackedFloat32Array = PackedFloat32Array()
@export var poses: PackedFloat32Array = PackedFloat32Array()
@export var clip_id: PackedInt32Array = PackedInt32Array()
@export var clip_names: PackedStringArray = PackedStringArray()
@export var clip_tags: PackedStringArray = PackedStringArray()
@export var traj_horizons: PackedInt32Array = PackedInt32Array()
@export var frame_stride: int = 3
@export var source: String = ""


## Read the target-bone-local rotation for (frame, bone) as a Quaternion.
func pose_quat(frame: int, bone: int) -> Quaternion:
	var b := frame * bone_count * 4 + bone * 4
	return Quaternion(poses[b + 0], poses[b + 1], poses[b + 2], poses[b + 3])


func clip_tag_of(frame: int) -> String:
	if frame < 0 or frame >= clip_id.size():
		return ""
	var c := clip_id[frame]
	if c < 0 or c >= clip_tags.size():
		return ""
	return clip_tags[c]
