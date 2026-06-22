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

	# --- 8. BDCC2 SWAPPABLE HAIR (under the generalized PartLibrary) ----------
	# Hair still works as the SLOT_HAIR slot of the generalized swap system: a BDCC2-mined
	# rigged hair GLB attaches under the head bone, registers spring bones on ITS OWN
	# skeleton, deflects under body motion via aeriea's spring physics, and swaps cleanly
	# with the CC0 cap. (Assets: alexofp/Rahi, BDCC2, MIT — see NOTICE.md.)
	var rig3 := BodyRig.new(); add_child(rig3); rig3.build()
	rig3.use_motion_matching = false; rig3.foot_ik_enabled = false
	rig3._setup_micro_life(0)
	# default hair part is the CC0 cap (hair on the body skeleton's hair01/02/03 chain).
	_assert("default hair part is the CC0 cap", rig3.current_part("hair") == "cap",
		"hair=%s" % rig3.current_part("hair"))
	# apply a BDCC2 ponytail via the legacy shim (apply_hairstyle -> apply_part(hair,…)).
	var ok_pt := rig3.apply_hairstyle("ponytail1")
	_assert("BDCC2 ponytail1 applies (via apply_hairstyle shim)", ok_pt, "ok=%s" % ok_pt)
	var hskel := _first_part_skel(rig3, "hair")
	_assert("BDCC2 hair attaches its OWN skeleton under the head bone", hskel != null,
		"hair_skel=%s" % (hskel != null))
	if hskel != null:
		_assert("BDCC2 hair skeleton has physics bones (Tail/Back/…)", hskel.get_bone_count() >= 2,
			"bones=%d" % hskel.get_bone_count())
		var has_mesh := false
		for child in hskel.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
				has_mesh = true
		_assert("BDCC2 hair has a real skinned mesh on the head", has_mesh, "mesh=%s" % has_mesh)
	_assert("BDCC2 hair registers spring bones on its own skeleton",
		rig3.micro_life_state()["hair_springs"] >= 1,
		"hair_springs=%d" % rig3.micro_life_state()["hair_springs"])
	# the BDCC2 hair bones must DEFLECT under body shake (aeriea's springs drive them).
	var bdcc2_dev := _part_deflection(rig3, hskel)
	_assert("BDCC2 hair SWAYS via aeriea's spring physics (>1mrad)", bdcc2_dev > 1e-3,
		"max deflection=%.5f rad" % bdcc2_dev)
	# swap to a DIFFERENT BDCC2 style: a new skeleton/mesh replaces the old one.
	rig3.apply_part("hair", "short")
	var hskel2 := _first_part_skel(rig3, "hair")
	_assert("swap to a different BDCC2 style replaces the hair skeleton",
		hskel2 != null and hskel2 != hskel, "new_skel=%s changed=%s" % [hskel2 != null, hskel2 != hskel])
	_assert("ShortHair registers its own spring count",
		rig3.micro_life_state()["hair_springs"] >= 1,
		"hair_springs=%d" % rig3.micro_life_state()["hair_springs"])
	# swap back to the CC0 cap: BDCC2 hair torn down, cap chain re-registered on the body.
	rig3.apply_part("hair", "cap")
	_assert("swap back to CC0 cap tears down the BDCC2 hair skeleton",
		_first_part_skel(rig3, "hair") == null, "hair_skel=%s" % (_first_part_skel(rig3, "hair") != null))
	_assert("CC0 cap re-registers the hair01/02/03 chain on the body skeleton",
		rig3.micro_life_state()["hair_springs"] >= 1,
		"hair_springs=%d" % rig3.micro_life_state()["hair_springs"])
	# unknown id falls back to the cap (never a bald head).
	rig3.apply_part("hair", "long")
	rig3.apply_part("hair", "nonexistent_style")
	_assert("unknown hair id falls back to the CC0 cap",
		rig3.current_part("hair") == "cap" and _first_part_skel(rig3, "hair") == null,
		"hair=%s hair_skel=%s" % [rig3.current_part("hair"), _first_part_skel(rig3, "hair") != null])

	# --- 9. BDCC2 SWAPPABLE EARS (head slot, swaying) ------------------------
	# A BDCC2 ear SET is TWO GLBs (L + R), each with its own skeleton, attached under the
	# head bone; the ear physics bones sway via aeriea's springs. >=2 ear styles swap.
	var rig4 := BodyRig.new(); add_child(rig4); rig4.build()
	rig4.use_motion_matching = false; rig4.foot_ik_enabled = false
	rig4._setup_micro_life(0)
	_assert("default ears part is 'none'", rig4.current_part("ears") == "none",
		"ears=%s" % rig4.current_part("ears"))
	var ok_ears := rig4.apply_part("ears", "feline")
	_assert("BDCC2 feline ears apply", ok_ears, "ok=%s" % ok_ears)
	var ear_skels := rig4._part_skeletons("ears")
	_assert("feline ears attach TWO skeletons (L + R) under the head",
		ear_skels.size() == 2, "ear_skels=%d" % ear_skels.size())
	_assert("ears register spring bones (>=2)", rig4.micro_life_state()["slot_springs"]["ears"] >= 2,
		"ear_springs=%d" % rig4.micro_life_state()["slot_springs"]["ears"])
	var ear_dev := _part_deflection(rig4, ear_skels[0] if ear_skels.size() > 0 else null)
	_assert("BDCC2 ears SWAY via aeriea's spring physics (>1mrad)", ear_dev > 1e-3,
		"max deflection=%.5f rad" % ear_dev)
	# swap to a SECOND ear style.
	rig4.apply_part("ears", "round")
	_assert("swap to round ears replaces the ear skeletons",
		rig4._part_skeletons("ears").size() == 2 and rig4.current_part("ears") == "round",
		"round ear_skels=%d" % rig4._part_skeletons("ears").size())
	# swap to none: ears torn down, no ear springs.
	rig4.apply_part("ears", "none")
	_assert("swap ears to none tears down ear skeletons",
		rig4._part_skeletons("ears").is_empty() and rig4.micro_life_state()["slot_springs"]["ears"] == 0,
		"ear_skels=%d ear_springs=%d" % [rig4._part_skeletons("ears").size(), rig4.micro_life_state()["slot_springs"]["ears"]])

	# --- 10. BDCC2 SWAPPABLE TAIL (spine05 slot, swaying chain) --------------
	# A BDCC2 tail is ONE GLB with a DEF-Tail1..N chain, attached under spine05 (pelvis
	# base); the chain sways via aeriea's springs. >=2 tail styles swap.
	var rig5 := BodyRig.new(); add_child(rig5); rig5.build()
	rig5.use_motion_matching = false; rig5.foot_ik_enabled = false
	rig5._setup_micro_life(0)
	var ok_tail := rig5.apply_part("tail", "fluffy")
	_assert("BDCC2 fluffy tail applies", ok_tail, "ok=%s" % ok_tail)
	var tail_skels := rig5._part_skeletons("tail")
	_assert("tail attaches its skeleton under spine05", tail_skels.size() == 1,
		"tail_skels=%d" % tail_skels.size())
	if tail_skels.size() == 1:
		_assert("tail skeleton has a multi-bone chain (DEF-Tail1..N)", tail_skels[0].get_bone_count() >= 4,
			"tail bones=%d" % tail_skels[0].get_bone_count())
	_assert("tail registers a spring chain (>=4)", rig5.micro_life_state()["slot_springs"]["tail"] >= 4,
		"tail_springs=%d" % rig5.micro_life_state()["slot_springs"]["tail"])
	var tail_dev := _part_deflection(rig5, tail_skels[0] if tail_skels.size() > 0 else null)
	_assert("BDCC2 tail SWAYS via aeriea's spring physics (>1mrad)", tail_dev > 1e-3,
		"max deflection=%.5f rad" % tail_dev)
	rig5.apply_part("tail", "dragon")
	_assert("swap to dragon tail replaces the tail skeleton",
		rig5._part_skeletons("tail").size() == 1 and rig5.current_part("tail") == "dragon",
		"dragon tail_skels=%d" % rig5._part_skeletons("tail").size())
	rig5.apply_part("tail", "none")
	_assert("swap tail to none tears down the tail skeleton + springs",
		rig5._part_skeletons("tail").is_empty() and rig5.micro_life_state()["slot_springs"]["tail"] == 0,
		"tail_skels=%d" % rig5._part_skeletons("tail").size())

	# --- 11. BDCC2 RIGID HORNS (head slot, NO sway) --------------------------
	# Horns are RIGID in BDCC2 (a bare MeshInstance3D, no skeleton) — they attach to the
	# head and ride it, but register NO spring physics (correct: horn is bone). Two styles.
	var rig6 := BodyRig.new(); add_child(rig6); rig6.build()
	rig6.use_motion_matching = false; rig6.foot_ik_enabled = false
	rig6._setup_micro_life(0)
	var ok_horn := rig6.apply_part("horns", "horn1")
	_assert("BDCC2 horns apply", ok_horn, "ok=%s" % ok_horn)
	_assert("horns attach a mesh (L + R) under the head", _slot_mesh_count(rig6, "horns") >= 2,
		"horn meshes=%d" % _slot_mesh_count(rig6, "horns"))
	_assert("horns register NO spring physics (rigid)", rig6.micro_life_state()["slot_springs"]["horns"] == 0,
		"horn_springs=%d" % rig6.micro_life_state()["slot_springs"]["horns"])
	rig6.apply_part("horns", "chaos")
	_assert("swap to chaos horns works", rig6.current_part("horns") == "chaos" and _slot_mesh_count(rig6, "horns") >= 2,
		"chaos horn meshes=%d" % _slot_mesh_count(rig6, "horns"))
	rig6.apply_part("horns", "none")
	_assert("swap horns to none tears them down", _slot_mesh_count(rig6, "horns") == 0,
		"horn meshes=%d" % _slot_mesh_count(rig6, "horns"))

	# --- 12. SLOTS ARE INDEPENDENT (multi-slot stacking) ---------------------
	# Applying ears + tail + a BDCC2 hairstyle TOGETHER: all coexist, each registers its
	# own springs, and the registries are additive (the whole point of named slots).
	var rig7 := BodyRig.new(); add_child(rig7); rig7.build()
	rig7.use_motion_matching = false; rig7.foot_ik_enabled = false
	rig7._setup_micro_life(0)
	rig7.apply_part("hair", "long")
	rig7.apply_part("ears", "feline")
	rig7.apply_part("tail", "fluffy")
	rig7.apply_part("horns", "horn1")
	var ss: Dictionary = rig7.micro_life_state()["slot_springs"]
	_assert("all four slots filled coexist (hair+ears+tail springs all >0, horns=0)",
		ss["hair"] >= 1 and ss["ears"] >= 2 and ss["tail"] >= 4 and ss["horns"] == 0,
		"slot_springs=%s" % str(ss))
	rig7.apply_part("hair", "short")
	var ss2: Dictionary = rig7.micro_life_state()["slot_springs"]
	_assert("changing one slot (hair) does not disturb ears/tail springs",
		ss2["ears"] >= 2 and ss2["tail"] >= 4, "after hair swap slot_springs=%s" % str(ss2))

	_finish()


## The first attached part skeleton for `slot`, or null. Wraps _part_skeletons().
func _first_part_skel(rig: BodyRig, slot: String) -> Skeleton3D:
	var s := rig._part_skeletons(slot)
	return s[0] if s.size() > 0 else null


## Count MeshInstance3D nodes attached for `slot` (recursively under its attachments) —
## used for RIGID parts (horns) that have no skeleton, just meshes.
func _slot_mesh_count(rig: BodyRig, slot: String) -> int:
	var n := 0
	for att in rig._part_attachments.get(slot, []):
		if is_instance_valid(att):
			for m in att.find_children("*", "MeshInstance3D", true, false):
				if (m as MeshInstance3D).mesh != null:
					n += 1
	return n


## Settle the rig still with its current part(s), then shake the body and return the max
## deflection (rad) of the first physics bone on the given attached part skeleton — i.e.
## confirm aeriea's spring physics actually sways the BDCC2 geometry (hair / ears / tail).
func _part_deflection(rig: BodyRig, hskel: Skeleton3D) -> float:
	if hskel == null:
		return 0.0
	var bi := -1
	for i in hskel.get_bone_count():
		var n := hskel.get_bone_name(i).to_lower()
		if n != "root" and not n.begins_with("def-root") and n != "neutral_bone":
			bi = i; break
	if bi < 0:
		return 0.0
	rig.set_movement_state(true, 0.0)
	rig.global_position = Vector3.ZERO
	for i in 30:
		rig.apply_pose(1.0 / 60.0)
	var settled := hskel.get_bone_pose_rotation(bi)
	var dev := 0.0
	for i in 40:
		rig.global_position = Vector3(0.05 * sin(i * 1.7), 0.07 * sin(i * 1.4), 0.04 * cos(i * 1.9))
		rig.apply_pose(1.0 / 60.0)
		dev = maxf(dev, settled.angle_to(hskel.get_bone_pose_rotation(bi)))
	return dev


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
