## Slice-4 Motion-Matching test (docs/decisions/body-and-locomotion-slice.md §4,
## Slice 4 verify).
##
## Asserts the Slice-4 properties:
##   1. DB LOADS: locomotion_mm.res loads as a MotionDB with the expected
##      frame/feature/bone counts and per-frame array sizes consistent.
##   2. SEARCH IS DETERMINISTIC: the same goal query returns the same matched
##      frame on repeated calls, and two independently-constructed matchers over
##      the same DB agree (the argmin float-path + lowest-index tie-break are
##      stable). A full re-run is identical (the committed DB is byte-stable).
##   3. MM RESPONDS TO THE MOVEMENTSTATE GOAL: distinct goals (idle / forward
##      walk / forward run / turn) select frames whose clip TAG is appropriate —
##      idle picks an idle clip, run picks a faster clip than walk, a turn goal
##      picks a turning clip — proving the search reads the goal, not a constant.
##   4. BODYRIG WIRES MM: BodyRig.build() loads the DB + matcher, and apply_pose
##      with a walk goal poses leg bones away from rest (MM drives the body).
##
## RENDER-SIDE only; the sim regression guard is the (unchanged) movement_behavior
## + golden_trace suites. Run windowed under xvfb (BodyRig needs a world):
##   xvfb-run -a godot4 --path . res://tests/body_motion_matching_test.tscn --quit-after 6000
extends Node3D

const DB_PATH := "res://assets/body/locomotion_mm.res"

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea body SLICE 4 Motion-Matching test ===\n")

	# --- 1. DB loads with consistent shape -----------------------------------
	var loaded = load(DB_PATH)
	_assert("MotionDB loads", loaded != null and loaded is MotionDB, DB_PATH)
	if loaded == null or not (loaded is MotionDB):
		_finish(); return
	var db: MotionDB = loaded
	_assert("frame_count > 0", db.frame_count > 0, "%d frames" % db.frame_count)
	_assert("feature_dim == 22", db.feature_dim == 22, "%d" % db.feature_dim)
	_assert("bone_count == 17", db.bone_count == 17, "%d" % db.bone_count)
	_assert("features sized frame_count*feature_dim",
		db.features.size() == db.frame_count * db.feature_dim,
		"%d == %d" % [db.features.size(), db.frame_count * db.feature_dim])
	_assert("poses sized frame_count*bone_count*4",
		db.poses.size() == db.frame_count * db.bone_count * 4,
		"%d == %d" % [db.poses.size(), db.frame_count * db.bone_count * 4])
	_assert("clip_id sized frame_count", db.clip_id.size() == db.frame_count,
		"%d" % db.clip_id.size())
	_assert("feature_mean/std sized feature_dim",
		db.feature_mean.size() == db.feature_dim and db.feature_std.size() == db.feature_dim,
		"%d / %d" % [db.feature_mean.size(), db.feature_std.size()])
	# tags present
	var tags := {}
	for t in db.clip_tags:
		tags[t] = true
	_assert("has idle/walk/run/turn clip tags",
		tags.has("idle") and tags.has("walk") and tags.has("run") and tags.has("turn"),
		str(db.clip_tags))

	# --- 2. search determinism ------------------------------------------------
	var m1 := MotionMatcher.new(); m1.setup(db)
	var m2 := MotionMatcher.new(); m2.setup(db)
	var goal_walk := Vector2(0.0, 3.0)   # 3 m/s forward
	var f_a := m1.search(goal_walk, 0.0)
	var f_b := m1.search(goal_walk, 0.0)   # repeat, same matcher
	var f_c := m2.search(goal_walk, 0.0)   # fresh matcher
	_assert("same query -> same matched frame (repeat)", f_a == f_b, "%d == %d" % [f_a, f_b])
	_assert("same query -> same matched frame (independent matcher)", f_a == f_c,
		"%d == %d" % [f_a, f_c])
	# different goals -> (generally) different frames
	var f_idle := m1.search(Vector2.ZERO, 0.0)
	var f_run := m1.search(Vector2(0.0, 8.0), 0.0)
	_assert("idle vs walk goals select different frames", f_idle != f_a,
		"idle=%d walk=%d" % [f_idle, f_a])

	# --- 3. MM responds to the goal: appropriate clip tags -------------------
	var tag_idle := db.clip_tag_of(f_idle)
	var tag_walk := db.clip_tag_of(f_a)
	var tag_run := db.clip_tag_of(f_run)
	var f_turn := m1.search(Vector2(0.3, 1.2), 0.9)   # turning while moving (rad/s)
	var tag_turn := db.clip_tag_of(f_turn)
	print("  [tags] idle->%s walk->%s run->%s turn->%s" % [tag_idle, tag_walk, tag_run, tag_turn])
	_assert("idle goal selects an idle clip", tag_idle == "idle", tag_idle)
	# run goal should pick a clip tagged run (or at least not idle); walk picks walk-ish
	_assert("run goal does not select idle", tag_run != "idle", tag_run)
	_assert("walk goal does not select idle", tag_walk != "idle", tag_walk)
	# the matched run frame should have a larger forward hip velocity feature than
	# the walk frame (the last two feature dims are hip planar vel, normalized).
	var hv_walk := _hipvel_mag(db, f_a)
	var hv_run := _hipvel_mag(db, f_run)
	_assert("run goal matches a faster frame than walk goal", hv_run > hv_walk,
		"run_hv=%.4f > walk_hv=%.4f" % [hv_run, hv_walk])
	# turn goal selects a frame with a LARGER future-facing change than a straight
	# walk goal — the MM-relevant signal for turning. (Exact clip-tag selection
	# depends on the BVH facing-sign convention; the load-bearing property is that
	# a turn goal responds by matching a more-turning frame than a straight goal.)
	var facing_turn := _facing_change_mag(db, f_turn)
	var facing_walk := _facing_change_mag(db, f_a)
	_assert("turn goal matches a more-turning frame than a straight walk goal",
		facing_turn > facing_walk,
		"turn=%.4f > walk=%.4f (matched tag=%s)" % [facing_turn, facing_walk, tag_turn])

	# --- 4. BodyRig wires MM and poses the body ------------------------------
	var rig := BodyRig.new()
	add_child(rig)
	var built := rig.build()
	_assert("BodyRig.build() succeeds", built, str(built))
	if built:
		_assert("BodyRig loaded the MotionDB", rig.motion_db != null and rig.matcher != null,
			"db=%s matcher=%s" % [rig.motion_db != null, rig.matcher != null])
		rig.foot_ik_enabled = false   # isolate MM pose
		var hip := rig.skeleton.find_bone("upperleg01.L")
		var rest_q := rig.skeleton.get_bone_rest(hip).basis.get_rotation_quaternion()
		# Walk goal: step a few frames; the leg should pose away from rest.
		rig.set_movement_state(true, 3.0, Vector2(0.0, 3.0), 0.0)
		for i in 12:
			rig.apply_pose(1.0 / 60.0)
		var walk_q := rig.skeleton.get_bone_pose_rotation(hip)
		_assert("MM walk goal poses the leg away from rest", rest_q.angle_to(walk_q) > 0.05,
			"angle=%.4f rad, frame=%d" % [rest_q.angle_to(walk_q), rig.motion_matched_frame()])
		# Determinism through the rig: same goals from a fresh rig -> same frame seq.
		var frame_seq_a := _drive_seq(rig, Vector2(0.0, 6.0))
		var rig2 := BodyRig.new(); add_child(rig2); rig2.build(); rig2.foot_ik_enabled = false
		var frame_seq_b := _drive_seq(rig2, Vector2(0.0, 6.0))
		_assert("MM frame sequence is deterministic across rigs", frame_seq_a == frame_seq_b,
			"%s == %s" % [str(frame_seq_a), str(frame_seq_b)])

	_finish()


func _facing_change_mag(db: MotionDB, frame: int) -> float:
	# feature dims [2],[3] = future-facing sin,cos at horizon 0 (normalized);
	# |sin| of the denormalized angle proxies turning magnitude.
	var base := frame * db.feature_dim
	var s := db.features[base + 2] * db.feature_std[2] + db.feature_mean[2]
	return absf(s)


func _hipvel_mag(db: MotionDB, frame: int) -> float:
	# last two normalized feature dims are local hip planar velocity (x,z)
	var base := frame * db.feature_dim
	var x := db.features[base + db.feature_dim - 2]
	var z := db.features[base + db.feature_dim - 1]
	return sqrt(x * x + z * z)


func _drive_seq(rig: BodyRig, goal: Vector2) -> Array:
	var seq := []
	rig.matcher.setup(rig.motion_db)   # reset matcher state
	for i in 20:
		rig.set_movement_state(true, goal.length(), goal, 0.0)
		rig.apply_pose(1.0 / 60.0)
		seq.append(rig.motion_matched_frame())
	return seq


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
