## Slice-C test (docs/decisions/body-parameterization.md §1.3 / §4 / §6 / §8): the full
## MakeHuman target import via the SPARSE CPU DELTA LIBRARY, the factor-PRODUCT macro cube,
## and METRIC uniform-scale height. Proves, windowed under xvfb:
##
##   (1) SPARSE LIBRARY loads from the committed artifact; a known detail target's
##       moved-record count matches the source .target's moved-base-vert count, and a
##       sample stored delta matches the source delta (scaled MH->m).
##   (2) FACTOR-PRODUCT macro: a combined gender×age×muscle×weight morph weight is the
##       PRODUCT of the anchor vals (matching MakeHuman's getTargetWeights), NOT the old
##       linear single-anchor value. Neutral default => no non-average anchor weighted.
##   (3) DETAIL modifier drives the mesh: setting a bidirectional/unipolar modifier morphs
##       vertices through the CPU bake (the right region moves; lighting stays outward).
##   (4) METRIC HEIGHT: height_cm is a UNIFORM SCALE — changing it scales the world bbox
##       uniformly (all axes by the same ratio) and leaves the pre-scale proportions
##       (the shape morph) untouched. Proportions axis is independent of height.
##   (5) FULL RANGES: muscle 0–100 and weight 50–150 are both functional (the lean/light
##       half now drives the min anchors, not just the heavy/muscular half).
##   (6) FULL PROPORTIONS CUBE: all 108 gender×age×muscle×weight×{ideal,uncommon} targets are
##       imported; the proportions morph weights by the §1.3 PRODUCT over the build's factor
##       anchor vals × the proportions axis val — NOT the retired 2-anchor approximation (the
##       regression asserts a build-specific cross-term that was ZERO under the old path now
##       carries full weight, and a dense reshape with outward normals).
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_detail_library_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const DetailLib := preload("res://scripts/body/detail_library.gd")
const BodyRigS := preload("res://scripts/body/body_rig.gd")
const MESH_PATH := "res://assets/body/base_body.res"

## MH->m scale (tools/detail_library_build.gd MH_TO_METERS).
const MH_TO_METERS := 0.1

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea body SLICE C — sparse delta library + factor-product macro + metric height ===\n")
	_test_sparse_library()
	_test_factor_product()
	_test_detail_morph_drives_mesh()
	_test_metric_height_uniform_scale()
	_test_full_ranges()
	_test_proportions_cube()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# (1) sparse library: counts + sample delta vs the source ----------------------
func _test_sparse_library() -> void:
	print("--- (1) sparse delta library: counts + sample delta ---")
	_assert("library loads from the committed artifact", DetailLib.ensure_loaded(), "index+bin present")

	# nose/nose-hump-incr: the source .target moves 414 BASE verts, all in the rendered body
	# group (no UV-seam split among them), so the library stores 414 render records.
	_assert("nose-hump-incr record count == 414 (matches source moved-vert count)",
		DetailLib.record_count("nose/nose-hump-incr.target") == 414,
		"count=%d" % DetailLib.record_count("nose/nose-hump-incr.target"))
	# head/head-oval (unipolar): present with deltas.
	_assert("head-oval (unipolar) present with deltas",
		DetailLib.record_count("head/head-oval.target") > 1000,
		"count=%d" % DetailLib.record_count("head/head-oval.target"))

	# Sample-delta golden: base vert 109 of nose-hump-incr has source delta (0,-.008,0) in MH
	# units == (0,-0.0008,0) m. It must appear among the stored records at that magnitude. We
	# scan for a record whose delta matches (the records are render-vert-keyed; base 109 maps
	# to one render vert, possibly more at a seam, all carrying the same delta).
	var target_delta := Vector3(0.0, -0.008 * MH_TO_METERS, 0.0)
	var found := false
	var n := DetailLib.record_count("nose/nose-hump-incr.target")
	for i in n:
		var rec := DetailLib.record_at("nose/nose-hump-incr.target", i)
		if rec.is_empty():
			continue
		if (rec[1] as Vector3).distance_to(target_delta) < 1e-6:
			found = true
			break
	_assert("a stored nose-hump delta matches the source (base109 -> (0,-0.0008,0) m)",
		found, "looked for %s among %d records" % [str(target_delta), n])

	# Macro factor-cube targets are present in the library (the cube the §1.3 product drives).
	_assert("macro cube target present (universal-male-old-maxmuscle-maxweight)",
		DetailLib.has_target("macrodetails/universal-male-old-maxmuscle-maxweight.target"),
		"cross-term cube cell")
	_assert("caucasian race-shape cube present (caucasian-female-old)",
		DetailLib.has_target("macrodetails/caucasian-female-old.target"), "age/gender shape")


# (2) factor-product macro -----------------------------------------------------
func _test_factor_product() -> void:
	print("--- (2) factor-PRODUCT macro cube (not linear) ---")
	# old + muscular + heavy + male -> the cross-term anchor = product 1*1*1*1 = 1.0.
	var combo := BodyState.new()
	combo.masculinity = 100.0; combo.age_years = 90.0; combo.muscle = 100.0; combo.weight = 150.0
	var cw := combo.to_blend_weights()
	var cross := "macrodetails/universal-male-old-maxmuscle-maxweight.target"
	_assert("male+old+maxmuscle+maxweight -> cross-term weight = 1.0 (PRODUCT)",
		absf(float(cw.get(cross, 0.0)) - 1.0) < 1e-4, "weight=%.4f" % float(cw.get(cross, 0.0)))

	# Partial build: muscle 75% -> maxmuscleVal = 0.75*2-1 = 0.5; weight 125% -> macro 0.75 ->
	# maxweightVal 0.5; so male-old-maxmuscle-maxweight = 1*1*0.5*0.5 = 0.25 (the product),
	# which a linear single-anchor sum could not produce on a combined cross-term.
	var partial := BodyState.new()
	partial.masculinity = 100.0; partial.age_years = 90.0; partial.muscle = 75.0; partial.weight = 125.0
	var pw := partial.to_blend_weights()
	_assert("muscle75%%×weight125%% cross-term = 0.25 (product of 0.5×0.5, not linear)",
		absf(float(pw.get(cross, 0.0)) - 0.25) < 1e-4, "weight=%.4f" % float(pw.get(cross, 0.0)))

	# Neutral default: no max/min muscle/weight anchor is weighted (the body is the base).
	var neutral := BodyState.new()
	var nw := neutral.to_blend_weights()
	var bad := ""
	for k in nw:
		var ks := String(k)
		if (ks.contains("maxmuscle") or ks.contains("minmuscle") or ks.contains("maxweight") or ks.contains("minweight")) and float(nw[k]) > 1e-4:
			bad = ks
	_assert("neutral default weights no non-average macro anchor", bad == "", "stray anchor: %s" % bad)


# (3) detail modifier drives the mesh ------------------------------------------
func _test_detail_morph_drives_mesh() -> void:
	print("--- (3) detail modifier morphs the mesh through the CPU bake ---")
	var mesh: ArrayMesh = load(MESH_PATH)
	var base: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var morph_mesh := mesh.duplicate(true) as ArrayMesh
	var mi := MeshInstance3D.new()
	mi.mesh = morph_mesh
	add_child(mi)

	# Compare a NOSE-morphed body against a NEUTRAL body, both baked. (Comparing against
	# base.obj would also pick up the whole-body neutral macro shift — base.obj is the raw
	# MakeHuman reference, not the displayed neutral; the displayed neutral = base + the
	# default macro blend. So the ISOLATED detail delta is neutral-vs-nose.)
	var neutral_bs := BodyState.new()
	neutral_bs.apply_morph_cpu(mi)
	var neutral_pos: PackedVector3Array = (morph_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()

	var bs := BodyState.new()
	bs.modifiers["nose/nose-hump-decr|incr"] = 1.0
	bs.apply_morph_cpu(mi)
	var morphed: PackedVector3Array = morph_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_disp := 0.0
	var moved_y_sum := 0.0
	var moved_count := 0
	for i in neutral_pos.size():
		var d := (morphed[i] - neutral_pos[i]).length()
		if d > 1e-5:
			max_disp = maxf(max_disp, d)
			moved_y_sum += neutral_pos[i].y
			moved_count += 1
	_assert("nose modifier moves vertices (max disp > 0.1mm) vs neutral", max_disp > 1e-4,
		"max disp=%.5f m, %d moved" % [max_disp, moved_count])
	var mean_y := moved_y_sum / float(maxi(1, moved_count))
	# Body is ~1.68 m tall; the face/nose sits high (> 1.4 m). The verts the nose modifier
	# moves (over the neutral baseline) must average in the head region, not the lower body.
	_assert("nose morph is localized to the head region (moved verts mean y > 1.4 m)",
		mean_y > 1.4, "moved-vert mean y = %.3f m (%d verts)" % [mean_y, moved_count])

	# Lighting stays correct: baked normals point OUTWARD under the detail morph.
	var mn: PackedVector3Array = morph_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var cen := Vector3.ZERO
	for p in morphed: cen += p
	cen /= float(morphed.size())
	var radial := 0.0
	for i in morphed.size():
		radial += mn[i].dot(morphed[i] - cen)
	_assert("detail-morph baked normals point OUTWARD (correct lighting, not inverted)",
		radial > 0.0, "Σ dot(normal,pos-centroid) = %.4f" % radial)
	mi.queue_free()


# (4) metric height uniform scale ----------------------------------------------
func _test_metric_height_uniform_scale() -> void:
	print("--- (4) metric height = uniform scale, orthogonal to proportions ---")
	var rig := BodyRigS.new()
	rig.use_motion_matching = false
	rig.foot_ik_enabled = false
	add_child(rig)

	var base_h := DetailLib.base_height_cm()
	_assert("base_height_cm read from library (~166.6 cm)", absf(base_h - 166.589) < 0.5,
		"base_height_cm=%.3f" % base_h)

	# height_scale = height_cm / base_height_cm.
	var tall := BodyState.new()
	tall.height_cm = base_h * 1.25
	_assert("height_cm = 1.25×base -> scale ~1.25", absf(tall.height_scale() - 1.25) < 1e-4,
		"scale=%.4f" % tall.height_scale())

	# Apply two heights; the world bbox must scale by the height ratio, while the PRE-SCALE
	# mesh (the shape) is identical (height never touches the morph deltas).
	# Use heights within [MIN_HEIGHT_CM, MAX_HEIGHT_CM] so neither clamps: base_h (~166.6)
	# and base_h*1.3 (~216.6, under the 230 ceiling).
	rig.apply_body_state(_state_with_height(base_h))
	var pre1 := _local_bbox_size(rig)
	var world1 := pre1 * rig.skeleton.scale.y
	rig.apply_body_state(_state_with_height(base_h * 1.3))
	var pre2 := _local_bbox_size(rig)
	var world2 := pre2 * rig.skeleton.scale.y
	_assert("pre-scale shape identical at both heights (height ⊥ shape)",
		absf(pre1 - pre2) < 1e-4, "pre1=%.4f pre2=%.4f" % [pre1, pre2])
	_assert("world stature scales by the height ratio (1.3×)",
		absf(world2 / world1 - 1.3) < 1e-3, "ratio=%.4f" % (world2 / world1))

	# Proportions independence: changing proportions at FIXED height changes the pre-scale
	# shape but NOT the height scale (the scale depends only on height_cm).
	var prop := _state_with_height(base_h)
	prop.proportions = 1.0
	rig.apply_body_state(prop)
	_assert("changing proportions leaves the height scale unchanged (axes independent)",
		absf(rig.skeleton.scale.y - 1.0) < 1e-4, "scale=%.4f" % rig.skeleton.scale.y)
	rig.queue_free()


func _state_with_height(h: float) -> BodyState:
	var bs := BodyState.new()
	bs.height_cm = h
	return bs


## Local (pre-scale) mesh bbox height in metres.
func _local_bbox_size(rig) -> float:
	var verts: PackedVector3Array = (rig.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var miny := INF; var maxy := -INF
	for v in verts:
		miny = minf(miny, v.y); maxy = maxf(maxy, v.y)
	return maxy - miny


# (5) full muscle/weight ranges ------------------------------------------------
func _test_full_ranges() -> void:
	print("--- (5) full muscle (0-100) / weight (50-150) ranges ---")
	# Lean (muscle 0) drives the MINmuscle anchors; muscular (100) the MAXmuscle anchors.
	var lean := BodyState.new(); lean.muscle = 0.0
	var lw := lean.to_blend_weights()
	# female-young-minmuscle-averageweight = femaleVal(0.5)*young(1)*minmuscle(1)*avg(1)=0.5
	_assert("muscle 0%% drives the MINmuscle anchor (lean half functional)",
		float(lw.get("macrodetails/universal-female-young-minmuscle-averageweight.target", 0.0)) > 0.4,
		"minmuscle weight=%.4f" % float(lw.get("macrodetails/universal-female-young-minmuscle-averageweight.target", 0.0)))
	var buff := BodyState.new(); buff.muscle = 100.0
	var bw := buff.to_blend_weights()
	_assert("muscle 100%% drives the MAXmuscle anchor",
		float(bw.get("macrodetails/universal-female-young-maxmuscle-averageweight.target", 0.0)) > 0.4,
		"maxmuscle weight=%.4f" % float(bw.get("macrodetails/universal-female-young-maxmuscle-averageweight.target", 0.0)))

	# Light (weight 50) drives the MINweight anchors; heavy (150) the MAXweight anchors.
	var light := BodyState.new(); light.weight = 50.0
	var ltw := light.to_blend_weights()
	_assert("weight 50%% drives the MINweight anchor (light half functional)",
		float(ltw.get("macrodetails/universal-female-young-averagemuscle-minweight.target", 0.0)) > 0.4,
		"minweight weight=%.4f" % float(ltw.get("macrodetails/universal-female-young-averagemuscle-minweight.target", 0.0)))
	var heavy := BodyState.new(); heavy.weight = 150.0
	var hw := heavy.to_blend_weights()
	_assert("weight 150%% drives the MAXweight anchor",
		float(hw.get("macrodetails/universal-female-young-averagemuscle-maxweight.target", 0.0)) > 0.4,
		"maxweight weight=%.4f" % float(hw.get("macrodetails/universal-female-young-averagemuscle-maxweight.target", 0.0)))


# (6) full proportions factor-cube (replaces the retired 2-anchor approximation) ----
## The §1.3 proportions cube: gender×age×muscle×weight×{ideal,uncommon} = 108 dense targets,
## each weighted by the PRODUCT of its decoded factor anchor vals × the proportions axis val.
## These assertions FAIL under the old 2-anchor path (which imported only the single
## female-young-averagemuscle-averageweight ideal/uncommon targets and weighted proportions by
## a lone (pr-0.5)/0.5 anchor — every build-specific proportions cross-term was ZERO there).
func _test_proportions_cube() -> void:
	print("--- (6) full proportions factor-cube (not the 2-anchor approximation) ---")

	# (a) FULL IMPORT: all 108 proportions cube targets present in the library, and the
	# build-specific cross-terms the old 2-anchor path NEVER imported now exist with deltas.
	var present := 0
	var genders := ["female", "male"]
	var ages := ["child", "young", "old"]
	var muscles := ["minmuscle", "averagemuscle", "maxmuscle"]
	var weights := ["minweight", "averageweight", "maxweight"]
	var props := ["idealproportions", "uncommonproportions"]
	for g in genders:
		for a in ages:
			for m in muscles:
				for wt in weights:
					for pr in props:
						var path := "macrodetails/proportions/%s-%s-%s-%s-%s.target" % [g, a, m, wt, pr]
						if DetailLib.has_target(path):
							present += 1
	_assert("all 108 proportions cube targets imported (full cube, not 2 anchors)",
		present == 108, "present=%d/108" % present)

	# A build-specific cross-term the 2-anchor path could NOT have imported: male-old-maxmuscle-
	# maxweight-idealproportions. Present AND dense (moves most verts).
	var sample := "macrodetails/proportions/female-old-maxmuscle-maxweight-idealproportions.target"
	_assert("proportions cross-term present with DENSE deltas (build-specific, not a stand-in)",
		DetailLib.record_count(sample) > 10000,
		"record_count=%d (source moves 19058 base verts)" % DetailLib.record_count(sample))

	# (b) SAMPLE DELTA GOLDEN vs source: base vert 0 of the sample target has source delta
	# (0,.099,0) MH units == (0,0.0099,0) m. It must appear among the stored render records.
	var target_delta := Vector3(0.0, 0.099 * MH_TO_METERS, 0.0)
	var found := false
	var n := DetailLib.record_count(sample)
	for i in n:
		var rec := DetailLib.record_at(sample, i)
		if rec.is_empty():
			continue
		if (rec[1] as Vector3).distance_to(target_delta) < 1e-6:
			found = true
			break
	_assert("a stored proportions delta matches the source (base0 -> (0,0.0099,0) m)",
		found, "looked for %s among %d records" % [str(target_delta), n])

	# (c) REGRESSION — factor PRODUCT, not the 2-anchor approximation. At a fully ideal-
	# proportioned heavy muscular OLD MALE, the proportions morph must put full weight on the
	# MALE-OLD-MAXMUSCLE-MAXWEIGHT-IDEAL cross-term: product male(1)·old(1)·maxmuscle(1)·
	# maxweight(1)·ideal(1) = 1.0. Under the old 2-anchor path this target was never imported
	# and its weight was 0 — ALL proportions weight went to the female-young-average stand-in.
	var ideal_male := BodyState.new()
	ideal_male.masculinity = 100.0; ideal_male.age_years = 90.0
	ideal_male.muscle = 100.0; ideal_male.weight = 150.0
	ideal_male.proportions = 1.0
	var imw := ideal_male.to_blend_weights()
	var cross := "macrodetails/proportions/male-old-maxmuscle-maxweight-idealproportions.target"
	_assert("ideal-proportioned old/heavy/muscular male -> cross-term weight = 1.0 (PRODUCT)",
		absf(float(imw.get(cross, 0.0)) - 1.0) < 1e-4, "weight=%.4f" % float(imw.get(cross, 0.0)))
	# And the old stand-in (female-young-average ideal) must carry ZERO here — proof the weight
	# moved off the 2-anchor approximation onto the correct build-specific cross-term.
	var standin := "macrodetails/proportions/female-young-averagemuscle-averageweight-idealproportions.target"
	_assert("the old 2-anchor stand-in carries ZERO at this build (weight left the approximation)",
		float(imw.get(standin, 0.0)) < 1e-6, "stand-in weight=%.6f" % float(imw.get(standin, 0.0)))

	# (d) PARTIAL PRODUCT: proportions 0.75 -> idealVal = 0.75*2-1 = 0.5; at neutral build
	# (female-young-averagemuscle-averageweight) the female-young-average-ideal target weight
	# = female(0.5)·young(1)·avg(1)·avg(1)·ideal(0.5) = 0.25. The bidirectional uncommon side
	# is zero above 0.5.
	var half := BodyState.new()
	half.proportions = 0.75
	var hw := half.to_blend_weights()
	_assert("proportions 0.75 at neutral build -> female-young-avg-ideal = 0.25 (0.5×0.5 product)",
		absf(float(hw.get(standin, 0.0)) - 0.25) < 1e-4, "weight=%.4f" % float(hw.get(standin, 0.0)))
	_assert("proportions 0.75 weights NO uncommon target (bidirectional, ideal side only)",
		float(hw.get("macrodetails/proportions/female-young-averagemuscle-averageweight-uncommonproportions.target", 0.0)) < 1e-6,
		"uncommon weight=%.6f" % float(hw.get("macrodetails/proportions/female-young-averagemuscle-averageweight-uncommonproportions.target", 0.0)))

	# (e) NEUTRAL: proportions 0.5 (the base) weights NO proportions target at all.
	var neutral := BodyState.new()
	var nw := neutral.to_blend_weights()
	var stray := ""
	for k in nw:
		if String(k).contains("proportions"):
			stray = String(k)
	_assert("proportions 0.5 (base) weights no proportions target", stray == "",
		"stray proportions target: %s" % stray)

	# (f) DENSE MORPH on the MESH: sweeping proportions reshapes the body (a DENSE move, unlike
	# a localized detail morph) with OUTWARD normals preserved.
	var mesh: ArrayMesh = load(MESH_PATH)
	var morph_mesh := mesh.duplicate(true) as ArrayMesh
	var mi := MeshInstance3D.new()
	mi.mesh = morph_mesh
	add_child(mi)
	var base_bs := BodyState.new()
	base_bs.apply_morph_cpu(mi)
	var base_pos: PackedVector3Array = (morph_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var ideal_bs := BodyState.new()
	ideal_bs.proportions = 1.0
	ideal_bs.apply_morph_cpu(mi)
	var ideal_pos: PackedVector3Array = morph_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved := 0
	var max_disp := 0.0
	for i in base_pos.size():
		var d := (ideal_pos[i] - base_pos[i]).length()
		if d > 1e-5:
			moved += 1
			max_disp = maxf(max_disp, d)
	# DENSE: a proportions morph moves a large fraction of the body, not a small region.
	_assert("ideal proportions DENSELY reshapes the body (>5000 verts move)", moved > 5000,
		"%d verts moved, max disp=%.4f m" % [moved, max_disp])
	# Outward normals under the dense proportions morph.
	var mn: PackedVector3Array = morph_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var cen := Vector3.ZERO
	for p in ideal_pos: cen += p
	cen /= float(ideal_pos.size())
	var radial := 0.0
	for i in ideal_pos.size():
		radial += mn[i].dot(ideal_pos[i] - cen)
	_assert("proportions-morph baked normals point OUTWARD (correct lighting)",
		radial > 0.0, "Σ dot(normal,pos-centroid) = %.4f" % radial)
	mi.queue_free()


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
