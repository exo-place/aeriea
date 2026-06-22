## Region-slider test — the DATA-DRIVEN per-region body-customization slider table
## (scripts/body/region_sliders.gd) and its end-to-end morph wiring. Proves, windowed
## under xvfb:
##
##   (1) TABLE INTEGRITY: every RegionSliders spec resolves to modifier full_name(s) the
##       ModifierRegistry actually knows, with a known kind, and every bound target is
##       present with NONZERO deltas in the sparse DetailLibrary. So no slider is a dead
##       binding — each is backed by real CC0 geometry. (≥40 region axes registered.)
##   (2) EACH AXIS MORPHS THE MESH: driving every bidirectional spec to +1 (and unipolar to
##       1) moves a nonzero set of vertices vs the neutral baked body, through the SAME
##       BodyState.modifiers → registry → DetailLibrary CPU bake the creator's sliders use.
##   (3) BIPOLAR SIGNS: for a bidirectional axis, +v and −v BOTH morph the mesh AND move it
##       in OPPOSING directions (the +1 and −1 displacement fields are anti-correlated), i.e.
##       the signed slider genuinely drives the decr↔incr poles, not one side only.
##   (4) BILATERAL SYMMETRY: a bilateral stem ("l-upperarm-muscle") drives BOTH the L and R
##       modifiers (one slider → symmetric both-arms morph).
##   (5) DETERMINISM: the same BodyState (with a full region-slider configuration) bakes a
##       BYTE-IDENTICAL morphed vertex buffer across two independent bakes.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_region_sliders_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const RegionSliders := preload("res://scripts/body/region_sliders.gd")
const DetailLib := preload("res://scripts/body/detail_library.gd")
const MESH_PATH := "res://assets/body/base_body.res"

var _pass := 0
var _fail := 0

## A scratch MeshInstance3D + its neutral baked positions, reused across morph assertions.
var _mi: MeshInstance3D
var _neutral_pos: PackedVector3Array


func _ready() -> void:
	print("\n=== aeriea body REGION SLIDERS — data-driven per-region detail customization ===\n")
	_setup_mesh()
	_test_table_integrity()
	_test_each_axis_morphs()
	_test_bipolar_signs()
	_test_bilateral_symmetry()
	_test_determinism()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


## A per-instance mesh copy + the NEUTRAL baked vertex positions (the displayed neutral =
## base + default macro blend), the baseline every region morph is measured against.
func _setup_mesh() -> void:
	var mesh: ArrayMesh = load(MESH_PATH)
	var morph_mesh := mesh.duplicate(true) as ArrayMesh
	_mi = MeshInstance3D.new()
	_mi.mesh = morph_mesh
	add_child(_mi)
	var neutral := BodyState.new()
	neutral.apply_morph_cpu(_mi)
	_neutral_pos = (morph_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()


## Bake a BodyState onto the scratch mesh and return its morphed vertex positions (a copy).
func _bake(bs: BodyState) -> PackedVector3Array:
	bs.apply_morph_cpu(_mi)
	return (_mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()


## The displacement field (per-vertex morphed − neutral) for a single spec driven to `v`.
func _disp_field(spec: Dictionary, v: float) -> PackedVector3Array:
	var bs := BodyState.new()
	for fn in RegionSliders.resolve_full_names(spec["name"]):
		bs.modifiers[fn] = v
	var pos := _bake(bs)
	var out := PackedVector3Array()
	out.resize(pos.size())
	for i in pos.size():
		out[i] = pos[i] - _neutral_pos[i]
	return out


# (1) table integrity ----------------------------------------------------------
func _test_table_integrity() -> void:
	print("--- (1) table integrity: every spec resolves to a real modifier + nonzero deltas ---")
	_assert("DetailLibrary + registry load", DetailLib.ensure_loaded() and not BodyState.registry().is_empty(), "artifacts present")
	_assert("a deep region table is registered (>= 40 axes)", RegionSliders.count() >= 40,
		"%d region sliders across %d groups" % [RegionSliders.count(), RegionSliders.GROUPS.size()])

	var by: Dictionary = BodyState.registry().get("by_full_name", {})
	var bad := ""
	var checked := 0
	for spec in RegionSliders.all_specs():
		for fn in RegionSliders.resolve_full_names(spec["name"]):
			checked += 1
			var entry = by.get(fn, null)
			if entry == null:
				bad = "unknown modifier %s (%s)" % [fn, spec["display"]]
				break
			# every target of the modifier must be in the library with > 0 records.
			for t in entry["targets"]:
				if DetailLib.record_count(String(t["path"])) <= 0:
					bad = "no deltas for %s -> %s" % [fn, String(t["path"])]
					break
			if bad != "":
				break
		if bad != "":
			break
	_assert("every resolved modifier exists with nonzero library deltas", bad == "",
		"checked %d bindings; %s" % [checked, bad if bad != "" else "all good"])


# (2) each axis morphs the mesh ------------------------------------------------
func _test_each_axis_morphs() -> void:
	print("--- (2) every region axis morphs the mesh (vs neutral) ---")
	var weak := []
	var sample_evidence := ""
	for spec in RegionSliders.all_specs():
		var d := _disp_field(spec, 1.0)   # +1 drives the incr pole (or unipolar full)
		var max_disp := 0.0
		var moved := 0
		for v in d:
			var l := v.length()
			if l > 1e-5:
				moved += 1
				max_disp = maxf(max_disp, l)
		if max_disp <= 1e-4:
			weak.append(spec["display"])
		elif sample_evidence == "":
			sample_evidence = "%s: max %.4f m, %d verts moved" % [spec["display"], max_disp, moved]
	_assert("every region axis moves the mesh at +1 (no dead slider)", weak.is_empty(),
		"weak/no-op axes: %s" % (str(weak) if not weak.is_empty() else "none; e.g. " + sample_evidence))


# (3) bipolar signs ------------------------------------------------------------
func _test_bipolar_signs() -> void:
	print("--- (3) bidirectional axes: +v and −v BOTH morph, in OPPOSING directions ---")
	var by: Dictionary = BodyState.registry().get("by_full_name", {})
	var failures := []
	var example := ""
	for spec in RegionSliders.all_specs():
		var fn := RegionSliders.resolve_full_names(spec["name"])[0]
		var entry = by.get(fn, null)
		if entry == null or String(entry["kind"]) != RegionSliders.KIND_BIDIRECTIONAL:
			continue
		var dp := _disp_field(spec, 1.0)
		var dn := _disp_field(spec, -1.0)
		var moved_p := 0
		var moved_n := 0
		var dot := 0.0
		for i in dp.size():
			if dp[i].length() > 1e-5: moved_p += 1
			if dn[i].length() > 1e-5: moved_n += 1
			dot += dp[i].dot(dn[i])
		# Both poles must move geometry, and the two displacement fields must be ANTI-correlated
		# (Σ dp·dn < 0): the +pole pushes where the −pole pulls. This is the signed-axis proof.
		if moved_p == 0 or moved_n == 0 or dot >= 0.0:
			failures.append("%s (moved+%d -%d dot=%.6f)" % [spec["display"], moved_p, moved_n, dot])
		elif example == "":
			example = "%s: +pole %d verts, −pole %d verts, Σdp·dn=%.6f (<0 = opposing)" % [spec["display"], moved_p, moved_n, dot]
	_assert("every bidirectional axis drives BOTH poles in opposing directions", failures.is_empty(),
		"failures: %s" % (str(failures) if not failures.is_empty() else "none; e.g. " + example))


# (4) bilateral symmetry -------------------------------------------------------
func _test_bilateral_symmetry() -> void:
	print("--- (4) a bilateral stem drives BOTH L and R modifiers ---")
	var fns := RegionSliders.resolve_full_names("l-upperarm-muscle")
	_assert("bilateral stem resolves to two full_names (L + R)", fns.size() == 2,
		"resolved: %s" % str(fns))
	var has_l := false
	var has_r := false
	for fn in fns:
		if fn.contains("l-upperarm-muscle"): has_l = true
		if fn.contains("r-upperarm-muscle"): has_r = true
	_assert("bilateral stem covers the LEFT and RIGHT upper-arm muscle modifiers", has_l and has_r,
		"L=%s R=%s" % [has_l, has_r])
	var by: Dictionary = BodyState.registry().get("by_full_name", {})
	_assert("both bilateral modifiers exist in the registry", by.has(fns[0]) and by.has(fns[1]),
		"%s / %s" % [fns[0], fns[1]])


# (5) determinism --------------------------------------------------------------
func _test_determinism() -> void:
	print("--- (5) same BodyState (full region config) -> byte-identical morphed mesh ---")
	# A representative full configuration across many regions, signs mixed.
	var cfg := {
		"breast/breast-volume-vert-down|up": 0.7,
		"buttocks/buttocks-volume-decr|incr": 0.5,
		"stomach/stomach-pregnant-decr|incr": -0.4,
		"measure/measure-waist-circ-decr|incr": -0.6,
		"measure/measure-shoulder-dist-decr|incr": 0.8,
		"armslegs/l-upperarm-muscle-decr|incr": 0.5,
		"armslegs/r-upperarm-muscle-decr|incr": 0.5,
		"head/head-oval": 0.6,
		"neck/neck-double-decr|incr": -0.3,
	}
	var a := BodyState.new(); a.modifiers = cfg.duplicate()
	var b := BodyState.new(); b.modifiers = cfg.duplicate()
	var pa := _bake(a)
	var pb := _bake(b)
	var identical := pa.size() == pb.size()
	if identical:
		for i in pa.size():
			if pa[i] != pb[i]:
				identical = false
				break
	_assert("two bakes of the same region config are byte-identical (deterministic)", identical,
		"%d verts compared" % pa.size())

	# And it actually moved a lot of geometry (this is a real, dense configuration).
	var moved := 0
	for i in pa.size():
		if (pa[i] - _neutral_pos[i]).length() > 1e-5:
			moved += 1
	_assert("the full region config densely reshapes the body (>2000 verts move)", moved > 2000,
		"%d verts moved vs neutral" % moved)


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
