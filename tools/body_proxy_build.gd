## Body PROXY converter — MakeHuman CC0 face/organ proxy geometry → rigged,
## morph-following Godot mesh pieces.
##
## WHY THIS EXISTS: tools/body_converter.gd renders ONLY base.obj's `g body`
## group. MakeHuman keeps the EYEBALLS, TEETH, TONGUE and GENITALS as SEPARATE
## geometry — the eyes as a dedicated low-poly proxy (data/eyes/low-poly/), the
## teeth/tongue/genitals as `helper-*` groups inside base.obj. Because the body
## group omits all of them, the rendered face had hollow eye sockets and an empty
## open mouth (the user's repeated "missing eyeballs / teeth / tongue" report).
##
## This tool imports that proxy/helper geometry as additional RIGGED, MORPH-
## FOLLOWING mesh pieces, using the SAME deterministic machinery as the body:
##   * geometry/UVs: OBJ corner-expansion (one render vert per unique (v,vt)).
##   * RIGGING: each proxy render vert is BOUND to base-mesh vertices (the eye
##     proxy via its .mhclo fitting, the helper groups trivially — they ARE base
##     verts). The proxy vert inherits the skin weights of the base vert(s) it is
##     bound to (top-4, renormalized) → it follows the Skeleton3D exactly as the
##     surrounding flesh does.
##   * MORPH-FOLLOWING: a per-proxy SPARSE DELTA LIBRARY (same ADLB binary format
##     as tools/detail_library_build.gd) carries, for every macro/detail target,
##     the per-proxy-render-vertex displacement — derived by pushing each base
##     vertex's `.target` delta THROUGH the proxy binding. So when the body
##     morphs (age / masculinity / proportions / detail) the eyes/teeth/tongue/
##     genitals move with it and stay seated.
##   * NORMALS: recomputed from the triangulated proxy surface with the SAME
##     OUTWARD convention as the body ((c-a)×(b-a) over reversed winding), so the
##     proxies light correctly (not inside-out).
##
## OUTPUTS (built by `nix build .#body-proxies`; committed, byte-deterministic):
##   res://assets/body/base_body_proxies.res         — ArrayMesh, ONE SURFACE per
##                                                      proxy piece (eyes, eyebrows,
##                                                      eyelashes, teeth, tongue,
##                                                      genitals), each with
##                                                      ARRAY_BONES/ARRAY_WEIGHTS.
##   res://assets/body/base_body_proxies.index.json  — surface i -> {name, material,
##                                                      vert_offset, vert_count} +
##                                                      provenance. vert_offset is the
##                                                      start of that surface's verts in
##                                                      the GLOBAL proxy-vertex numbering
##                                                      used by the delta library.
##   res://assets/body/base_body_proxies_detail.bin       — ADLB v1 sparse deltas keyed
##                                                      by GLOBAL proxy render-vertex idx.
##   res://assets/body/base_body_proxies_detail.index.json — target path -> {offset,
##                                                      count, kind}.
##
## scripts/body/body_rig.gd attaches each surface as a child skinned MeshInstance3D
## sharing the body's Skeleton3D + Skin, and re-bakes morphed positions + normals on
## apply_body_state() via DetailLibrary (pointed at the proxy artifact).
##
## DETERMINISM: same pinned MakeHuman source → identical bytes (verts in OBJ order,
## fixed quad diagonal + reversed winding, deltas in ascending global render index).
extends Node

## MakeHuman → meters (same as tools/body_converter.gd; 1u = 1m).
const MH_TO_METERS := 0.1
const MAX_INFLUENCES := 4

const OUT_DIR := "res://assets/body"
const OUT_MESH := "res://assets/body/base_body_proxies.res"
const OUT_INDEX := "res://assets/body/base_body_proxies.index.json"
const OUT_BIN := "res://assets/body/base_body_proxies_detail.bin"
const OUT_DETAIL_INDEX := "res://assets/body/base_body_proxies_detail.index.json"

const ModifierRegistry := preload("res://scripts/body/modifier_registry.gd")

## The proxy pieces, in deterministic surface order. Each is one of:
##   {name, kind=="helper", group}                 — an OBJ group inside base.obj
##                                                    (its faces, its own UVs; the
##                                                    verts ARE base verts → exact bind)
##   {name, kind=="helper_multi", groups:[...]}     — several base.obj groups welded into
##                                                    one surface (e.g. both teeth arches)
##   {name, kind=="proxy", obj, mhclo, material}    — a standalone proxy obj + .mhclo fit
##                                                    (the eyes), bound barycentrically.
## `material` is a hint consumed by BodyRig to pick a sensible material.
const PIECES := [
	{"name": "eyes", "kind": "proxy",
		"obj": "eyes/low-poly/low-poly.obj", "mhclo": "eyes/low-poly/low-poly.mhclo",
		"material": "eye"},
	# eyebrows + eyelashes are PROJECT-AUTHORED (CC0-clean, our own geometry). The pinned
	# MakeHuman v1.3.0 core ships NO CC0 eyebrow mesh (only a `clear.thumb` + brow morph
	# targets; the meshes are community-DB, not uniform CC0); the base.obj `helper-*-eyelashes`
	# groups ARE CC0 but are sparse cards meant for an alpha lash texture and render as opaque
	# pale sheets without it. So we author both as thin dark strips along the brow/lash line,
	# seated + rigged + morph-following by binding to the symmetric eye-helper base verts.
	{"name": "eyebrows", "kind": "authored_face_hair", "material": "brows"},
	{"name": "eyelashes", "kind": "authored_face_hair", "material": "lashes"},
	{"name": "teeth", "kind": "helper_multi",
		"groups": ["helper-upper-teeth", "helper-lower-teeth"], "material": "teeth"},
	{"name": "tongue", "kind": "helper", "group": "helper-tongue", "material": "tongue",
		# SEATING (polish): the MakeHuman base tongue rest shape sits low/recessed in
		# the cavity — its dorsum reads below the teeth and its tip falls behind the
		# incisors, so at a front open-mouth angle it looks swallowed. We lift the
		# dorsum + ease the tip forward by a small RAW-MH-space nudge applied AFTER the
		# binding (so skin weights + the morph delta-library are untouched: the tongue
		# stays rigged + fully morph-following — it is just re-seated higher/forward in
		# its rest pose). Tuned against the open-mouth render. MH units (×0.1 = metres).
		"seat_up": 0.16, "seat_fwd": 0.18},
	{"name": "genitals", "kind": "helper", "group": "helper-genital", "material": "genitals"},
	# HAIR — the CC0 `helper-hair` group is a real scalp cap that drapes to mid-back. We
	# render it as a hair surface and RE-SKIN it (after the normal helper bind) onto the
	# injected hair-bone chain (hair01/02/03 + head) by vertical band, so the hair spring
	# physics (scripts/body/spring_bone.gd, resolved by the "hair" name fragment) sways it.
	# Binding (for morph-following) is the normal helper-vert bind; only the FINAL skin
	# weights are overridden to the hair bones. material "hair" -> matte dark keratin.
	{"name": "hair", "kind": "helper", "group": "helper-hair", "material": "hair",
		"hair_chain": true},
]


func _ready() -> void:
	get_tree().quit(_run())


func _src_data_root() -> String:
	var env := OS.get_environment("MAKEHUMAN_SRC")
	if env != "":
		return env.path_join("makehuman").path_join("data") if not env.ends_with("data") else env
	return ProjectSettings.globalize_path("res://vendor/makehuman-cc0/data")


func _run() -> int:
	var data_root := _src_data_root()
	print("body_proxy_build: data root = %s" % data_root)

	# --- parse base.obj: ALL `v`, all `vt`, all groups' faces (we need helper groups
	# AND the base-vert array the eye proxy binds into). -------------------------------
	var obj_path := data_root.path_join("3dobjs/base.obj")
	var base := _parse_base_obj(obj_path)
	if base.is_empty():
		push_error("body_proxy_build: failed to parse %s" % obj_path)
		return 1
	var base_verts: PackedVector3Array = base["verts"]   # raw MH-space, all `v`
	var base_uvs: PackedVector2Array = base["uvs"]       # all `vt`
	var group_faces: Dictionary = base["group_faces"]    # group name -> Array of faces (each: Array of [vi,ti])
	var body_vert_count: int = base["body_vert_count"]

	# feet-to-origin lift: IDENTICAL frame to the body (lowest BODY vert -> y=0).
	var min_y := INF
	for i in body_vert_count:
		min_y = minf(min_y, base_verts[i].y)
	print("body_proxy_build: %d base verts (%d body), min_y=%.4f" % [base_verts.size(), body_vert_count, min_y])

	# transform a raw MH base vert -> scaled+lifted render space.
	var to_render := func(v: Vector3) -> Vector3:
		return Vector3(v.x * MH_TO_METERS, (v.y - min_y) * MH_TO_METERS, v.z * MH_TO_METERS)

	# --- rig: parse skeleton (for bone order) + skin weights (per base vert) -----------
	var skel := _parse_skeleton_order(data_root.path_join("rigs/default.mhskel"))
	if skel.is_empty():
		push_error("body_proxy_build: failed to parse skeleton order")
		return 1
	var name_to_index: Dictionary = skel["name_to_index"]
	var skin := _parse_weights(data_root.path_join("rigs/default_weights.mhw"), name_to_index, base_verts.size())
	if skin.is_empty():
		push_error("body_proxy_build: failed to parse weights")
		return 1
	var base_bones: PackedInt32Array = skin["bones"]
	var base_weights: PackedFloat32Array = skin["weights"]

	# --- build each piece's surface + its binding (proxy render vert -> base bary) -----
	# Global proxy-vertex numbering spans ALL pieces (for the delta library keys).
	var mesh := ArrayMesh.new()
	var index_entries := []
	var global_offset := 0
	# binding[global_ri] = Array of [base_idx, weight] (the barycentric base-vert binding).
	var binding := []

	for piece in PIECES:
		var built: Dictionary
		if piece["kind"] == "proxy":
			built = _build_proxy_piece(piece, data_root, base_verts, group_faces)
		elif piece["kind"] == "authored_face_hair":
			built = _build_authored_face_hair(String(piece["name"]), base_verts)
		else:
			var groups: Array = piece.get("groups", [piece.get("group", "")])
			built = _build_helper_piece(groups, base_verts, base_uvs, group_faces)
			# SEATING nudge (tongue): a tapered RAW-MH-space re-seat applied to the bound
			# rest positions only — binding (skin weights + morph deltas) is unchanged.
			if not built.is_empty() and (piece.has("seat_up") or piece.has("seat_fwd")):
				_apply_seating(built, float(piece.get("seat_up", 0.0)), float(piece.get("seat_fwd", 0.0)))
		if built.is_empty():
			push_error("body_proxy_build: piece '%s' produced no geometry" % piece["name"])
			return 1
		var rpos_raw: PackedVector3Array = built["render_pos_raw"]   # raw MH-space proxy positions
		var ruv: PackedVector2Array = built["render_uv"]
		var rtris: PackedInt32Array = built["tris"]
		var rbind: Array = built["binding"]                          # per render vert: [[base_idx,w],...]
		var rn := rpos_raw.size()

		# render-space positions
		var rpos := PackedVector3Array(); rpos.resize(rn)
		for i in rn:
			rpos[i] = to_render.call(rpos_raw[i])
		# normals (outward, same convention as the body)
		var normals := _compute_normals(rpos, rtris)
		# skin weights: blend the bound base verts' top-4 influences by binding weight,
		# then re-collapse to top-4 + renormalize (deterministic).
		var bones_arr := PackedInt32Array(); bones_arr.resize(rn * MAX_INFLUENCES)
		var weights_arr := PackedFloat32Array(); weights_arr.resize(rn * MAX_INFLUENCES)
		for i in rn:
			var acc := {}   # bone index -> weight
			for bw in rbind[i]:
				var b: int = bw[0]
				var bweight: float = bw[1]
				var bo := b * MAX_INFLUENCES
				for k in MAX_INFLUENCES:
					var bone := base_bones[bo + k]
					var w := base_weights[bo + k] * bweight
					if w <= 0.0:
						continue
					acc[bone] = float(acc.get(bone, 0.0)) + w
			_collapse_top4(acc, bones_arr, weights_arr, i * MAX_INFLUENCES)

		# HAIR: override the bound skin weights with the hair-bone chain so the hair
		# spring physics moves it. Each hair vert is assigned to head + hair01/02/03 by its
		# vertical position within the hair piece's bbox (top -> head/hair01, tips ->
		# hair03), blended across two adjacent chain bones for a smooth falloff. Deterministic.
		if piece.get("hair_chain", false):
			_skin_hair_chain(rpos, bones_arr, weights_arr, name_to_index)

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = rpos
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = ruv
		arrays[Mesh.ARRAY_INDEX] = rtris
		arrays[Mesh.ARRAY_BONES] = bones_arr
		arrays[Mesh.ARRAY_WEIGHTS] = weights_arr
		var surf_idx := mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(surf_idx, String(piece["name"]))

		index_entries.append({
			"name": String(piece["name"]),
			"material": String(piece.get("material", "default")),
			"vert_offset": global_offset,
			"vert_count": rn,
			"triangle_count": rtris.size() / 3,
		})
		# accumulate global binding
		for i in rn:
			binding.append(rbind[i])
		global_offset += rn
		print("body_proxy_build: piece '%s' surface %d: %d verts, %d tris" % [piece["name"], surf_idx, rn, rtris.size() / 3])

	# --- write the mesh + index --------------------------------------------------------
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err := ResourceSaver.save(mesh, OUT_MESH, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("body_proxy_build: failed to save mesh (err %d)" % err)
		return 1
	print("body_proxy_build: wrote %s" % OUT_MESH)
	_write_index(index_entries, global_offset)

	# The eye material is PROCEDURAL (assets/body/eye.gdshader — iris/pupil/sclera computed
	# analytically from the proxy UVs), so no eye texture is emitted or vendored: the
	# proxy artifacts have no external texture dependency.

	# --- build the per-proxy SPARSE DELTA LIBRARY (morph-following) --------------------
	if not _build_delta_library(data_root, binding, global_offset):
		push_error("body_proxy_build: failed to build delta library")
		return 1

	print("body_proxy_build: DONE")
	return 0


# ---------------------------------------------------------------------------
# Piece builders
# ---------------------------------------------------------------------------

## Build a HELPER-group piece (teeth/tongue/genitals): its faces live in base.obj,
## referencing base verts directly. Corner-expand on (v,vt); each render vert binds
## EXACTLY to its single base vertex (weight 1) — an exact, trivially-correct fit.
func _build_helper_piece(groups: Array, base_verts: PackedVector3Array, base_uvs: PackedVector2Array, group_faces: Dictionary) -> Dictionary:
	var render_pos := PackedVector3Array()
	var render_uv := PackedVector2Array()
	var tris := PackedInt32Array()
	var binding := []
	var corner_to_render := {}
	var corner := func(c: Array) -> int:
		var vi: int = c[0]
		var ti: int = c[1]
		var key := vi * 2000000 + (ti + 1)
		var existing = corner_to_render.get(key, -1)
		if existing != -1:
			return existing
		var ri := render_pos.size()
		render_pos.append(base_verts[vi])
		var uv := Vector2(0.0, 0.0)
		if ti >= 0 and ti < base_uvs.size():
			var raw := base_uvs[ti]
			uv = Vector2(raw.x, 1.0 - raw.y)   # OBJ bottom-left -> Godot top-left
		render_uv.append(uv)
		binding.append([[vi, 1.0]])
		corner_to_render[key] = ri
		return ri
	for g in groups:
		var faces = group_faces.get(g, null)
		if faces == null:
			push_error("body_proxy_build: missing group %s" % g)
			return {}
		for face in faces:
			_emit_face_tris(face, corner, tris)
	if render_pos.is_empty() or tris.is_empty():
		return {}
	return {"render_pos_raw": render_pos, "render_uv": render_uv, "tris": tris, "binding": binding}


## SEATING re-pose (tongue): lift + ease-forward the bound rest positions of a helper
## piece, TAPERED so the front/dorsum moves most and the back/root stays anchored (no
## throat clipping). Pure raw-MH-space edit of render_pos_raw; the binding (skin weights,
## morph delta library) is derived from the UNCHANGED base verts, so the piece stays fully
## rigged + morph-following — it is only re-seated higher/forward in its rest pose. The
## taper weight is the normalised front-ness (z) × upper-ness (y) of each vert within the
## piece's own bbox, so the tip+dorsum rise into the cavity and the root holds.
func _apply_seating(built: Dictionary, up_mh: float, fwd_mh: float) -> void:
	var pos: PackedVector3Array = built["render_pos_raw"]
	if pos.is_empty():
		return
	var ab := AABB(pos[0], Vector3.ZERO)
	for p in pos:
		ab = ab.expand(p)
	var z0 := ab.position.z
	var zr := maxf(ab.size.z, 1e-6)
	var y0 := ab.position.y
	var yr := maxf(ab.size.y, 1e-6)
	for i in pos.size():
		var fwdness := clampf((pos[i].z - z0) / zr, 0.0, 1.0)        # 0 back -> 1 front/tip
		var upness := clampf((pos[i].y - y0) / yr, 0.0, 1.0)         # 0 floor -> 1 dorsum
		# lift the dorsum (blend of fwd+up so the whole upper surface rises), ease the tip fwd.
		var lift := up_mh * (0.45 + 0.55 * maxf(fwdness, upness))
		var push := fwd_mh * (fwdness * fwdness)                      # strongest at the very tip
		pos[i] = pos[i] + Vector3(0.0, lift, push)
	built["render_pos_raw"] = pos


## Build a PROJECT-AUTHORED face-hair piece (eyebrows OR eyelashes). These are NOT from
## MakeHuman: the pinned v1.3.0 core ships NO CC0 eyebrow mesh (only a `clear.thumb` + brow
## morph targets — the meshes are community-DB, not uniform CC0), and while the base.obj
## `helper-*-eyelashes` groups ARE CC0 they are sparse alpha-texture cards that render as
## opaque pale sheets without their lash texture. So we author both ourselves (our own work,
## no third-party licence) — a thin arched dark ribbon along the brow / upper-lash line —
## seated on the symmetric LEFT/RIGHT eye-helper base verts (14598..14742) and bound, per
## authored vertex, to the NEAREST eye-helper base vert (single-index, weight 1). Binding to
## the eye-helper set (rather than the whole mesh) keeps L/R anchoring SYMMETRIC and stable,
## and hands each strip the same skin weights + macro/detail morph deltas as the eye region,
## so the strips are rigged + morph-following through the SAME pipeline as the helper pieces,
## deterministically (nearest-vert is a pure function of the pinned base mesh).
func _build_authored_face_hair(piece_name: String, base_verts: PackedVector3Array) -> Dictionary:
	# Split the eye-helper verts into LEFT (x<0) and RIGHT (x>=0) and bbox each, so each
	# brow/lash is built + anchored against ITS OWN eye — symmetric by construction.
	var lo := PackedInt32Array(); var ro := PackedInt32Array()
	for i in range(14598, 14743):
		if base_verts[i].x < 0.0:
			lo.append(i)
		else:
			ro.append(i)
	if lo.is_empty() or ro.is_empty():
		return {}

	var render_pos := PackedVector3Array()
	var render_uv := PackedVector2Array()
	var tris := PackedInt32Array()
	var binding := []
	var segs := 7
	for eye_idx in [lo, ro]:
		var eb := AABB(base_verts[eye_idx[0]], Vector3.ZERO)
		for i in eye_idx:
			eb = eb.expand(base_verts[i])
		# nearest among THIS eye's helper verts -> rigid, symmetric, region-correct binding.
		var nearest := func(p: Vector3) -> int:
			var best: int = eye_idx[0]
			var bd := INF
			for vi in eye_idx:
				var d := base_verts[vi].distance_squared_to(p)
				if d < bd:
					bd = d; best = vi
			return best
		var add_vert := func(p: Vector3, uv: Vector2) -> int:
			var ri := render_pos.size()
			render_pos.append(p)
			render_uv.append(uv)
			binding.append([[nearest.call(p), 1.0]])
			return ri
		# Geometry params in this eye's local bbox frame. The brow/lash spans the FULL eye
		# width (x0..x1), centred on the eye, so it reads at human proportions (~3cm wide),
		# arched, sitting a touch proud of the skin so it isn't z-buried. x sweeps from the
		# nasal corner (x0) to the temporal corner (x1) for whichever eye this is.
		var x0 := eb.position.x + eb.size.x * 0.04
		var x1 := eb.position.x + eb.size.x * 0.96
		var front := eb.position.z + eb.size.z
		var row_bottom := PackedInt32Array()
		var row_top := PackedInt32Array()
		for s in range(segs + 1):
			var t: float = float(s) / float(segs)          # 0 -> 1 across the eye width
			var x: float = lerpf(x0, x1, t)
			# proud-of-skin: the strip bows FORWARD at mid-span (parabola) so it floats just
			# off the curved brow/lid instead of clipping into it.
			var bow: float = (1.0 - pow(2.0 * t - 1.0, 2.0))
			if piece_name == "eyebrows":
				# arched ribbon just ABOVE the eye opening. It must float PROUD of the convex
				# forehead at every point (else the middle z-buries behind the skin and the
				# brow breaks into disconnected wedges) — so z follows the brow-ridge bulge:
				# most-forward at mid-span (bow), easing back toward the temple + nose. A gentle
				# arch; bottom edge near the upper-lid crease.
				var brow_y: float = eb.position.y + eb.size.y * 0.96 + eb.size.y * 0.12 * bow
				var thick: float = eb.size.y * 0.24
				var z: float = front + eb.size.z * (0.22 + 0.05 * bow)
				row_bottom.append(add_vert.call(Vector3(x, brow_y, z), Vector2(t, 1.0)))
				row_top.append(add_vert.call(Vector3(x, brow_y + thick, z), Vector2(t, 0.0)))
			else:
				# eyelashes: a slim dark rim on the UPPER lid edge, flared forward + proud of
				# the lid so it isn't z-buried (same convex-surface reasoning as the brow).
				var lash_y: float = eb.position.y + eb.size.y * (0.84 + 0.06 * bow)
				var thick2: float = eb.size.y * 0.11
				var z2: float = front + eb.size.z * (0.20 + 0.10 * bow)
				row_bottom.append(add_vert.call(Vector3(x, lash_y, z2), Vector2(t, 1.0)))
				row_top.append(add_vert.call(Vector3(x, lash_y + thick2, z2), Vector2(t, 0.0)))
		# Emit each quad as TWO triangles, BOTH windings, so the flat strip shows from any
		# angle (these are thin authored cards, not closed volumes — 2-sided is correct).
		for s in segs:
			var a0 := row_bottom[s]; var a1 := row_bottom[s + 1]
			var b0 := row_top[s]; var b1 := row_top[s + 1]
			tris.append(a0); tris.append(b1); tris.append(a1)
			tris.append(a0); tris.append(b0); tris.append(b1)
			tris.append(a0); tris.append(a1); tris.append(b1)
			tris.append(a0); tris.append(b1); tris.append(b0)
	if render_pos.is_empty() or tris.is_empty():
		return {}
	return {"render_pos_raw": render_pos, "render_uv": render_uv, "tris": tris, "binding": binding}


## Build a standalone PROXY piece (the eyes): parse its own .obj (positions+UVs+faces)
## and its .mhclo fitting; each proxy vertex is bound to the base mesh via the .mhclo
## `verts` section. We then corner-expand the proxy obj's faces on (v,vt).
##
## .mhclo `verts` formats (both handled):
##   - SINGLE index   "B"                                  -> proxy vert == base vert B.
##   - BARYCENTRIC    "B0 B1 B2 w0 w1 w2 dx dy dz"         -> proxy_raw =
##         w0·V[B0]+w1·V[B1]+w2·V[B2] + (dx,dy,dz) scaled by the .mhclo scale refs.
##     (The low-poly eyes use the single-index form; we support both for robustness.)
## The binding we KEEP for skinning + morph-following is the barycentric base-vert
## set with weights {w0,w1,w2} (single-index → {B:1}); the constant offset rides
## along on every morph identically (it is a rigid attachment in the local frame).
func _build_proxy_piece(piece: Dictionary, data_root: String, base_verts: PackedVector3Array, _group_faces: Dictionary) -> Dictionary:
	var obj_path := data_root.path_join(piece["obj"])
	var mhclo_path := data_root.path_join(piece["mhclo"])
	var pobj := _parse_simple_obj(obj_path)
	if pobj.is_empty():
		return {}
	var pverts: PackedVector3Array = pobj["verts"]   # proxy obj positions (UNUSED for pos; we refit)
	var puvs: PackedVector2Array = pobj["uvs"]
	var pfaces: Array = pobj["faces"]                # Array of faces (each Array of [vi,ti])

	var fit := _parse_mhclo(mhclo_path, base_verts)
	if fit.is_empty() or fit["bindings"].size() != pverts.size():
		push_error("body_proxy_build: mhclo binding count %d != proxy vert count %d" % [
			(fit["bindings"].size() if not fit.is_empty() else -1), pverts.size()])
		return {}
	var fitted: PackedVector3Array = fit["fitted_pos"]    # raw MH-space, refit onto base
	var bindings: Array = fit["bindings"]                 # per proxy vert: [[base_idx,w],...]

	# corner-expand proxy faces on (v,vt); a proxy vert under several vt -> several render
	# verts (each keeps its parent proxy vert's base binding + fitted position).
	var render_pos := PackedVector3Array()
	var render_uv := PackedVector2Array()
	var tris := PackedInt32Array()
	var binding := []
	var corner_to_render := {}
	var corner := func(c: Array) -> int:
		var vi: int = c[0]
		var ti: int = c[1]
		var key := vi * 2000000 + (ti + 1)
		var existing = corner_to_render.get(key, -1)
		if existing != -1:
			return existing
		var ri := render_pos.size()
		render_pos.append(fitted[vi])
		var uv := Vector2(0.0, 0.0)
		if ti >= 0 and ti < puvs.size():
			var raw := puvs[ti]
			uv = Vector2(raw.x, 1.0 - raw.y)
		render_uv.append(uv)
		binding.append(bindings[vi])
		corner_to_render[key] = ri
		return ri
	for face in pfaces:
		_emit_face_tris(face, corner, tris)
	if render_pos.is_empty() or tris.is_empty():
		return {}
	return {"render_pos_raw": render_pos, "render_uv": render_uv, "tris": tris, "binding": binding}


## Emit triangles for one face (Array of [vi,ti] corners) via the `corner` resolver,
## using the SAME reversed winding + fixed quad diagonal as tools/body_converter.gd so
## culling + normal direction match the body exactly.
func _emit_face_tris(face: Array, corner: Callable, tris: PackedInt32Array) -> void:
	var c := PackedInt32Array()
	for cc in face:
		c.append(corner.call(cc))
	if c.size() == 4:
		tris.append(c[0]); tris.append(c[2]); tris.append(c[1])
		tris.append(c[0]); tris.append(c[3]); tris.append(c[2])
	elif c.size() == 3:
		tris.append(c[0]); tris.append(c[2]); tris.append(c[1])


# ---------------------------------------------------------------------------
# Morph-following delta library (ADLB), keyed by GLOBAL proxy render-vertex index.
# ---------------------------------------------------------------------------

## For every macro/detail target, push each base-vertex delta THROUGH the proxy
## binding: proxy_render_delta = Σ_k w_k · base_delta[B_k] (the barycentric combo of
## the deltas of the base verts the proxy vert is bound to). A proxy vert bound to
## base verts that the target does not move contributes 0 (stays seated). Output is
## the SAME ADLB binary format as tools/detail_library_build.gd, so the runtime
## DetailLibrary loads it unchanged — just pointed at the proxy artifact.
func _build_delta_library(data_root: String, binding: Array, total_verts: int) -> bool:
	# precompute base_idx -> list of (global_ri, weight) so a target's moved base verts
	# scatter straight onto the proxy render verts that reference them.
	var base_to_proxy := {}   # base_idx -> Array of [global_ri, weight]
	for ri in total_verts:
		for bw in binding[ri]:
			var b: int = bw[0]
			if not base_to_proxy.has(b):
				base_to_proxy[b] = []
			(base_to_proxy[b] as Array).append([ri, float(bw[1])])

	# Same target set as detail_library_build: detail (registry bidir/unipolar) + macro cube.
	var registry := ModifierRegistry.parse(data_root)
	var detail_paths := {}
	for e in registry["modifiers"]:
		if String(e["kind"]) == ModifierRegistry.KIND_MACRO:
			continue
		for t in e["targets"]:
			detail_paths[String(t["path"])] = true
	var macro_paths := _collect_macro_cube(data_root)
	var detail_sorted := detail_paths.keys(); detail_sorted.sort()
	var macro_sorted := macro_paths; macro_sorted.sort()

	var blob := StreamPeerBuffer.new()
	blob.big_endian = false
	blob.put_u8(0x41); blob.put_u8(0x44); blob.put_u8(0x4C); blob.put_u8(0x42)  # "ADLB"
	blob.put_u32(1)
	var total := detail_sorted.size() + macro_sorted.size()
	blob.put_u32(total)
	var data_start := blob.get_position()
	var index_entries := []
	var imported := 0; var empty := 0

	for kind_list in [["detail", detail_sorted], ["macro", macro_sorted]]:
		var kind: String = kind_list[0]
		for rel in kind_list[1]:
			var deltas := _parse_target(data_root.path_join("targets").path_join(rel))  # base idx -> Vec3 (MH units)
			# accumulate proxy-render-vert deltas (metres) via the binding
			var acc := {}   # global_ri -> Vector3 (metres)
			if not deltas.is_empty():
				for b in deltas.keys():
					var plist = base_to_proxy.get(b, null)
					if plist == null:
						continue
					var d: Vector3 = deltas[b]
					var dm := Vector3(d.x * MH_TO_METERS, d.y * MH_TO_METERS, d.z * MH_TO_METERS)
					for pr in plist:
						var ri: int = pr[0]
						var w: float = pr[1]
						acc[ri] = (acc.get(ri, Vector3.ZERO)) + dm * w
			var keys := acc.keys()
			keys.sort()
			var off := blob.get_position()
			var count := 0
			for ri in keys:
				var dd: Vector3 = acc[ri]
				if dd.length() < 1e-9:
					continue
				blob.put_u32(int(ri))
				blob.put_float(dd.x); blob.put_float(dd.y); blob.put_float(dd.z)
				count += 1
			index_entries.append({"path": rel, "offset": off, "count": count, "kind": kind})
			if count > 0: imported += 1
			else: empty += 1
	print("body_proxy_build: delta library: %d targets with proxy deltas, %d empty, blob %d bytes" % [imported, empty, blob.get_size()])

	var bf := FileAccess.open(OUT_BIN, FileAccess.WRITE)
	if bf == null:
		return false
	bf.store_buffer(blob.data_array); bf.flush(); bf.close()
	print("body_proxy_build: wrote %s" % OUT_BIN)

	var lines := PackedStringArray()
	lines.append("{")
	lines.append("\t\"_comment\": \"Generated by tools/body_proxy_build.gd. Sparse CPU delta library for the EYE/TEETH/TONGUE/GENITAL proxy pieces, keyed by GLOBAL proxy render-vertex index. DO NOT hand-edit; regenerate with `nix build .#body-proxies`.\",")
	lines.append("\t\"license\": \"CC0-1.0 (MakeHuman core proxies + targets; LICENSE.md §C)\",")
	lines.append("\t\"source\": {\"owner\": \"makehumancommunity\", \"repo\": \"makehuman\", \"rev\": \"v1.3.0\", \"sha256\": \"sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=\"},")
	lines.append("\t\"format\": \"ADLB v1: LE; header magic+u32 version+u32 count; per target `count` records of (u32 global_proxy_render_vertex_index, f32 dx, f32 dy, f32 dz) in metres\",")
	lines.append("\t\"render_vertex_count\": %d," % total_verts)
	lines.append("\t\"data_offset\": %d," % data_start)
	lines.append("\t\"target_count\": %d," % total)
	lines.append("\t\"targets\": [")
	for i in index_entries.size():
		var e: Dictionary = index_entries[i]
		var row := "\t\t{\"path\": %s, \"kind\": %s, \"offset\": %d, \"count\": %d}" % [
			JSON.stringify(String(e["path"])), JSON.stringify(String(e["kind"])),
			int(e["offset"]), int(e["count"])]
		if i < index_entries.size() - 1:
			row += ","
		lines.append(row)
	lines.append("\t]")
	lines.append("}")
	var jf := FileAccess.open(OUT_DETAIL_INDEX, FileAccess.WRITE)
	if jf == null:
		return false
	jf.store_string("\n".join(lines) + "\n"); jf.flush(); jf.close()
	print("body_proxy_build: wrote %s (%d targets)" % [OUT_DETAIL_INDEX, total])
	return true


func _write_index(entries: Array, total_verts: int) -> void:
	var lines := PackedStringArray()
	lines.append("{")
	lines.append("\t\"_comment\": \"Generated by tools/body_proxy_build.gd. Maps each surface of base_body_proxies.res to its piece name + material hint + its slice of the GLOBAL proxy-vertex numbering used by base_body_proxies_detail. DO NOT hand-edit; regenerate with `nix build .#body-proxies`.\",")
	lines.append("\t\"license\": \"CC0-1.0 (MakeHuman core proxies; LICENSE.md §C)\",")
	lines.append("\t\"source\": {\"owner\": \"makehumancommunity\", \"repo\": \"makehuman\", \"rev\": \"v1.3.0\", \"sha256\": \"sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=\"},")
	lines.append("\t\"total_vertex_count\": %d," % total_verts)
	lines.append("\t\"surfaces\": [")
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := "\t\t{\"name\": %s, \"material\": %s, \"vert_offset\": %d, \"vert_count\": %d, \"triangle_count\": %d}" % [
			JSON.stringify(String(e["name"])), JSON.stringify(String(e["material"])),
			int(e["vert_offset"]), int(e["vert_count"]), int(e["triangle_count"])]
		if i < entries.size() - 1:
			row += ","
		lines.append(row)
	lines.append("\t]")
	lines.append("}")
	var jf := FileAccess.open(OUT_INDEX, FileAccess.WRITE)
	if jf != null:
		jf.store_string("\n".join(lines) + "\n"); jf.flush(); jf.close()
		print("body_proxy_build: wrote %s" % OUT_INDEX)


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

## Parse base.obj: all `v`, all `vt`, and per-GROUP face lists (each face an Array of
## [vi(0-based), ti(0-based|-1)] corners). Also the body vert count (for the feet lift).
func _parse_base_obj(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("body_proxy_build: cannot open %s (err %d)" % [path, FileAccess.get_open_error()])
		return {}
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var group_faces := {}
	var cur := ""
	var body_base_vmax := -1
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("v "):
			var p := line.split(" ", false)
			verts.append(Vector3(p[1].to_float(), p[2].to_float(), p[3].to_float()))
		elif line.begins_with("vt "):
			var p := line.split(" ", false)
			uvs.append(Vector2(p[1].to_float(), p[2].to_float()))
		elif line.begins_with("g "):
			var p := line.split(" ", false)
			cur = p[1] if p.size() >= 2 else ""
			if not group_faces.has(cur):
				group_faces[cur] = []
		elif line.begins_with("f "):
			var p := line.split(" ", false)
			var face := []
			for i in range(1, p.size()):
				var parts := p[i].split("/")
				var vi := int(parts[0].to_int() - 1)
				var ti := -1
				if parts.size() >= 2 and parts[1] != "":
					ti = int(parts[1].to_int() - 1)
				face.append([vi, ti])
				if cur == "body":
					body_base_vmax = maxi(body_base_vmax, vi)
			(group_faces[cur] as Array).append(face)
	f.close()
	if verts.is_empty():
		return {}
	return {"verts": verts, "uvs": uvs, "group_faces": group_faces, "body_vert_count": body_base_vmax + 1}


## Parse a standalone proxy .obj (positions, UVs, faces). Faces are Arrays of [vi,ti].
func _parse_simple_obj(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("body_proxy_build: cannot open proxy obj %s" % path)
		return {}
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var faces := []
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("v "):
			var p := line.split(" ", false)
			verts.append(Vector3(p[1].to_float(), p[2].to_float(), p[3].to_float()))
		elif line.begins_with("vt "):
			var p := line.split(" ", false)
			uvs.append(Vector2(p[1].to_float(), p[2].to_float()))
		elif line.begins_with("f "):
			var p := line.split(" ", false)
			var face := []
			for i in range(1, p.size()):
				var parts := p[i].split("/")
				var vi := int(parts[0].to_int() - 1)
				var ti := -1
				if parts.size() >= 2 and parts[1] != "":
					ti = int(parts[1].to_int() - 1)
				face.append([vi, ti])
			faces.append(face)
	f.close()
	return {"verts": verts, "uvs": uvs, "faces": faces}


## Parse a .mhclo fitting. Returns:
##   fitted_pos : PackedVector3Array — each proxy vert's RAW MH-space position,
##                 reconstructed from the base mesh (so it sits on the CURRENT base,
##                 independent of the proxy obj's own baked coordinates).
##   bindings   : Array — per proxy vert, [[base_idx, weight], ...] (the barycentric
##                 base-vert set used for skinning + morph-following).
## Scale refs (x_scale/y_scale/z_scale "<vA> <vB> <ref_dist>") rescale the constant
## offset by current_base_distance(vA,vB)/ref_dist, so the offset tracks the body's
## local scale. For single-index entries there is no offset, so scale refs are inert.
func _parse_mhclo(path: String, base_verts: PackedVector3Array) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("body_proxy_build: cannot open mhclo %s" % path)
		return {}
	var scale_ref := [Vector3(1,1,1), Vector3(1,1,1)]  # unused unless we have offsets
	var sx := 1.0; var sy := 1.0; var sz := 1.0
	var in_verts := false
	var fitted := PackedVector3Array()
	var bindings := []
	var dist := func(a: int, b: int) -> float:
		if a < 0 or b < 0 or a >= base_verts.size() or b >= base_verts.size():
			return 1.0
		return base_verts[a].distance_to(base_verts[b])
	while not f.eof_reached():
		var line := f.get_line()
		var s := line.strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		if not in_verts:
			if s.begins_with("x_scale"):
				var p := s.split(" ", false); sx = dist.call(p[1].to_int(), p[2].to_int()) / maxf(p[3].to_float(), 1e-6)
			elif s.begins_with("y_scale"):
				var p := s.split(" ", false); sy = dist.call(p[1].to_int(), p[2].to_int()) / maxf(p[3].to_float(), 1e-6)
			elif s.begins_with("z_scale"):
				var p := s.split(" ", false); sz = dist.call(p[1].to_int(), p[2].to_int()) / maxf(p[3].to_float(), 1e-6)
			elif s.begins_with("verts "):
				in_verts = true
			continue
		# in the verts section
		var p := s.split(" ", false)
		if p.size() == 1:
			# SINGLE index: proxy vert == base vert
			var b := p[0].to_int()
			fitted.append(base_verts[b])
			bindings.append([[b, 1.0]])
		elif p.size() >= 9:
			# BARYCENTRIC: B0 B1 B2 w0 w1 w2 dx dy dz
			var b0 := p[0].to_int(); var b1 := p[1].to_int(); var b2 := p[2].to_int()
			var w0 := p[3].to_float(); var w1 := p[4].to_float(); var w2 := p[5].to_float()
			var off := Vector3(p[6].to_float() * sx, p[7].to_float() * sy, p[8].to_float() * sz)
			var pos := base_verts[b0] * w0 + base_verts[b1] * w1 + base_verts[b2] * w2 + off
			fitted.append(pos)
			# bind weights for skin/morph: the barycentric weights (normalized defensively)
			var sum := w0 + w1 + w2
			if absf(sum) < 1e-6:
				sum = 1.0
			bindings.append([[b0, w0 / sum], [b1, w1 / sum], [b2, w2 / sum]])
		else:
			# malformed line — treat as single index if one int, else skip
			if p.size() >= 1:
				var b := p[0].to_int()
				fitted.append(base_verts[b]); bindings.append([[b, 1.0]])
	f.close()
	return {"fitted_pos": fitted, "bindings": bindings}


## Parse default.mhskel only for the DETERMINISTIC bone order (name -> index), matching
## tools/body_converter.gd's topological order so ARRAY_BONES indices line up with the
## body's Skeleton3D (the proxies share that skeleton).
func _parse_skeleton_order(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("bones"):
		return {}
	var bones: Dictionary = data["bones"]
	# Inject the SAME secondary-motion bones tools/body_converter.gd adds (belly / glute.L
	# / glute.R / hair01-03), so this builder's topo-sorted bone ORDER is IDENTICAL to the
	# body's — the proxies (and the hair piece) share that Skeleton3D, so their ARRAY_BONES
	# indices must line up bone-for-bone. Names + parents must match the converter exactly.
	for sb in _synth_soft_bone_parents():
		bones[sb[0]] = {"parent": sb[1]}
	var all_names := bones.keys()
	all_names.sort()
	var ordered := PackedStringArray()
	var placed := {}
	var progressed := true
	while progressed and ordered.size() < all_names.size():
		progressed = false
		for bname in all_names:
			if placed.has(bname):
				continue
			var parent = bones[bname].get("parent", null)
			if parent == null or placed.has(parent):
				ordered.append(bname); placed[bname] = true; progressed = true
	for bname in all_names:
		if not placed.has(bname):
			ordered.append(bname)
	var name_to_index := {}
	for i in ordered.size():
		name_to_index[ordered[i]] = i
	return {"name_to_index": name_to_index}


## Re-skin the hair surface onto the head + hair01/02/03 chain by vertical band, so the
## hair spring-bones drive it. The hair cap spans crown (high Y) to tips (low Y); we map
## that span across 3 segments and assign each vert to TWO adjacent chain bones with a
## linear blend (so the seam between links is smooth). Topmost verts stay anchored to
## `head` (the scalp doesn't fly off); progressively lower verts ride hair01->hair02->
## hair03, where the spring deflection — strongest at the chain tip — produces visible
## sway. Pure function of vertex Y within the piece bbox => deterministic.
func _skin_hair_chain(rpos: PackedVector3Array, bones_arr: PackedInt32Array,
		weights_arr: PackedFloat32Array, name_to_index: Dictionary) -> void:
	var chain := [
		int(name_to_index.get("head", 0)),
		int(name_to_index.get("hair01", 0)),
		int(name_to_index.get("hair02", 0)),
		int(name_to_index.get("hair03", 0)),
	]
	var n := rpos.size()
	if n == 0:
		return
	var ymin := INF
	var ymax := -INF
	for p in rpos:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var yr := maxf(ymax - ymin, 1e-6)
	var nseg := chain.size() - 1   # 3 segments between 4 bones
	for i in n:
		# t: 0 at the crown (top), 1 at the tips (bottom).
		var t := clampf((ymax - rpos[i].y) / yr, 0.0, 1.0)
		var f := t * float(nseg)            # position along the chain in [0, nseg]
		var seg := mini(int(floor(f)), nseg - 1)
		var frac := f - float(seg)          # blend toward the next bone
		var o := i * MAX_INFLUENCES
		for k in MAX_INFLUENCES:
			bones_arr[o + k] = 0
			weights_arr[o + k] = 0.0
		bones_arr[o] = chain[seg]
		weights_arr[o] = 1.0 - frac
		bones_arr[o + 1] = chain[seg + 1]
		weights_arr[o + 1] = frac
		# (defensive) if both collapsed to the same bone at a band edge, keep weight 1.
		if bones_arr[o] == bones_arr[o + 1]:
			weights_arr[o] = 1.0
			weights_arr[o + 1] = 0.0


## The secondary-motion bones injected by BOTH this builder and tools/body_converter.gd,
## as [name, parent] pairs in any order (the topo sort orders them). MUST stay in lockstep
## with body_converter.gd._synth_soft_bones (same names + parents) so the shared skeleton's
## bone INDICES match across both artifacts. (Positions live only in the converter, which
## writes the rig JSON; here we need only the order, so parent links suffice.)
func _synth_soft_bone_parents() -> Array:
	return [
		["belly", "spine04"],
		["glute.L", "pelvis.L"],
		["glute.R", "pelvis.R"],
		["hair01", "head"],
		["hair02", "hair01"],
		["hair03", "hair02"],
	]


## Parse default_weights.mhw -> per-base-vert top-4 ARRAY_BONES/ARRAY_WEIGHTS, IDENTICAL
## to tools/body_converter.gd._parse_weights (so the proxy skin matches the body skin).
func _parse_weights(path: String, name_to_index: Dictionary, n: int) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("weights"):
		return {}
	var weights: Dictionary = data["weights"]
	var per_vert := {}
	var bnames := weights.keys(); bnames.sort()
	for bname in bnames:
		if not name_to_index.has(bname):
			continue
		var bidx: int = name_to_index[bname]
		for pair in weights[bname]:
			var vi := int(pair[0]); var w := float(pair[1])
			if vi < 0 or vi >= n or w <= 0.0:
				continue
			if not per_vert.has(vi):
				per_vert[vi] = []
			per_vert[vi].append([bidx, w])
	var bones_arr := PackedInt32Array(); bones_arr.resize(n * MAX_INFLUENCES)
	var weights_arr := PackedFloat32Array(); weights_arr.resize(n * MAX_INFLUENCES)
	for vi in n:
		var infl = per_vert.get(vi, null)
		var acc := {}
		if infl == null or (infl as Array).is_empty():
			bones_arr[vi * MAX_INFLUENCES] = 0; weights_arr[vi * MAX_INFLUENCES] = 1.0
			continue
		for e in infl:
			acc[e[0]] = float(acc.get(e[0], 0.0)) + float(e[1])
		_collapse_top4(acc, bones_arr, weights_arr, vi * MAX_INFLUENCES)
	return {"bones": bones_arr, "weights": weights_arr}


## Collapse a {bone_index: weight} map into top-4 (desc weight, ties asc bone),
## renormalized to sum 1, written at `off` in the bones/weights arrays. Deterministic.
func _collapse_top4(acc: Dictionary, bones_arr: PackedInt32Array, weights_arr: PackedFloat32Array, off: int) -> void:
	var arr := []
	for b in acc.keys():
		arr.append([int(b), float(acc[b])])
	arr.sort_custom(func(a, b2):
		if a[1] != b2[1]:
			return a[1] > b2[1]
		return a[0] < b2[0])
	var top := arr.slice(0, MAX_INFLUENCES)
	var sum := 0.0
	for e in top:
		sum += e[1]
	for k in MAX_INFLUENCES:
		bones_arr[off + k] = 0
		weights_arr[off + k] = 0.0
	if sum <= 0.0:
		bones_arr[off] = 0; weights_arr[off] = 1.0
		return
	for k in top.size():
		bones_arr[off + k] = top[k][0]
		weights_arr[off + k] = top[k][1] / sum


## Parse a `.target` (sparse base-vert deltas, MH units). { base_idx: Vector3 }.
func _parse_target(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var out := {}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var p := line.split(" ", false)
		if p.size() < 4:
			continue
		out[p[0].to_int()] = Vector3(p[1].to_float(), p[2].to_float(), p[3].to_float())
	f.close()
	return out


## Collect the macro factor-cube target rel-paths (universal + caucasian + proportions),
## IDENTICAL to tools/detail_library_build.gd._collect_macro_cube (so proxies follow the
## same macro morphs the body does). Height/asian/african excluded.
func _collect_macro_cube(data_root: String) -> Array:
	var out := []
	var udir := data_root.path_join("targets").path_join("macrodetails")
	var ud := DirAccess.open(udir)
	if ud != null:
		ud.list_dir_begin()
		var name := ud.get_next()
		while name != "":
			if not ud.current_is_dir() and (name.begins_with("universal-") or name.begins_with("caucasian-")) and name.ends_with(".target"):
				out.append("macrodetails/%s" % name)
			name = ud.get_next()
		ud.list_dir_end()
	var pdir := data_root.path_join("targets").path_join("macrodetails/proportions")
	var pd := DirAccess.open(pdir)
	if pd != null:
		pd.list_dir_begin()
		var pname := pd.get_next()
		while pname != "":
			if not pd.current_is_dir() and pname.ends_with(".target"):
				out.append("macrodetails/proportions/%s" % pname)
			pname = pd.get_next()
		pd.list_dir_end()
	return out


## Outward smooth normals — SAME convention as tools/body_converter.gd._compute_normals
## ((c-a)×(b-a) so normals point outward over the reversed winding). Deterministic.
func _compute_normals(verts: PackedVector3Array, tris: PackedInt32Array) -> PackedVector3Array:
	var n := verts.size()
	var normals := PackedVector3Array(); normals.resize(n)
	for i in n:
		normals[i] = Vector3.ZERO
	var t := 0
	while t < tris.size():
		var a := tris[t]; var b := tris[t + 1]; var c := tris[t + 2]
		var fn := (verts[c] - verts[a]).cross(verts[b] - verts[a])
		normals[a] += fn; normals[b] += fn; normals[c] += fn
		t += 3
	for i in n:
		var ln := normals[i]
		normals[i] = ln.normalized() if ln.length() > 1e-9 else Vector3.UP
	return normals
