## CORE-BODY LEG MULTI-BONE re-skin + swap test.
##
## The generalization of the head re-skin (single-bone collapse) to a TRUE MULTI-BONE body
## re-skin, validated on ONE part: the BDCC2 DIGITIGRADE leg mesh (tools/bdcc2_body_reskin.gd
## -> assets/body/parts/bdcc2/reskin/digi_legs.res). The leg is skinned across MANY BDCC2 bones
## (thigh/shin/foot/knee L+R) and rebound onto aeriea's MakeHuman leg bones (upperleg01/
## lowerleg01/foot, L+R) via bdcc2_bone_map, carrying REAL aeriea bone indices — so under
## aeriea's OWN LBS it DEFORMS joint-by-joint: bend the knee, the shin/foot follow while the
## thigh stays; bend the hip, the whole leg swings. Proven by posing those bones and measuring.
##
## Asserts:
##   1. ASSET: the committed multi-bone re-skin loads as an ArrayMesh seated at leg height
##      (feet ~y0, hips ~y0.9) carrying per-vertex ARRAY_BONES across MULTIPLE aeriea bones.
##   2. SLOT: the `legs` core-body slot exists with default "human"; digitigrade is multibone.
##   3. APPLY: applying it binds a MeshInstance3D to aeriea's OWN skeleton with a FULL skin
##      (>1 bind), riding aeriea's leg bones.
##   4. MULTI-BONE DEFORM: bending the KNEE moves a foot-region vertex but NOT a thigh-region
##      vertex (independent lower-leg deformation); bending the HIP swings BOTH (whole-leg
##      chain). This is the multi-bone property a single-bone collapse cannot have.
##   5. ANIMATES UNDER LOCOMOTION: a walk pose / MM step moves the leg verts over frames.
##   6. SWAP + FALLBACK: digitigrade <-> plantigrade <-> human swap cleanly; unknown id falls
##      back to "human" (never broken); swapping to human tears the overlay down.
##   7. DETERMINISM: the re-skin asset is fixed geometry — two loads give identical vert[0].
##
## RENDER-SIDE only. Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_leg_reskin_test.tscn --quit-after 6000
extends Node3D

const PartLibrary := preload("res://scripts/body/part_library.gd")

var _pass := 0
var _fail := 0

const DIGI_RES := "res://assets/body/parts/bdcc2/reskin/digi_legs.res"
const PLANTI_RES := "res://assets/body/parts/bdcc2/reskin/planti_legs.res"


func _ready() -> void:
	print("\n=== aeriea CORE-BODY LEG multi-bone re-skin + swap test ===\n")

	# --- 1. committed multi-bone re-skin asset ------------------------------------
	_assert("digi-legs re-skin asset exists", ResourceLoader.exists(DIGI_RES), DIGI_RES)
	var mesh = load(DIGI_RES)
	_assert("digi-legs re-skin loads as ArrayMesh", mesh is ArrayMesh,
		"type=%s" % (mesh.get_class() if mesh else "null"))
	if mesh is ArrayMesh:
		var ab: AABB = (mesh as ArrayMesh).get_aabb()
		# Legs span feet (~y0) to hips (~y0.9). Bottom near floor, top below the waist.
		_assert("re-skinned legs seated at leg height (AABB y in [-0.05, 1.0])",
			ab.position.y > -0.05 and ab.position.y + ab.size.y < 1.0,
			"aabb y=[%.3f, %.3f]" % [ab.position.y, ab.position.y + ab.size.y])
		# MULTI-BONE: the surface's ARRAY_BONES must reference MORE THAN ONE unique aeriea bone.
		var bones0: PackedInt32Array = (mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_BONES]
		var uniq := {}
		for b in bones0:
			uniq[b] = true
		_assert("re-skinned legs span MULTIPLE aeriea bones (true multi-bone, not single collapse)",
			uniq.size() >= 4, "unique aeriea bones=%d" % uniq.size())

	# --- 2. slot exists, default human, digitigrade is multibone -------------------
	_assert("PartLibrary has a 'legs' core-body slot",
		PartLibrary.SLOTS.has("legs"), "slots=%s" % str(PartLibrary.SLOTS))
	_assert("legs slot default is 'human'",
		PartLibrary.default_id("legs") == "human", "default=%s" % PartLibrary.default_id("legs"))
	_assert("digitigrade is a re-skin part", PartLibrary.is_reskin("legs", "digitigrade"),
		"is_reskin=%s" % PartLibrary.is_reskin("legs", "digitigrade"))
	_assert("digitigrade is flagged MULTI-BONE", PartLibrary.is_multibone("legs", "digitigrade"),
		"multibone=%s" % PartLibrary.is_multibone("legs", "digitigrade"))
	_assert("head canine is NOT multibone (single-bone collapse)",
		not PartLibrary.is_multibone("head", "canine"),
		"multibone=%s" % PartLibrary.is_multibone("head", "canine"))

	# --- build a rig -------------------------------------------------------------
	var rig := BodyRig.new()
	add_child(rig)
	if not rig.build():
		_assert("BodyRig.build() succeeds", false, "build failed"); _finish(); return
	rig.foot_ik_enabled = false
	rig._setup_micro_life(0)

	# --- 3. apply: binds a MeshInstance with a FULL multi-bind skin ---------------
	var ok := rig.apply_part("legs", "digitigrade")
	_assert("BDCC2 digitigrade legs apply", ok, "ok=%s" % ok)
	var mi := _reskin_mesh(rig)
	_assert("digitigrade binds a MeshInstance3D under aeriea's own skeleton", mi != null,
		"mi=%s" % (mi != null))
	if mi != null:
		_assert("re-skin uses a FULL multi-bone Skin (>1 bind)",
			mi.skin != null and mi.skin.get_bind_count() > 1,
			"binds=%d" % (mi.skin.get_bind_count() if mi.skin else -1))
		_assert("re-skin legs have NO own skeleton (they ride aeriea's, not their own)",
			rig._part_skeletons("legs").is_empty(), "own_skels=%d" % rig._part_skeletons("legs").size())

	# --- 3b. BASE-MESH MASKING: the human leg region is hidden under the digi legs ----
	_assert("base mesh has a non-empty LEGS region (thigh/shin/foot/toe verts identified)",
		rig.region_vert_count("legs") > 0, "legs region verts=%d" % rig.region_vert_count("legs"))
	_assert("applying the digitigrade legs MASKS the base-mesh leg region",
		rig.is_region_masked("legs"), "masked=%s" % rig.is_region_masked("legs"))
	_assert("masked leg verts are collapsed off the body (below feet)",
		_region_max_y(rig, "legs") < -100.0, "max masked y=%.1f" % _region_max_y(rig, "legs"))
	# The head/torso region of the base mesh is untouched (only the legs collapsed).
	_assert("base-mesh torso/head verts are UNTOUCHED by the leg mask",
		_body_max_y(rig) > 1.0, "body max y=%.3f" % _body_max_y(rig))

	# --- 4. MULTI-BONE deformation -----------------------------------------------
	# Pick a thigh-region vertex (highest y) and a foot-region vertex (lowest y) on surface 0,
	# along with the aeriea bone each rides.
	var dmesh := mi.mesh as ArrayMesh
	var verts: PackedVector3Array = dmesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vbones: PackedInt32Array = dmesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = dmesh.surface_get_arrays(0)[Mesh.ARRAY_WEIGHTS]
	var hi := 0
	var lo := 0
	for i in verts.size():
		if verts[i].y > verts[hi].y: hi = i
		if verts[i].y < verts[lo].y: lo = i
	var thigh_bone: int = vbones[hi * 4]
	var foot_bone: int = vbones[lo * 4]
	_assert("thigh-region and foot-region verts ride DIFFERENT aeriea bones",
		thigh_bone != foot_bone, "thigh rides %s, foot rides %s" %
		[rig.skeleton.get_bone_name(thigh_bone), rig.skeleton.get_bone_name(foot_bone)])

	var hi0 := _lbs_world(rig.skeleton, mi.skin, verts, vbones, weights, hi)
	var lo0 := _lbs_world(rig.skeleton, mi.skin, verts, vbones, weights, lo)

	# Bend the bone the FOOT vertex rides (the knee/lower-leg joint). Foot region must swing;
	# thigh region (upstream) must NOT move — independent lower-leg deformation.
	rig.skeleton.set_bone_pose_rotation(foot_bone, Quaternion(Vector3.RIGHT, 1.0))
	rig.skeleton.force_update_all_bone_transforms()
	var foot_moved_knee := lo0.distance_to(_lbs_world(rig.skeleton, mi.skin, verts, vbones, weights, lo))
	var thigh_moved_knee := hi0.distance_to(_lbs_world(rig.skeleton, mi.skin, verts, vbones, weights, hi))
	_assert("knee bend swings the FOOT region (>2cm)", foot_moved_knee > 0.02,
		"foot moved %.4f m" % foot_moved_knee)
	_assert("knee bend leaves the THIGH region (<2mm) — independent lower-leg deform",
		thigh_moved_knee < 0.002, "thigh moved %.4f m" % thigh_moved_knee)
	rig.skeleton.reset_bone_pose(foot_bone)
	rig.skeleton.force_update_all_bone_transforms()

	# Bend the bone the THIGH vertex rides (the hip). The whole leg swings: BOTH verts move.
	rig.skeleton.set_bone_pose_rotation(thigh_bone, Quaternion(Vector3.RIGHT, 0.7))
	rig.skeleton.force_update_all_bone_transforms()
	var thigh_moved_hip := hi0.distance_to(_lbs_world(rig.skeleton, mi.skin, verts, vbones, weights, hi))
	var foot_moved_hip := lo0.distance_to(_lbs_world(rig.skeleton, mi.skin, verts, vbones, weights, lo))
	_assert("hip bend swings the THIGH region (>2cm)", thigh_moved_hip > 0.02,
		"thigh moved %.4f m" % thigh_moved_hip)
	_assert("hip bend swings the FOOT region too (whole-leg chain, >2cm)", foot_moved_hip > 0.02,
		"foot moved %.4f m" % foot_moved_hip)
	rig.skeleton.reset_bone_pose(thigh_bone)
	rig.skeleton.force_update_all_bone_transforms()

	# --- 5. animates under locomotion --------------------------------------------
	rig.set_movement_state(true, 4.0)   # walking forward
	var base := _lbs_world(rig.skeleton, mi.skin, verts, vbones, weights, lo)
	var max_dev := 0.0
	for i in 90:
		rig.apply_pose(1.0 / 60.0)
		max_dev = maxf(max_dev, base.distance_to(_lbs_world(rig.skeleton, mi.skin, verts, vbones, weights, lo)))
	_assert("re-skinned legs ANIMATE under locomotion (foot vert travels >1cm over a walk)",
		max_dev > 0.01, "max foot-vertex travel=%.4f m" % max_dev)
	rig.set_movement_state(true, 0.0)
	rig.apply_pose(1.0 / 60.0)

	# --- 6. swap + fallback ------------------------------------------------------
	var ok_pl := rig.apply_part("legs", "plantigrade")
	_assert("swap to plantigrade legs works",
		ok_pl and rig.current_part("legs") == "plantigrade",
		"ok=%s legs=%s" % [ok_pl, rig.current_part("legs")])
	var pl_mi := _reskin_mesh(rig)
	_assert("plantigrade swap replaces the re-skin mesh",
		pl_mi != null and pl_mi != mi, "new=%s changed=%s" % [pl_mi != null, pl_mi != mi])
	rig.apply_part("legs", "no_such_legs")
	_assert("unknown legs id falls back to 'human'",
		rig.current_part("legs") == "human", "legs=%s" % rig.current_part("legs"))
	_assert("falling back to human tears down the re-skin overlay",
		_reskin_mesh(rig) == null, "reskin_mi=%s" % (_reskin_mesh(rig) != null))
	rig.apply_part("legs", "digitigrade")
	_assert("re-apply digitigrade after human works", _reskin_mesh(rig) != null,
		"reskin_mi=%s" % (_reskin_mesh(rig) != null))
	rig.apply_part("legs", "human")
	_assert("explicit swap to human tears down the overlay",
		rig.current_part("legs") == "human" and _reskin_mesh(rig) == null,
		"legs=%s reskin_mi=%s" % [rig.current_part("legs"), _reskin_mesh(rig) != null])
	# Falling back to human RESTORES the base-mesh leg region (un-masked, verts back in place).
	_assert("swapping back to human UN-MASKS the base-mesh leg region",
		not rig.is_region_masked("legs"), "masked=%s" % rig.is_region_masked("legs"))
	_assert("restored leg verts are back at leg height (region present again)",
		_region_max_y(rig, "legs") > 0.0, "max leg-region y=%.3f" % _region_max_y(rig, "legs"))
	# MASK SURVIVES A MORPH RE-BAKE (a slider move keeps the human legs hidden).
	rig.apply_part("legs", "digitigrade")
	var bs := BodyState.new()
	bs.muscle = 80.0
	rig.apply_body_state(bs)
	_assert("base-mesh leg mask SURVIVES a morph re-bake (slider move keeps human legs hidden)",
		rig.is_region_masked("legs") and _region_max_y(rig, "legs") < -100.0,
		"masked=%s max masked y=%.1f" % [rig.is_region_masked("legs"), _region_max_y(rig, "legs")])
	rig.apply_part("legs", "human")
	rig.apply_body_state(BodyState.new())

	# --- 7. determinism ----------------------------------------------------------
	var m2 = load(PLANTI_RES)
	_assert("plantigrade re-skin also loads as ArrayMesh", m2 is ArrayMesh,
		"type=%s" % (m2.get_class() if m2 else "null"))
	var v_a: PackedVector3Array = (load(DIGI_RES) as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var v_b: PackedVector3Array = (load(DIGI_RES) as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_assert("re-skin asset is deterministic geometry (vert[0] identical across loads)",
		v_a.size() > 0 and v_a[0] == v_b[0], "v0a=%s v0b=%s" % [str(v_a[0]), str(v_b[0])])

	# --- 8. legs slot coexists with head + accessories ---------------------------
	rig.apply_part("legs", "digitigrade")
	rig.apply_part("head", "canine")
	rig.apply_part("tail", "fluffy")
	var ss: Dictionary = rig.micro_life_state()["slot_springs"]
	_assert("legs swap coexists with head + tail (independent slots)",
		_reskin_mesh(rig) != null and ss["tail"] >= 4 and rig.current_part("head") == "canine",
		"legs_reskin=%s tail=%d head=%s" % [_reskin_mesh(rig) != null, ss["tail"], rig.current_part("head")])

	_finish()


## The MeshInstance3D bound for the legs slot's re-skin (or null if showing default human).
func _reskin_mesh(rig: BodyRig) -> MeshInstance3D:
	for att in rig._part_attachments.get("legs", []):
		if att is MeshInstance3D and is_instance_valid(att):
			return att
	return null


## LBS world position of vertex vi via the multi-bone skin (bind i -> bone i, so the
## ARRAY_BONES index is both the bone AND the bind index). Sum of weighted contributions.
func _lbs_world(skel: Skeleton3D, skin: Skin, verts: PackedVector3Array,
		bones: PackedInt32Array, weights: PackedFloat32Array, vi: int) -> Vector3:
	var p := Vector3.ZERO
	for k in 4:
		var w: float = weights[vi * 4 + k]
		if w <= 0.0:
			continue
		var bidx: int = bones[vi * 4 + k]
		p += w * (skel.get_bone_global_pose(bidx) * skin.get_bind_pose(bidx) * verts[vi])
	return p


## Max Y over a region's base-mesh verts in the CURRENT baked surface (very negative when the
## region is masked/collapsed below the feet; ~leg height when restored).
func _region_max_y(rig: BodyRig, slot: String) -> float:
	var mi := rig.mesh_instance
	if mi == null or mi.mesh == null:
		return 0.0
	var verts: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mx := -INF
	for vi in rig.region_vert_indices(slot):
		mx = maxf(mx, verts[vi].y)
	return mx if mx > -INF else 0.0


## Max Y over the whole baked body surface (excluding the collapsed cluster) — the head/torso
## top, used to confirm the leg mask leaves the upper body untouched.
func _body_max_y(rig: BodyRig) -> float:
	var mi := rig.mesh_instance
	if mi == null or mi.mesh == null:
		return 0.0
	var verts: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mx := -INF
	for v in verts:
		mx = maxf(mx, v.y)
	return mx if mx > -INF else 0.0


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
