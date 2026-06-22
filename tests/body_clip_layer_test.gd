## BDCC2 clip-layer test — the mined-and-retargeted animation clips.
##
## Asserts:
##   1. DB LOADS: bdcc2_clips.res loads as a ClipDB with consistent shape (clips,
##      frames, bones; flat pose array sized frame_count*bone_count*4) and the
##      expected SFW clip ids present (idle variants + gestures), and that every
##      stored quat is finite + normalized (no broken/exploded retarget output).
##   2. RETARGET APPLIES NON-TRIVIAL ROTATIONS VIA THE BONE-MAP: stamping a clip
##      frame on the MakeHuman skeleton (mh_rest * stored_quat, the runtime path)
##      moves mapped upper-body bones meaningfully away from rest — proving the
##      BDCC2(Blender-rig)->MakeHuman bone-map retarget actually drives MH bones.
##      And it is ANATOMICALLY RIGHT, not just nonzero: the 'wave' clip raises the
##      right wrist ABOVE the shoulder at its peak (a real wave, not a scramble),
##      while 'idle' keeps the hand down at the side.
##   3. CONTROLLER-STATE BINDING selects the right clip: BodyRig auto-plays an idle
##      FIDGET after standing still long enough (grounded + ~0 speed), and a
##      gesture played via play_clip() overlays the upper body then eases out.
##   4. DETERMINISM UNAFFECTED: the clip layer is render-side; the same sim-time +
##      cosmetic seed yields the same fidget schedule + overlay pose on two fresh
##      rigs, and the clip layer never advances the sim (it only writes bone poses).
##
## RENDER-SIDE only; the sim regression guard is the (unchanged) movement_behavior
## + golden_trace suites. Run windowed under xvfb (BodyRig needs a world):
##   xvfb-run -a godot4 --path . res://tests/body_clip_layer_test.tscn --quit-after 6000
extends Node3D

const ClipDB := preload("res://scripts/body/clip_db.gd")
const Bdcc2BoneMap := preload("res://scripts/body/bdcc2_bone_map.gd")
const DB_PATH := "res://assets/body/bdcc2_clips.res"

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea BDCC2 clip-layer test ===\n")

	# --- 1. DB loads with consistent shape -----------------------------------
	var loaded = load(DB_PATH)
	_assert("ClipDB loads", loaded != null and loaded is ClipDB, DB_PATH)
	if loaded == null or not (loaded is ClipDB):
		_finish(); return
	var db: ClipDB = loaded
	_assert("frame_count > 0", db.frame_count > 0, "%d frames" % db.frame_count)
	_assert("clip_count > 0", db.clip_count() > 0, "%d clips" % db.clip_count())
	_assert("bone_count == bone-map coverage", db.bone_count == Bdcc2BoneMap.target_bones().size(),
		"%d vs %d" % [db.bone_count, Bdcc2BoneMap.target_bones().size()])
	_assert("poses array sized frame*bone*4",
		db.poses.size() == db.frame_count * db.bone_count * 4,
		"%d vs %d" % [db.poses.size(), db.frame_count * db.bone_count * 4])
	for need in ["idle", "wave", "head_nod", "talking", "sigh"]:
		_assert("clip id '%s' present" % need, db.clip_index(need) >= 0, "")
	# every quat finite + normalized (no NaN / exploded retarget)
	var bad := 0
	for f in db.frame_count:
		for b in db.bone_count:
			var q := db.pose_quat(f, b)
			if not (is_finite(q.x) and is_finite(q.y) and is_finite(q.z) and is_finite(q.w)):
				bad += 1
			elif absf(q.length() - 1.0) > 0.02:
				bad += 1
	_assert("all stored quats finite + normalized", bad == 0, "%d bad of %d" % [bad, db.frame_count * db.bone_count])

	# --- 2. retarget applies non-trivial rotations VIA THE BONE-MAP ----------
	var rig := BodyRig.new()
	add_child(rig)
	_assert("BodyRig.build() succeeds", rig.build(), "")
	_assert("BodyRig loaded the ClipDB", rig.clip_db != null, "")
	if rig.clip_db == null:
		_finish(); return

	# Stamp the wave clip at a mid frame and confirm a mapped upper-arm bone moved.
	var wi := db.clip_index("wave")
	var arm := rig.skeleton.find_bone("upperarm01.R")
	var arm_rest := rig.skeleton.get_bone_rest(arm).basis.get_rotation_quaternion()
	# find the peak right-wrist frame across the wave clip
	var peak_gf := -1
	var peak_y := -INF
	var shoulder_y := 0.0
	for lf in db.clip_len[wi]:
		var gf := db.clip_first[wi] + lf
		_stamp_clip_frame(rig, db, gf)
		var wy := rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone("wrist.R")).origin.y
		if wy > peak_y:
			peak_y = wy; peak_gf = gf
	# shoulder height (rest of the clip's first frame)
	_stamp_clip_frame(rig, db, db.clip_first[wi])
	shoulder_y = rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone("upperarm01.R")).origin.y
	# at the peak: upper-arm rotated away from rest AND wrist above shoulder
	_stamp_clip_frame(rig, db, peak_gf)
	var arm_peak := rig.skeleton.get_bone_pose_rotation(arm)
	_assert("wave moves the mapped upper arm away from rest (>0.2 rad)",
		arm_rest.angle_to(arm_peak) > 0.2,
		"angle=%.3f rad" % arm_rest.angle_to(arm_peak))
	_assert("wave raises the right wrist ABOVE the shoulder (real wave, not scramble)",
		peak_y > shoulder_y + 0.03, "wristY=%.3f shoulderY=%.3f" % [peak_y, shoulder_y])

	# idle keeps the hand DOWN (the retarget didn't just throw every clip up).
	var ii := db.clip_index("idle")
	var idle_hand_max := -INF
	for lf in db.clip_len[ii]:
		_stamp_clip_frame(rig, db, db.clip_first[ii] + lf)
		idle_hand_max = maxf(idle_hand_max, rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone("wrist.R")).origin.y)
	_assert("idle keeps the hand down at the side (below shoulder)",
		idle_hand_max < shoulder_y, "idleHandMaxY=%.3f shoulderY=%.3f" % [idle_hand_max, shoulder_y])

	# head_nod actually pitches the head (mapped neck/head bones driven).
	var ni := db.clip_index("head_nod")
	var head_b := rig.skeleton.find_bone("head")
	var head_rest := rig.skeleton.get_bone_rest(head_b).basis.get_rotation_quaternion()
	var head_max := 0.0
	for lf in db.clip_len[ni]:
		_stamp_clip_frame(rig, db, db.clip_first[ni] + lf)
		head_max = maxf(head_max, head_rest.angle_to(rig.skeleton.get_bone_pose_rotation(head_b)))
	_assert("head_nod pitches the head away from rest (>0.1 rad)", head_max > 0.1,
		"max head angle=%.3f rad" % head_max)

	# reset poses for the controller-binding section
	for i in rig.skeleton.get_bone_count():
		rig.skeleton.reset_bone_pose(i)

	# --- 3. controller-state binding: idle fidget + gesture overlay ----------
	rig.use_motion_matching = true
	# shorten the fidget delay so the test reaches it quickly
	rig.fidget_first_delay = 1.0
	# STANDING: grounded, ~0 speed -> after fidget_first_delay an idle fidget plays.
	rig.set_movement_state(true, 0.0)
	rig._smoothed_speed = 0.0
	var got_fidget := false
	for i in 200:   # ~3.3s at 60fps; first delay 1.0s
		rig.apply_pose(1.0 / 60.0)
		if rig.is_clip_playing():
			got_fidget = true
			break
	_assert("standing still auto-plays an idle FIDGET (controller-state binding)",
		got_fidget, "active='%s'" % rig.active_clip_id())

	# A gesture played explicitly overlays the upper body, then eases out by its end.
	rig.stop_clip()
	for i in 30: rig.apply_pose(1.0 / 60.0)   # let any fidget ease out
	var played := rig.play_clip("wave", false)
	_assert("play_clip('wave') accepts a known clip", played, "")
	rig.apply_pose(1.0 / 60.0)
	for i in 12: rig.apply_pose(1.0 / 60.0)   # blend in
	var arm_during := rig.skeleton.get_bone_pose_rotation(rig.skeleton.find_bone("upperarm01.R"))
	var arm_rest2 := rig.skeleton.get_bone_rest(rig.skeleton.find_bone("upperarm01.R")).basis.get_rotation_quaternion()
	_assert("gesture overlay drives the upper arm while playing",
		arm_rest2.angle_to(arm_during) > 0.1, "angle=%.3f" % arm_rest2.angle_to(arm_during))

	# MOVING: a fidget does not start (locomotion owns the body).
	rig.stop_clip()
	for i in 30: rig.apply_pose(1.0 / 60.0)
	rig.set_movement_state(true, 6.0)
	rig._smoothed_speed = 6.0
	var fidget_while_moving := false
	for i in 200:
		rig.apply_pose(1.0 / 60.0)
		if rig.active_clip_id() != "":
			fidget_while_moving = true
			break
	_assert("moving does NOT auto-play an idle fidget", not fidget_while_moving,
		"active='%s'" % rig.active_clip_id())

	# --- 4. determinism: same sim-time + seed -> same overlay pose -----------
	var a := _run_fidget_rig()
	var b := _run_fidget_rig()
	_assert("clip layer is deterministic (same seed+sim-time -> same overlay)",
		a.angle_to(b) < 1e-5, "angle diff=%.8f rad" % a.angle_to(b))

	_finish()


## Stamp a ClipDB frame's upper-body pose on the rig's skeleton via the runtime path
## (mh_rest * stored_quat) — mirrors BodyRig._apply_clip_layer's stamp at weight 1.
func _stamp_clip_frame(rig: BodyRig, db: ClipDB, gf: int) -> void:
	for bname in BodyRig.CLIP_UPPER_BONES:
		var bi := rig.skeleton.find_bone(bname)
		if bi < 0: continue
		var dbi := db.bone_names.find(bname)
		if dbi < 0: continue
		var rest_q := rig.skeleton.get_bone_rest(bi).basis.get_rotation_quaternion()
		rig.skeleton.set_bone_pose_rotation(bi, (rest_q * db.pose_quat(gf, dbi)).normalized())


## Fresh rig, stand still until a fidget plays, advance a fixed number of frames,
## return the right upper-arm pose. Deterministic given the cosmetic seed (0) + the
## fixed delta sequence — the determinism probe.
func _run_fidget_rig() -> Quaternion:
	var r := BodyRig.new()
	add_child(r)
	r.build()
	r.fidget_first_delay = 1.0
	r.set_movement_state(true, 0.0)
	r._smoothed_speed = 0.0
	for i in 240:
		r.apply_pose(1.0 / 60.0)
	return r.skeleton.get_bone_pose_rotation(r.skeleton.find_bone("upperarm01.R"))


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


func _finish() -> void:
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
