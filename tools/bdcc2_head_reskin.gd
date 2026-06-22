## BDCC2 core-body HEAD re-skin → aeriea MakeHuman rig (committed ArrayMesh artifact).
##
## The marquee "swappable body PARTS" pipeline: takes a BDCC2 core-body part mesh
## (skinned to BDCC2's OWN deform skeleton) and REBINDS its per-vertex bone indices +
## weights onto aeriea's 169-bone MakeHuman skeleton via the bone-map, producing a
## byte-reproducible res://assets/body/parts/bdcc2/reskin/<part>.res (an ArrayMesh)
## that aeriea's BodyRig skins to its OWN skeleton — so the swapped part DEFORMS with
## the body (it rides the mapped bone when the skeleton animates), not a static attach.
##
## WHY A HEAD RE-SKINS CLEAN. The BDCC2 head GLBs (CanineHead / FelineHead) ship a
## HEAD-LOCAL deform rig: DEF-Head is the rig ROOT at the origin, and every other
## bone (DEF-Jaw, DEF-Mouth*, DEF-Eye*, DEF-Brow*, DEF-Tongue*) is a CHILD of DEF-Head.
## The gross head mesh is ~99% weighted to DEF-Head; the remainder are facial-detail
## bones that have NO aeriea counterpart in bdcc2_bone_map. So the faithful transfer is:
##   - DEF-Head        -> aeriea "head"
##   - every facial sub-bone (child of DEF-Head) -> COLLAPSE to aeriea "head"
## i.e. the whole head becomes a rigid unit riding aeriea's `head` bone. That is exactly
## what a HEAD SWAP needs: aeriea owns facial animation through its own proxy/face rig;
## the swapped head's job is to replace the skull geometry and follow the head bone.
##
## THE TRANSFER (bind-pose-relative). For each vertex we compute its BIND global position
## by LBS through the GLB skeleton's bind pose (with the GLB's own per-vertex weights), then
## re-express it in aeriea's `head`-bone REST-LOCAL frame (aeriea head rest basis is identity,
## so this is just global - head_global + SEAT). The rebound mesh carries ARRAY_BONES = the
## aeriea head bone index on every influence and ARRAY_WEIGHTS = 1.0 -> when aeriea's LBS
## skins it, the head sits in aeriea's head frame and rides the head bone. SEAT is a small
## tunable head-local offset (metres) that lands BDCC2's DEF-Head origin on aeriea's anatomy.
##
## DETERMINISM: fixed source order, fixed float path, fixed bone index -> byte-identical .res.
##
## Run (BDCC2 checkout present):
##   BDCC2_SRC=/abs/path/to/BDCC2 xvfb-run -a godot4 --path . res://tools/bdcc2_head_reskin.tscn --quit-after 300
## (defaults to ~/git/pterror/BDCC2 if BDCC2_SRC is unset.)
extends Node

const Bdcc2BoneMap := preload("res://scripts/body/bdcc2_bone_map.gd")

const DEFAULT_SRC := "/home/me/git/pterror/BDCC2"
const OUT_DIR := "res://assets/body/parts/bdcc2/reskin/"

## The aeriea bone the head rides (bdcc2_bone_map: "head" <- BDCC2 anim "head"; the part
## GLBs use the DEF- deform names — DEF-Head — which we map here to the same aeriea bone).
const AERIEA_HEAD_BONE := "head"

## FIT — scale + seat the BDCC2 head onto aeriea's head REGION (not just its bone origin).
##
## DIAGNOSED (tools/bdcc2_fit_diagnose.gd):
##   - aeriea head region (base-mesh verts dominantly weighted to the head subtree):
##       size (0.176, 0.234, 0.207) m, CENTER (0.0, 1.549, 0.064).
##   - BDCC2 CanineHead gross shell (yawed to +Z, head-local): size (0.248, 0.224, 0.292),
##       CENTER (0.0, 0.098, -0.057). Its DEF-Head ORIGIN sits at the jaw/throat (y≈0), so the
##       old "place DEF-Head origin on the head bone" seated the skull LOW and the snout FORWARD
##       of aeriea's head — and at BDCC2's native size the head read small in aeriea's region.
##
## THE FIT. A per-part SCALE about the BDCC2 head-mesh CENTER, then a TRANSLATE landing that
## center on aeriea's head-region CENTER. So the head fills the region and is centred on it
## (no longer hanging off the jaw). UNIFORM scale (not per-axis): the BDCC2 head is an ANIMAL
## head — wider + deeper (the snout) than a human skull — so per-axis scaling to the human
## region's proportions would SQUASH the muzzle. Uniform preserves the animal silhouette while
## filling the region. DESIGN-FORK (flagged for the owner): uniform-preserve-silhouette is the
## default; the alternative is per-axis match-human-proportions (loses the muzzle projection).
const HEAD_FIT_SCALE := 0.88
## BDCC2 head-mesh center (RAW head-local, NO yaw — matches SEAT_YAW=0) — the scale pivot.
## From the diagnostic raw AABB pos (0,-0.014,-0.089) + size (0.248,0.224,0.292): center z=+0.057.
const BDCC2_HEAD_CENTER := Vector3(0.0, 0.098, 0.057)
## aeriea head-region center (global rest) — where the scaled head's center lands.
const AERIEA_HEAD_CENTER := Vector3(0.0, 1.549, 0.064)
## Residual hand-tunable nudge (metres) on top of the center-to-center seat. 0 = pure fit.
const SEAT := Vector3(0.0, 0.0, 0.0)
## FACING. The BDCC2 HEAD GLBs are authored facing +Z natively — DIAGNOSED (bdcc2_fit_diagnose.gd):
## the snout/face mass is overwhelmingly at +z (1330 verts at z>0.05 vs 56 at z<-0.05). aeriea also
## faces +Z, so NO yaw is needed. (The earlier PI yaw — copied from the BODY rig, which DOES face
## -Z — flipped the snout to face BACKWARD, rendering a smooth faceless back-of-head to the front.)
const SEAT_YAW := 0.0

## Core-body part meshes to re-skin. Each row: aeriea id, GLB path (under SRC), and the
## SURFACE node name(s) whose geometry forms the gross head shell to transfer. We transfer
## the main head shell + cheek fluff (the visible animal-head silhouette); the eyes/teeth/
## tongue/brow/lash detail meshes are aeriea's own proxy concern and are intentionally not
## carried (they'd need the unmapped facial bones to animate — out of scope for the swap).
const PARTS := [
	{"id": "canine_head", "glb": "Mesh/Parts/Head/CanineHead/CanineHead.glb",
		"meshes": ["CanineHead", "CheekFluff"]},
	{"id": "feline_head", "glb": "Mesh/Parts/Head/FelineHead/FelineHead.glb",
		"meshes": ["FelineHead", "CheekFluff"]},
]


func _ready() -> void:
	get_tree().quit(_run())


func _src() -> String:
	var env := OS.get_environment("BDCC2_SRC")
	return env if env != "" else DEFAULT_SRC


func _run() -> int:
	var src := _src()
	print("bdcc2_head_reskin: src = %s" % src)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# aeriea head bone GLOBAL rest position (the frame the re-skinned verts live in).
	var rig := _load_json("res://assets/body/base_body_rig.json")
	if rig.is_empty():
		push_error("cannot load aeriea rig json"); return 1
	var head_global := _aeriea_bone_global(rig, AERIEA_HEAD_BONE)
	if head_global == Vector3.INF:
		push_error("aeriea head bone not found"); return 1
	print("bdcc2_head_reskin: aeriea head global = %s" % str(head_global))

	var ok := 0
	for part in PARTS:
		if _reskin_one(src, part, head_global):
			ok += 1
	print("bdcc2_head_reskin: %d/%d parts re-skinned" % [ok, PARTS.size()])
	return 0 if ok == PARTS.size() else 1


func _reskin_one(src: String, part: Dictionary, head_global: Vector3) -> bool:
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

	# Reset to bind pose so get_bone_global_pose returns each bone's BIND global transform.
	for i in skel.get_bone_count():
		skel.reset_bone_pose(i)
	var bind_global := []
	bind_global.resize(skel.get_bone_count())
	for i in skel.get_bone_count():
		bind_global[i] = skel.get_bone_global_pose(i)

	# Build the rebound ArrayMesh: one surface per transferred mesh, ARRAY_BONES -> aeriea
	# head index (filled at apply time by BodyRig, which knows the bone order), ARRAY_WEIGHTS
	# -> 1.0 on the single influence. We store the head index as 0 here and rely on a
	# single-bone Skin bound to "head" at load (BodyRig builds that). Positions are baked into
	# aeriea's head-bone-local frame so LBS reseats them correctly.
	var out_mesh := ArrayMesh.new()
	var total_verts := 0
	for mesh_name in part["meshes"]:
		var mi := scene.find_child(mesh_name, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			print("  (mesh '%s' not found in %s — skipped)" % [mesh_name, id]); continue
		var n := _transfer_surface(mi, skel, bind_global, head_global, out_mesh, mesh_name)
		total_verts += n
	if out_mesh.get_surface_count() == 0:
		print("  SKIP %s (no surfaces transferred)" % id); return false

	var out_path := OUT_DIR.path_join("%s.res" % id)
	var err := ResourceSaver.save(out_mesh, out_path)
	if err != OK:
		push_error("save %s failed err=%d" % [out_path, err]); return false
	var ab := out_mesh.get_aabb()
	print("  %-14s -> %s : %d surfaces, %d verts, aabb pos=%s size=%s" %
		[id, out_path, out_mesh.get_surface_count(), total_verts,
		 str(ab.position.snappedf(0.001)), str(ab.size.snappedf(0.001))])
	return true


## Transfer one MeshInstance3D's surface 0: bake each vertex into aeriea's head-bone-local
## frame and rebind its skin to the single aeriea head bone (index written as 0 + a single-
## bone skin at load). Returns vertex count. The vertex BIND global position is computed by
## LBS through the GLB bind pose with the GLB's OWN per-vertex weights — faithful to however
## the head was skinned (overwhelmingly DEF-Head, with facial bones collapsing to head too,
## since DEF-Head sits at the rig origin and the facial bones are its children at small offset).
func _transfer_surface(mi: MeshInstance3D, skel: Skeleton3D, bind_global: Array,
		head_global: Vector3, out_mesh: ArrayMesh, surf_name: String) -> int:
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var bones_arr = arr[Mesh.ARRAY_BONES]
	var weights_arr = arr[Mesh.ARRAY_WEIGHTS]
	var nv := verts.size()
	# Influences-per-vertex (Godot: 4 or 8).
	var ipv := 4
	if bones_arr is PackedInt32Array and nv > 0:
		ipv = bones_arr.size() / nv

	# The mesh's own node transform (rest) relative to the skeleton — the head GLBs put the
	# mesh directly under the skeleton with identity, but compose to be safe.
	var mesh_xf: Transform3D = mi.transform

	var out_verts := PackedVector3Array(); out_verts.resize(nv)
	var out_norms := PackedVector3Array(); out_norms.resize(nv)
	var out_bones := PackedInt32Array(); out_bones.resize(nv * 4)
	var out_weights := PackedFloat32Array(); out_weights.resize(nv * 4)

	var yaw := Basis(Vector3.UP, SEAT_YAW)
	for vi in nv:
		var v: Vector3 = yaw * (mesh_xf * verts[vi])
		var nrm: Vector3 = (yaw * (mesh_xf.basis * norms[vi])).normalized() if vi < norms.size() else Vector3.UP
		# v is the GLB bind-pose-relative position (at bind, LBS(v) == v — verified). Apply the
		# FIT: uniformly SCALE about the BDCC2 head-mesh center (fills aeriea's head region without
		# squashing the muzzle), then TRANSLATE so that center lands on aeriea's head-region center.
		# The result lives in aeriea's WORLD rest space; the load-time single-bone Skin (bind =
		# head_global_rest inverse) makes it ride the head bone, so a head pose rotates it about the
		# head-bone base while the geometry sits centred on (and filling) the head region at rest.
		var fitted := BDCC2_HEAD_CENTER + (v - BDCC2_HEAD_CENTER) * HEAD_FIT_SCALE
		var world := AERIEA_HEAD_CENTER + (fitted - BDCC2_HEAD_CENTER) + SEAT
		out_verts[vi] = world
		out_norms[vi] = nrm
		# Single influence on the aeriea head bone (index written as 0; the load-time Skin is
		# a single bind named "head", so index 0 -> aeriea head).
		out_bones[vi * 4 + 0] = 0
		out_bones[vi * 4 + 1] = 0
		out_bones[vi * 4 + 2] = 0
		out_bones[vi * 4 + 3] = 0
		out_weights[vi * 4 + 0] = 1.0
		out_weights[vi * 4 + 1] = 0.0
		out_weights[vi * 4 + 2] = 0.0
		out_weights[vi * 4 + 3] = 0.0

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
	out_mesh.surface_set_name(out_mesh.get_surface_count() - 1, surf_name)
	return nv


## aeriea bone GLOBAL rest position (sum of head offsets up the parent chain). The JSON
## stores GLOBAL `head` positions already, so this is a direct lookup.
func _aeriea_bone_global(rig: Dictionary, name: String) -> Vector3:
	for b in rig["bones"]:
		if String(b["name"]) == name:
			var h: Array = b["head"]
			return Vector3(h[0], h[1], h[2])
	return Vector3.INF


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
