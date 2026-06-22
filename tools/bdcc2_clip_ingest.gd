## BDCC2 animation-clip ingest + retarget → ClipDB (committed artifact).
##
## Mines BDCC2's ACTUAL GLB animation clips (Anims/Raw/*.glb — alexofp / Rahi, MIT,
## "use as a base"; see NOTICE.md) and retargets the SFW subset onto aeriea's 169-bone
## MakeHuman rig, writing res://assets/body/bdcc2_clips.res (a ClipDB Resource).
##
## We do NOT vendor BDCC2's anim architecture (LayeredAnimPlayer / AnimationTree /
## GlobalRegistry); only the per-frame bone rotations are mined and re-expressed as
## MH-bone-LOCAL quats. aeriea's own clip layer (BodyRig) drives them.
##
## RETARGET (the crux): BDCC2 and MH are both A-pose humanoids with DIFFERENT per-bone
## local axis frames. A naive local-quat copy scrambles the limbs. Instead, for each
## sampled frame we let Godot FK both skeletons and take each bone's GLOBAL rotation
## RELATIVE TO its own bind (G_rel = G_pose * G_bind^-1) in WORLD space — so the local
## axis conventions cancel. We de-yaw G_rel by the root's G_rel (facing is sim-owned),
## then convert to an MH-LOCAL pose via the MH parent's target global. MH bone rests
## have identity basis, so the MH target global rotation == the de-yawed G_rel, and
## mh_local = mh_parent_global^-1 * mh_target_global. Stored rest-relative as the MM
## poses are (mh_rest_q is identity here, but compose for robustness).
##
## DETERMINISM: clips ingested in the fixed SOURCES order; frames sampled at a fixed
## stride/rate; fixed float path. Same BDCC2 GLBs -> byte-identical bdcc2_clips.res.
##
## Run (BDCC2 checkout present):
##   BDCC2_SRC=/abs/path/to/BDCC2 godot4 --path . res://tools/bdcc2_clip_ingest.tscn --quit-after 6000
## (defaults to ~/git/pterror/BDCC2 if BDCC2_SRC is unset.)
extends Node

const ClipDB := preload("res://scripts/body/clip_db.gd")
const Bdcc2BoneMap := preload("res://scripts/body/bdcc2_bone_map.gd")

const OUT_DB := "res://assets/body/bdcc2_clips.res"
const DEFAULT_SRC := "/home/me/git/pterror/BDCC2"

## Sampled frames per second (sub-sampled from the GLB's native rate). 20 fps keeps
## the committed DB compact while preserving gesture detail.
const SAMPLE_FPS := 20.0
## Cap sampled frames per clip (keeps the artifact a few MB; long talk loops trimmed).
const MAX_FRAMES := 240

## The SFW subset to mine. Each row: aeriea id, BDCC2 GLB file, BDCC2 anim name.
## Order is FIXED (determinism). NSFW sex-scene clips (SexCowgirl, Tribadism, SoloSex,
## AgainstWall*, restraint/armbinder/stocks) are deliberately NOT mined into this
## walk-around set — they belong to a separate intimacy context (noted in the report).
const SOURCES := [
	# idle variants / fidgets (loopable, bind to a STANDING controller state)
	{"id": "idle",            "file": "LocomotionAnims", "anim": "Idle-loop"},
	{"id": "idle_long",       "file": "LocomotionAnims", "anim": "IdleLong-loop"},
	{"id": "idle_long_idle",  "file": "LocomotionAnims", "anim": "IdleLongIdle-loop"},
	{"id": "idle_sexy",       "file": "LocomotionAnims", "anim": "IdleSexy-loop"},
	# gestures (one-shot / loop, bindable to emote inputs)
	{"id": "wave",            "file": "GestureAnims",    "anim": "Wave"},
	{"id": "head_nod",        "file": "GestureAnims",    "anim": "HeadNod"},
	{"id": "head_shake",      "file": "GestureAnims",    "anim": "HeadShake"},
	{"id": "talking",         "file": "GestureAnims",    "anim": "Talking2Hands"},
	{"id": "talking_one",     "file": "GestureAnims",    "anim": "Talking1Hand"},
	{"id": "shrug",           "file": "GestureAnims",    "anim": "ShrugAngry"},
	{"id": "sigh",            "file": "GestureAnims",    "anim": "Sigh"},
	{"id": "look_away",       "file": "GestureAnims",    "anim": "LookAway"},
	{"id": "happy_hands",     "file": "GestureAnims",    "anim": "HappyHandGesture"},
	{"id": "thinking",        "file": "GestureAnims",    "anim": "SexyThinking"},
	# pose-style fidgets (short loops)
	{"id": "sit",             "file": "BasicAnims",      "anim": "Sit-loop"},
]


func _ready() -> void:
	get_tree().quit(_run())


func _src() -> String:
	var env := OS.get_environment("BDCC2_SRC")
	return env if env != "" else DEFAULT_SRC


func _run() -> int:
	var src := _src()
	print("bdcc2_clip_ingest: src = %s" % src)

	# Build the aeriea MH skeleton (target) — we need its bone parents + rests.
	var rig_json := _load_json("res://assets/body/base_body_rig.json")
	if rig_json.is_empty():
		push_error("cannot load MH rig json"); return 1
	var mh := _build_mh_skeleton(rig_json)
	add_child(mh)

	var target_bones := Bdcc2BoneMap.target_bones()
	var nb := target_bones.size()
	print("bdcc2_clip_ingest: %d target bones" % nb)

	# MH rest local quats (basis is identity in the JSON, but compose for robustness).
	var mh_rest_q := {}
	for tb in target_bones:
		var bi := mh.find_bone(tb)
		mh_rest_q[tb] = mh.get_bone_rest(bi).basis.get_rotation_quaternion() if bi >= 0 else Quaternion.IDENTITY

	# Cache loaded BDCC2 scenes per file (each holds a skeleton + AnimationPlayer).
	var scene_cache := {}

	var all_poses := PackedFloat32Array()
	var clip_first := PackedInt32Array()
	var clip_len := PackedInt32Array()
	var clip_fps := PackedFloat32Array()
	var clip_names := PackedStringArray()
	var clip_ids := PackedStringArray()
	var frame_cursor := 0

	for row in SOURCES:
		var file: String = row["file"]
		var anim_name: String = row["anim"]
		var id: String = row["id"]
		if not scene_cache.has(file):
			scene_cache[file] = _load_glb(src.path_join("Anims/Raw/%s.glb" % file))
		var scene = scene_cache[file]
		if scene == null:
			print("  SKIP %s (load fail)" % id); continue
		var skel := scene.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if skel == null or ap == null:
			print("  SKIP %s (no skel/ap)" % id); continue
		var anim := _find_anim(ap, anim_name)
		if anim == null:
			print("  SKIP %s (anim '%s' not found)" % [id, anim_name]); continue

		# BDCC2 bind global rotations (FK at rest).
		var bdcc_bind := _bind_globals(skel)

		var frames := _sample_clip(mh, skel, ap, anim, anim_name, target_bones,
			mh_rest_q, bdcc_bind, all_poses)
		clip_first.append(frame_cursor)
		clip_len.append(frames)
		clip_fps.append(SAMPLE_FPS)
		clip_names.append(anim_name)
		clip_ids.append(id)
		frame_cursor += frames
		print("  %-16s <- %s/%s : %d frames" % [id, file, anim_name, frames])

	var db := ClipDB.new()
	db.frame_count = frame_cursor
	db.bone_count = nb
	db.bone_names = target_bones
	db.poses = all_poses
	db.clip_first = clip_first
	db.clip_len = clip_len
	db.clip_fps = clip_fps
	db.clip_names = clip_names
	db.clip_ids = clip_ids
	db.source = "BDCC2 (alexofp/Rahi, MIT) Anims/Raw — retargeted via bdcc2_bone_map"
	var err := ResourceSaver.save(db, OUT_DB)
	if err != OK:
		push_error("save failed err=%d" % err); return 1
	print("bdcc2_clip_ingest: wrote %s (%d clips, %d frames, %d bones)" %
		[OUT_DB, db.clip_count(), db.frame_count, db.bone_count])
	return 0


## Sample one clip: step the AnimationPlayer at SAMPLE_FPS, FK the BDCC2 skeleton,
## retarget each target bone, append rest-relative MH-local quats. Returns frame count.
func _sample_clip(mh: Skeleton3D, skel: Skeleton3D, ap: AnimationPlayer, anim: Animation,
		anim_name: String, target_bones: PackedStringArray, mh_rest_q: Dictionary,
		bdcc_bind: Dictionary, out: PackedFloat32Array) -> int:
	var length := anim.length
	# At least one frame; for zero-length poses sample a single frame.
	var n := maxi(1, int(round(length * SAMPLE_FPS)))
	n = mini(n, MAX_FRAMES)
	var dt := (length / float(n)) if n > 0 else 0.0
	var nb := target_bones.size()
	for fi in n:
		var t := float(fi) * dt
		ap.play(_anim_play_name(ap, anim_name))
		ap.seek(t, true)
		# Force the pose to apply this frame (advance_to update the skeleton).
		ap.advance(0.0)
		# BDCC2 per-bone global rotation relative to bind (world space).
		var g_rel := {}
		for tb in target_bones:
			var bdcc_name: String = Bdcc2BoneMap.MAP[tb]
			var bi := skel.find_bone(bdcc_name)
			if bi < 0:
				g_rel[tb] = Quaternion.IDENTITY
				continue
			var g_pose := skel.get_bone_global_pose(bi).basis.get_rotation_quaternion()
			var g_bind: Quaternion = bdcc_bind.get(bdcc_name, Quaternion.IDENTITY)
			g_rel[tb] = (g_pose * g_bind.inverse()).normalized()
		# De-yaw by the root's relative rotation (facing is sim-owned).
		var root_rel: Quaternion = g_rel.get("root", Quaternion.IDENTITY)
		var yaw_inv := _yaw_only(root_rel).inverse()
		var tgt_global := {}
		for tb in target_bones:
			tgt_global[tb] = (yaw_inv * (g_rel[tb] as Quaternion)).normalized()
		# Convert target globals to MH-local via mapped parent; store rest-relative.
		for bi2 in nb:
			var tb2: String = target_bones[bi2]
			var par: String = Bdcc2BoneMap.MH_PARENT.get(tb2, "")
			var local: Quaternion
			if tb2 == "root":
				# ROOT IS SIM-OWNED. The clip layer must NEVER drive body heading/root
				# orientation — that belongs to the controller + locomotion/MM layer. The
				# root's de-yawed global is still USED above as every leg/spine bone's
				# parent frame (so the limbs are root-relative and correct), but the stored
				# root quat itself is forced to identity so a gesture/idle layered on top
				# never flips or re-faces the body (BDCC2 binds facing -Z; the residual
				# 180° flip is exactly the heading the sim owns).
				local = Quaternion.IDENTITY
			elif par != "" and tgt_global.has(par):
				local = ((tgt_global[par] as Quaternion).inverse() * (tgt_global[tb2] as Quaternion)).normalized()
			else:
				local = (tgt_global[tb2] as Quaternion)
			# Store delta = mh_rest^-1 * (mh_rest * local)?  The applier does mh_rest * stored.
			# We want final mh_local_pose = mh_rest * stored == the target local. With MH rest
			# basis identity, stored == local. Compose generally so a future non-identity rest
			# stays correct: stored = mh_rest^-1 * local.
			var rest_q: Quaternion = mh_rest_q.get(tb2, Quaternion.IDENTITY)
			var stored := (rest_q.inverse() * local).normalized()
			out.append(stored.x); out.append(stored.y); out.append(stored.z); out.append(stored.w)
	return n


## BDCC2 bind global rotations (skeleton at rest pose, before any clip).
func _bind_globals(skel: Skeleton3D) -> Dictionary:
	# Reset every bone to rest so global poses == bind globals.
	for i in skel.get_bone_count():
		skel.reset_bone_pose(i)
	var out := {}
	for i in skel.get_bone_count():
		out[skel.get_bone_name(i)] = skel.get_bone_global_pose(i).basis.get_rotation_quaternion()
	return out


## Yaw-only (about world Y) component of a quaternion.
func _yaw_only(q: Quaternion) -> Quaternion:
	var fwd := q * Vector3.FORWARD
	var yaw := atan2(fwd.x, fwd.z)
	return Quaternion(Vector3.UP, yaw)


func _find_anim(ap: AnimationPlayer, name: String) -> Animation:
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib.has_animation(name):
			return lib.get_animation(name)
	return null


func _anim_play_name(ap: AnimationPlayer, name: String) -> String:
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib.has_animation(name):
			return ("%s/%s" % [lib_name, name]) if lib_name != "" else name
	return name


func _load_glb(path: String):
	if not FileAccess.file_exists(path):
		push_error("glb missing: %s" % path); return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		return null
	var scene := doc.generate_scene(st)
	if scene != null:
		add_child(scene)   # in-tree so AnimationPlayer can drive the skeleton
	return scene


func _build_mh_skeleton(rig: Dictionary) -> Skeleton3D:
	var bones: Array = rig["bones"]
	var skel := Skeleton3D.new()
	skel.name = "MHTarget"
	for i in bones.size():
		skel.add_bone(bones[i]["name"])
	for i in bones.size():
		skel.set_bone_parent(i, int(bones[i]["parent"]))
	for i in bones.size():
		var bd: Dictionary = bones[i]
		var origin := Vector3(bd["head"][0], bd["head"][1], bd["head"][2])
		var p := int(bd["parent"])
		var local := origin
		if p >= 0:
			var ph: Array = bones[p]["head"]
			local = origin - Vector3(ph[0], ph[1], ph[2])
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
		skel.set_bone_pose_position(i, local)
	return skel


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
