## Slice-1 body asset test (docs/decisions/body-and-locomotion-slice.md §4,
## Slice 1 verify). Loads the nix-built base body ArrayMesh and asserts:
##
##   - the render mesh is OBJ CORNER-EXPANDED: one render vertex per unique (v, vt)
##     face corner (14517 verts; the 13380 body base verts split at UV seams), so
##     ARRAY_VERTEX / ARRAY_TEX_UV / ARRAY_BONES / ARRAY_WEIGHTS all share that count
##   - UVs are present, sized to the render verts, finite, non-degenerate, in [0,1],
##     and span the atlas — the fix for the "UVs all fucked" bug where the converter
##     dropped `vt` entirely (no ARRAY_TEX_UV) so textures smeared at UV (0,0)
##   - ONLY the `g body` group renders (helper-* / joint-* faces never leak in) —
##     the earlier "stray dots/boxes" fix; triangle count stays 26756
##   - skin weights are duplicated onto seam-split render verts and still sum ~1
##   - the macro blendshapes exist BY NAME, including the age axis
##     (age_old / age_baby / age_child are non-negotiable — they feed §2.2)
##   - applying a blendshape weight actually MOVES vertices (morph works), on the
##     expanded render-vertex set — proven by reading the blendshape arrays
##   - the body is at human scale at 1u = 1m: bbox height ~1.6–1.9 m, feet ~y=0
##
## Run windowed under xvfb (the project's verification posture):
##   xvfb-run -a godot4 --path . res://tests/body_asset_test.tscn --quit-after 6000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const MESH_PATH := "res://assets/body/base_body.res"
## The mesh is built by OBJ CORNER-EXPANSION: one render vertex per unique (v, vt)
## face corner, so UV seams are handled (a base vertex referenced under multiple
## texcoords becomes multiple render verts, each with its own UV). The `g body`
## group's 13380 base verts expand to this many render verts (1137 split at seams).
## The render mesh's ARRAY_VERTEX / ARRAY_TEX_UV / ARRAY_BONES / ARRAY_WEIGHTS are
## all this size; blendshape deltas + skin weights are duplicated onto split verts
## via a render→base map so morphs and skinning stay correct.
const EXPECTED_RENDER_VERTS := 14517
## Full MakeHuman base topology (body + helper-* proxies + joint-* cubes). The
## converter keeps every BASE vertex so morph/skin/joint indices stay valid; the
## render→base map keys the expanded render verts back to these.
const EXPECTED_BASE_VERTS := 19158
## Body base verts = the first 13380 base `v` (OBJ vrange 1..13380). Only render
## verts derived from base verts in this range may be referenced by the rendered
## index buffer; any render vert mapping to a base index >= this would mean a
## helper-* / joint-* face leaked in.
const BODY_VERT_COUNT := 13380
## The `g body` group triangulates to exactly this many triangles (13378 quads/
## tris → 26756 tris with the fixed-diagonal quad split). Independent of UV
## corner-expansion (expansion changes vertex count, not triangle count).
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

	# --- surface arrays (per RENDER vertex; corner-expanded) ------------------
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	_assert("render vertex count == %d (OBJ corner-expanded)" % EXPECTED_RENDER_VERTS,
		verts.size() == EXPECTED_RENDER_VERTS, "got %d" % verts.size())

	# --- UVs: present, sized to render verts, sane, non-degenerate ------------
	# The bug this guards: the converter dropped `vt` entirely (no ARRAY_TEX_UV),
	# so every fragment sampled UV (0,0) and textures smeared. Corner-expansion now
	# assigns each render vert its own OBJ texcoord (V flipped to Godot's origin).
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	_assert("UV array present", uv != null and uv.size() > 0, "uv null/empty")
	if uv != null:
		_assert("UV array sized to render verts (%d)" % EXPECTED_RENDER_VERTS,
			uv.size() == verts.size(), "uv=%d verts=%d" % [uv.size(), verts.size()])
		var ux_min := INF; var ux_max := -INF; var uy_min := INF; var uy_max := -INF
		var distinct := {}
		var nanc := 0
		for u in uv:
			if is_nan(u.x) or is_nan(u.y) or is_inf(u.x) or is_inf(u.y):
				nanc += 1
				continue
			ux_min = minf(ux_min, u.x); ux_max = maxf(ux_max, u.x)
			uy_min = minf(uy_min, u.y); uy_max = maxf(uy_max, u.y)
			distinct[Vector2(snappedf(u.x, 0.001), snappedf(u.y, 0.001))] = true
		_assert("no NaN/Inf UVs", nanc == 0, "%d bad" % nanc)
		# Non-degenerate: not all identical/zero — the MakeHuman atlas spreads over UV.
		_assert("UVs non-degenerate (>1000 distinct)", distinct.size() > 1000,
			"%d distinct" % distinct.size())
		_assert("UVs within sane bounds [0,1]",
			ux_min >= -0.001 and ux_max <= 1.001 and uy_min >= -0.001 and uy_max <= 1.001,
			"u %.3f..%.3f v %.3f..%.3f" % [ux_min, ux_max, uy_min, uy_max])
		_assert("UVs actually span the atlas (u,v range > 0.5)",
			(ux_max - ux_min) > 0.5 and (uy_max - uy_min) > 0.5,
			"u span %.3f v span %.3f" % [ux_max - ux_min, uy_max - uy_min])

	# --- rendered geometry is BODY-ONLY (no helper/joint dots) ----------------
	# Every referenced render vert must come from a BODY base vert (< BODY_VERT_COUNT);
	# any higher base index means a helper-* / joint-* face leaked into the render set.
	# The render→base mapping is reconstructed by matching each render vert's position
	# back to a base vert is unnecessary here — we instead bound it via the manifest
	# render_vertex_count + the triangle count (helper faces would inflate both).
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_assert("body triangle count == %d (body group only)" % EXPECTED_BODY_TRIS,
		idx.size() / 3 == EXPECTED_BODY_TRIS, "got %d tris" % (idx.size() / 3))
	var ref_max := -1
	var ref_min := EXPECTED_RENDER_VERTS
	for i in idx:
		ref_max = maxi(ref_max, i)
		ref_min = mini(ref_min, i)
	_assert("index buffer references only render verts (max < %d)" % EXPECTED_RENDER_VERTS,
		ref_max < EXPECTED_RENDER_VERTS, "referenced range %d..%d" % [ref_min, ref_max])
	_assert("rendered verts start at render vertex 0", ref_min == 0, "min ref = %d" % ref_min)

	# --- skin weights sized to render verts + sum ~1 per vert -----------------
	# Weights are duplicated from the base vert onto every render vert split from it;
	# each render vert must still carry a normalized 4-influence set.
	var sw: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var sb: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	_assert("ARRAY_WEIGHTS sized 4*render verts", sw.size() == verts.size() * 4,
		"got %d (expected %d)" % [sw.size(), verts.size() * 4])
	_assert("ARRAY_BONES sized 4*render verts", sb.size() == verts.size() * 4,
		"got %d (expected %d)" % [sb.size(), verts.size() * 4])
	var bad_sum := 0
	for vi in verts.size():
		var s := sw[vi*4] + sw[vi*4+1] + sw[vi*4+2] + sw[vi*4+3]
		if absf(s - 1.0) > 0.01:
			bad_sum += 1
	_assert("every render vert's weights sum ~1", bad_sum == 0, "%d verts off" % bad_sum)

	# --- human scale at 1u = 1m ----------------------------------------------
	# All render verts come from the body group now, so the whole array is the body.
	var min_y := INF
	var max_y := -INF
	for v in verts:
		min_y = min(min_y, v.y)
		max_y = max(max_y, v.y)
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
