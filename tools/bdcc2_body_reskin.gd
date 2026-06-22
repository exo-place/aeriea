## BDCC2 body/limb part MULTI-BONE re-skin → aeriea MakeHuman rig (committed ArrayMesh).
##
## The generalization of tools/bdcc2_head_reskin.gd from a SINGLE-bone collapse (a head
## rides one `head` bone) to a TRUE MULTI-BONE transfer: a mesh skinned across MANY BDCC2
## bones (a leg part spanning thigh/shin/foot/toe) is rebound onto aeriea's MakeHuman
## skeleton so it DEFORMS limb-by-limb when aeriea animates — bend the knee and the shin
## follows, not a rigid attach.
##
## WHY THIS IS THE HARD CASE (and how it resolves):
##   - BDCC2's body GLB skins to its OWN ~77-bone deform rig using CLEAN anim names
##     (hips, thigh.L, shin.L, foot.L, toe.L, ...). NOT Rigify DEF-* — that assumption
##     was for the accessory part GLBs (tails/ears). scripts/body/bdcc2_bone_map.gd maps
##     those exact anim names onto aeriea's MH bones, so EVERY gross leg bone maps 1:1
##     (thigh->upperleg01, shin->lowerleg01, foot->foot, toe->toe1-1).
##   - The skeletons do NOT share rest positions (the earlier "nearly identical" claim was
##     WRONG, diagnosed via tools/bdcc2_fit_diagnose.gd): the BDCC2 leg MESH spans y[0,0.646]
##     while aeriea's leg spans y[0.072,0.865] (starts ~0.22m HIGHER, ~0.15m LONGER), and the
##     per-joint ratio differs (~15%). Keeping the raw vertex world position and binding to a
##     higher/longer aeriea bone is what produced the THIN PILLARS + DETACHED lower-leg pieces:
##     the verts sat below their bind bones, so any pose tore them vertically.
##   - Helper bones the mesh also weights (knee.L/R IK helpers, char_root) have NO aeriea
##     counterpart; we COLLAPSE each to its nearest MAPPED ancestor (knee->thigh's mapped
##     bone via the BDCC2 parent chain; char_root->root).
##
## THE TRANSFER (POSITION-ONLY per-influence RETARGET + multi-bone rebind). At BDCC2's bind,
## LBS(p) == p (verified). aeriea's BodyRig builds its body Skin with bind = global_rest^-1,
## also LBS(p) == p at rest. To seat each leg SEGMENT on its aeriea bone (matching aeriea's
## longer/higher proportions joint-by-joint) we shift each vertex by the WEIGHTED delta between
## its BDCC2 bind-bone ORIGIN and the mapped aeriea bone ORIGIN:
##     p_aeriea = p + Σ wᵢ · (aeriea_rest_origin[i] - bdcc_rest_origin[i])
## POSITION-ONLY (origins, not full transforms) on purpose: the BDCC2 leg bones carry large
## non-identity bases (Blender bones point +Y up the bone; thigh ~180° roll, foot ~-73° pitch)
## while aeriea's rest bases are identity, so a full aeriea_rest·bdcc_rest⁻¹ would ROTATE
## geometry that is already correctly world-oriented — scrambling it. The origin-only delta is a
## smooth per-vertex translation: it carries each joint to aeriea's joint position with NO basis
## rotation and NO shear (the knee blend is a gentle interpolation of two translation deltas, not
## a rotation blend). Then we REMAP each influence's bone index to the aeriea index + RENORMALIZE
## weights. Under aeriea's LBS the vertex rides its mapped bones; at rest it reproduces the
## RETARGETED position (legs now reach aeriea's hip + length, no pillars). DESIGN-FORK (flagged):
## this WARPS the mesh to aeriea's rest proportions (aeriea owns the skeleton — the default);
## alternatives are accept-BDCC2-proportions or warp-aeriea's-rig.
##
## DETERMINISM: fixed source order, fixed mesh/surface order, fixed float path, stable
## aeriea bone indices from the committed rig JSON -> byte-identical .res.
##
## Run (BDCC2 checkout present):
##   BDCC2_SRC=/abs/path/to/BDCC2 xvfb-run -a godot4 --path . res://tools/bdcc2_body_reskin.tscn --quit-after 300
## (defaults to ~/git/pterror/BDCC2 if BDCC2_SRC is unset.)
extends Node

const Bdcc2BoneMap := preload("res://scripts/body/bdcc2_bone_map.gd")

const DEFAULT_SRC := "/home/me/git/pterror/BDCC2"
const OUT_DIR := "res://assets/body/parts/bdcc2/reskin/"
const RIG_PATH := "res://assets/body/base_body_rig.json"

## Body/limb part meshes to re-skin. Each row: aeriea id, GLB path (under SRC), and the
## MeshInstance3D node name whose surfaces form the limb shell. The legs live INSIDE the
## body GLB (no standalone leg part); we isolate the DigiLegs / PlantiLegs sub-meshes.
const PARTS := [
	{"id": "digi_legs", "glb": "Mesh/Parts/Body/FeminineBody/FeminineBody.glb", "mesh": "DigiLegs"},
	{"id": "planti_legs", "glb": "Mesh/Parts/Body/FeminineBody/FeminineBody.glb", "mesh": "PlantiLegs"},
]


func _ready() -> void:
	get_tree().quit(_run())


func _src() -> String:
	var env := OS.get_environment("BDCC2_SRC")
	return env if env != "" else DEFAULT_SRC


func _run() -> int:
	var src := _src()
	print("bdcc2_body_reskin: src = %s" % src)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# aeriea bone NAME -> stable INDEX (the order BodyRig adds bones; same as the JSON order)
	# and NAME -> global rest ORIGIN (the retarget target position per joint).
	var rig := _load_json(RIG_PATH)
	if rig.is_empty():
		push_error("cannot load aeriea rig json"); return 1
	var aeriea_index := {}
	var aeriea_origin := {}
	var bones: Array = rig["bones"]
	for i in bones.size():
		aeriea_index[String(bones[i]["name"])] = i
		var h: Array = bones[i]["head"]
		aeriea_origin[String(bones[i]["name"])] = Vector3(h[0], h[1], h[2])

	var ok := 0
	for part in PARTS:
		if _reskin_one(src, part, aeriea_index, aeriea_origin):
			ok += 1
	print("bdcc2_body_reskin: %d/%d parts re-skinned" % [ok, PARTS.size()])
	return 0 if ok == PARTS.size() else 1


## Map a BDCC2 bone name to an aeriea bone name, collapsing unmapped helper bones to their
## nearest MAPPED ancestor by walking the BDCC2 bind hierarchy. Returns "" if nothing in the
## chain maps (should not happen for a body part — the chain reaches `hips`).
func _map_bdcc2_bone(bdcc_name: String, bdcc_skel: Skeleton3D) -> String:
	# Reverse the MAP (BDCC2 anim name -> aeriea MH name).
	var bi := bdcc_skel.find_bone(bdcc_name)
	while bi >= 0:
		var nm := bdcc_skel.get_bone_name(bi)
		for mh in Bdcc2BoneMap.MAP:
			if String(Bdcc2BoneMap.MAP[mh]) == nm:
				return mh
		bi = bdcc_skel.get_bone_parent(bi)
	return ""


func _reskin_one(src: String, part: Dictionary, aeriea_index: Dictionary, aeriea_origin: Dictionary) -> bool:
	var id: String = part["id"]
	var glb_path := src.path_join(part["glb"])
	if not FileAccess.file_exists(glb_path):
		print("  SKIP %s (missing %s)" % [id, glb_path]); return false
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(glb_path, st) != OK:
		print("  SKIP %s (load fail)" % id); return false
	var scene := doc.generate_scene(st)
	if scene == null:
		print("  SKIP %s (no scene)" % id); return false
	add_child(scene)
	var skel := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		print("  SKIP %s (no skeleton)" % id); return false
	for i in skel.get_bone_count():
		skel.reset_bone_pose(i)
	skel.force_update_all_bone_transforms()

	var mi := scene.find_child(part["mesh"], true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		print("  SKIP %s (mesh '%s' not found)" % [id, part["mesh"]]); return false

	# Precompute, per BDCC2 bone: (a) the aeriea bone INDEX it maps to, and (b) the RETARGET
	# DELTA = aeriea_rest_origin - bdcc_rest_origin, both in the YAWED frame the verts live in
	# (verts get yaw·mesh_xf·v in _transfer_surface; the BDCC2 bone origin must match that frame,
	# so we yaw the bone's bind global origin too). A vertex is then shifted by the weighted sum of
	# its influences' deltas — seating each leg segment on its aeriea joint at aeriea proportions.
	var yaw := Basis(Vector3.UP, PI)
	var bdcc_to_aeriea_idx := {}
	var bdcc_retarget_delta := {}
	for bi in skel.get_bone_count():
		var bdcc_name := skel.get_bone_name(bi)
		var mh := _map_bdcc2_bone(bdcc_name, skel)
		var aname := mh if (mh != "" and aeriea_index.has(mh)) else "root"
		bdcc_to_aeriea_idx[bi] = int(aeriea_index.get(aname, 0))
		var bdcc_origin: Vector3 = yaw * skel.get_bone_global_pose(bi).origin
		var aeriea_o: Vector3 = aeriea_origin.get(aname, Vector3.ZERO)
		bdcc_retarget_delta[bi] = aeriea_o - bdcc_origin

	var out_mesh := ArrayMesh.new()
	var total := 0
	var aeriea_bones_used := {}
	for s in mi.mesh.get_surface_count():
		total += _transfer_surface(mi, s, bdcc_to_aeriea_idx, bdcc_retarget_delta, out_mesh, aeriea_bones_used)

	if out_mesh.get_surface_count() == 0:
		print("  SKIP %s (no surfaces transferred)" % id); return false

	var out_path := OUT_DIR.path_join("%s.res" % id)
	var err := ResourceSaver.save(out_mesh, out_path)
	if err != OK:
		push_error("save %s failed err=%d" % [out_path, err]); return false
	var ab := out_mesh.get_aabb()
	print("  %-12s -> %s : %d surfaces, %d verts, %d aeriea bones, aabb pos=%s size=%s" %
		[id, out_path, out_mesh.get_surface_count(), total, aeriea_bones_used.size(),
		 str(ab.position.snappedf(0.001)), str(ab.size.snappedf(0.001))])
	return true


## Transfer one surface: remap each vertex's BDCC2 (bone,weight) influences onto aeriea bone
## indices, collapse to <=4 influences, renormalize. Positions kept in WORLD/bind space (the
## standard-LBS bind makes the bind world position == the mesh-space vertex; aeriea's body Skin
## uses the same bind, so the rebound vertex reseats correctly and rides its mapped bones).
func _transfer_surface(mi: MeshInstance3D, s: int, bdcc_to_aeriea_idx: Dictionary,
		bdcc_retarget_delta: Dictionary, out_mesh: ArrayMesh, aeriea_bones_used: Dictionary) -> int:
	var arr := mi.mesh.surface_get_arrays(s)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var src_bones = arr[Mesh.ARRAY_BONES]
	var src_weights = arr[Mesh.ARRAY_WEIGHTS]
	var nv := verts.size()
	if nv == 0 or not (src_bones is PackedInt32Array):
		return 0
	var ipv: int = src_bones.size() / nv

	# The mesh node's transform relative to the skeleton (identity for the body GLB, but
	# compose to be exact). BDCC2 bodies face -Z; aeriea faces +Z. The clip retarget de-yaws
	# 180° (facing is sim-owned). A LEG mesh is left/right symmetric about X but front/back is
	# NOT — a -Z mesh has knees pointing -Z while aeriea's knees point +Z. So yaw 180° about Y
	# so the legs bend the right way (same SEAT_YAW the head tool applies).
	var mesh_xf: Transform3D = mi.transform
	var yaw := Basis(Vector3.UP, PI)

	var out_verts := PackedVector3Array(); out_verts.resize(nv)
	var out_norms := PackedVector3Array(); out_norms.resize(nv)
	var out_bones := PackedInt32Array(); out_bones.resize(nv * 4)
	var out_weights := PackedFloat32Array(); out_weights.resize(nv * 4)

	for vi in nv:
		var p: Vector3 = yaw * (mesh_xf * verts[vi])
		var n: Vector3 = (yaw * (mesh_xf.basis * norms[vi])).normalized() if vi < norms.size() else Vector3.UP
		# RETARGET: shift the vertex by the WEIGHTED sum of its influences' (aeriea - bdcc) bone-
		# origin deltas, seating each leg segment on its aeriea joint at aeriea proportions. Computed
		# from the ORIGINAL BDCC2 influences/weights (before the aeriea collapse below), normalized
		# by the total influence weight so the shift is a true weighted average of the joint deltas.
		var shift := Vector3.ZERO
		var wsum := 0.0
		for k in ipv:
			var ww: float = src_weights[vi * ipv + k]
			if ww <= 0.0:
				continue
			shift += ww * (bdcc_retarget_delta.get(src_bones[vi * ipv + k], Vector3.ZERO) as Vector3)
			wsum += ww
		if wsum > 0.0:
			shift /= wsum
		out_verts[vi] = p + shift
		out_norms[vi] = n
		# Accumulate weight onto each MAPPED aeriea bone (several BDCC2 bones may collapse to
		# the same aeriea bone, e.g. knee+thigh -> upperleg01 — sum their weights).
		var acc := {}
		for k in ipv:
			var w: float = src_weights[vi * ipv + k]
			if w <= 0.0:
				continue
			var bidx: int = src_bones[vi * ipv + k]
			var aidx: int = bdcc_to_aeriea_idx.get(bidx, 0)
			acc[aidx] = float(acc.get(aidx, 0.0)) + w
		# Take the top 4 aeriea influences (Godot ARRAY_BONES = 4/vertex here).
		var pairs := []
		for aidx in acc:
			pairs.append([aidx, acc[aidx]])
		pairs.sort_custom(func(a, b): return a[1] > b[1])
		var sum := 0.0
		for k in 4:
			if k < pairs.size():
				sum += pairs[k][1]
		if sum <= 0.0:
			sum = 1.0
			pairs = [[0, 1.0]]
		for k in 4:
			if k < pairs.size():
				out_bones[vi * 4 + k] = int(pairs[k][0])
				out_weights[vi * 4 + k] = float(pairs[k][1]) / sum
				aeriea_bones_used[int(pairs[k][0])] = true
			else:
				out_bones[vi * 4 + k] = int(pairs[0][0]) if pairs.size() > 0 else 0
				out_weights[vi * 4 + k] = 0.0

	var sa := []
	sa.resize(Mesh.ARRAY_MAX)
	sa[Mesh.ARRAY_VERTEX] = out_verts
	sa[Mesh.ARRAY_NORMAL] = out_norms
	sa[Mesh.ARRAY_BONES] = out_bones
	sa[Mesh.ARRAY_WEIGHTS] = out_weights
	if arr[Mesh.ARRAY_TEX_UV] != null:
		sa[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV]
	sa[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sa)
	out_mesh.surface_set_name(out_mesh.get_surface_count() - 1, "%s_%d" % [mi.name, s])
	return nv


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
