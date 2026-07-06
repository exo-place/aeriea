## Motion-Matching ingest + retarget + feature-DB build (Slice 4 of
## docs/decisions/body-and-locomotion-slice.md).
##
## Pipeline (mirrors tools/body_converter.gd's reproducible posture):
##
##   100STYLE BVH (CC BY 4.0, Ian Mason — Zenodo 8127870)
##        │  parse hierarchy + per-frame Euler channels  (ASCII, deterministic)
##        ▼
##   per-frame skeleton pose (root motion + joint local rotations)
##        │  retarget onto the Slice-3 163-bone MakeHuman rig
##        │  (joint-name map; bone-local quaternions; deterministic)
##        ▼
##   Motion-Matching FEATURE DB  (research §A1):
##     per-frame [ trajectory(future pos+dir over horizons),
##                 left/right foot local pos + vel, hip planar velocity ]
##     z-normalized; + the retargeted per-frame bone-rotation poses.
##        ▼
##   res://assets/body/locomotion_mm.res  (committed; the BUILT artifact, like
##                                          base_body.res — runtime needs neither
##                                          the raw dataset nor nix)
##
## DETERMINISM: BVH lines parsed in file order; clips ingested in a fixed sorted
## order; frames sub-sampled at a fixed stride; features computed with a fixed
## float path; normalization stats folded in stable order. Same vendored/pinned
## input → byte-identical locomotion_mm.res.
##
## Run (fetch-free, vendored subset):
##   godot4 --headless --path . res://tools/motion_ingest.tscn --quit-after 6000
## Run (nix, pinned full 100STYLE fetch):
##   nix build .#motion-assets
##
## HONEST SCOPE: 100STYLE BVH (ASCII) is ingested fully. CMU is sourced+pinned
## (gbionics/cmu-fbx @ d18e9d3…) but its FBX is Kaydara *binary* FBX, which Godot
## has no runtime parser for — CMU ingest is deferred behind a BVH mirror / an
## editor-side FBX→BVH step (see the decision doc Slice-4 section). The ingest
## seam below is dataset-agnostic at the BVH boundary, so CMU drops in later.
extends Node

const SRC_DIR_DEFAULT := "res://vendor/100style-cc-by/100STYLE"
const OUT_DB := "res://assets/body/locomotion_mm.res"
const RIG_PATH := "res://assets/body/base_body_rig.json"

## Arm bones whose BVH bind (T-pose, arm-out) differs from the MH bind (A-pose,
## arm-down). These retarget by SEGMENT DIRECTION (A-pose-zeroed); every other
## mapped bone uses the full de-yawed global orientation (BVH/MH binds agree).
const ARM_BONES := {
	"upperarm01.L": true, "lowerarm01.L": true,
	"upperarm01.R": true, "lowerarm01.R": true,
}

## Sub-sample stride over the 60fps BVH (keeps the committed DB compact while
## preserving locomotion detail). 60fps / 4 = 15 fps sample rate.
const FRAME_STRIDE := 4
## Cap sampled frames emitted per clip (keeps the committed DB a few MB, like
## base_body.res; each clip still contributes a rich locomotion span). Frames are
## taken from the clip start (after CLIP_TRIM); deterministic.
const MAX_FRAMES_PER_CLIP := 360
## Trajectory feature horizons, in SAMPLED frames ahead (≈ 0.5s, 1.0s at 20fps).
const TRAJ_HORIZONS := [10, 20]
## Drop the first/last N sampled frames of each clip (BVH ends settle / T-pose).
const CLIP_TRIM := 6

## The locomotion subset clips we ingest, with the desired-trajectory "intent"
## each one represents (used only for the test's clip-selection assertions and
## for a small per-clip tag in the manifest; the MM search itself is data-driven).
## Suffixes: ID idle, FW fwd-walk, FR fwd-run, BW back-walk, BR back-run,
## SW side-walk, SR side-run, TR1 turn.

## MakeHuman target bones we drive from retargeted BVH joints. We map the major
## locomotion joints; the rest of the 163-bone rig keeps its rest pose (fine —
## MM drives the gross body, foot-IK refines ground contact on top).
## key = MakeHuman bone name ; value = candidate 100STYLE/BVH joint names.
# Candidate joint names cover the 100STYLE skeleton (Hips/Chest/LeftHip/LeftKnee/
# LeftAnkle/LeftShoulder/LeftElbow/LeftCollar/…) plus common alternates so the
# same map works for a CMU-derived BVH mirror later.
const BONE_MAP := {
	"root":          ["Hips", "hip", "Hip"],
	# Axial chain (spine+neck+head) — NOT single-joint local-rotation copy. These are
	# solved by orientation-driven spline-IK (_solve_axial); the candidate here only
	# marks the bone present + resolves an existence check. See AXIAL_CHAIN / AXIAL_ARC
	# and docs/decisions/spine-retarget-world-orientation.md.
	"spine05":       ["Hips"],
	"spine04":       ["Chest"],
	"spine03":       ["Chest2"],
	"spine02":       ["Chest3"],
	"spine01":       ["Chest4"],
	"neck01":        ["Neck", "neck"],
	"neck02":        ["Neck"],
	"neck03":        ["Neck"],
	"head":          ["Head", "head"],
	"upperleg01.L":  ["LeftHip", "LeftUpLeg", "LHipJoint", "LeftUpperLeg"],
	"lowerleg01.L":  ["LeftKnee", "LeftLeg", "LeftLowerLeg"],
	"foot.L":        ["LeftAnkle", "LeftFoot"],
	"upperleg01.R":  ["RightHip", "RightUpLeg", "RHipJoint", "RightUpperLeg"],
	"lowerleg01.R":  ["RightKnee", "RightLeg", "RightLowerLeg"],
	"foot.R":        ["RightAnkle", "RightFoot"],
	"upperarm01.L":  ["LeftShoulder", "LeftArm", "LeftUpperArm"],
	"lowerarm01.L":  ["LeftElbow", "LeftForeArm", "LeftLowerArm"],
	"upperarm01.R":  ["RightShoulder", "RightArm", "RightUpperArm"],
	"lowerarm01.R":  ["RightElbow", "RightForeArm", "RightLowerArm"],
	"clavicle.L":    ["LeftCollar", "LeftClavicle"],
	"clavicle.R":    ["RightCollar", "RightClavicle"],
}

## For each mapped MH bone, the rig-JSON bone whose HEAD gives this bone's TAIL —
## so head→tail is the bone's REST DIRECTION in MH space. Used to build the
## rest-orientation alignment (BVH bind dir → MH bind dir) per bone. End bones
## (foot/head/forearm/lowerleg) point at a representative descendant tip.
## NOTE: the axial chain (spine*/neck*/head) is absent here on purpose — those bones
## are solved by orientation-driven spline-IK (_solve_axial), not the bind-direction
## transfer this table feeds. Only root/legs/arms use segment-direction alignment.
const MH_TAIL := {
	"root":          "spine05",
	"upperleg01.L":  "lowerleg01.L",
	"lowerleg01.L":  "foot.L",
	"foot.L":        "toe1-1.L",
	"upperleg01.R":  "lowerleg01.R",
	"lowerleg01.R":  "foot.R",
	"foot.R":        "toe1-1.R",
	"clavicle.L":    "upperarm01.L",
	"upperarm01.L":  "lowerarm01.L",
	"lowerarm01.L":  "wrist.L",
	"clavicle.R":    "upperarm01.R",
	"upperarm01.R":  "lowerarm01.R",
	"lowerarm01.R":  "wrist.R",
}

## For each mapped MH bone, the BVH joint whose OFFSET gives the corresponding
## bone segment's REST DIRECTION (the child joint along the same limb segment in
## the 100STYLE skeleton). The segment dir = the child's OFFSET (joint-local, but
## at the zero/bind pose all ancestor rotations are identity so it is also the
## world-space bind direction of that segment).
const BVH_TAIL := {
	"root":          "Chest",
	"upperleg01.L":  "LeftKnee",
	"lowerleg01.L":  "LeftAnkle",
	"foot.L":        "LeftToe",
	"upperleg01.R":  "RightKnee",
	"lowerleg01.R":  "RightAnkle",
	"foot.R":        "RightToe",
	"clavicle.L":    "LeftShoulder",
	"upperarm01.L":  "LeftElbow",
	"lowerarm01.L":  "LeftWrist",
	"clavicle.R":    "RightShoulder",
	"upperarm01.R":  "RightElbow",
	"lowerarm01.R":  "RightWrist",
}

## The MakeHuman-bone hierarchy among the mapped bones (nearest mapped ancestor),
## used to convert per-joint GLOBAL rotation deltas into chain-correct LOCAL
## rotations on the MakeHuman skeleton. "" = no mapped parent (driven in the
## root/world frame).
## CORRECTED axial topology (was inverted). Real MH chain by parent index:
## root → spine05 → spine04 → spine03 → spine02 → spine01 → neck01 → neck02 →
## neck03 → head (spine05 = lumbar/lowest, spine01 = thoracic/highest, parent of
## neck01). Clavicles attach at spine01 (the top of the spine), not the old spine03.
const MH_PARENT := {
	"root":          "",
	"spine05":       "root",
	"spine04":       "spine05",
	"spine03":       "spine04",
	"spine02":       "spine03",
	"spine01":       "spine02",
	"neck01":        "spine01",
	"neck02":        "neck01",
	"neck03":        "neck02",
	"head":          "neck03",
	"upperleg01.L":  "root",
	"lowerleg01.L":  "upperleg01.L",
	"foot.L":        "lowerleg01.L",
	"upperleg01.R":  "root",
	"lowerleg01.R":  "upperleg01.R",
	"foot.R":        "lowerleg01.R",
	"clavicle.L":    "spine01",
	"upperarm01.L":  "clavicle.L",
	"lowerarm01.L":  "upperarm01.L",
	"clavicle.R":    "spine01",
	"upperarm01.R":  "clavicle.R",
	"lowerarm01.R":  "upperarm01.R",
}

## --- Orientation-driven spline-IK for the axial chain ----------------------
## (docs/decisions/spine-retarget-world-orientation.md). We preserve the SOURCE
## chain's WORLD-space segment orientation (not parent-relative local rotations,
## which are segment-count dependent and lossy across skeletons). Per frame we
## arc-slerp the de-yawed source world orientations onto each target joint's
## normalized arc position, then constrain (coronal locked flat, sagittal free,
## axial twist passed-through-but-per-joint-capped) and convert to local over the
## CORRECTED chain. Closed form → byte-deterministic (no iteration).

## Target axial chain in parent→child order, each with its normalized arc position
## along the corresponding SOURCE segment (spine = Hips→Neck, neck = Neck→Head).
## Positions measured from both rigs (see the decision doc's arc tables).
const AXIAL_CHAIN := ["spine05", "spine04", "spine03", "spine02", "spine01",
	"neck01", "neck02", "neck03", "head"]
const AXIAL_ARC := {
	"spine05": {"seg": "spine", "s": 0.146},
	"spine04": {"seg": "spine", "s": 0.230},
	"spine03": {"seg": "spine", "s": 0.345},
	"spine02": {"seg": "spine", "s": 0.496},
	"spine01": {"seg": "spine", "s": 0.748},
	"neck01":  {"seg": "spine", "s": 1.000},
	"neck02":  {"seg": "neck",  "s": 0.350},
	"neck03":  {"seg": "neck",  "s": 0.667},
	"head":    {"seg": "neck",  "s": 1.000},
}
## Source de-yawed world-orientation samples along the spine (Hips→Neck) and neck
## (Neck→Head) arcs: [BVH joint name, normalized arc position]. Ascending.
const SRC_SPINE_SAMPLES := [
	["Hips", 0.000], ["Chest", 0.235], ["Chest2", 0.422],
	["Chest3", 0.590], ["Chest4", 0.759], ["Neck", 1.000],
]
const SRC_NECK_SAMPLES := [["Neck", 0.000], ["Head", 1.000]]

## Coronal (lateral / side-to-side) deadband: below this the coronal swing is noise
## and is zeroed on EVERY axial joint. Design fork resolved to a hard threshold in
## the 5-8° band. MEASURED DISCOVERY (see the decision doc): the 100STYLE source
## carries a pervasive, REAL ~15-23°/segment lateral component that is LOAD-BEARING
## for head orientation — hard-locking all of it flat reintroduces a 27-40° head
## world-orientation error (i.e. a head-mis-orientation defect akin to the one this
## fix removes). So the policy is SPLIT: the SPINE (torso) is locked flat above the
## deadband — the actual "no hunch / upright" intent, spine coronal → 0 — while the
## NECK passes evidenced coronal through so the head still lands on the source
## orientation (head_err stays ~6°). NECK_CORONAL_PASSTHROUGH names that split.
const LAT_EPS_DEG := 6.0
const NECK_CORONAL_PASSTHROUGH := true
## Per-joint LOCAL axial-twist ceiling. The arc-slerp of world orientations already
## DISTRIBUTES source twist smoothly across the chain (the primary distribution
## mechanism — measured: spine joints ≤4°, twist concentrates naturally in the neck,
## ≤17° on neck01 in a turn, declining down the neck — anatomically correct, not a
## dump). This ceiling is the guard that caps any single subsegment so evidenced
## twist stays spread and none is synthesized/piled onto one joint; set generous so
## it preserves the natural neck twist (≤17°) and only bites a pathological dump.
const MAX_JOINT_TWIST_DEG := 25.0


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _src_dir() -> String:
	var env := OS.get_environment("STYLE100_SRC")
	if env != "":
		return env
	return ProjectSettings.globalize_path(SRC_DIR_DEFAULT)


func _run() -> int:
	var src := _src_dir()
	print("motion_ingest: src = %s" % src)
	var bvh_paths := _list_bvh(src)
	if bvh_paths.is_empty():
		push_error("motion_ingest: no BVH clips under %s" % src)
		return 1
	bvh_paths.sort()  # deterministic clip order
	print("motion_ingest: %d clips" % bvh_paths.size())

	# Per-clip retargeted frames + features, concatenated.
	var bone_names := PackedStringArray(BONE_MAP.keys())
	var nbones := bone_names.size()

	var all_poses := PackedFloat32Array()   # frame * nbones * 4 (quat xyzw)
	var all_feats := PackedFloat32Array()   # frame * feat_dim (raw, pre-norm)
	var clip_id_of_frame := PackedInt32Array()
	var clip_names := PackedStringArray()
	var clip_tags := PackedStringArray()

	var feat_dim := _feature_dim()

	for ci in bvh_paths.size():
		var path: String = bvh_paths[ci]
		var clip := _parse_bvh(path)
		if clip.is_empty():
			print("  skip (parse fail): %s" % path)
			continue
		var name := path.get_file().get_basename()
		var retf := _retarget_clip(clip, bone_names)   # Array of {pose:PackedFloat32, root_xz:Vector2, foot:..., facing:float}
		var max_h := int(TRAJ_HORIZONS.max())
		if retf.size() < (2 * CLIP_TRIM + 2 * max_h + 1):
			print("  skip (too short %d): %s" % [retf.size(), name])
			continue
		var ci_out := clip_names.size()
		clip_names.append(name)
		clip_tags.append(_tag_for(name))
		# emit frames in [CLIP_TRIM, n - max_horizon) so future trajectory exists
		var n := retf.size()
		var last := n - max_h - 1
		last = min(last, CLIP_TRIM + MAX_FRAMES_PER_CLIP)
		# Per-clip axial verification (all emitted frames), in degrees.
		var head_err_max := 0.0
		var spine_cor_max := 0.0
		var neck_cor_max := 0.0
		var tw_max := 0.0
		var sag_err_max := 0.0
		for fi in range(CLIP_TRIM, last):
			# pose
			var pose: PackedFloat32Array = retf[fi]["pose"]
			all_poses.append_array(pose)
			# feature
			var feat := _frame_feature(retf, fi)
			all_feats.append_array(feat)
			clip_id_of_frame.append(ci_out)
			head_err_max = maxf(head_err_max, float(retf[fi].get("head_err", 0.0)))
			spine_cor_max = maxf(spine_cor_max, float(retf[fi].get("spine_cor", 0.0)))
			neck_cor_max = maxf(neck_cor_max, float(retf[fi].get("neck_cor", 0.0)))
			tw_max = maxf(tw_max, float(retf[fi].get("tw_max", 0.0)))
			sag_err_max = maxf(sag_err_max,
				absf(float(retf[fi].get("sag_sum", 0.0)) - float(retf[fi].get("src_sag", 0.0))))
		print("  %s: %d frames -> emitted (tag=%s) | axial: head_err<=%.1f° spine_cor<=%.1f° neck_cor<=%.1f° twist<=%.1f° aggr-sag-err<=%.1f°" %
			[name, n, _tag_for(name), rad_to_deg(head_err_max), rad_to_deg(spine_cor_max),
			rad_to_deg(neck_cor_max), rad_to_deg(tw_max), rad_to_deg(sag_err_max)])
		# At-source guard: a craned/double-head retarget shows head_err in the 70-90°
		# regime; the corrected spline-IK holds ~6°. Fail the build if any clip regresses
		# past the design's <10° head-fidelity contract (small numeric margin). Also guard
		# the torso-flat contract (spine coronal must stay ~0).
		if rad_to_deg(head_err_max) > 12.0:
			push_error("motion_ingest: %s head world-orientation error %.1f° exceeds 12° guard (double-head regression)" %
				[name, rad_to_deg(head_err_max)])
			return 1
		if rad_to_deg(spine_cor_max) > 4.0:
			push_error("motion_ingest: %s spine coronal %.1f° exceeds 4° flat-torso guard" %
				[name, rad_to_deg(spine_cor_max)])
			return 1

	var frame_count := clip_id_of_frame.size()
	if frame_count == 0:
		push_error("motion_ingest: zero frames emitted")
		return 1
	print("motion_ingest: %d frames, feat_dim=%d, nbones=%d" % [frame_count, feat_dim, nbones])

	# --- z-normalize features (per dimension), stable fold order --------------
	var mean := PackedFloat32Array(); mean.resize(feat_dim)
	var std := PackedFloat32Array(); std.resize(feat_dim)
	for d in feat_dim:
		var s := 0.0
		for f in frame_count:
			s += all_feats[f * feat_dim + d]
		mean[d] = s / float(frame_count)
	for d in feat_dim:
		var s := 0.0
		for f in frame_count:
			var x := all_feats[f * feat_dim + d] - mean[d]
			s += x * x
		std[d] = sqrt(s / float(frame_count))
		if std[d] < 1e-6:
			std[d] = 1.0
	for f in frame_count:
		for d in feat_dim:
			var i := f * feat_dim + d
			all_feats[i] = (all_feats[i] - mean[d]) / std[d]

	# --- build + save the resource -------------------------------------------
	# Load the script explicitly rather than via the `class_name` global symbol:
	# in a clean headless build (nix sandbox) the global class cache may not be
	# populated before this tool's script loads, so referencing `MotionDB`
	# directly is a parse error. load() resolves the type at runtime.
	var MotionDBScript := load("res://scripts/body/motion_db.gd")
	var db: Resource = MotionDBScript.new()
	db.frame_count = frame_count
	db.feature_dim = feat_dim
	db.bone_count = nbones
	db.bone_names = bone_names
	db.features = all_feats
	db.feature_mean = mean
	db.feature_std = std
	db.poses = all_poses
	db.clip_id = clip_id_of_frame
	db.clip_names = clip_names
	db.clip_tags = clip_tags
	db.traj_horizons = PackedInt32Array(TRAJ_HORIZONS)
	db.frame_stride = FRAME_STRIDE
	db.source = "100STYLE (Ian Mason; Zenodo 8127870; CC BY 4.0) locomotion subset: Neutral/StartStop/March"

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/body"))
	var werr := ResourceSaver.save(db, OUT_DB, ResourceSaver.FLAG_COMPRESS)
	if werr != OK:
		push_error("motion_ingest: save failed %d" % werr)
		return 1
	print("motion_ingest: wrote %s (frames=%d)" % [OUT_DB, frame_count])
	return 0


# ---------------------------------------------------------------------------
# Feature layout (research §A1):
#   for each horizon h in TRAJ_HORIZONS:  future root pos (x,z) rel to current,
#                                         future facing dir (x,z) rel to current  -> 4 each
#   left foot local pos (x,y,z) + vel (x,y,z)                                     -> 6
#   right foot local pos (x,y,z) + vel (x,y,z)                                    -> 6
#   hip planar velocity (x,z)                                                     -> 2
# ---------------------------------------------------------------------------
func _feature_dim() -> int:
	return TRAJ_HORIZONS.size() * 4 + 6 + 6 + 2


func _frame_feature(retf: Array, fi: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var cur: Dictionary = retf[fi]
	var origin: Vector2 = cur["root_xz"]
	var facing: float = cur["facing"]   # yaw radians
	var cosf := cos(-facing)
	var sinf := sin(-facing)
	# Trajectory: future root position + future facing, in the current frame's
	# local (facing-aligned) frame -> rotation/translation invariant goal.
	for h in TRAJ_HORIZONS:
		var fut: Dictionary = retf[fi + h]
		var dxz: Vector2 = (fut["root_xz"] as Vector2) - origin
		var lx := dxz.x * cosf - dxz.y * sinf
		var lz := dxz.x * sinf + dxz.y * cosf
		out.append(lx); out.append(lz)
		var fyaw: float = fut["facing"] - facing
		out.append(sin(fyaw)); out.append(cos(fyaw))
	# Feet (already local to root in retarget) + velocity vs previous sampled frame.
	var prev: Dictionary = retf[max(fi - 1, 0)]
	var lf: Vector3 = cur["foot_l"]; var lf0: Vector3 = prev["foot_l"]
	var rf: Vector3 = cur["foot_r"]; var rf0: Vector3 = prev["foot_r"]
	out.append(lf.x); out.append(lf.y); out.append(lf.z)
	out.append(lf.x - lf0.x); out.append(lf.y - lf0.y); out.append(lf.z - lf0.z)
	out.append(rf.x); out.append(rf.y); out.append(rf.z)
	out.append(rf.x - rf0.x); out.append(rf.y - rf0.y); out.append(rf.z - rf0.z)
	# Hip planar velocity in local frame.
	var hv: Vector2 = (origin - (prev["root_xz"] as Vector2))
	var hvx := hv.x * cosf - hv.y * sinf
	var hvz := hv.x * sinf + hv.y * cosf
	out.append(hvx); out.append(hvz)
	return out


# ---------------------------------------------------------------------------
# BVH parsing (ASCII) — hierarchy + MOTION channels, in file order.
# Returns {} on failure, else:
#   { joints: [ {name, parent, offset:Vector3, channels:[String]} ],
#     order: [joint_index per channel-group],   # implicit by joints order
#     frame_time: float, frames: int,
#     motion: PackedFloat32Array (frames * total_channels) }
# ---------------------------------------------------------------------------
func _parse_bvh(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n", false)
	var joints := []
	var stack := []   # indices
	var total_channels := 0
	var i := 0
	# --- HIERARCHY ---
	while i < lines.size():
		var ln: String = lines[i].strip_edges()
		i += 1
		if ln.begins_with("MOTION"):
			break
		var toks := ln.split(" ", false)
		if toks.size() == 0:
			continue
		var kw: String = toks[0]
		if kw == "ROOT" or kw == "JOINT":
			var jn: String = toks[1] if toks.size() > 1 else "j%d" % joints.size()
			var parent := -1 if stack.is_empty() else int(stack[-1])
			joints.append({"name": jn, "parent": parent, "offset": Vector3.ZERO, "channels": []})
			stack.append(joints.size() - 1)
		elif kw == "End":
			# End Site — skip its block (OFFSET + braces), consume until matching }
			var depth := 0
			while i < lines.size():
				var l2: String = lines[i].strip_edges(); i += 1
				if l2.begins_with("{"): depth += 1
				elif l2.begins_with("}"):
					depth -= 1
					if depth <= 0: break
		elif kw == "OFFSET":
			if not stack.is_empty() and toks.size() >= 4:
				joints[int(stack[-1])]["offset"] = Vector3(float(toks[1]), float(toks[2]), float(toks[3]))
		elif kw == "CHANNELS":
			if not stack.is_empty():
				var cnt := int(toks[1])
				var chans := []
				for c in range(cnt):
					chans.append(toks[2 + c])
				joints[int(stack[-1])]["channels"] = chans
				total_channels += cnt
		elif kw == "}":
			if not stack.is_empty():
				stack.pop_back()
	# --- MOTION ---
	var frames := 0
	var frame_time := 1.0 / 60.0
	while i < lines.size():
		var ln2: String = lines[i].strip_edges(); i += 1
		if ln2.begins_with("Frames:"):
			frames = int(ln2.split(":", false)[1].strip_edges())
		elif ln2.begins_with("Frame Time:"):
			frame_time = float(ln2.split(":", false)[1].strip_edges())
			break
	var motion := PackedFloat32Array()
	while i < lines.size():
		var ln3: String = lines[i].strip_edges(); i += 1
		if ln3 == "":
			continue
		var vals := ln3.split(" ", false)
		for v in vals:
			motion.append(float(v))
	return {
		"joints": joints, "frame_time": frame_time,
		"frames": frames, "total_channels": total_channels, "motion": motion,
	}


# ---------------------------------------------------------------------------
# Retarget a parsed BVH clip onto the MakeHuman target bones.
# For each SAMPLED frame: compute every BVH joint's local rotation (quat) from
# its Euler channels, build joint global transforms (forward kinematics over the
# BVH skeleton) to recover root position + facing + foot positions, then emit
# the target-bone local rotations via the BONE_MAP.
# Returns an Array (per sampled frame) of:
#   { pose: PackedFloat32 (nbones*4, target-bone-local quat xyzw, rest=identity
#           delta means we store the BVH joint local rotation directly),
#     root_xz: Vector2, facing: float, foot_l: Vector3, foot_r: Vector3 }
# ---------------------------------------------------------------------------
func _retarget_clip(clip: Dictionary, bone_names: PackedStringArray) -> Array:
	var joints: Array = clip["joints"]
	var nj := joints.size()
	var total_channels: int = clip["total_channels"]
	var motion: PackedFloat32Array = clip["motion"]
	var frames: int = clip["frames"]
	if total_channels == 0 or frames == 0:
		return []

	# joint name -> index
	var jidx := {}
	for k in nj:
		jidx[joints[k]["name"]] = k
	# resolve each target bone -> a BVH joint index (first candidate that exists)
	var target_to_bvh := {}
	for tb in bone_names:
		var cands: Array = BONE_MAP[tb]
		for c in cands:
			if jidx.has(c):
				target_to_bvh[tb] = int(jidx[c]); break
	var foot_l_idx := int(jidx.get("LeftAnkle", jidx.get("LeftFoot", -1)))
	var foot_r_idx := int(jidx.get("RightAnkle", jidx.get("RightFoot", -1)))
	var nbones := bone_names.size()

	# channel base offset per joint (in motion-row order = joints declaration order)
	var ch_base := []
	ch_base.resize(nj)
	var acc := 0
	for k in nj:
		ch_base[k] = acc
		acc += (joints[k]["channels"] as Array).size()

	# --- FRAME-OF-REFERENCE: rest-relative LOCAL retarget ---------------------
	# THE BUG THIS REPLACES: the old retarget used BVH MOTION frame 0 as the "rest"
	# reference and transferred the GLOBAL rotation delta G(f)·G(0)⁻¹. But a 100STYLE
	# MOTION frame 0 is NOT a neutral bind pose — it is an arbitrary already-posed
	# capture frame (e.g. Neutral_ID frame 0 has the Hips yawed 74° and the left
	# elbow bent ~100°). So every emitted pose carried the NEGATION of that arbitrary
	# frame: a genuine still-standing idle came out with the root thrown ~65° and the
	# forearm ~94° off — the documented contortion.
	#
	# THE FIX (global-orientation transfer with per-bone bind alignment): the MH mesh
	# is bound in an A-POSE while the MH bone rest bases are world-identity (the A-pose
	# lives in the SKIN, not the bone rests — see body_rig.gd). The BVH bind pose is a
	# T-POSE. So we transfer the BVH joint's GLOBAL orientation, re-expressed in the MH
	# bone's frame by R_align (the rotation carrying the BVH bind segment direction onto
	# the MH bind segment direction), then convert to an MH-LOCAL pose via the MH parent's
	# global. Because the MH global rest is identity for every bone, MH-local pose =
	# (parent target global)⁻¹ · (this bone's target global). At a relaxed capture (arm
	# hanging ≈ the A-pose mesh direction) this lands the MH arm bone near identity — no
	# double-counted A-pose offset — which is exactly a natural stand.
	#
	# ROOT FACING is sim-owned (the player controller drives heading); it must NEVER be
	# baked into a bone pose. The root's GLOBAL orientation has its world YAW stripped
	# (lean/tilt kept) so a turned-in-capture idle stands facing forward, and the whole
	# upper-body chain inherits the de-yawed frame (no spurious 65° root throw).
	_build_dir_caches(jidx, joints)

	var out := []
	var fi := 0
	while fi < frames:
		# global rotations (for the transfer) + transforms (root pos/facing + feet).
		var res := _fk_frame(joints, ch_base, motion, total_channels, fi, nj)
		var global_rot: Array = res["grot"]
		var gxf: Array = res["gxf"]
		# only emit on the sub-sample stride
		if fi % FRAME_STRIDE == 0:
			var root_t: Transform3D = gxf[0]
			var root_xz := Vector2(root_t.origin.x, root_t.origin.z) * 0.01  # BVH cm -> m
			var fwd := root_t.basis * Vector3.FORWARD
			var facing := atan2(fwd.x, fwd.z)
			var foot_l := Vector3.ZERO
			var foot_r := Vector3.ZERO
			if foot_l_idx >= 0:
				foot_l = (root_t.affine_inverse() * (gxf[foot_l_idx] as Transform3D)).origin * 0.01
			if foot_r_idx >= 0:
				foot_r = (root_t.affine_inverse() * (gxf[foot_r_idx] as Transform3D)).origin * 0.01
			# Strip the world yaw of the root's GLOBAL orientation; every mapped bone's
			# captured direction is then re-expressed relative to this de-yawed root frame
			# so the whole body is facing-invariant (facing is sim-owned).
			var root_g: Quaternion = global_rot[target_to_bvh.get("root", 0)] if target_to_bvh.has("root") else Quaternion.IDENTITY
			var yaw_inv := _yaw_only(root_g).inverse()
			# Target MH GLOBAL orientation per mapped bone. The MH bone rests are world-
			# identity, so for the torso/legs (whose BVH bind segment direction matches the
			# MH bind direction) the de-yawed BVH global IS the MH target global directly —
			# this gave a natural root/spine/legs (root ≈ 7°, legs ≈ 10° at idle). The ARMS
			# differ: BVH binds them in a T-pose, MH binds them A-posed (in the MESH). For
			# those bones we pre-multiply by the per-bone A_OFFSET (the A-pose↔T-pose bind
			# rotation), so a captured arm that hangs ≈ the A-pose lands near identity
			# instead of carrying the full T→side swing (the earlier 76° double-count).
			# De-yawed SOURCE world orientations at each axial sample joint — the
			# orientation profile the target spine/neck/head chain must reproduce.
			var gd := {}
			for jn in ["Hips", "Chest", "Chest2", "Chest3", "Chest4", "Neck", "Head"]:
				if jidx.has(jn):
					gd[jn] = (yaw_inv * (global_rot[int(jidx[jn])] as Quaternion)).normalized()
			var tgt_global := {}
			for tb in MH_PARENT.keys():
				# Axial bones are solved by spline-IK below, not by single-joint transfer.
				if AXIAL_ARC.has(tb):
					continue
				if not target_to_bvh.has(tb):
					tgt_global[tb] = Quaternion.IDENTITY
					continue
				var g: Quaternion = (yaw_inv * (global_rot[target_to_bvh[tb]] as Quaternion)).normalized()
				if ARM_BONES.has(tb) and _mh_dir_cache.has(tb) and _bvh_dir_cache.has(tb):
					# DIRECTION transfer (A-pose mesh dir → captured dir): the T/A bind
					# mismatch makes the arms' full orientation transfer double-count the
					# A-pose, so the arms map by SEGMENT DIRECTION (zeroed at the A-pose).
					var cap_dir: Vector3 = (g * (_bvh_dir_cache[tb] as Vector3)).normalized()
					tgt_global[tb] = _shortest_arc(_mh_dir_cache[tb], cap_dir)
				else:
					# GLOBAL-ORIENTATION transfer (legs / root): BVH and MH bind directions
					# agree, so the de-yawed BVH global IS the MH target global.
					tgt_global[tb] = g
			# Axial chain: orientation-driven spline-IK over the corrected topology
			# (writes constrained WORLD orientations into tgt_global; the pose loop
			# below converts them to local via the corrected MH_PARENT). root must be
			# resolved first (done above) — it is the base of the axial chain.
			_solve_axial(gd, tgt_global)
			var pose := PackedFloat32Array(); pose.resize(nbones * 4)
			for bi in nbones:
				var tb: String = bone_names[bi]
				var q := Quaternion.IDENTITY
				if tgt_global.has(tb) and target_to_bvh.has(tb):
					var par: String = MH_PARENT.get(tb, "")
					if par != "" and tgt_global.has(par):
						q = ((tgt_global[par] as Quaternion).inverse() * (tgt_global[tb] as Quaternion)).normalized()
					else:
						q = (tgt_global[tb] as Quaternion)
				pose[bi * 4 + 0] = q.x
				pose[bi * 4 + 1] = q.y
				pose[bi * 4 + 2] = q.z
				pose[bi * 4 + 3] = q.w
			var m := _axial_metrics(gd, tgt_global)
			out.append({"pose": pose, "root_xz": root_xz, "facing": facing,
				"foot_l": foot_l, "foot_r": foot_r,
				"head_err": m["head_err"], "spine_cor": m["spine_cor"], "neck_cor": m["neck_cor"],
				"tw_max": m["tw_max"], "sag_sum": m["sag_sum"], "src_sag": m["src_sag"]})
		fi += 1
	return out


## Verification metrics for one solved axial frame (all radians), compared against
## the SOURCE de-yawed world orientations (gd). head_err = angle(target head world,
## source head world) — the anti-double-head guard. cor_max/tw_max = worst per-joint
## coronal / axial-twist over the axial chain. sag_sum = aggregate spine (root→neck01)
## sagittal bend; src_sag = source Hips→Neck total sagittal (the aggregate S target).
func _axial_metrics(gd: Dictionary, tgt_global: Dictionary) -> Dictionary:
	var head_err := 0.0
	if gd.has("Head") and tgt_global.has("head"):
		head_err = (tgt_global["head"] as Quaternion).angle_to(gd["Head"] as Quaternion)
	var spine_cor := 0.0
	var neck_cor := 0.0
	var tw_max := 0.0
	var sag_sum := 0.0
	for tb in AXIAL_CHAIN:
		var par: String = MH_PARENT.get(tb, "")
		var pw: Quaternion = tgt_global.get(par, Quaternion.IDENTITY)
		var lq := (pw.inverse() * (tgt_global.get(tb, Quaternion.IDENTITY) as Quaternion)).normalized()
		var e := Basis(lq).get_euler(EULER_ORDER_YXZ)
		if tb.begins_with("neck") or tb == "head":
			neck_cor = maxf(neck_cor, absf(e.z))
		else:
			spine_cor = maxf(spine_cor, absf(e.z))
		tw_max = maxf(tw_max, absf(e.y))
		if AXIAL_ARC[tb]["seg"] == "spine":
			sag_sum += e.x
	var src_sag := 0.0
	if gd.has("Hips") and gd.has("Neck"):
		var sl := ((gd["Hips"] as Quaternion).inverse() * (gd["Neck"] as Quaternion)).normalized()
		src_sag = Basis(sl).get_euler(EULER_ORDER_YXZ).x
	return {"head_err": head_err, "spine_cor": spine_cor, "neck_cor": neck_cor,
		"tw_max": tw_max, "sag_sum": sag_sum, "src_sag": src_sag}


## Normalized REST (bind) segment directions per mapped bone, in each skeleton's
## own world-aligned bind frame. The retarget aligns the MH bone's rest direction
## onto the captured BVH-segment direction, so these caches are the zero reference.
var _mh_dir_cache := {}
var _bvh_dir_cache := {}

func _build_dir_caches(jidx: Dictionary, joints: Array) -> void:
	_mh_dir_cache = {}
	_bvh_dir_cache = {}
	var mh_head := _load_mh_heads()
	for tb in MH_PARENT.keys():
		var bvh_dir := _bvh_bind_dir(tb, jidx, joints)
		var mh_dir := _mh_bind_dir(tb, mh_head)
		if bvh_dir.length() < 1e-5 or mh_dir.length() < 1e-5:
			continue
		_bvh_dir_cache[tb] = bvh_dir.normalized()
		_mh_dir_cache[tb] = mh_dir.normalized()


## BVH bind segment direction = the child joint's OFFSET (world dir at bind, since
## all ancestor rotations are identity in the bind pose). Y-up cm; direction only.
func _bvh_bind_dir(tb: String, jidx: Dictionary, joints: Array) -> Vector3:
	var tail: String = BVH_TAIL.get(tb, "")
	if tail == "__yup":
		return Vector3.UP
	if tail == "" or not jidx.has(tail):
		return Vector3.ZERO
	return joints[int(jidx[tail])]["offset"]


## MH bind segment direction = head(bone) → head(tail bone), from the rig JSON.
func _mh_bind_dir(tb: String, mh_head: Dictionary) -> Vector3:
	var tail: String = MH_TAIL.get(tb, "")
	if tail == "__yup":
		return Vector3.UP
	if not mh_head.has(tb) or not mh_head.has(tail):
		return Vector3.ZERO
	return (mh_head[tail] as Vector3) - (mh_head[tb] as Vector3)


func _load_mh_heads() -> Dictionary:
	var f := FileAccess.open(RIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var out := {}
	if data == null or not (data is Dictionary) or not data.has("bones"):
		return out
	for bd in data["bones"]:
		var h: Array = bd["head"]
		out[bd["name"]] = Vector3(h[0], h[1], h[2])
	return out


## Shortest-arc quaternion rotating unit vector a onto unit vector b.
func _shortest_arc(a: Vector3, b: Vector3) -> Quaternion:
	var d := a.dot(b)
	if d >= 0.999999:
		return Quaternion.IDENTITY
	if d <= -0.999999:
		# antiparallel — rotate 180° about any perpendicular axis.
		var axis := a.cross(Vector3.UP)
		if axis.length() < 1e-5:
			axis = a.cross(Vector3.RIGHT)
		return Quaternion(axis.normalized(), PI)
	var axis2 := a.cross(b).normalized()
	return Quaternion(axis2, acos(clampf(d, -1.0, 1.0)))


## Orientation-driven spline-IK for the axial chain. For each target axial joint,
## arc-slerp the de-yawed source world orientations at its normalized arc position,
## convert to local over the CORRECTED chain (parent already resolved in tgt_global),
## constrain the local pose (coronal flat / sagittal free / twist capped), then
## re-accumulate the CONSTRAINED world orientation so children build on it. Writes
## world orientations into tgt_global; the caller's pose loop recovers the exact
## constrained local via (parent_world)^-1 · (this_world). Closed-form/deterministic.
func _solve_axial(gd: Dictionary, tgt_global: Dictionary) -> void:
	for tb in AXIAL_CHAIN:
		var info: Dictionary = AXIAL_ARC[tb]
		var samples: Array = SRC_SPINE_SAMPLES if info["seg"] == "spine" else SRC_NECK_SAMPLES
		var desired_world := _arc_slerp(gd, samples, info["s"])
		var par: String = MH_PARENT.get(tb, "")
		var par_world: Quaternion = tgt_global.get(par, Quaternion.IDENTITY)
		var local_raw := (par_world.inverse() * desired_world).normalized()
		var is_neck: bool = tb.begins_with("neck") or tb == "head"
		var local_c := _constrain_axial_local(local_raw, is_neck)
		tgt_global[tb] = (par_world * local_c).normalized()


## Slerp the arc-parameterized source orientation curve at normalized position s.
## samples: [[joint_name, arc_pos], ...] ascending. Clamps to the end samples.
func _arc_slerp(gd: Dictionary, samples: Array, s: float) -> Quaternion:
	var n := samples.size()
	if n == 0:
		return Quaternion.IDENTITY
	if s <= float(samples[0][1]):
		return (gd.get(samples[0][0], Quaternion.IDENTITY) as Quaternion)
	if s >= float(samples[n - 1][1]):
		return (gd.get(samples[n - 1][0], Quaternion.IDENTITY) as Quaternion)
	for i in range(n - 1):
		var a := float(samples[i][1])
		var b := float(samples[i + 1][1])
		if s >= a and s <= b:
			var t := (s - a) / maxf(b - a, 1e-6)
			var qa := (gd.get(samples[i][0], Quaternion.IDENTITY) as Quaternion)
			var qb := (gd.get(samples[i + 1][0], Quaternion.IDENTITY) as Quaternion)
			return qa.slerp(qb, t).normalized()
	return (gd.get(samples[n - 1][0], Quaternion.IDENTITY) as Quaternion)


## Apply the anatomical joint limits to ONE axial joint's LOCAL pose. Swing/twist
## decomposition via Euler YXZ (ex = sagittal / fore-aft about X, ey = axial twist
## about Y, ez = coronal / lateral about Z) — exact and reconstructable:
##   - coronal (ez): below LAT_EPS → 0 (noise) on every joint; above LAT_EPS the SPINE
##     locks flat (torso upright, no hunch) while the NECK passes evidenced lateral
##     through (needed for head orientation fidelity — see NECK_CORONAL_PASSTHROUGH).
##   - axial twist (ey): passed through but CAPPED per joint (never dumped/synthesized).
##   - sagittal (ex): FREE — driven only by the sampled orientations, so the S-curve
##     emerges in aggregate across the chain, never imposed per-segment.
func _constrain_axial_local(local_q: Quaternion, is_neck: bool) -> Quaternion:
	var e := Basis(local_q).get_euler(EULER_ORDER_YXZ)  # (x=sagittal, y=twist, z=coronal)
	if absf(e.z) < deg_to_rad(LAT_EPS_DEG):
		e.z = 0.0
	elif not (is_neck and NECK_CORONAL_PASSTHROUGH):
		e.z = 0.0  # spine (torso): lock even evidenced lateral flat — no hunch/sway
	var tmax := deg_to_rad(MAX_JOINT_TWIST_DEG)
	e.y = clampf(e.y, -tmax, tmax)
	return Basis.from_euler(e, EULER_ORDER_YXZ).get_rotation_quaternion()


## The YAW (twist about world UP) component of a rotation — swing/twist decomposition.
## Multiplying a global by _yaw_only(root_global)⁻¹ removes the body's world facing.
func _yaw_only(q: Quaternion) -> Quaternion:
	var v := Vector3(q.x, q.y, q.z)
	var proj := Vector3.UP * v.dot(Vector3.UP)
	var twist := Quaternion(proj.x, proj.y, proj.z, q.w)
	if twist.length_squared() < 1e-12:
		return Quaternion.IDENTITY
	return twist.normalized()


## Compute every BVH joint's LOCAL rotation + LOCAL position for one frame.
func _local_pose_frame(joints: Array, ch_base: Array, motion: PackedFloat32Array,
		total_channels: int, fi: int, nj: int) -> Dictionary:
	var row := fi * total_channels
	var local_rot := []; local_rot.resize(nj)
	var local_pos := []; local_pos.resize(nj)
	for k in nj:
		var chans: Array = joints[k]["channels"]
		var off: Vector3 = joints[k]["offset"]
		var pos := off
		var q := Quaternion.IDENTITY
		var cb: int = ch_base[k]
		for ci in chans.size():
			var ch: String = chans[ci]
			var idx := row + cb + ci
			var val := motion[idx] if idx < motion.size() else 0.0
			match ch:
				"Xposition": pos.x = val
				"Yposition": pos.y = val
				"Zposition": pos.z = val
				"Xrotation": q = q * Quaternion(Vector3.RIGHT, deg_to_rad(val))
				"Yrotation": q = q * Quaternion(Vector3.UP, deg_to_rad(val))
				"Zrotation": q = q * Quaternion(Vector3.BACK, deg_to_rad(val))
		local_rot[k] = q
		local_pos[k] = pos
	return {"lrot": local_rot, "lpos": local_pos}


## FK: global transforms + global rotations for one frame.
func _fk_frame(joints: Array, ch_base: Array, motion: PackedFloat32Array,
		total_channels: int, fi: int, nj: int) -> Dictionary:
	var lp := _local_pose_frame(joints, ch_base, motion, total_channels, fi, nj)
	var local_rot: Array = lp["lrot"]
	var local_pos: Array = lp["lpos"]
	var gxf := []; gxf.resize(nj)
	var grot := []; grot.resize(nj)
	for k in nj:
		var lt := Transform3D(Basis(local_rot[k]), local_pos[k])
		var p := int(joints[k]["parent"])
		if p < 0:
			gxf[k] = lt
			grot[k] = local_rot[k]
		else:
			gxf[k] = (gxf[p] as Transform3D) * lt
			grot[k] = (grot[p] as Quaternion) * (local_rot[k] as Quaternion)
	return {"gxf": gxf, "grot": grot, "lrot": local_rot}


func _list_bvh(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".bvh"):
			out.append(dir.path_join(fn))
		fn = d.get_next()
	d.list_dir_end()
	return out


func _tag_for(name: String) -> String:
	var n := name.to_lower()
	if n.ends_with("_id"): return "idle"
	if n.ends_with("_fw"): return "walk"
	if n.ends_with("_fr"): return "run"
	if n.ends_with("_bw"): return "walk_back"
	if n.ends_with("_br"): return "run_back"
	if n.ends_with("_sw"): return "strafe_walk"
	if n.ends_with("_sr"): return "strafe_run"
	if n.begins_with("tr") or n.find("_tr") >= 0: return "turn"
	return "loco"
