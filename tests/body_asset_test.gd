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
	for required in ["age_old", "age_baby", "age_child", "gender_male", "muscle_max", "weight_max", "height_max",
			"proportions_ideal", "proportions_uncommon"]:
		_assert("blendshape '%s' present" % required, names.has(StringName(required)), str(names))

	# --- morph blendshapes are DELTAS (RELATIVE mode), and they move vertices --
	# surface_get_blend_shape_arrays() returns, per blendshape, the stored array.
	# In BLEND_SHAPE_MODE_RELATIVE the array is the per-vertex DELTA (morphed-base);
	# Godot composes final = base + Σ(weightᵢ · deltaᵢ). The array MUST be deltas:
	# storing absolute morphed positions here was the bug that doubled the body's
	# size and lifted it off the floor at weight 1 (the "slider changes size" bug).
	# A delta array is mostly ~0 (only the morph-affected verts move) and its max
	# magnitude is a sane local displacement (well under a body-height), NOT a full
	# absolute position (~1.6 m for a top-of-head vertex).
	var bs_arrays := mesh.surface_get_blend_shape_arrays(0)
	var age_old_idx := names.find(StringName("age_old"))
	_assert("age_old index found", age_old_idx >= 0, "idx=%d" % age_old_idx)
	if age_old_idx >= 0:
		var delta: PackedVector3Array = bs_arrays[age_old_idx][Mesh.ARRAY_VERTEX]
		_assert("morph array vertex count == base", delta.size() == verts.size(),
			"got %d" % delta.size())
		var max_disp := 0.0
		var moved_count := 0
		var mean_y := 0.0   # mean Y of the stored array — ~0 for a delta, ~1 m for absolute
		for i in verts.size():
			var d := delta[i].length()
			if d > 1e-6:
				moved_count += 1
			max_disp = max(max_disp, d)
			mean_y += delta[i].y
		mean_y /= float(verts.size())
		_assert("age_old morph moves vertices (max disp > 1mm)", max_disp > 0.001,
			"max disp = %.4f m, %d verts moved" % [max_disp, moved_count])
		# Delta sanity: a DELTA array, NOT absolute positions. The discriminator is
		# magnitude — every stored value is a small LOCAL displacement (max well under
		# a body-height), and the mean Y is near 0 (deltas centre on 0). Absolute
		# storage (the old bug that doubled the body's size and lifted it off the
		# floor at weight 1) would make max ~1.6 m+ and mean Y ~0.9 m (the body's
		# centroid height). Here both confirm deltas.
		_assert("age_old delta magnitudes are local (max < 0.5 m, not absolute ~1.6 m)",
			max_disp < 0.5, "max disp = %.4f m" % max_disp)
		_assert("age_old array centres on 0 (delta, not absolute; |mean Y| < 0.1 m)",
			absf(mean_y) < 0.1, "mean Y = %.4f m" % mean_y)
		# Blendshape NORMAL deltas must be CONSTANT across all vertices. We store a ZERO
		# normal delta (the correct-lighting fix): Godot 4 stores blendshape normals
		# OCTAHEDRAL-COMPRESSED, which can't carry a delta, and the morphed-normal
		# correction is done on the CPU at runtime (BodyState.apply_morph_cpu). Because
		# octa decode maps the stored (0,0,0) to a single constant unit direction, a
		# correct zero-delta array reads back as the SAME vector for every vertex. The
		# BROKEN prior approach (true per-vertex morphed-base deltas) read back as MANY
		# different noisy directions (octa-amplified float noise) — the blotchy-lighting
		# bug. So "all normal deltas identical" is the checkable invariant distinguishing
		# the fix (constant) from the bug (varied). (We can't assert literal zero: octa
		# readback never returns the zero vector.)
		var ndelta: PackedVector3Array = bs_arrays[age_old_idx][Mesh.ARRAY_NORMAL]
		_assert("age_old normal array present (format must match surface)",
			ndelta != null and ndelta.size() == verts.size(),
			"got %s" % (ndelta.size() if ndelta != null else -1))
		if ndelta != null and ndelta.size() > 0:
			var first := ndelta[0]
			var distinct_n := 0
			for i in ndelta.size():
				if ndelta[i].distance_to(first) > 1e-4:
					distinct_n += 1
			_assert("age_old normal deltas are CONSTANT (zero-delta fix; not per-vertex noise)",
				distinct_n == 0, "%d verts differ from the constant" % distinct_n)

	# --- a SECOND axis morphs differently (sanity: not all the same) ----------
	var weight_idx := names.find(StringName("weight_max"))
	if weight_idx >= 0:
		var wd: PackedVector3Array = bs_arrays[weight_idx][Mesh.ARRAY_VERTEX]
		var wdisp := 0.0
		for i in verts.size():
			wdisp = max(wdisp, wd[i].length())
		_assert("weight_max morph moves vertices", wdisp > 0.001, "max disp = %.4f m" % wdisp)

	# --- CPU morph bake produces CORRECT normals under morph (the creator + in-game
	# skinned path; BodyState.apply_morph_cpu). The GPU blendshapes carry a zero normal
	# delta, so correct lighting under morph depends ENTIRELY on the CPU rebake. Assert
	# that after a heavy morph the baked per-vertex normals AGREE with the triangle
	# winding (geometric normal) — a flipped/stale normal would disagree and light the
	# morphed body inside-out (the user's "backfaces" report). ----------------------
	var morph_mesh := (load(MESH_PATH) as ArrayMesh).duplicate(true)
	var mi := MeshInstance3D.new()
	mi.mesh = morph_mesh
	add_child(mi)
	var bstate := BodyState.new()
	bstate.weight = 1.0
	bstate.muscle = 0.8
	bstate.age = 0.8
	bstate.apply_morph_cpu(mi)
	var ma: Array = morph_mesh.surface_get_arrays(0)
	var mv: PackedVector3Array = ma[Mesh.ARRAY_VERTEX]
	var mn: PackedVector3Array = ma[Mesh.ARRAY_NORMAL]
	var mtris: PackedInt32Array = ma[Mesh.ARRAY_INDEX]
	var agree := 0
	var tcount := 0
	var ti := 0
	while ti < mtris.size():
		var a := mtris[ti]; var b := mtris[ti + 1]; var c := mtris[ti + 2]
		var gn := (mv[b] - mv[a]).cross(mv[c] - mv[a])
		var sn := (mn[a] + mn[b] + mn[c])
		if gn.dot(sn) > 0.0:
			agree += 1
		tcount += 1
		ti += 3
	var agree_frac := float(agree) / float(maxi(tcount, 1))
	_assert("CPU-morph baked normals agree with winding (correct lighting under morph; not inside-out)",
		agree_frac > 0.99, "agree fraction = %.5f" % agree_frac)
	# Format preserved through the rebake (skin arrays + tangents kept, so the SKINNED
	# in-game body still binds + composes with LBS).
	var mfmt: int = morph_mesh.surface_get_format(0)
	_assert("CPU-morph bake preserves skin + normal format (LBS still composes)",
		bool(mfmt & Mesh.ARRAY_FORMAT_BONES) and bool(mfmt & Mesh.ARRAY_FORMAT_WEIGHTS)
		and bool(mfmt & Mesh.ARRAY_FORMAT_NORMAL),
		"format = %d" % mfmt)
	mi.queue_free()

	# --- GLOBAL ORIENTATION: the mesh must face OUTWARD (not globally inverted) ----
	# This is an INTERPRETATION-FREE test of triangle winding, independent of any
	# rendered image and of normals. A previously-shipped check ("baked normals agree
	# with winding") is USELESS for detecting inversion: a fully INVERTED mesh is
	# self-consistent (its winding agrees with its own inward normals). What that never
	# tested is OUTWARD-ness — a globally inverted mesh still looks body-shaped head-on
	# (you see the inside of the far surface) and only reveals itself as whole-body
	# backfaces when the camera ORBITS.
	#
	# Two objective measures over the stored index/winding order:
	#   1. SIGNED VOLUME  V = (1/6) Σ v0·(v1×v2). For a closed mesh wound CCW-outward in
	#      Godot's right-handed space this is POSITIVE; a globally inverted mesh NEGATIVE.
	#   2. OUTWARD AGGREGATE  Σ dot(faceNormal_from_winding, faceCentroid − meshCentroid).
	#      POSITIVE ⇒ winding normals point away from the centroid (outward).
	# Godot's StandardMaterial3D with default cull_mode=BACK renders CCW-from-camera as
	# FRONT-facing (verified empirically on Forward+: front_face=CCW, standard right-
	# handed/OpenGL convention — NOT clockwise), so CCW-outward winding == correctly
	# front-facing from outside. Both POSITIVE == the body shows its solid exterior from
	# every orbit angle. This guard makes the inversion regression impossible to ship.
	var ov: PackedVector3Array = verts
	var oidx: PackedInt32Array = idx
	var mc := Vector3.ZERO
	for p in ov:
		mc += p
	mc /= float(ov.size())
	var signed_vol := 0.0
	var outward := 0.0
	var oti := 0
	while oti < oidx.size():
		var a := ov[oidx[oti]]; var b := ov[oidx[oti + 1]]; var c := ov[oidx[oti + 2]]
		signed_vol += a.dot(b.cross(c))
		var fn := (b - a).cross(c - a)
		outward += fn.dot((a + b + c) / 3.0 - mc)
		oti += 3
	signed_vol /= 6.0
	_assert("mesh signed volume POSITIVE (wound OUTWARD, not globally inverted)",
		signed_vol > 0.0, "V = %.9f m^3" % signed_vol)
	_assert("winding outward aggregate POSITIVE (face normals point away from centroid)",
		outward > 0.0, "sum = %.6f" % outward)

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
