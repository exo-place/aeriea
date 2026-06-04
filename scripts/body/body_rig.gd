## BodyRig — builds and owns the player's visible, skinned, animated body.
##
## Slice 3 of docs/decisions/body-and-locomotion-slice.md. It reconstructs, at
## runtime and deterministically, a Skeleton3D + skinned MeshInstance3D from two
## byte-reproducible CC0 artifacts produced by tools/body_converter.gd:
##
##   - res://assets/body/base_body.res        — the ArrayMesh: base mesh + macro
##     blendshapes + per-vertex ARRAY_BONES/ARRAY_WEIGHTS (LBS skin weights from
##     the vendored CC0 default_weights.mhw).
##   - res://assets/body/base_body_rig.json   — the bone hierarchy + rest
##     transforms (from the vendored CC0 default.mhskel joint cubes). Bone order
##     matches the ARRAY_BONES indices in the mesh.
##
## Reconstructing the rig in code (instead of baking a .scn) keeps the pipeline
## byte-deterministic: PackedScene assigns random local-subresource IDs, the JSON
## does not. The body is scaled 1u = 1m (feet at the node origin, y=0).
##
## On top of the static skin this node runs the §3 RENDER-SIDE animation layer:
##   - procedural locomotion: a leg/arm walk-run cycle whose phase advances with
##     horizontal speed, blended toward an idle pose at rest;
##   - analytic two-bone foot-IK: each foot raycasts down, plants on the surface,
##     orients to the surface normal, and the pelvis drops by the larger offset.
##
## It reads MovementState ONLY (grounded / horizontal speed / facing) — it never
## writes the sim. Animation is excluded from the sim hash (movement-substrate
## §6); the unchanged golden traces are the regression guard.
class_name BodyRig
extends Node3D

const MESH_PATH := "res://assets/body/base_body.res"
const RIG_PATH := "res://assets/body/base_body_rig.json"
## Slice 4 — the committed Motion-Matching feature DB (100STYLE CC BY 4.0). When
## present, MM drives the gross body pose (replacing the procedural sine cycle);
## foot-IK stays the ground-adaptation layer on top. When absent, the Slice-3
## procedural cycle is the graceful-degradation floor (decision doc §3.2).
const MOTION_DB_PATH := "res://assets/body/locomotion_mm.res"

# Leg chain bone names (MakeHuman default rig). Two-bone IK uses hip/knee/ankle.
const HIP_L := "upperleg01.L"
const HIP_R := "upperleg01.R"
const KNEE_L := "lowerleg01.L"
const KNEE_R := "lowerleg01.R"
const FOOT_L := "foot.L"
const FOOT_R := "foot.R"
const SHOULDER_L := "upperarm01.L"
const SHOULDER_R := "upperarm01.R"
const ROOT_BONE := "root"

## Tuning (render-side only).
@export var stride_length: float = 0.9      ## metres of speed-phase per cycle
@export var max_leg_swing_deg: float = 35.0  ## peak thigh swing at run speed
@export var max_arm_swing_deg: float = 28.0
@export var run_speed_ref: float = 9.0       ## speed at which swing/cadence peak
@export var ik_ray_up: float = 0.6           ## ray origin above ankle
@export var ik_ray_down: float = 0.9         ## ray reach below ankle
@export var foot_ik_enabled: bool = true

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D

## The body's morph parameters (the single source of truth, BodyState). Default is the
## neutral young-adult base. Set via apply_body_state() to re-morph the SKINNED body.
var body_state: BodyState = BodyState.new()

var _bone_index := {}     ## name -> bone index
var _rest_local := {}     ## name -> resting bone-local Transform3D (for layering)

## Animation phase, advanced by horizontal distance travelled (render-side clock).
var _phase: float = 0.0
## Smoothed speed for blend (render-side; no sim feedback).
var _smoothed_speed: float = 0.0

## Set by the host each frame BEFORE _apply_pose: the current MovementState read.
var grounded: bool = true
var horizontal_speed: float = 0.0
## Slice 4 — desired LOCAL-frame planar velocity (+z forward, +x right; m/s) and
## desired yaw rate (rad/s), the Motion-Matching goal derived from MovementState.
## Defaulted from horizontal_speed when the host uses the 2-arg seam (Slice-3
## callers), so MM still gets a forward-locomotion goal without changes upstream.
var local_velocity: Vector2 = Vector2.ZERO
var turn_rate: float = 0.0

## Slice 4 — Motion Matching. Built in build() iff MOTION_DB_PATH loads.
var motion_db: MotionDB
var matcher: MotionMatcher
var use_motion_matching: bool = true

## The space state used for foot-IK raycasts; the host supplies its world.
var _space: PhysicsDirectSpaceState3D
var _ik_exclude: Array = []


func _ready() -> void:
	if not build():
		push_error("BodyRig: build() failed")


## Build the skeleton + skinned mesh from the two artifacts. Returns false on any
## failure. Idempotent-ish: safe to call once from _ready or explicitly in tests.
func build() -> bool:
	var mesh: ArrayMesh = load(MESH_PATH)
	if mesh == null:
		push_error("BodyRig: cannot load mesh %s" % MESH_PATH)
		return false
	var rig := _load_rig_json()
	if rig.is_empty():
		push_error("BodyRig: cannot load rig %s" % RIG_PATH)
		return false

	var bones: Array = rig["bones"]
	var nb := bones.size()

	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)

	# global rest per bone (origin from JSON; basis identity here)
	var global_rest := []
	global_rest.resize(nb)
	for i in nb:
		var bd: Dictionary = bones[i]
		var h: Array = bd["head"]
		global_rest[i] = Transform3D(Basis.IDENTITY, Vector3(h[0], h[1], h[2]))

	for i in nb:
		skeleton.add_bone(bones[i]["name"])
		_bone_index[bones[i]["name"]] = i
	for i in nb:
		skeleton.set_bone_parent(i, int(bones[i]["parent"]))
	for i in nb:
		var p := int(bones[i]["parent"])
		var local: Transform3D = global_rest[i]
		if p >= 0:
			local = (global_rest[p] as Transform3D).affine_inverse() * (global_rest[i] as Transform3D)
		skeleton.set_bone_rest(i, local)
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		_rest_local[bones[i]["name"]] = local

	# Skin: bind i -> bone i; bind pose = inverse of the bone's GLOBAL rest, since
	# the mesh vertices live in the same global-rest space (standard LBS).
	var skin := Skin.new()
	for i in nb:
		skin.add_bind(i, (global_rest[i] as Transform3D).affine_inverse())
		skin.set_bind_name(i, bones[i]["name"])

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Body"
	# PER-INSTANCE mesh copy. apply_body_state() bakes the CPU-morphed positions +
	# recomputed normals into this surface (the correct-normals-under-morph path; the
	# GPU blendshapes carry a ZERO normal delta and CANNOT be lit correctly under morph
	# — see BodyState/body_converter). Baking mutates the ArrayMesh, so it MUST be a
	# private copy: the shared load() result is the cache and mutating it would corrupt
	# every other body and persist across runs. The skin/skeleton binding (vertex/bone
	# arrays) is unchanged by the bake, so LBS still composes correctly on top.
	mesh = (mesh as ArrayMesh).duplicate(true)
	mesh_instance.mesh = mesh
	# A simple skin material so the body reads as a body (not a flat silhouette).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.68, 0.58)
	mat.roughness = 0.7
	mesh_instance.material_override = mat
	skeleton.add_child(mesh_instance)
	mesh_instance.skin = skin
	mesh_instance.skeleton = mesh_instance.get_path_to(skeleton)

	# Slice 4 — load the committed Motion-Matching DB if present and wire the
	# deterministic matcher. Absent DB => graceful degradation to the Slice-3
	# procedural cycle (decision doc §3.2). RENDER-SIDE only.
	if ResourceLoader.exists(MOTION_DB_PATH):
		var db = load(MOTION_DB_PATH)
		if db is MotionDB and db.frame_count > 0:
			motion_db = db
			matcher = MotionMatcher.new()
			matcher.setup(motion_db)

	# Bake the initial BodyState morph (default = neutral) with correct normals. This
	# establishes the neutral-base capture on the MeshInstance metadata so later
	# re-morphs are stable and non-cumulative.
	apply_body_state(body_state)

	return true


## Re-morph the SKINNED body to `state` with CORRECT normals under morph.
##
## The in-game body is skinned (Skeleton3D / LBS). The morph (blendshapes) lives in the
## mesh REST space and is applied BEFORE skinning — final = LBS(base + Σ wᵢ·Δvᵢ). So
## baking the CPU-morphed rest-space positions + recomputed rest-space normals into the
## base surface is exactly what the GPU blendshape stage feeds the skinning stage, and
## LBS then composes on top unchanged. This is why a rest-space CPU bake is correct for
## the skinned body and not merely the static viewer (verified with a posed+morphed
## render). We use the CPU bake instead of GPU blendshape weights because Godot stores
## blendshape normals octahedral-compressed, which cannot carry a normal delta — the
## GPU-only morph leaves stale normals that mis-light the morphed surface (BodyState).
func apply_body_state(state: BodyState) -> void:
	body_state = state
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	body_state.apply_morph_cpu(mesh_instance)


## Body-local eye height (metres above the body's feet origin), derived from the
## actual rig's eye landmark — NOT a magic constant. The body mesh has feet at
## local y=0; the eye bones (eye.L/eye.R from the CC0 default.mhskel joint cubes)
## sit at the anatomical eye level. The first-person camera reads this so the eye
## sits at the body's real eyes, not at an assumed height above the skull (the
## camera-inside-the-head bug: a hardcoded pivot above the shorter-than-assumed
## body put the eye at the crown, so looking down rendered the skull interior).
## Falls back to the head bone, then a sane default, if the eye bones are absent.
func eye_height() -> float:
	if skeleton == null:
		return 1.6
	var sum := 0.0
	var n := 0
	for bn in ["eye.L", "eye.R"]:
		if _bone_index.has(bn):
			sum += skeleton.get_bone_global_pose(_bone_index[bn]).origin.y
			n += 1
	if n > 0:
		return sum / float(n)
	if _bone_index.has("head"):
		# head joint sits at the base of the skull; nudge up to ~eye level
		return skeleton.get_bone_global_pose(_bone_index["head"]).origin.y + 0.05
	return 1.6


## Body-local top-of-head height (metres above feet) — the rendered mesh's max Y.
## Used to sanity-check the eye sits below the crown.
func head_top() -> float:
	if mesh_instance == null or mesh_instance.mesh == null:
		return 1.7
	var ab: AABB = mesh_instance.mesh.get_aabb()
	# The mesh AABB includes blendshape extents (e.g. height_max), so clamp to the
	# base surface top by reading ARRAY_VERTEX rather than the morph-inflated AABB.
	var arrays := (mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mx := -INF
	for v in verts:
		mx = maxf(mx, v.y)
	return mx if mx > -INF else ab.position.y + ab.size.y


func _load_rig_json() -> Dictionary:
	var f := FileAccess.open(RIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("bones"):
		return {}
	return data


# ---------------------------------------------------------------------------
# §3 animation layer — RENDER-SIDE. Pure read of MovementState -> bone pose.
# Call set_movement_state(...) then apply_pose(delta) each frame.
# ---------------------------------------------------------------------------

## Host feeds the sim read. grounded + horizontal speed are the locomotion
## drivers; this is the entire seam (movement-substrate §3.1).
func set_movement_state(p_grounded: bool, p_horizontal_speed: float,
		p_local_velocity: Vector2 = Vector2.INF, p_turn_rate: float = 0.0) -> void:
	grounded = p_grounded
	horizontal_speed = p_horizontal_speed
	# If the host supplies a local velocity vector (Slice-4 seam), use it as the MM
	# goal; otherwise synthesize a forward-locomotion goal from the scalar speed so
	# Slice-3 callers (2-arg) still drive MM with a sensible forward intent.
	if p_local_velocity == Vector2.INF:
		local_velocity = Vector2(0.0, p_horizontal_speed)   # +z forward
	else:
		local_velocity = p_local_velocity
	turn_rate = p_turn_rate


## Set the world + the bodies to exclude from foot-IK rays (typically the player
## CharacterBody3D). Call once after the rig is in the tree.
func setup_ik(space: PhysicsDirectSpaceState3D, exclude: Array) -> void:
	_space = space
	_ik_exclude = exclude


## Advance the procedural locomotion + apply foot-IK. RENDER-SIDE: reads only the
## cached MovementState; touches only bone poses; never the sim.
func apply_pose(delta: float) -> void:
	if skeleton == null:
		return
	_smoothed_speed = lerpf(_smoothed_speed, horizontal_speed, clampf(delta * 12.0, 0.0, 1.0))

	# Slice 4 — Motion Matching drives the gross body when a DB is loaded; foot-IK
	# (below) stays the ground-adaptation layer on top. Falls through to the
	# Slice-3 procedural cycle when no DB is present (graceful degradation).
	if matcher != null and use_motion_matching:
		_apply_motion_matching()
		# Foot-IK over MM: the Slice-3 two-bone solver + pelvis-drop were tuned for
		# the procedural cycle and FIGHT the MM pose (they collapse the pelvis when
		# layered on captured poses). Re-deriving foot-IK as a gentle additive
		# ground-adaptation layer that respects the MM pose is the documented
		# Slice-4 refinement (decision doc §3.2); until then MM ground contact comes
		# from the captured clips themselves, so IK is skipped under MM.
		return

	# Reset the layered bones to rest before re-posing (so the pose is a pure
	# function of state, not an accumulation).
	for bname in [HIP_L, HIP_R, KNEE_L, KNEE_R, SHOULDER_L, SHOULDER_R, FOOT_L, FOOT_R, ROOT_BONE]:
		if _rest_local.has(bname):
			_set_bone_local(bname, _rest_local[bname])

	# --- procedural walk/run cycle -------------------------------------------
	# Phase advances with DISTANCE (speed * dt / stride) so cadence scales with
	# speed; at rest the phase freezes and the swing blend -> 0 (idle pose).
	var speed := _smoothed_speed
	var blend := clampf(speed / run_speed_ref, 0.0, 1.0)   # idle(0) -> run(1)
	if grounded and speed > 0.05:
		_phase += (speed / maxf(stride_length, 0.01)) * delta
	# keep phase bounded
	_phase = fposmod(_phase, TAU)

	var swing := deg_to_rad(max_leg_swing_deg) * blend
	var arm := deg_to_rad(max_arm_swing_deg) * blend
	var s := sin(_phase)
	var s_opp := sin(_phase + PI)

	# Legs swing fore/aft about the hip X axis; opposite phase L/R. Knees flex on
	# the back-swing (a cheap, readable gait). Arms counter-swing the legs.
	_rotate_bone_local(HIP_L, Vector3.RIGHT, s * swing)
	_rotate_bone_local(HIP_R, Vector3.RIGHT, s_opp * swing)
	_rotate_bone_local(KNEE_L, Vector3.RIGHT, maxf(0.0, -s) * swing * 1.4)
	_rotate_bone_local(KNEE_R, Vector3.RIGHT, maxf(0.0, -s_opp) * swing * 1.4)
	_rotate_bone_local(SHOULDER_L, Vector3.RIGHT, s_opp * arm)
	_rotate_bone_local(SHOULDER_R, Vector3.RIGHT, s * arm)

	if grounded and foot_ik_enabled and _space != null:
		_apply_foot_ik()


# --- Slice 4: Motion-Matching pose ------------------------------------------
# Deterministically search the feature DB for the frame best matching the current
# MovementState-derived goal, then apply that frame's per-bone local rotations to
# the skeleton. RENDER-SIDE; pure function of (goal, DB). Resets the MM-driven
# bones to rest first so the pose is a pure function of the matched frame.
var _mm_frame: int = 0

## Below this planar speed (m/s) the body is treated as standing still and is
## blended fully to the authored MakeHuman REST pose (a clean neutral stand). The
## captured-clip "idle" frames in the DB are mid-fidget poses that, at true rest,
## read as a frozen contorted stance (head/arms thrown off-axis); the authored
## rest is the correct neutral. Between idle_speed and idle_blend_top the MM pose
## fades in. Render-side only; chosen well below the test walk goal (3 m/s).
@export var idle_speed: float = 0.15
@export var idle_blend_top: float = 0.9

func _apply_motion_matching() -> void:
	# Step the matcher (deterministic argmin / clip-advance) with the goal.
	var vel := local_velocity
	if not grounded:
		# Airborne: the locomotion DB has no fall clips; freeze the goal at idle so
		# MM holds a neutral pose (foot-IK is also skipped while airborne).
		vel = Vector2.ZERO
	_mm_frame = matcher.step(vel, turn_rate)

	# Idle blend: at/near rest, fade the whole MM pose toward the authored rest
	# pose so a standing body looks like a normal neutral stand (the DB's captured
	# idle frames are off-axis fidgets that read as broken when frozen). Uses the
	# render-side smoothed speed so the transition is stable. A pure function of
	# state — no accumulation, no sim feedback.
	var mm_w := clampf((_smoothed_speed - idle_speed) / maxf(idle_blend_top - idle_speed, 1e-3), 0.0, 1.0)

	# Reset every MM-driven bone to rest, then stamp the matched local rotations
	# blended against rest by mm_w (mm_w=0 -> pure rest stand; mm_w=1 -> full MM).
	var nb := motion_db.bone_count
	for bi in nb:
		var bname := motion_db.bone_names[bi]
		if not _bone_index.has(bname):
			continue
		var rest: Transform3D = _rest_local.get(bname, Transform3D.IDENTITY)
		var rest_q := rest.basis.get_rotation_quaternion()
		var q := motion_db.pose_quat(_mm_frame, bi)
		if mm_w < 1.0:
			# Compose the MM delta onto the rest rotation, then fade in from rest.
			# (Rest bases are identity here, so rest_q*q == q; the slerp from rest_q
			# is what produces the neutral stand at idle.)
			q = rest_q.slerp((rest_q * q).normalized(), mm_w)
		# The DB quats are BVH-joint local rotations. Apply as the bone's local
		# rotation, keeping the rest position. The root keeps its rest position
		# (sim owns translation); MM supplies only orientation.
		var idx: int = _bone_index[bname]
		skeleton.set_bone_pose_position(idx, rest.origin)
		skeleton.set_bone_pose_rotation(idx, q)


## Expose the matched frame for tests (which DB frame the MM search chose).
func motion_matched_frame() -> int:
	return _mm_frame


# --- analytic two-bone foot-IK ----------------------------------------------
# For each foot: raycast straight down from above the foot; if it hits ground,
# place an IK target at the hit, solve the hip-knee-ankle chain analytically (law
# of cosines), orient the foot to the surface normal. The pelvis (root) drops by
# the LARGER of the two foot ground offsets so both feet can reach. Deterministic,
# closed-form, cheap.
func _apply_foot_ik() -> void:
	var hit_l := _foot_ground(FOOT_L)
	var hit_r := _foot_ground(FOOT_R)

	# Pelvis/root adjustment: lower the root by the larger downward offset so the
	# higher foot stays planted and the lower foot can reach (standard pelvis drop).
	var drop := 0.0
	if hit_l.has("offset"):
		drop = maxf(drop, -minf(0.0, hit_l["offset"]))
	if hit_r.has("offset"):
		drop = maxf(drop, -minf(0.0, hit_r["offset"]))
	if drop > 0.0 and _rest_local.has(ROOT_BONE):
		var rt: Transform3D = _rest_local[ROOT_BONE]
		rt.origin.y -= clampf(drop, 0.0, 0.4)
		_set_bone_local(ROOT_BONE, rt)

	if hit_l.has("position"):
		_solve_two_bone_ik(HIP_L, KNEE_L, FOOT_L, hit_l["position"], hit_l["normal"])
	if hit_r.has("position"):
		_solve_two_bone_ik(HIP_R, KNEE_R, FOOT_R, hit_r["position"], hit_r["normal"])


## Raycast down from above the foot. Returns {position, normal, offset} where
## offset = hit.y - rest_foot.y (negative => ground is below the rest foot).
func _foot_ground(foot_name: String) -> Dictionary:
	if not _bone_index.has(foot_name):
		return {}
	var foot_global := skeleton.global_transform * skeleton.get_bone_global_pose(_bone_index[foot_name])
	var p := foot_global.origin
	var from := p + Vector3.UP * ik_ray_up
	var to := p + Vector3.DOWN * ik_ray_down
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = _ik_exclude
	var hit := _space.intersect_ray(params)
	if hit.is_empty():
		return {}
	var pos: Vector3 = hit["position"]
	return {"position": pos, "normal": hit["normal"], "offset": pos.y - p.y}


## Analytic two-bone IK: given hip/knee/foot bones and a world-space target, bend
## the chain (law of cosines for the knee angle) so the ankle reaches the target.
## Orients the foot toward the surface normal. Operates in the skeleton's local
## frame. Closed-form, no iteration.
func _solve_two_bone_ik(hip: String, knee: String, foot: String, target_world: Vector3, normal: Vector3) -> void:
	if not (_bone_index.has(hip) and _bone_index.has(knee) and _bone_index.has(foot)):
		return
	var hi: int = _bone_index[hip]
	var ki: int = _bone_index[knee]
	var fi: int = _bone_index[foot]

	# Current global positions (post the procedural-cycle pose) of the joints.
	var skel_xf := skeleton.global_transform
	var hip_pos := (skel_xf * skeleton.get_bone_global_pose(hi)).origin
	var knee_pos := (skel_xf * skeleton.get_bone_global_pose(ki)).origin
	var foot_pos := (skel_xf * skeleton.get_bone_global_pose(fi)).origin

	var l_upper := hip_pos.distance_to(knee_pos)
	var l_lower := knee_pos.distance_to(foot_pos)
	if l_upper < 1e-4 or l_lower < 1e-4:
		return

	var to_target := target_world - hip_pos
	var dist := clampf(to_target.length(), 1e-4, (l_upper + l_lower) - 1e-3)

	# Law of cosines: hip-flex angle that points the upper leg correctly, then the
	# knee bend. We apply the DELTA from the current straight-ish pose as additive
	# local rotations about the leg's bend axis (the skeleton's local X, matching
	# the procedural swing axis).
	var cos_hip := clampf((l_upper * l_upper + dist * dist - l_lower * l_lower) / (2.0 * l_upper * dist), -1.0, 1.0)
	var cos_knee := clampf((l_upper * l_upper + l_lower * l_lower - dist * dist) / (2.0 * l_upper * l_lower), -1.0, 1.0)
	var hip_angle := acos(cos_hip)
	var knee_angle := PI - acos(cos_knee)

	# Aim the hip so the upper leg roughly faces the target (pitch toward target in
	# the sagittal plane), then add the cosine flex. This is a deterministic, cheap
	# approximation sufficient for ground-adaptation (the future MM/physics
	# controller replaces this whole layer).
	var aim_pitch := atan2(to_target.y + dist, Vector3(to_target.x, 0.0, to_target.z).length() + 1e-4)
	_rotate_bone_local(hip, Vector3.RIGHT, -(aim_pitch) * 0.0 + hip_angle - PI * 0.5, true)
	_rotate_bone_local(knee, Vector3.RIGHT, knee_angle, true)

	# Orient the foot to the surface normal (flatten on slopes).
	if _rest_local.has(foot):
		var n := normal.normalized()
		var tilt := Vector3.UP.angle_to(n)
		if tilt > 0.001:
			var axis := Vector3.UP.cross(n).normalized()
			# convert world tilt axis into the foot's local frame approximately via
			# the skeleton basis; small-angle, render-side, deterministic.
			var local_axis := (skel_xf.basis.inverse() * axis).normalized()
			_rotate_bone_local(foot, local_axis, tilt, true)


# ---------------------------------------------------------------------------
# Bone pose helpers (local-frame, additive over rest).
# ---------------------------------------------------------------------------

func _set_bone_local(name: String, xf: Transform3D) -> void:
	if not _bone_index.has(name):
		return
	var i: int = _bone_index[name]
	skeleton.set_bone_pose_position(i, xf.origin)
	skeleton.set_bone_pose_rotation(i, xf.basis.get_rotation_quaternion())


## Rotate a bone about a local axis by `angle` radians. When `additive` is false
## the rotation is applied relative to the bone's rest; when true it composes onto
## the bone's current pose (used to layer IK on top of the procedural cycle).
func _rotate_bone_local(name: String, axis: Vector3, angle: float, additive: bool = false) -> void:
	if not _bone_index.has(name) or absf(angle) < 1e-6:
		return
	var i: int = _bone_index[name]
	var rot := Quaternion(axis.normalized(), angle)
	if additive:
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * rot)
	else:
		var base: Transform3D = _rest_local.get(name, Transform3D.IDENTITY)
		skeleton.set_bone_pose_rotation(i, base.basis.get_rotation_quaternion() * rot)
		skeleton.set_bone_pose_position(i, base.origin)
