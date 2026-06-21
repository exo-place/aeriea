## Gaze test — aeriea's GazeRig behind the set_look_target seam (built-in LookAt
## pattern; no BDCC2 code).
##
## Asserts:
##   (a) DETERMINISM — same skeleton pose + same target + same dt sequence gives the
##       identical resolved look (no RNG, no wall-clock).
##   (b) DIRECTION — a target to the RIGHT yaws right (+x); LEFT yaws left; UP pitches
##       up (+y); DOWN pitches down.
##   (c) INFLUENCE — lower influence turns the head LESS toward the same target.
##   (d) CLEAR — clearing the target eases the look back toward rest (~0).
##   (e) BONES — the head bone actually rotates from rest when looking aside.
##
## Run: xvfb-run -a godot4 --path . res://tests/gaze_test.tscn --quit-after 2000
extends Node

const GazeRig := preload("res://scripts/body/face/gaze_rig.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea gaze test ===\n")
	_test_determinism()
	_test_direction()
	_test_influence()
	_test_clear()
	_test_bone_moves()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


# Build a minimal skeleton with a head bone at the origin, facing -Z (MakeHuman
# convention). Chain: spine -> neck01 -> head, head ~1.6m up.
func _make_skeleton() -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.add_bone("spine")
	sk.add_bone("neck01")
	sk.add_bone("head")
	sk.set_bone_parent(1, 0)
	sk.set_bone_parent(2, 1)
	sk.set_bone_rest(0, Transform3D(Basis(), Vector3(0, 0, 0)))
	sk.set_bone_rest(1, Transform3D(Basis(), Vector3(0, 1.4, 0)))
	sk.set_bone_rest(2, Transform3D(Basis(), Vector3(0, 0.15, 0)))
	for i in 3:
		var r := sk.get_bone_rest(i)
		sk.set_bone_pose_position(i, r.origin)
		sk.set_bone_pose_rotation(i, r.basis.get_rotation_quaternion())
	add_child(sk)
	return sk


func _run(target: Vector3, influence: float, steps: int, dt: float) -> Dictionary:
	var sk := _make_skeleton()
	var g := GazeRig.new()
	add_child(g)
	g.set_process(false)
	g.setup(sk)
	g.set_look_target(target, influence)
	for i in steps:
		g.step(dt)
	var out: Dictionary = g.resolved()
	g.queue_free()
	sk.queue_free()
	return out


func _test_determinism() -> void:
	var a := _run(Vector3(1, 1.55, 1), 1.0, 60, 1.0 / 60.0)
	var b := _run(Vector3(1, 1.55, 1), 1.0, 60, 1.0 / 60.0)
	_ok((a["look"] as Vector2).is_equal_approx(b["look"] as Vector2),
		"same pose+target+dt -> identical resolved look")


func _test_direction() -> void:
	# Head sits at ~y=1.55, facing -Z. Target to the RIGHT (+x) and FORWARD (-z).
	var right := _run(Vector3(2, 1.55, -1), 1.0, 90, 1.0 / 60.0)["look"] as Vector2
	_ok(right.x > 0.1, "target to the right -> yaw right (+x): %s" % right)
	var left := _run(Vector3(-2, 1.55, -1), 1.0, 90, 1.0 / 60.0)["look"] as Vector2
	_ok(left.x < -0.1, "target to the left -> yaw left (-x): %s" % left)
	var up := _run(Vector3(0, 3.0, -1), 1.0, 90, 1.0 / 60.0)["look"] as Vector2
	_ok(up.y > 0.1, "target above -> pitch up (+y): %s" % up)
	var down := _run(Vector3(0, 0.2, -1), 1.0, 90, 1.0 / 60.0)["look"] as Vector2
	_ok(down.y < -0.1, "target below -> pitch down (-y): %s" % down)


func _test_influence() -> void:
	var full := _run(Vector3(2, 1.55, -1), 1.0, 120, 1.0 / 60.0)["look"] as Vector2
	var half := _run(Vector3(2, 1.55, -1), 0.4, 120, 1.0 / 60.0)["look"] as Vector2
	_ok(absf(half.x) < absf(full.x),
		"lower influence turns the head less (%.3f < %.3f)" % [absf(half.x), absf(full.x)])


func _test_clear() -> void:
	var sk := _make_skeleton()
	var g := GazeRig.new()
	add_child(g)
	g.set_process(false)
	g.setup(sk)
	g.set_look_target(Vector3(2, 1.55, -1), 1.0)
	for i in 120:
		g.step(1.0 / 60.0)
	var turned := (g.resolved()["look"] as Vector2).length()
	_ok(turned > 0.1, "head turned toward target before clear")
	g.clear_look_target()
	for i in 180:
		g.step(1.0 / 60.0)
	var rested := (g.resolved()["look"] as Vector2).length()
	_ok(rested < 0.02, "clear_look_target eases the look back to rest (%.4f)" % rested)
	g.queue_free()
	sk.queue_free()


func _test_bone_moves() -> void:
	var sk := _make_skeleton()
	var g := GazeRig.new()
	add_child(g)
	g.set_process(false)
	g.setup(sk)
	var hi := sk.find_bone("head")
	var rest_q := sk.get_bone_pose_rotation(hi)
	g.set_look_target(Vector3(2, 1.55, -1), 1.0)
	for i in 120:
		g.step(1.0 / 60.0)
	var now_q := sk.get_bone_pose_rotation(hi)
	_ok(rest_q.angle_to(now_q) > 0.05, "head bone rotates from rest when looking aside")
	g.queue_free()
	sk.queue_free()
