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
		# --- ANATOMICAL-LANDMARK UV CHECK (catches WRONG COORDINATES) ------------
		# The span/distinct checks above are CHECKERBOARD-BLIND: a UV set that is
		# V-flipped the wrong way, off-by-one in the OBJ `vt` index, or otherwise
		# scrambled still spans the atlas and has thousands of distinct values, so it
		# passes them — yet maps the texture to the WRONG body coordinates. This check
		# anchors to POSE-INDEPENDENT anatomical landmarks (topmost render vertex =
		# head crown; bottommost = foot sole) and asserts each lands in the EXPECTED
		# MakeHuman-atlas sub-region (measured from the correct, verified mesh). A
		# backwards V-flip swaps the crown's v (~0.58) with the foot's (~0.96); an
		# off-by-one in the vt index shifts the crown out of its u-band. Either fails
		# here while sailing through the checkerboard-style asserts above.
		# Anchor the landmark check on the STATIC asset (base_body.res), not the runtime
		# CPU-baked mesh: Slice C bakes the default MACRO MORPH into the runtime neutral (the
		# displayed neutral = base + the default factor-cube blend, not raw base.obj), which
		# slightly reshapes the feet and so changes WHICH vertex is bottommost. The landmark
		# UV coords (0.135, 0.958) were measured on the verified static mesh, and UVs are
		# morph-invariant (the bake never touches ARRAY_TEX_UV), so the static asset is the
		# correct reference for this V-flip / scrambled-UV guard.
		var static_mesh := load("res://assets/body/base_body.res") as ArrayMesh
		if static_mesh != null:
			var rt2: Array = static_mesh.surface_get_arrays(0)
			var lv: PackedVector3Array = rt2[Mesh.ARRAY_VERTEX]
			var lu: PackedVector2Array = rt2[Mesh.ARRAY_TEX_UV]
			var y_max := -INF; var y_min := INF; var crown := 0; var sole := 0
			for i in lv.size():
				if lv[i].y > y_max: y_max = lv[i].y; crown = i
				if lv[i].y < y_min: y_min = lv[i].y; sole = i
			var crown_uv: Vector2 = lu[crown]
			var sole_uv: Vector2 = lu[sole]
			_assert("head-crown vertex UV in expected atlas region (u~0.66, v~0.58)",
				absf(crown_uv.x - 0.661) < 0.06 and absf(crown_uv.y - 0.578) < 0.06,
				"crown uv=(%.3f, %.3f)" % [crown_uv.x, crown_uv.y])
			# v~0.96 is the smoking gun for the V-flip: a backwards flip would place
			# the sole near v~0.04.
			_assert("foot-sole vertex UV in expected atlas region (u~0.14, v~0.96)",
				absf(sole_uv.x - 0.135) < 0.06 and absf(sole_uv.y - 0.958) < 0.06,
				"sole uv=(%.3f, %.3f)" % [sole_uv.x, sole_uv.y])
			_assert("head-crown and foot-sole UVs in distinct atlas rows (|dv|>0.25)",
				absf(crown_uv.y - sole_uv.y) > 0.25,
				"|dv|=%.3f" % absf(crown_uv.y - sole_uv.y))

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
	# HARD REQUIREMENT: a still-standing gameplay body is NEVER in the skeleton's
	# neutral/bind pose — it holds the captured MOCAP IDLE stance (the procedural
	# fallback seeds its idle from the same zero-goal Neutral_ID match). So at rest a
	# tracked joint's pose must DIFFER from its bind rotation beyond a threshold.
	# (The old test asserted the opposite — "idle near rest" — which was the defect.)
	var arm_l := rig.skeleton.find_bone("upperarm01.L")
	var arm_rest := rig.skeleton.get_bone_rest(arm_l).basis.get_rotation_quaternion()
	var arm_idle := rig.skeleton.get_bone_pose_rotation(arm_l)
	_assert("idle is NOT the bind/rest pose (mocap stand, arm down at side)",
		arm_rest.angle_to(arm_idle) > 0.3,
		"upperarm.L idle vs rest angle=%.4f rad" % arm_rest.angle_to(arm_idle))
	# The legs also settle off the spread bind pose at idle.
	var idle_q := rig.skeleton.get_bone_pose_rotation(hip_l)
	_assert("idle: legs settle off the bind pose",
		rest_q.angle_to(idle_q) > 0.01,
		"upperleg.L idle vs rest angle=%.4f rad" % rest_q.angle_to(idle_q))

	# DETERMINISM: the idle micro-motion is a pure function of accumulated idle time
	# (seeded/replayable timeline), never Math.random / wall-clock. A fresh rig fed
	# the SAME delta sequence reaches the SAME idle pose.
	var rig_d := BodyRig.new(); add_child(rig_d); rig_d.build()
	rig_d.use_motion_matching = false; rig_d.foot_ik_enabled = false
	rig_d.set_movement_state(true, 0.0); rig_d._smoothed_speed = 0.0
	for i in 40:
		rig_d.apply_pose(1.0 / 60.0)
	var rig_d2 := BodyRig.new(); add_child(rig_d2); rig_d2.build()
	rig_d2.use_motion_matching = false; rig_d2.foot_ik_enabled = false
	rig_d2.set_movement_state(true, 0.0); rig_d2._smoothed_speed = 0.0
	for i in 40:
		rig_d2.apply_pose(1.0 / 60.0)
	# Use a bone the procedural floor actually drives at idle (upperarm carries the
	# breathing micro-motion; spine is only driven on the MM path).
	var sp := rig_d.skeleton.find_bone("upperarm01.L")
	var idle_det_a := rig_d.skeleton.get_bone_pose_rotation(sp)
	var idle_det_b := rig_d2.skeleton.get_bone_pose_rotation(sp)
	_assert("idle is deterministic (same seed+sim-time -> same pose)",
		idle_det_a.angle_to(idle_det_b) < 1e-5,
		"upperarm.L idle angle diff=%.8f rad" % idle_det_a.angle_to(idle_det_b))
	# And it is genuinely ALIVE: the idle pose changes over sim time (breathing /
	# weight-shift), it is not a frozen static stance.
	var sp_t0 := rig_d.skeleton.get_bone_pose_rotation(sp)
	for i in 60:
		rig_d.apply_pose(1.0 / 60.0)
	var sp_t1 := rig_d.skeleton.get_bone_pose_rotation(sp)
	_assert("idle micro-motion is alive (pose advances over sim time)",
		sp_t0.angle_to(sp_t1) > 1e-4,
		"upperarm.L moved %.6f rad over 1s idle" % sp_t0.angle_to(sp_t1))

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
