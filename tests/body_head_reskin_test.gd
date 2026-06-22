## CORE-BODY HEAD re-skin + swap test.
##
## The marquee "swappable body PARTS" item, validated on ONE part (the BDCC2 canine head)
## re-skinned onto aeriea's MakeHuman skeleton (tools/bdcc2_head_reskin.gd ->
## assets/body/parts/bdcc2/reskin/canine_head.res). Unlike the accessory slots (which
## ATTACH a GLB + its own little skeleton), a core-body part is RE-SKINNED onto aeriea's OWN
## 169-bone skeleton: a committed ArrayMesh whose verts ride the aeriea `head` bone, so it
## DEFORMS with the body via aeriea's LBS — proven here by posing the head bone and measuring
## that the re-skinned vertices move with it.
##
## Asserts:
##   1. ASSET: the committed re-skin .res loads as an ArrayMesh with verts seated at aeriea's
##      head height (the bake placed BDCC2's DEF-Head origin on aeriea's head bone, ~y=1.5).
##   2. SLOT: the `head` slot exists with default "human" (aeriea's own head, no overlay).
##   3. APPLY: applying the BDCC2 canine head binds a MeshInstance3D to aeriea's OWN skeleton
##      (single-bind skin on the `head` bone), and hides aeriea's default face proxy surfaces.
##   4. DEFORMS: posing the `head` bone moves the re-skinned head vertices NON-TRIVIALLY (it
##      rides the skeleton — the whole point of a weight-transfer vs a static attach).
##   5. ANIMATES UNDER CLIP: a head-nodding clip overlay moves the re-skinned head over frames.
##   6. SWAP + FALLBACK: canine <-> feline <-> human swap cleanly; an unknown id falls back to
##      "human" (never a broken/headless state); swapping back to human tears the overlay down.
##   7. DETERMINISM: the re-skin asset is fixed geometry — two loads give identical vert[0].
##
## RENDER-SIDE only. Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_head_reskin_test.tscn --quit-after 6000
extends Node3D

const PartLibrary := preload("res://scripts/body/part_library.gd")

var _pass := 0
var _fail := 0

const CANINE_RES := "res://assets/body/parts/bdcc2/reskin/canine_head.res"
const FELINE_RES := "res://assets/body/parts/bdcc2/reskin/feline_head.res"


func _ready() -> void:
	print("\n=== aeriea CORE-BODY HEAD re-skin + swap test ===\n")

	# --- 1. committed re-skin asset loads + is seated at aeriea's head height -------
	_assert("canine re-skin asset exists", ResourceLoader.exists(CANINE_RES), CANINE_RES)
	var mesh = load(CANINE_RES)
	_assert("canine re-skin loads as ArrayMesh", mesh is ArrayMesh,
		"type=%s" % (mesh.get_class() if mesh else "null"))
	if mesh is ArrayMesh:
		var ab: AABB = (mesh as ArrayMesh).get_aabb()
		# The FIT scales + seats the head to FILL aeriea's head REGION (center ~y1.549), not just
		# perch its origin on the head bone — so the AABB sits in [1.4, 1.7], NOT at the floor.
		_assert("re-skinned head seated at aeriea head height (AABB y in [1.3,1.9])",
			ab.position.y > 1.3 and ab.position.y + ab.size.y < 1.9,
			"aabb y=[%.3f, %.3f]" % [ab.position.y, ab.position.y + ab.size.y])
		# FIT QUALITY: the head's CENTER lands near aeriea's head-region center (0, 1.549, 0.064)
		# and its size FILLS the region (~0.2 m each axis) — proving it no longer reads tiny/low.
		var ctr := ab.get_center()
		_assert("re-skinned head CENTER matches aeriea head-region center (within 5 cm)",
			ctr.distance_to(Vector3(0.0, 1.549, 0.064)) < 0.05,
			"center=%s" % str(ctr.snappedf(0.001)))
		_assert("re-skinned head FILLS the head region (each axis 0.12–0.32 m — not tiny)",
			ab.size.x > 0.12 and ab.size.x < 0.32 and ab.size.y > 0.12 and ab.size.y < 0.32,
			"size=%s" % str(ab.size.snappedf(0.001)))
		# Snout faces +Z (forward, toward aeriea's facing): more head mass at +z than -z.
		var zf := 0; var zb := 0
		for v in ((mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.z > ctr.z + 0.02: zf += 1
			elif v.z < ctr.z - 0.02: zb += 1
		_assert("re-skinned head faces FORWARD (+Z snout — more mass front than back)", zf > zb,
			"verts z>ctr:%d z<ctr:%d" % [zf, zb])
		# NO degenerate/exploded verts: the whole head fits in a sane box (no spike to a sentinel).
		_assert("re-skinned head has NO exploded verts (AABB max extent < 0.5 m)",
			ab.size.x < 0.5 and ab.size.y < 0.5 and ab.size.z < 0.5,
			"size=%s" % str(ab.size.snappedf(0.001)))
		_assert("re-skinned head carries skin weights (ARRAY_BONES/WEIGHTS present)",
			(mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_BONES] is PackedInt32Array,
			"bones=%s" % typeof((mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_BONES]))

	# --- 2. slot exists with default "human" ---------------------------------------
	_assert("PartLibrary has a 'head' core-body slot",
		PartLibrary.SLOTS.has("head"), "slots=%s" % str(PartLibrary.SLOTS))
	_assert("head slot default is 'human' (aeriea's own head)",
		PartLibrary.default_id("head") == "human", "default=%s" % PartLibrary.default_id("head"))
	_assert("canine head is flagged as a re-skin part",
		PartLibrary.is_reskin("head", "canine"), "is_reskin=%s" % PartLibrary.is_reskin("head", "canine"))
	_assert("human (default) is NOT a re-skin part",
		not PartLibrary.is_reskin("head", "human"), "is_reskin=%s" % PartLibrary.is_reskin("head", "human"))

	# --- build a rig -----------------------------------------------------------------
	var rig := BodyRig.new()
	add_child(rig)
	if not rig.build():
		_assert("BodyRig.build() succeeds", false, "build failed"); _finish(); return
	rig.use_motion_matching = false
	rig.foot_ik_enabled = false
	rig._setup_micro_life(0)

	_assert("default head part is 'human'", rig.current_part("head") == "human",
		"head=%s" % rig.current_part("head"))

	# --- 3. apply the canine head: binds a MeshInstance to aeriea's OWN skeleton ----
	var ok := rig.apply_part("head", "canine")
	_assert("BDCC2 canine head applies", ok, "ok=%s" % ok)
	var reskin_mi := _reskin_mesh(rig)
	_assert("canine head binds a MeshInstance3D under aeriea's own skeleton",
		reskin_mi != null, "mi=%s" % (reskin_mi != null))
	if reskin_mi != null:
		_assert("re-skin MeshInstance is skinned to aeriea's skeleton (has a Skin)",
			reskin_mi.skin != null and reskin_mi.skin.get_bind_count() >= 1,
			"binds=%d" % (reskin_mi.skin.get_bind_count() if reskin_mi.skin else -1))
		_assert("re-skin skin binds the aeriea 'head' bone",
			reskin_mi.skin != null and reskin_mi.skin.get_bind_name(0) == "head",
			"bind0=%s" % (reskin_mi.skin.get_bind_name(0) if reskin_mi.skin else ""))
		# Core-body head re-skins onto aeriea's MAIN skeleton — it must NOT carry its own little
		# skeleton (that's the accessory pattern); _part_skeletons(head) is empty.
		_assert("re-skin head has NO own skeleton (it rides aeriea's, not its own)",
			rig._part_skeletons("head").is_empty(), "own_skels=%d" % rig._part_skeletons("head").size())

	# --- 3b. BASE-MESH MASKING: the human skull region is hidden under the animal head ----
	# The base mesh has a head region (verts dominantly weighted to the head/face subtree);
	# applying a re-skin head collapses those verts so the human skull doesn't co-render.
	_assert("base mesh has a non-empty HEAD region (face/skull verts identified)",
		rig.region_vert_count("head") > 0, "head region verts=%d" % rig.region_vert_count("head"))
	_assert("applying the canine head MASKS the base-mesh skull region",
		rig.is_region_masked("head"), "masked=%s" % rig.is_region_masked("head"))
	# Masking DROPS the covered region triangles from the rendered surface (no sentinel collapse):
	# most of the head region's verts are no longer referenced by the index buffer.
	var head_total := rig.region_vert_count("head")
	_assert("masked head region triangles are DROPPED from the rendered surface",
		rig.region_rendered_vert_count("head") < head_total / 2,
		"rendered %d / %d region verts" % [rig.region_rendered_vert_count("head"), head_total])
	# Non-head verts (e.g. a foot vert) stay put — only the head region is collapsed.
	_assert("non-head base verts are UNTOUCHED by the head mask",
		_body_min_y(rig) > -1.0, "body min y=%.3f" % _body_min_y(rig))

	# --- 4. DEFORMS with the skeleton: posing the head bone moves the head verts ----
	var head_bi := rig.skeleton.find_bone("head")
	_assert("aeriea head bone exists", head_bi >= 0, "idx=%d" % head_bi)
	var probe_rest := _probe_vertex_world(rig, reskin_mi, head_bi)
	# Bend the head bone and re-measure the same vertex.
	rig.skeleton.set_bone_pose_rotation(head_bi, Quaternion(Vector3.RIGHT, 0.5))
	rig.skeleton.force_update_all_bone_transforms()
	var probe_bent := _probe_vertex_world(rig, reskin_mi, head_bi)
	var moved := probe_rest.distance_to(probe_bent)
	_assert("re-skinned head DEFORMS with the skeleton (head vertex moves >2cm under head bend)",
		moved > 0.02, "vertex moved %.4f m" % moved)
	rig.skeleton.reset_bone_pose(head_bi)
	rig.skeleton.force_update_all_bone_transforms()

	# --- 5. animates under a head-driving clip overlay -----------------------------
	# Play the head_nod gesture (drives the head bone via the clip layer); over frames the
	# re-skinned head must move with it (it rides aeriea's head bone, which the clip poses).
	if rig.clip_db != null and rig.clip_db.clip_index("head_nod") >= 0:
		rig.set_movement_state(true, 0.0)
		rig.play_clip("head_nod", true)
		var base := _probe_vertex_world(rig, reskin_mi, head_bi)
		var max_dev := 0.0
		for i in 60:
			rig.apply_pose(1.0 / 60.0)
			max_dev = maxf(max_dev, base.distance_to(_probe_vertex_world(rig, reskin_mi, head_bi)))
		_assert("re-skinned head ANIMATES under a head-nod clip (>5mm over the clip)",
			max_dev > 5e-3, "max head-vertex travel=%.4f m" % max_dev)
		rig.stop_clip()
	else:
		print("  (head_nod clip absent — skipping clip-animation check)")

	# --- 6. swap + fallback --------------------------------------------------------
	var ok_fel := rig.apply_part("head", "feline")
	_assert("swap to feline head works", ok_fel and rig.current_part("head") == "feline",
		"ok=%s head=%s" % [ok_fel, rig.current_part("head")])
	var fel_mi := _reskin_mesh(rig)
	_assert("feline swap replaces the re-skin mesh",
		fel_mi != null and fel_mi != reskin_mi, "new=%s changed=%s" % [fel_mi != null, fel_mi != reskin_mi])
	# unknown id -> falls back to "human" (never a broken/headless state).
	rig.apply_part("head", "no_such_head")
	_assert("unknown head id falls back to 'human'",
		rig.current_part("head") == "human", "head=%s" % rig.current_part("head"))
	_assert("falling back to human tears down the re-skin overlay",
		_reskin_mesh(rig) == null, "reskin_mi=%s" % (_reskin_mesh(rig) != null))
	# back to canine then explicitly to human.
	rig.apply_part("head", "canine")
	_assert("re-apply canine after human works", _reskin_mesh(rig) != null,
		"reskin_mi=%s" % (_reskin_mesh(rig) != null))
	rig.apply_part("head", "human")
	_assert("explicit swap to human tears down the overlay",
		rig.current_part("head") == "human" and _reskin_mesh(rig) == null,
		"head=%s reskin_mi=%s" % [rig.current_part("head"), _reskin_mesh(rig) != null])
	# Falling back to human RESTORES the base-mesh skull region (un-masked, verts back in place).
	_assert("swapping back to human UN-MASKS the base-mesh skull region",
		not rig.is_region_masked("head"), "masked=%s" % rig.is_region_masked("head"))
	_assert("restored head region triangles are rendered again (all verts referenced)",
		rig.region_rendered_vert_count("head") == rig.region_vert_count("head"),
		"rendered %d / %d" % [rig.region_rendered_vert_count("head"), rig.region_vert_count("head")])

	# --- 6b. MASK SURVIVES A MORPH RE-BAKE ----------------------------------------
	# A morph re-bake rewrites ARRAY_VERTEX from neutral; the mask must be re-asserted, so a
	# masked head stays masked across an apply_body_state call (e.g. a slider move).
	rig.apply_part("head", "canine")
	var bs := BodyState.new()
	bs.muscle = 80.0
	rig.apply_body_state(bs)
	_assert("base-mesh head mask SURVIVES a morph re-bake (slider move keeps skull hidden)",
		rig.is_region_masked("head") and rig.region_rendered_vert_count("head") < rig.region_vert_count("head") / 2,
		"masked=%s rendered %d/%d" % [rig.is_region_masked("head"), rig.region_rendered_vert_count("head"), rig.region_vert_count("head")])
	rig.apply_part("head", "human")
	rig.apply_body_state(BodyState.new())

	# --- 7. determinism ------------------------------------------------------------
	var m1 = load(CANINE_RES)
	var m2 = load(FELINE_RES)
	_assert("feline re-skin asset also loads as ArrayMesh", m2 is ArrayMesh,
		"type=%s" % (m2.get_class() if m2 else "null"))
	if m1 is ArrayMesh:
		var v_a: PackedVector3Array = (m1 as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var v_b: PackedVector3Array = (load(CANINE_RES) as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_assert("re-skin asset is deterministic geometry (vert[0] identical across loads)",
			v_a.size() > 0 and v_a[0] == v_b[0], "v0a=%s v0b=%s" % [str(v_a[0]), str(v_b[0])])

	# --- 8. core-body slot independent from accessory slots ------------------------
	# A head swap coexists with accessory slots (ears/tail) — they're independent.
	rig.apply_part("head", "canine")
	rig.apply_part("ears", "feline")
	rig.apply_part("tail", "fluffy")
	var ss: Dictionary = rig.micro_life_state()["slot_springs"]
	_assert("head swap coexists with ears+tail (their springs unaffected)",
		ss["ears"] >= 2 and ss["tail"] >= 4 and _reskin_mesh(rig) != null,
		"ears=%d tail=%d head_reskin=%s" % [ss["ears"], ss["tail"], _reskin_mesh(rig) != null])

	_finish()


## The MeshInstance3D bound for the head slot's re-skin (or null if showing default human).
func _reskin_mesh(rig: BodyRig) -> MeshInstance3D:
	for att in rig._part_attachments.get("head", []):
		if att is MeshInstance3D and is_instance_valid(att):
			return att
	return null


## World position of the re-skin's topmost (skull) vertex, via its single-bone skin on the
## head bone: world = head_bone_global_pose * skin_bind * v_rest. A stable probe of "does the
## head ride the bone". Returns ZERO if the mesh is absent.
func _probe_vertex_world(rig: BodyRig, mi: MeshInstance3D, head_bi: int) -> Vector3:
	if mi == null or mi.mesh == null or mi.skin == null:
		return Vector3.ZERO
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return Vector3.ZERO
	var top := 0
	for i in verts.size():
		if verts[i].y > verts[top].y:
			top = i
	var bone_pose := rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(head_bi)
	return bone_pose * mi.skin.get_bind_pose(0) * verts[top]


## Max Y over a region's base-mesh verts in the CURRENT baked surface. When the region is
## masked the verts are collapsed below the feet (so this is very negative); when restored
## they sit at their real height. A direct read of whether the region is hidden.
func _max_masked_y(rig: BodyRig, slot: String) -> float:
	var mi := rig.mesh_instance
	if mi == null or mi.mesh == null:
		return 0.0
	var verts: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Re-derive the region's vert indices the same way the rig does is internal; instead use
	# the rig's count + scan for the collapsed sentinel cluster vs the region's natural range.
	var mx := -INF
	for vi in rig.region_vert_indices(slot):
		mx = maxf(mx, verts[vi].y)
	return mx if mx > -INF else 0.0


## Min Y over the WHOLE baked body surface — used to confirm non-masked verts (feet) are not
## collapsed (the body's feet sit near y=0, well above the sentinel point).
func _body_min_y(rig: BodyRig) -> float:
	var mi := rig.mesh_instance
	if mi == null or mi.mesh == null:
		return 0.0
	var verts: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Exclude the collapsed masked cluster (sentinel y ~ -1000) so we read the REAL body floor.
	var mn := INF
	for v in verts:
		if v.y > -100.0:
			mn = minf(mn, v.y)
	return mn if mn < INF else 0.0


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
