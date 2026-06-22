## Micro-life + secondary-motion layer test.
##
## Asserts the procedural embodiment-juice layer (breathing / eye-saccades / idle
## sway / hair / jiggle) actually animates, is TUNABLE, and stays OFF the sim path:
##   1. SPRING REGISTRY: jiggle springs register on ALL soft-region bones — breast.L/R
##      PLUS the now-added belly + glute.L/glute.R bones — and the hair registry is
##      NON-EMPTY (the helper-hair cap rigged onto the hair01/02/03 chain). Previously
##      belly/glute/hair were a documented GAP (empty registries); they now register.
##   2. JIGGLE MOVES: shaking the body (changing its global transform between frames)
##      produces a nonzero deflection on a soft-region bone vs. a still body.
##   3. JIGGLE TUNABLE: a higher jiggle_gain produces a larger deflection.
##   4. SACCADE ALIVE: the eye micro-saccade offset becomes nonzero and changes over
##      time (the eyes are never dead-still).
##   5. BREATHING TUNABLE: breath_amplitude scales the breathing micro-motion; zero
##      amplitude => (near) no breath contribution.
##   6. DETERMINISM: same cosmetic seed + same dt/transform sequence => same saccade
##      offset (reproducible cosmetic stream).
##   7. SIM-PATH ISOLATION: the layer only touches bone poses — driving it never
##      changes the MovementState inputs the host fed in (a structural check).
##
## RENDER-SIDE only. Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_micro_life_test.tscn --quit-after 6000
extends Node3D

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea body MICRO-LIFE + secondary-motion test ===\n")

	var rig := BodyRig.new()
	add_child(rig)
	if not rig.build():
		_assert("BodyRig.build() succeeds", false, "build failed")
		_finish(); return
	rig.use_motion_matching = false
	rig.foot_ik_enabled = false
	rig._setup_micro_life(0)

	# --- 1. spring registry --------------------------------------------------
	# The pipeline now ADDS belly + glute.L/R + a hair01/02/03 chain to the rig, so the
	# previously-empty registries are NON-EMPTY: all 5 soft-region bones register, and
	# the hair chain registers >=1 spring. (Was: only breast.L/R; hair was a GAP at 0.)
	var st := rig.micro_life_state()
	_assert("jiggle springs registered on ALL soft-region bones (breast.L/R + belly + glute.L/R)",
		st["jiggle_springs"] >= 5, "registered=%d (expected >=5)" % st["jiggle_springs"])
	for sb in ["breast.L", "breast.R", "belly", "glute.L", "glute.R"]:
		_assert("soft-region bone present in rig: %s" % sb,
			rig.skeleton.find_bone(sb) >= 0, "idx=%d" % rig.skeleton.find_bone(sb))
	_assert("HAIR registry NON-EMPTY: hair-bone chain registered (was the documented GAP)",
		st["hair_springs"] >= 1, "hair springs=%d (expected >=1)" % st["hair_springs"])
	for hb in ["hair01", "hair02", "hair03"]:
		_assert("hair bone present in rig: %s" % hb,
			rig.skeleton.find_bone(hb) >= 0, "idx=%d" % rig.skeleton.find_bone(hb))

	# --- 2. jiggle moves under body motion -----------------------------------
	var breast := rig.skeleton.find_bone("breast.L")
	_assert("breast.L bone exists (jiggle target)", breast >= 0, "idx=%d" % breast)
	# Still body: settle a few frames, jiggle should be ~rest.
	rig.set_movement_state(true, 0.0)
	rig.global_position = Vector3.ZERO
	for i in 30:
		rig.apply_pose(1.0 / 60.0)
	var still_q := rig.skeleton.get_bone_pose_rotation(breast)
	# Shaking body: jolt the global transform up/down between frames -> the spring lags.
	var max_shake_dev := 0.0
	for i in 30:
		rig.global_position = Vector3(0, 0.06 * sin(i * 1.4), 0)
		rig.apply_pose(1.0 / 60.0)
		var shaken := rig.skeleton.get_bone_pose_rotation(breast)
		max_shake_dev = maxf(max_shake_dev, still_q.angle_to(shaken))
	_assert("jiggle: soft-region bone deflects under body motion (>0.5mrad)",
		max_shake_dev > 5e-4, "max deflection=%.5f rad" % max_shake_dev)

	# --- 2b. the NEWLY-ADDED springs all produce nonzero deflection ----------
	# belly + glute jiggle (soft-region) and the hair chain (hair physics) must now move
	# under body motion — the whole point of adding the bones + skin. Each is measured on
	# a fresh rig (shake the global transform, take max deflection from the settled pose).
	for bn in ["belly", "glute.L", "glute.R", "hair01", "hair02", "hair03"]:
		var dev := _bone_shake_deflection(bn)
		_assert("NEW spring deflects under body motion: %s (>0.2mrad)" % bn,
			dev > 2e-4, "max deflection=%.5f rad" % dev)

	# --- 3. jiggle tunable ---------------------------------------------------
	var dev_lo := _shake_deflection(0.2)
	var dev_hi := _shake_deflection(1.5)
	_assert("jiggle TUNABLE: higher gain -> larger deflection",
		dev_hi > dev_lo, "gain0.2=%.5f < gain1.5=%.5f" % [dev_lo, dev_hi])

	# --- 4. saccade alive ----------------------------------------------------
	var rig2 := BodyRig.new(); add_child(rig2); rig2.build()
	rig2.use_motion_matching = false; rig2.foot_ik_enabled = false
	rig2._setup_micro_life(42)
	rig2.set_movement_state(true, 0.0)
	var sacc_seen := 0.0
	var sacc_changes := 0
	var prev := rig2.saccade_offset()
	for i in 600:                     # 10s — several saccade intervals
		rig2.apply_pose(1.0 / 60.0)
		var cur := rig2.saccade_offset()
		sacc_seen = maxf(sacc_seen, cur.length())
		if cur.distance_to(prev) > 1e-4:
			sacc_changes += 1
		prev = cur
	_assert("saccade: eye micro-offset becomes nonzero (eyes never dead-still)",
		sacc_seen > 1e-3, "max |offset|=%.5f" % sacc_seen)
	_assert("saccade: offset changes over time (irregular darts)",
		sacc_changes > 30, "frames-changed=%d" % sacc_changes)

	# --- 5. breathing tunable ------------------------------------------------
	var breath_full := _breath_excursion(1.0)
	var breath_off := _breath_excursion(0.0)
	_assert("breathing produces spine/clavicle motion", breath_full > 1e-4,
		"excursion=%.6f rad" % breath_full)
	_assert("breathing TUNABLE: amplitude 0 ~kills the breath contribution",
		breath_off < breath_full * 0.25, "off=%.6f full=%.6f" % [breath_off, breath_full])

	# --- 6. determinism ------------------------------------------------------
	var a := _saccade_after(7, 200)
	var b := _saccade_after(7, 200)
	_assert("cosmetic stream deterministic (same seed -> same saccade offset)",
		a.distance_to(b) < 1e-6, "a=%s b=%s" % [str(a), str(b)])
	var c := _saccade_after(8, 200)
	_assert("different cosmetic seed -> different saccade timeline",
		a.distance_to(c) > 1e-5, "seed7=%s seed8=%s" % [str(a), str(c)])

	# --- 7. sim-path isolation (structural) ----------------------------------
	# Driving the micro-life layer must not mutate the MovementState the host fed in;
	# the layer is a pure consumer (reads grounded/speed, writes only bone poses).
	rig.set_movement_state(true, 0.0)
	var g_before := rig.grounded
	var s_before := rig.horizontal_speed
	for i in 20:
		rig.apply_pose(1.0 / 60.0)
	_assert("micro-life does not write back into the MovementState inputs",
		rig.grounded == g_before and is_equal_approx(rig.horizontal_speed, s_before),
		"grounded %s->%s speed %.3f->%.3f" % [g_before, rig.grounded, s_before, rig.horizontal_speed])

	_finish()


## Settle a fresh rig still, then shake its global transform; return the max deflection
## (rad) of the NAMED bone's pose rotation from its settled pose. Works for any spring-
## driven bone (soft-region jiggle OR hair chain). A fresh rig per call so the springs
## start from rest (reproducible).
func _bone_shake_deflection(bone_name: String) -> float:
	var rig := BodyRig.new(); add_child(rig); rig.build()
	rig.use_motion_matching = false; rig.foot_ik_enabled = false
	rig._setup_micro_life(0)
	var bi := rig.skeleton.find_bone(bone_name)
	if bi < 0:
		rig.queue_free()
		return 0.0
	rig.set_movement_state(true, 0.0)
	rig.global_position = Vector3.ZERO
	for i in 30:
		rig.apply_pose(1.0 / 60.0)
	var settled := rig.skeleton.get_bone_pose_rotation(bi)
	var dev := 0.0
	for i in 40:
		# Shake both vertically and horizontally so chains hanging in any axis are thrown.
		rig.global_position = Vector3(0.05 * sin(i * 1.7), 0.07 * sin(i * 1.4), 0.04 * cos(i * 1.9))
		rig.apply_pose(1.0 / 60.0)
		dev = maxf(dev, settled.angle_to(rig.skeleton.get_bone_pose_rotation(bi)))
	rig.queue_free()
	return dev


## Settle a fresh rig still, then shake it with the given jiggle_gain; return the max
## breast-bone deflection from the still pose.
func _shake_deflection(gain: float) -> float:
	var rig := BodyRig.new(); add_child(rig); rig.build()
	rig.use_motion_matching = false; rig.foot_ik_enabled = false
	rig._setup_micro_life(0)
	rig.micro.jiggle_gain = gain
	var breast := rig.skeleton.find_bone("breast.L")
	rig.set_movement_state(true, 0.0)
	rig.global_position = Vector3.ZERO
	for i in 30:
		rig.apply_pose(1.0 / 60.0)
	var still := rig.skeleton.get_bone_pose_rotation(breast)
	var dev := 0.0
	for i in 30:
		rig.global_position = Vector3(0, 0.06 * sin(i * 1.4), 0)
		rig.apply_pose(1.0 / 60.0)
		dev = maxf(dev, still.angle_to(rig.skeleton.get_bone_pose_rotation(breast)))
	rig.queue_free()
	return dev


## Max spine01 excursion over a breath cycle with the given breath_amplitude, jiggle off
## (isolate breathing). Returns the peak-to-rest angle on a breath-driven bone.
func _breath_excursion(amp: float) -> float:
	var rig := BodyRig.new(); add_child(rig); rig.build()
	rig.use_motion_matching = false; rig.foot_ik_enabled = false
	rig._setup_micro_life(0)
	rig.micro.jiggle_enabled = false
	rig.micro.sway_enabled = false
	rig.micro.breath_amplitude = amp
	# On the procedural-fallback path, breathing is layered on upperarm/spine via
	# _idle_micro; sample upperarm01.L (carries the breath lift).
	var arm := rig.skeleton.find_bone("upperarm01.L")
	rig.set_movement_state(true, 0.0)
	rig.apply_pose(1.0 / 60.0)
	var base := rig.skeleton.get_bone_pose_rotation(arm)
	var ex := 0.0
	# A full breath cycle at 0.25 Hz ~ 4s = 240 frames; sweep two cycles.
	for i in 480:
		rig.apply_pose(1.0 / 60.0)
		ex = maxf(ex, base.angle_to(rig.skeleton.get_bone_pose_rotation(arm)))
	rig.queue_free()
	return ex


## The saccade offset after `frames` of idle on a rig with cosmetic seed `seed`.
func _saccade_after(seed: int, frames: int) -> Vector2:
	var rig := BodyRig.new(); add_child(rig); rig.build()
	rig.use_motion_matching = false; rig.foot_ik_enabled = false
	rig._setup_micro_life(seed)
	rig.set_movement_state(true, 0.0)
	for i in frames:
		rig.apply_pose(1.0 / 60.0)
	var o := rig.saccade_offset()
	rig.queue_free()
	return o


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
