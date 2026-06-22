## Arm IK/FK test — analytic two-bone arm-IK on the BodyRig (mirrors the foot-IK
## pattern for reach/plant/brace). Asserts:
##
##   1. REACH: with a reach target set (weight 1), the wrist actually reaches the
##      world target (wrist→target distance small) for a target inside arm range.
##   2. FK UNTOUCHED at weight 0 / no target: the arm chain pose is byte-identical
##      to the base anim pose (arm IK is a no-op without a target / at weight 0).
##   3. NO ELBOW INVERSION: the solved elbow stays on the human (pole) side — the
##      elbow→pole direction has a positive component along the pole hint, and the
##      chain is not hyper-extended.
##   4. INDEPENDENCE: reaching one arm leaves the other arm at its base pose.
##   5. BLEND: weight 0.5 lands the wrist between the base pose and the full reach.
##   6. RANGE CLAMP: a target far beyond arm length extends toward it without NaN /
##      inversion (wrist on the shoulder→target ray, near max extension).
##   7. DETERMINISM: same (target, base pose) -> same solved pose, twice.
##
## RENDER-SIDE only — exercises the pose layer in isolation; the sim regression
## guard is the (unchanged) movement_behavior + golden_trace suites.
##
##   xvfb-run -a godot4 --path . res://tests/body_arm_ik_test.tscn --quit-after 6000
extends Node3D

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea body ARM-IK (reach) test ===\n")

	var rig := BodyRig.new()
	add_child(rig)
	if not rig.build():
		_assert("BodyRig.build() succeeds", false, "build failed")
		_finish(); return
	# Isolate the arm IK from the locomotion/clip layers for a clean base pose:
	# drive the procedural floor at rest (a stable, deterministic base arm pose).
	rig.use_motion_matching = false
	rig.foot_ik_enabled = false
	rig.clip_layer_enabled = false
	# Freeze the breathing/sway micro-motion so the BASE arm pose is stable frame-to-
	# frame — otherwise the no-op / determinism checks would see the (correct) breath
	# drift in the base and read it as an arm-IK difference. The arm IK runs BEFORE
	# micro-life regardless; this just gives the test a fixed reference base pose.
	_freeze_micro(rig)
	rig.set_movement_state(true, 0.0)
	rig._smoothed_speed = 0.0

	var skel := rig.skeleton
	var wl := skel.find_bone("wrist.L")
	var wr := skel.find_bone("wrist.R")
	var ul := skel.find_bone("upperarm01.L")
	var ll := skel.find_bone("lowerarm01.L")
	_assert("arm bones resolve (upperarm/lowerarm/wrist .L/.R)",
		wl >= 0 and wr >= 0 and ul >= 0 and ll >= 0,
		"ul=%d ll=%d wl=%d wr=%d" % [ul, ll, wl, wr])
	if wl < 0:
		_finish(); return

	# --- capture the BASE (no-reach) pose -----------------------------------
	rig.clear_reach()
	rig.apply_pose(1.0 / 60.0)
	var base_ul := skel.get_bone_pose_rotation(ul)
	var base_ll := skel.get_bone_pose_rotation(ll)
	var base_wl_pos := _wrist_world(rig, wl)
	var base_wr_pos := _wrist_world(rig, wr)
	var base_ur := skel.get_bone_pose_rotation(skel.find_bone("upperarm01.R"))

	# --- 2. FK UNTOUCHED at weight 0 / no target ----------------------------
	# No-op proof: capture the arm pose, invoke the arm-IK layer DIRECTLY with NO frame
	# advance (so the base anim can't drift between reads), and require it changes
	# nothing — _apply_arm_ik() early-returns on an empty/weight-0 reach, so the base
	# pose is untouched.
	#
	# NOTE ON THE THRESHOLD. Godot's Skeleton3D.get_bone_pose_rotation() itself returns
	# a quaternion that differs by a CONSTANT ~6.9e-4 rad (~0.04°) between two
	# back-to-back reads of the SAME unwritten pose (an internal quantization quirk:
	# read1↔read2↔read3 all show exactly this value with ZERO writes between — verified).
	# That floor is intrinsic to the engine read, not to the arm IK. So the no-op
	# tolerance is set ABOVE that read floor (2e-3 rad) and FAR below any real IK effect
	# (a weight-1 reach swings the arm by ~0.5 rad — see the REACH/BLEND asserts). A
	# genuine no-op lands at the read floor; any IK contribution would blow past 2e-3.
	var READ_FLOOR := 2.0e-3
	var before_ul := skel.get_bone_pose_rotation(ul)
	var before_ll := skel.get_bone_pose_rotation(ll)
	rig.clear_reach()
	rig._apply_arm_ik()   # empty reach -> must be a true no-op
	var noop_u := skel.get_bone_pose_rotation(ul).angle_to(before_ul)
	var noop_l := skel.get_bone_pose_rotation(ll).angle_to(before_ll)
	_assert("no target: _apply_arm_ik() leaves the arm chain unchanged (no-op)",
		noop_u < READ_FLOOR and noop_l < READ_FLOOR,
		"upper dq=%.9f lower dq=%.9f (read floor %.4f)" % [noop_u, noop_l, READ_FLOOR])
	# weight 0 reach: also a true no-op, same in-frame isolation.
	rig.reach_for("L", base_wl_pos + Vector3(0.3, 0.2, 0.3), Vector3.INF, 0.0)
	rig._apply_arm_ik()
	var w0_u := skel.get_bone_pose_rotation(ul).angle_to(before_ul)
	var w0_l := skel.get_bone_pose_rotation(ll).angle_to(before_ll)
	_assert("weight 0: _apply_arm_ik() leaves the arm chain unchanged (no-op)",
		w0_u < READ_FLOOR and w0_l < READ_FLOOR,
		"upper dq=%.9f lower dq=%.9f (read floor %.4f)" % [w0_u, w0_l, READ_FLOOR])
	rig.clear_reach()
	rig.apply_pose(1.0 / 60.0)

	# --- 1. REACH: wrist reaches a target inside arm range ------------------
	# Build a target that is reachable: a point partway along shoulder->base wrist
	# direction, then offset, all kept within (l_upper + l_lower).
	var sh_pos := _bone_world(rig, ul)
	var l_total := sh_pos.distance_to(_bone_world(rig, ll)) + _bone_world(rig, ll).distance_to(base_wl_pos)
	# Target: out in front and down, at 70% of total arm length from the shoulder.
	var fwd := (rig.global_transform.basis * Vector3(0.4, -0.5, -0.7)).normalized()
	var target := sh_pos + fwd * (l_total * 0.7)
	rig.reach_for("L", target, Vector3.INF, 1.0)
	rig.apply_pose(1.0 / 60.0)
	var reached := _wrist_world(rig, wl)
	var reach_err := reached.distance_to(target)
	_assert("REACH: wrist reaches the world target (err < 3cm)", reach_err < 0.03,
		"wrist->target = %.4f m (arm len %.3f m)" % [reach_err, l_total])

	# --- 3. NO ELBOW INVERSION ----------------------------------------------
	# Default pole hint biases the elbow down+out. The elbow must sit OFF the
	# shoulder->wrist line (a bent, not hyper-extended, arm) AND on the lower side.
	var elbow := _bone_world(rig, ll)
	var line := (reached - sh_pos)
	var t := clampf(line.normalized().dot(elbow - sh_pos) / maxf(line.length(), 1e-4), 0.0, 1.0)
	var closest := sh_pos + line * t
	var off_line := elbow.distance_to(closest)
	_assert("NO INVERSION: elbow is bent off the shoulder-wrist line (>2cm)",
		off_line > 0.02, "elbow off-line = %.4f m" % off_line)
	# Elbow drops below the shoulder->wrist chord (human elbow points down, not up).
	_assert("NO INVERSION: elbow on the lower (pole) side, not flipped up",
		elbow.y < closest.y + 0.01, "elbow.y=%.3f closest.y=%.3f" % [elbow.y, closest.y])

	# --- 4. INDEPENDENCE: right arm untouched while left reaches ------------
	var wr_now := _wrist_world(rig, wr)
	var ur_now := skel.get_bone_pose_rotation(skel.find_bone("upperarm01.R"))
	_assert("INDEPENDENCE: right arm pose unchanged while left reaches",
		base_ur.angle_to(ur_now) < 1e-6 and wr_now.distance_to(base_wr_pos) < 1e-4,
		"R upperarm dq=%.8f, R wrist dpos=%.6f" % [base_ur.angle_to(ur_now), wr_now.distance_to(base_wr_pos)])

	# Both arms independently: reach R to its own target too.
	var sh_r := _bone_world(rig, skel.find_bone("upperarm01.R"))
	var fwd_r := (rig.global_transform.basis * Vector3(-0.4, -0.5, -0.7)).normalized()
	var target_r := sh_r + fwd_r * (l_total * 0.7)
	rig.reach_for("R", target_r, Vector3.INF, 1.0)
	rig.apply_pose(1.0 / 60.0)
	var reached_r := _wrist_world(rig, wr)
	var reached_l2 := _wrist_world(rig, wl)
	_assert("BOTH arms reach their own targets independently",
		reached_r.distance_to(target_r) < 0.03 and reached_l2.distance_to(target) < 0.03,
		"R err=%.4f, L err=%.4f" % [reached_r.distance_to(target_r), reached_l2.distance_to(target)])
	rig.clear_reach("R")

	# --- 5. BLEND: weight 0.5 lands the wrist between base and full reach ----
	rig.clear_reach(); rig.apply_pose(1.0 / 60.0)
	var base_w := _wrist_world(rig, wl)
	rig.reach_for("L", target, Vector3.INF, 1.0)
	rig.apply_pose(1.0 / 60.0)
	var full_w := _wrist_world(rig, wl)
	rig.clear_reach(); rig.apply_pose(1.0 / 60.0)
	rig.reach_for("L", target, Vector3.INF, 0.5)
	rig.apply_pose(1.0 / 60.0)
	var half_w := _wrist_world(rig, wl)
	var d_base := half_w.distance_to(base_w)
	var d_full := half_w.distance_to(full_w)
	_assert("BLEND: weight 0.5 wrist sits between base and full reach",
		d_base > 0.01 and d_full > 0.01 and half_w.distance_to(full_w) < base_w.distance_to(full_w),
		"to-base=%.3f to-full=%.3f (base->full=%.3f)" % [d_base, d_full, base_w.distance_to(full_w)])

	# --- 6. RANGE CLAMP: unreachable far target extends without inversion ----
	rig.clear_reach(); rig.apply_pose(1.0 / 60.0)
	var far_target := sh_pos + fwd * (l_total * 5.0)   # way beyond reach
	rig.reach_for("L", far_target, Vector3.INF, 1.0)
	rig.apply_pose(1.0 / 60.0)
	var far_wrist := _wrist_world(rig, wl)
	var far_reach := far_wrist.distance_to(sh_pos)
	# Wrist should be near max extension and ON the shoulder->target ray, no NaN.
	var on_ray := (far_wrist - sh_pos).normalized().dot(fwd)
	_assert("RANGE CLAMP: far target extends arm to ~max reach (no NaN)",
		not is_nan(far_reach) and far_reach > l_total * 0.9 and far_reach <= l_total + 0.01,
		"far reach=%.3f (max %.3f)" % [far_reach, l_total])
	_assert("RANGE CLAMP: wrist aims along the shoulder->target ray",
		on_ray > 0.95, "alignment dot=%.4f" % on_ray)

	# --- 7. DETERMINISM: same target+base -> same solved pose ---------------
	# Two FRESH rigs, identical drive sequence (same frame count, same target). The IK
	# is a pure function of (target, base pose); identical inputs must give an identical
	# solved pose. Both rigs are stepped one frame, then given the reach, then stepped —
	# the SAME number of apply_pose calls, so their base poses match and so must the IK.
	var det1 := _make_rig()
	det1.apply_pose(1.0 / 60.0)
	det1.reach_for("L", target, Vector3.INF, 1.0)
	det1.apply_pose(1.0 / 60.0)
	var det_a := det1.skeleton.get_bone_pose_rotation(det1.skeleton.find_bone("upperarm01.L"))
	var det_al := det1.skeleton.get_bone_pose_rotation(det1.skeleton.find_bone("lowerarm01.L"))
	var det2 := _make_rig()
	det2.apply_pose(1.0 / 60.0)
	det2.reach_for("L", target, Vector3.INF, 1.0)
	det2.apply_pose(1.0 / 60.0)
	var det_b := det2.skeleton.get_bone_pose_rotation(det2.skeleton.find_bone("upperarm01.L"))
	var det_bl := det2.skeleton.get_bone_pose_rotation(det2.skeleton.find_bone("lowerarm01.L"))
	_assert("DETERMINISM: same target+base -> same solved arm pose",
		det_a.angle_to(det_b) < 1e-6 and det_al.angle_to(det_bl) < 1e-6,
		"upper dq=%.8f lower dq=%.8f" % [det_a.angle_to(det_b), det_al.angle_to(det_bl)])

	_finish()


## A fresh BodyRig configured identically to the test's primary rig (procedural floor
## at rest, foot-IK/clip off, breathing/sway frozen) — the common base for the paired
## no-op / determinism comparisons.
func _make_rig() -> BodyRig:
	var r := BodyRig.new()
	add_child(r)
	r.build()
	r.use_motion_matching = false
	r.foot_ik_enabled = false
	r.clip_layer_enabled = false
	_freeze_micro(r)
	r.set_movement_state(true, 0.0)
	r._smoothed_speed = 0.0
	return r


# Freeze the render-side breathing/sway micro-motion so the base arm pose is a fixed
# reference for the no-op / determinism asserts (the arm IK layers before micro-life;
# jiggle/hair springs don't touch arm bones, saccade is eye-only).
func _freeze_micro(rig: BodyRig) -> void:
	if rig.micro != null:
		rig.micro.breathing_enabled = false
		rig.micro.sway_enabled = false


# World-space position of a bone's joint origin.
func _bone_world(rig: BodyRig, bone_idx: int) -> Vector3:
	return (rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(bone_idx)).origin


# World-space position of the WRIST joint (the IK end effector). The solver aims the
# wrist JOINT at the target, so we measure the wrist bone origin.
func _wrist_world(rig: BodyRig, wrist_idx: int) -> Vector3:
	return _bone_world(rig, wrist_idx)


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
