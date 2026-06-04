## Slice-1 body asset test (docs/decisions/body-and-locomotion-slice.md §4,
## Slice 1 verify). Loads the nix-built base body ArrayMesh and asserts:
##
##   - the mesh loads and keeps all 19158 vertices of the MakeHuman base topology
##     (the full vertex array is retained so blendshape + skin-weight indices, and
##     the .mhskel joint-cube vertex indices the rig reads, stay valid)
##   - ONLY the `g body` group is rendered: the index buffer references exactly the
##     body vertex range (0..13379) and never the helper-* / joint-* vertices
##     (>= 13380) — the fix for the "stray dots/boxes" bug where MakeHuman's helper
##     proxies + joint cubes were being rendered along with the body
##   - the macro blendshapes exist BY NAME, including the age axis
##     (age_old / age_baby / age_child are non-negotiable — they feed §2.2)
##   - applying a blendshape weight actually MOVES vertices (morph works) — proven
##     by reconstructing the morphed surface via a SurfaceTool / MeshDataTool-free
##     read of the blendshape arrays and measuring a nonzero displacement
##   - the body is at human scale at 1u = 1m: bbox height ~1.6–1.9 m, feet ~y=0
##
## Run windowed under xvfb (the project's verification posture):
##   xvfb-run -a godot4 --path . res://tests/body_asset_test.tscn --quit-after 6000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const MESH_PATH := "res://assets/body/base_body.res"
## Full MakeHuman base topology (body + helper-* proxies + joint-* cubes). The
## converter keeps every vertex so morph/skin/joint indices stay valid.
const EXPECTED_VERTS := 19158
## The rendered `g body` group is the first 13380 vertices (OBJ vrange 1..13380 →
## 0-based 0..13379). Everything at index >= this is helper/joint geometry that
## must NOT be referenced by any rendered triangle.
const BODY_VERT_COUNT := 13380
## The `g body` group triangulates to exactly this many triangles (13378 quads/
## tris → 26756 tris with the fixed-diagonal quad split). Asserting the exact
## count guards against helper faces leaking back into the render set.
const EXPECTED_BODY_TRIS := 26756

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea body SLICE 1 asset test ===\n")
	var mesh: ArrayMesh = load(MESH_PATH)
	_assert("mesh loads", mesh != null, MESH_PATH)
	if mesh == null:
		get_tree().quit(1)
		return

	# --- surface arrays -------------------------------------------------------
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	_assert("vertex count == %d (full base, indices preserved)" % EXPECTED_VERTS,
		verts.size() == EXPECTED_VERTS, "got %d" % verts.size())

	# --- rendered geometry is BODY-ONLY (no helper/joint dots) ----------------
	# The index buffer must reference ONLY the body vertex range (0..13379); any
	# referenced vertex >= BODY_VERT_COUNT means a helper-* / joint-* face leaked
	# into the rendered mesh (the "stray dots/boxes" bug).
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_assert("body triangle count == %d (body group only)" % EXPECTED_BODY_TRIS,
		idx.size() / 3 == EXPECTED_BODY_TRIS, "got %d tris" % (idx.size() / 3))
	var ref_max := -1
	var ref_min := EXPECTED_VERTS
	for i in idx:
		ref_max = maxi(ref_max, i)
		ref_min = mini(ref_min, i)
	_assert("no helper/joint faces rendered (max referenced vert < %d)" % BODY_VERT_COUNT,
		ref_max < BODY_VERT_COUNT, "referenced range %d..%d" % [ref_min, ref_max])
	_assert("rendered verts start at body vertex 0", ref_min == 0, "min ref = %d" % ref_min)

	# --- human scale at 1u = 1m ----------------------------------------------
	# Measure the BODY bbox only (vertices 0..BODY_VERT_COUNT-1); helper-* verts
	# (hair above the head, skirt below the feet) live in the array but are not the
	# body and would skew the silhouette.
	var min_y := INF
	var max_y := -INF
	for i in BODY_VERT_COUNT:
		min_y = min(min_y, verts[i].y)
		max_y = max(max_y, verts[i].y)
	var height := max_y - min_y
	_assert("bbox height ~human (1.6–1.9 m)", height >= 1.6 and height <= 1.9,
		"height = %.4f m" % height)
	_assert("feet at ~y=0", absf(min_y) < 0.02, "min_y = %.4f m" % min_y)

	# --- blendshapes exist by name, incl. age --------------------------------
	var names := []
	for i in mesh.get_blend_shape_count():
		names.append(mesh.get_blend_shape_name(i))
	print("  blendshapes: %s" % str(names))
	for required in ["age_old", "age_baby", "age_child", "gender_male", "muscle_max", "weight_max", "height_max"]:
		_assert("blendshape '%s' present" % required, names.has(StringName(required)), str(names))

	# --- morph actually moves vertices ---------------------------------------
	# surface_get_blend_shape_arrays() returns, per blendshape, the FULL morphed
	# vertex set (RELATIVE mode stores absolute morphed positions in the array).
	# Compare the age_old morph target verts against the base verts → must differ.
	var bs_arrays := mesh.surface_get_blend_shape_arrays(0)
	var age_old_idx := names.find(StringName("age_old"))
	_assert("age_old index found", age_old_idx >= 0, "idx=%d" % age_old_idx)
	if age_old_idx >= 0:
		var morphed: PackedVector3Array = bs_arrays[age_old_idx][Mesh.ARRAY_VERTEX]
		_assert("morph array vertex count == base", morphed.size() == verts.size(),
			"got %d" % morphed.size())
		var max_disp := 0.0
		var moved_count := 0
		for i in verts.size():
			var d := (morphed[i] - verts[i]).length()
			if d > 1e-6:
				moved_count += 1
			max_disp = max(max_disp, d)
		_assert("age_old morph moves vertices (max disp > 1mm)", max_disp > 0.001,
			"max disp = %.4f m, %d verts moved" % [max_disp, moved_count])

	# --- a SECOND axis morphs differently (sanity: not all the same) ----------
	var weight_idx := names.find(StringName("weight_max"))
	if weight_idx >= 0:
		var wm: PackedVector3Array = bs_arrays[weight_idx][Mesh.ARRAY_VERTEX]
		var wdisp := 0.0
		for i in verts.size():
			wdisp = max(wdisp, (wm[i] - verts[i]).length())
		_assert("weight_max morph moves vertices", wdisp > 0.001, "max disp = %.4f m" % wdisp)

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
