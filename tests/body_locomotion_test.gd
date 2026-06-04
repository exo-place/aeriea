## Slice-3 body locomotion + skinning test
## (docs/decisions/body-and-locomotion-slice.md §4, Slice 3 verify).
##
## Asserts the four Slice-3 properties:
##   1. SKIN: base_body.res carries per-vertex LBS data (ARRAY_BONES/ARRAY_WEIGHTS,
##      4 influences/vertex, weights ~normalized) and BodyRig builds a Skeleton3D
##      with the expected bone count (163, the MakeHuman default rig).
##   2. SKIN DEFORMS: posing a bone moves the skinned mesh — proven by computing
##      the linear-blend-skinned position of a vertex weighted to that bone (via
##      the bone/weight arrays + skeleton global poses + Skin bind poses) before
##      and after rotating the bone, and measuring a nonzero displacement.
##   3. FOOT-IK: with a flat ground StaticBody under the body, the foot-IK ray
##      hits the surface and the foot is planted at ~ground height.
##   4. PROCEDURAL LOCOMOTION reads MovementState: the cycle phase advances when
##      horizontal speed > 0 and FREEZES at rest (idle); leg-bone pose differs
##      from rest while "running" and returns to rest when stopped.
##
## RENDER-SIDE only — this test exercises the pose layer in isolation; the sim
## regression guard is the (unchanged) movement_behavior + golden_trace suites.
##
## Run windowed under xvfb (a real PhysicsDirectSpaceState3D is needed for IK):
##   xvfb-run -a godot4 --path . res://tests/body_locomotion_test.tscn --quit-after 6000
extends Node3D

const EXPECTED_BONES := 163

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea body SLICE 3 locomotion + skin test ===\n")

	# --- 1. SKIN DATA present on the mesh ------------------------------------
	var mesh: ArrayMesh = load(BodyRig.MESH_PATH)
	_assert("mesh loads", mesh != null, BodyRig.MESH_PATH)
	if mesh == null:
		_finish(); return
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	_assert("mesh has ARRAY_BONES", bones.size() > 0, "%d" % bones.size())
	_assert("mesh has ARRAY_WEIGHTS", weights.size() > 0, "%d" % weights.size())
	_assert("4 bone influences per vertex", bones.size() == verts.size() * 4,
		"%d bones / %d verts" % [bones.size(), verts.size()])
	# weights per vertex sum ~1 (renormalized) — check a sample
	var sum0 := weights[0] + weights[1] + weights[2] + weights[3]
	_assert("vertex 0 weights normalized (sum~1)", absf(sum0 - 1.0) < 1e-3, "sum=%.5f" % sum0)

	# --- build the rig -------------------------------------------------------
	var rig := BodyRig.new()
	add_child(rig)
	var built := rig.build()
	_assert("BodyRig.build() succeeds", built, str(built))
	if not built:
		_finish(); return
	_assert("skeleton bone count == %d" % EXPECTED_BONES,
		rig.skeleton.get_bone_count() == EXPECTED_BONES,
		"got %d" % rig.skeleton.get_bone_count())
	_assert("skinned MeshInstance3D present with Skin",
		rig.mesh_instance != null and rig.mesh_instance.skin != null,
		"skin binds=%d" % (rig.mesh_instance.skin.get_bind_count() if rig.mesh_instance and rig.mesh_instance.skin else -1))

	# --- 2. SKIN DEFORMS: posing a bone moves a skinned vertex ---------------
	# Pick a vertex heavily weighted to a leg bone, compute its LBS position at
	# rest, rotate the bone, recompute, and require movement.
	var foot_idx := rig.skeleton.find_bone("lowerleg01.L")
	_assert("test bone 'lowerleg01.L' exists", foot_idx >= 0, "idx=%d" % foot_idx)
	if foot_idx >= 0:
		var vtx := _find_vertex_weighted_to(bones, weights, foot_idx)
		_assert("found a vertex weighted to test bone", vtx >= 0, "vtx=%d" % vtx)
		if vtx >= 0:
			var skin: Skin = rig.mesh_instance.skin
			var p_rest := _skinned_pos(verts, bones, weights, rig.skeleton, skin, vtx)
			# rotate the bone hard about local X
			rig.skeleton.set_bone_pose_rotation(foot_idx,
				rig.skeleton.get_bone_pose_rotation(foot_idx) * Quaternion(Vector3.RIGHT, 0.8))
			var p_posed := _skinned_pos(verts, bones, weights, rig.skeleton, skin, vtx)
			var disp := p_rest.distance_to(p_posed)
			_assert("posing a bone deforms the skinned vertex (disp > 5mm)", disp > 0.005,
				"disp=%.4f m" % disp)
			# restore
			rig.skeleton.reset_bone_pose(foot_idx)

	# --- 2b. RUNTIME-BUILT MESH carries UVs + per-morph normals --------------
	# The bug that slipped through 6933c5a's asset-only test: a fix can be verified
	# on base_body.res yet not reach what the player SEES, because the rendered body
	# is BodyRig.mesh_instance.mesh. Assert UVs and blendshape normals on the mesh
	# BodyRig actually hands the renderer — the user's real view, not the raw asset.
	var rt_mesh := rig.mesh_instance.mesh as ArrayMesh
	_assert("BodyRig renders an ArrayMesh", rt_mesh != null, str(rt_mesh))
	if rt_mesh != null:
		var rt := rt_mesh.surface_get_arrays(0)
		var rt_verts: PackedVector3Array = rt[Mesh.ARRAY_VERTEX]
		var rt_uv: PackedVector2Array = rt[Mesh.ARRAY_TEX_UV]
		_assert("runtime mesh has a UV array", rt_uv != null and rt_uv.size() > 0,
			"uv=%d" % (rt_uv.size() if rt_uv else 0))
		_assert("runtime UV array sized to runtime verts",
			rt_uv != null and rt_uv.size() == rt_verts.size(),
			"uv=%d verts=%d" % [rt_uv.size() if rt_uv else 0, rt_verts.size()])
		# Non-degenerate: a body that lost UVs collapses every UV to (0,0); the real
		# atlas spreads across many distinct coords spanning >0.5 in both axes.
		var distinct := {}
		var umin := INF; var umax := -INF; var vmin := INF; var vmax := -INF
		if rt_uv != null:
			for u in rt_uv:
				distinct[Vector2(snappedf(u.x, 0.001), snappedf(u.y, 0.001))] = true
				umin = minf(umin, u.x); umax = maxf(umax, u.x)
				vmin = minf(vmin, u.y); vmax = maxf(vmax, u.y)
		_assert("runtime UVs non-degenerate (>1000 distinct)", distinct.size() > 1000,
			"%d distinct" % distinct.size())
		_assert("runtime UVs span the atlas (>0.5 each axis)",
			(umax - umin) > 0.5 and (vmax - vmin) > 0.5,
			"u span %.3f v span %.3f" % [umax - umin, vmax - vmin])
		# Blendshapes morph POSITION; their normals must be recomputed from the
		# morphed geometry, not copied from the base (stale base normals shade the
		# morphed body wrongly and break any future normal-mapped skin). Assert each
		# blendshape ships a full-size normal array that DIFFERS from the base normals.
		var base_n: PackedVector3Array = rt[Mesh.ARRAY_NORMAL]
		var bsa := rt_mesh.surface_get_blend_shape_arrays(0)
		_assert("runtime mesh has blendshapes", bsa.size() > 0, "%d" % bsa.size())
		var all_have_normals := true
		var any_differs := false
		for bi in bsa.size():
			var bn = bsa[bi][Mesh.ARRAY_NORMAL]
			if bn == null or (bn as PackedVector3Array).size() != base_n.size():
				all_have_normals = false
				continue
			for i in base_n.size():
				if (bn[i] - base_n[i]).length() > 1e-4:
					any_differs = true
					break
		_assert("every blendshape carries a full normal array", all_have_normals, "")
		_assert("blendshape normals recomputed from morphed geometry (differ from base)",
			any_differs, "no blendshape normal differed from base")

	# --- 3. FOOT-IK plants a foot on a raycast surface -----------------------
	# Place a flat ground StaticBody just under the rig and run IK.
	var ground := _make_ground(0.0)
	add_child(ground)
	# let physics register the body
	await get_tree().physics_frame
	await get_tree().physics_frame
	rig.setup_ik(get_world_3d().direct_space_state, [])  # nothing to exclude here
	# put the rig slightly above ground so feet hover, then IK should pull a target
	# onto the surface.
	rig.global_position = Vector3(0, 0.05, 0)
	await get_tree().physics_frame
	var fhit := rig._foot_ground(BodyRig.FOOT_L)
	_assert("foot-IK ray hits the ground surface", fhit.has("position"),
		str(fhit.keys()))
	if fhit.has("position"):
		var gy: float = (fhit["position"] as Vector3).y
		_assert("foot-IK target at ~ground height (y~0)", absf(gy) < 0.02,
			"hit y=%.4f" % gy)
		# normal points up on flat ground
		var n: Vector3 = fhit["normal"]
		_assert("foot-IK surface normal ~up on flat ground", n.dot(Vector3.UP) > 0.95,
			"n=%s" % str(n))

	# --- 4. PROCEDURAL LOCOMOTION responds to MovementState ------------------
	# Slice 4 added Motion Matching, which apply_pose() prefers when a MotionDB is
	# loaded. This section tests the Slice-3 PROCEDURAL floor (the graceful-
	# degradation path that still ships when no MM DB is present), so disable MM
	# here and drive the analytic cycle directly. (MM itself is covered by
	# body_motion_matching_test.)
	rig.use_motion_matching = false
	rig.foot_ik_enabled = false   # isolate the cycle from IK for this assertion
	# At REST: phase must not advance, leg returns to rest.
	rig.set_movement_state(true, 0.0)
	rig._smoothed_speed = 0.0
	var phase_rest_a := rig._phase
	for i in 10:
		rig.apply_pose(1.0 / 60.0)
	var phase_rest_b := rig._phase
	_assert("idle: phase does not advance at rest", is_equal_approx(phase_rest_a, phase_rest_b),
		"%.5f -> %.5f" % [phase_rest_a, phase_rest_b])
	var hip_l := rig.skeleton.find_bone("upperleg01.L")
	var rest_q := rig.skeleton.get_bone_rest(hip_l).basis.get_rotation_quaternion()
	var idle_q := rig.skeleton.get_bone_pose_rotation(hip_l)
	_assert("idle: hip near rest pose", rest_q.angle_to(idle_q) < 0.05,
		"angle=%.4f rad" % rest_q.angle_to(idle_q))

	# MOVING: phase advances, and faster speed advances it MORE per frame.
	rig.set_movement_state(true, 9.0)
	rig._smoothed_speed = 9.0
	var phase_before := rig._phase
	rig.apply_pose(1.0 / 60.0)
	var adv_fast := absf(rig._phase - phase_before)
	_assert("running: cycle phase advances with speed", adv_fast > 1e-4,
		"dphase=%.5f" % adv_fast)

	rig.set_movement_state(true, 3.0)
	rig._smoothed_speed = 3.0
	var pb2 := rig._phase
	rig.apply_pose(1.0 / 60.0)
	var adv_slow := absf(rig._phase - pb2)
	_assert("slower speed advances phase less than faster speed", adv_slow < adv_fast,
		"slow=%.5f < fast=%.5f" % [adv_slow, adv_fast])

	# MOVING leg pose differs from rest (visible swing).
	rig.set_movement_state(true, 9.0)
	rig._smoothed_speed = 9.0
	rig._phase = PI * 0.5   # peak of the sine swing
	rig.apply_pose(1.0 / 60.0)
	var run_q := rig.skeleton.get_bone_pose_rotation(hip_l)
	_assert("running: hip swings away from rest", rest_q.angle_to(run_q) > 0.1,
		"angle=%.4f rad" % rest_q.angle_to(run_q))

	_finish()


# ---------------------------------------------------------------------------
# Linear-blend-skinning reference (CPU) — the honest deform check.
# ---------------------------------------------------------------------------

## Compute the LBS world position of vertex `vi`:
##   p' = sum_k w_k * (S_bone_k * BindPose_k) * p
## where S_bone_k is the bone's CURRENT global pose, BindPose_k the Skin bind
## (inverse global rest). This mirrors what the GPU skinner does, so a nonzero
## delta proves the skin actually deforms with the bone.
func _skinned_pos(verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array,
		skel: Skeleton3D, skin: Skin, vi: int) -> Vector3:
	var p := verts[vi]
	var acc := Vector3.ZERO
	for k in 4:
		var w := weights[vi * 4 + k]
		if w <= 0.0:
			continue
		var b := bones[vi * 4 + k]
		var bind := skin.get_bind_pose(b)            # inverse global rest
		var cur := skel.get_bone_global_pose(b)      # current global pose
		acc += w * (cur * (bind * p))
	return acc


func _find_vertex_weighted_to(bones: PackedInt32Array, weights: PackedFloat32Array, bone: int) -> int:
	var n := weights.size() / 4
	var best := -1
	var best_w := 0.0
	for vi in n:
		for k in 4:
			if bones[vi * 4 + k] == bone and weights[vi * 4 + k] > best_w:
				best_w = weights[vi * 4 + k]
				best = vi
	return best


func _make_ground(y: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	cs.shape = box
	body.add_child(cs)
	body.position = Vector3(0, y - 0.1, 0)
	return body


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
