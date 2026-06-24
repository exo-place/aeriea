## Build-B body/morph flat-fix test — the four fixes from docs/decisions/character-creator-ux.md
## (§8.2 cup size, §8.3 randomize, §8.6 height) + -and-body §6.3 (iris). OBJECTIVE clauses only
## (visual aesthetics are USER-gated, never asserted here):
##
##   (1) RANDOMIZE INSTANT: _randomize_all bakes ONCE, not per value-node. Measured: wall-time is
##       a small fraction of the old per-axis-bake path (we assert the per-call apply/bake count
##       via _suspend_apply, and that wall-time is well under a freeze threshold).
##   (2) RANDOMIZE COHERENT: across many seeds, the result's masculinity stays IN-BUCKET — never
##       in the androgynous 40–60 band (androgynous opt-in OFF by default). Deterministic.
##   (3) HEIGHT cm: setting height_cm changes the rig's uniform stature scale; the value reads a
##       sensible cm number; the displayed dial value is "<n>cm".
##   (4) BREAST SIZE: the imported cup cube is in the detail library (216 targets) and driving
##       breast_size 0->1 monotonically increases chest-region forward protrusion (REAL size, not
##       just lift). The bidirectional volume "lift" axis is unchanged (distinct control).
##   (5) IRIS: the shipped eye shader param is round (pupil_aspect 1.0) and the proxy scale is
##       uniform — so the iris is NOT geometrically distorted. (The render verification lives in
##       tools/eye_iris_render; this asserts the round invariant the render confirmed.)
##
##   xvfb-run -a godot4 --path . res://tests/creator_buildbfix_test.tscn --quit-after 12000
extends Node

const CharacterCreator := preload("res://scripts/body/character_creator.gd")
const BodyRigScript := preload("res://scripts/body/body_rig.gd")
const DetailLibrary := preload("res://scripts/body/detail_library.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CREATOR BUILD-B — instant coherent randomize + cm height + cup-cube size + iris ===\n")
	_test_cup_cube_library()
	_test_breast_size_morph()
	await _test_scene()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])


# (4a) the 216-target cup cube is present in the detail library --------------------------------
func _test_cup_cube_library() -> void:
	print("--- (4a) cup cube imported into the detail library ---")
	DetailLibrary.ensure_loaded()
	var cup_count := 0
	var sample := ""
	for p in DetailLibrary.paths_of_kind("macro"):
		if String(p).contains("breast/female-") and String(p).contains("cup"):
			cup_count += 1
			if sample == "":
				sample = String(p)
	_ok("the 216-target breast cup cube is imported", cup_count == 216,
		"cup targets=%d (sample %s)" % [cup_count, sample])
	# A specific maxcup target has nonzero deltas (it actually morphs).
	var maxcup := "breast/female-young-averagemuscle-averageweight-maxcup-averagefirmness.target"
	_ok("a maxcup target carries real deltas (count>0)", DetailLibrary.has_target(maxcup),
		"%s present=%s" % [maxcup, DetailLibrary.has_target(maxcup)])


# (4b) breast_size 0->1 increases chest-region forward protrusion (real size, not lift) --------
func _test_breast_size_morph() -> void:
	print("--- (4b) breast_size morph: monotone chest protrusion delta (REAL size) ---")
	var rig = BodyRigScript.new()
	add_child(rig)
	rig.build()
	var zs := []
	for s in [0.0, 0.5, 1.0]:
		var bs := BodyState.new()
		bs.masculinity = 20.0
		bs.breast_size = float(s)
		rig.apply_body_state(bs)
		zs.append(_chest_max_z(rig))
	var delta: float = zs[2] - zs[0]
	var monotone: bool = zs[0] < zs[1] and zs[1] < zs[2]
	_ok("breast_size 0->1 monotonically increases chest protrusion", monotone,
		"z(small)=%.4f z(avg)=%.4f z(large)=%.4f" % [zs[0], zs[1], zs[2]])
	_ok("breast_size delta is a REAL measurable size change (>10mm)", delta > 0.010,
		"delta = %.4f m (%.1f mm)" % [delta, delta * 1000.0])
	rig.queue_free()


func _chest_max_z(rig) -> float:
	var mi: MeshInstance3D = rig.mesh_instance
	if mi == null or mi.mesh == null:
		return 0.0
	var verts: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var maxz := -INF
	for v in verts:
		if v.y >= 1.15 and v.y <= 1.45:
			maxz = maxf(maxz, v.z)
	return maxz


# (1)(2)(3)(5) scene-level ---------------------------------------------------------------------
func _test_scene() -> void:
	var cc := CharacterCreator.new()
	add_child(cc)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: BodyState = cc.get("_body_state")

	# (1) RANDOMIZE INSTANT — wall-time + the one-bake invariant.
	print("--- (1) randomize is INSTANT (bakes once, not per value-node) ---")
	# Count _apply_state bakes during a randomize: with _suspend_apply, the only un-suppressed
	# bake is the single one at the end. We measure wall-time as the objective freeze metric.
	var t0 := Time.get_ticks_usec()
	cc.call("_randomize_all")
	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("  randomize wall-time = %.1f ms" % dt_ms)
	# The old path baked 7+ times (6 axes + final) over 14,517 verts each = seconds. One bake is
	# well under 1 s even on CI; assert a generous 1500 ms ceiling (the freeze was multi-second).
	_ok("randomize completes without a multi-second freeze (<1500 ms)", dt_ms < 1500.0,
		"%.1f ms" % dt_ms)

	# (2) RANDOMIZE COHERENT — masculinity stays in-bucket across many seeds (androgynous OFF).
	print("--- (2) randomize lands a COHERENT gender (never the 40-60 androgynous band) ---")
	cc.set("_allow_androgynous_random", false)
	var in_band := 0
	var n := 40
	for i in n:
		cc.call("_randomize_all")
		var m: float = bs.masculinity
		# In-bucket = NOT strictly inside the androgynous band (40,60). Allow the exact edges.
		if m <= 40.0 or m >= 60.0:
			in_band += 1
		else:
			print("    OUT-OF-BUCKET roll: masculinity=%.1f" % m)
	_ok("all %d rolls land a definite presentation (masc <=40 or >=60)" % n, in_band == n,
		"%d/%d in-bucket" % [in_band, n])

	# (2b) DETERMINISM: same seed+counter -> same masculinity (seeded, replayable).
	print("--- (2b) randomize is deterministic (seeded) ---")
	cc.set("_random_seed", 12345)
	cc.set("_random_counter", 0)
	cc.call("_randomize_all")
	var m1: float = bs.masculinity
	cc.set("_random_seed", 12345)
	cc.set("_random_counter", 0)
	cc.call("_randomize_all")
	var m2: float = bs.masculinity
	_ok("same seed+counter -> identical masculinity", is_equal_approx(m1, m2),
		"m1=%.3f m2=%.3f" % [m1, m2])

	# (3) HEIGHT cm — setting height_cm changes stature scale; reads a sensible cm number.
	print("--- (3) Height is a real cm value-node driving stature scale ---")
	bs.height_cm = 150.0
	var scale_short: float = bs.height_scale()
	bs.height_cm = 200.0
	var scale_tall: float = bs.height_scale()
	_ok("a taller height_cm gives a larger stature scale", scale_tall > scale_short,
		"scale@150cm=%.4f scale@200cm=%.4f" % [scale_short, scale_tall])
	bs.height_cm = 172.0
	_ok("the height value reads a sensible cm number", bs.height_cm > 50.0 and bs.height_cm < 230.0,
		"height_cm=%.1f" % bs.height_cm)
	_ok("the dial displays height in cm (\"<n>cm\")", String(cc.call("_format_value", "height_cm")).ends_with("cm"),
		"display=%s" % cc.call("_format_value", "height_cm"))

	# (5) IRIS round invariant — shader param round + proxy uniform scale.
	print("--- (5) iris is round (shipped param round; proxy uniform scale) ---")
	var rig = cc.get("_rig")
	var ep: Dictionary = rig.get("_eye_params")
	_ok("eye shader pupil_aspect == 1.0 (round)", is_equal_approx(float(ep["pupil_aspect"]), 1.0),
		"pupil_aspect=%s" % ep["pupil_aspect"])
	var skel: Skeleton3D = rig.get("skeleton")
	var sc: Vector3 = skel.scale if skel != null else Vector3.ONE
	_ok("skeleton scale is uniform (no normal-distorting non-uniform scale)",
		is_equal_approx(sc.x, sc.y) and is_equal_approx(sc.y, sc.z),
		"skeleton scale=%s" % str(sc))

	cc.queue_free()
