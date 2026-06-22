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
## The rigged, morph-following EYE/TEETH/TONGUE/GENITAL proxy pieces (built by
## tools/body_proxy_build.gd). Without these the face renders with hollow eye sockets
## and an empty open mouth — they ARE the eyeballs/teeth/tongue. ONE multi-surface
## ArrayMesh; ProxyMorph re-bakes its morphed positions/normals on apply_body_state.
const ProxyMorph := preload("res://scripts/body/proxy_morph.gd")
const PROXY_MESH_PATH := "res://assets/body/base_body_proxies.res"
## Procedural eye shader (iris/pupil/sclera computed analytically from the proxy UVs —
## resolution-independent, no baked texture). Parameterised by EYE_PARAMS_DEFAULT.
const EYE_SHADER := preload("res://assets/body/eye.gdshader")
## Default eye parameters — a natural warm-brown eye matching the prior baked look.
## Override per-character by passing a dict of the same keys to set_eye_params().
## pupil_aspect: 1.0 round (human); <1 vertical slit (cat/reptile); >1 horizontal slit.
const EYE_PARAMS_DEFAULT := {
	"iris_color": Color(0.36, 0.20, 0.09),
	"iris_inner": Color(0.20, 0.10, 0.04),
	"iris_radius": 0.62,
	"pattern_strength": 0.55,
	"pattern_scale": 64.0,
	"pupil_color": Color(0.02, 0.02, 0.02),
	"pupil_size": 0.34,
	"pupil_aspect": 1.0,
	"limbal_color": Color(0.06, 0.03, 0.02),
	"limbal_width": 0.14,
	"sclera_color": Color(0.93, 0.90, 0.88),
	"vein_color": Color(0.78, 0.45, 0.42),
	"vein_strength": 0.12,
	"eye_roughness": 0.06,
	"eye_specular": 0.9,
}
## Pieces hidden by default. The face must look complete, so eyes/teeth/tongue/
## eyebrows/eyelashes are ON; genitals are an attachable piece whose default
## visibility follows the NSFW flag.
const PROXY_DEFAULT_HIDDEN := {"genitals": true}
## The single SKIN tone, shared by the body mesh AND the genital proxy so the genitals
## follow skin tone/masculinity (not a fixed paler colour) — fixing the pale-genital seam.
const SKIN_ALBEDO := Color(0.86, 0.68, 0.58)
const SKIN_ROUGHNESS := 0.7
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

const SpringBone := preload("res://scripts/body/spring_bone.gd")
const MicroLifeParams := preload("res://scripts/body/micro_life_params.gd")

## Soft-region bones the jiggle layer drives (spring-bones). breast.L/R exist in the
## CC0 MakeHuman default rig; belly/glute have NO dedicated bones in this rig (a GAP —
## see apply_micro_life), so they are listed for when the rig is extended but resolve
## to nothing today (graceful: the registry simply skips absent bones).
const SOFT_REGION_BONES := ["breast.L", "breast.R", "belly", "glute.L", "glute.R"]
## Name fragments that mark a HAIR bone for the hair spring-bone chain. The CC0 default
## rig has NO hair bones (the base is bald-rigged) — so this matches nothing today and
## hair secondary motion is a documented GAP until a hair-bone chain is added to the rig.
const HAIR_BONE_FRAGMENTS := ["hair"]

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
## The body SKIN material, shared by the genital proxy so its tone tracks the body skin.
var _skin_material: StandardMaterial3D
## The proxy pieces (eyes/teeth/tongue/genitals) as a single skinned MeshInstance3D
## sharing `skeleton` + the body Skin. Null if the proxy artifact is absent (the body
## still renders, just without eyeballs/teeth/tongue — graceful degradation).
var proxy_instance: MeshInstance3D
## Map: piece name -> surface index in the proxy mesh (for show/hide + tests).
var _proxy_surface := {}

## Live eye parameters (a copy of EYE_PARAMS_DEFAULT, overridable via set_eye_params).
var _eye_params: Dictionary = EYE_PARAMS_DEFAULT.duplicate(true)
## NSFW-first full-body goal: the genitals piece is attachable. OFF by default (SFW face
## focus); flip and re-apply to render it. The MACHINERY always builds — only visibility
## follows this flag (DESIGN.md NSFW-first; the genital piece renders correctly when on).
@export var show_genitals: bool = false

## The body's morph parameters (the single source of truth, BodyState). Default is the
## neutral young-adult base. Set via apply_body_state() to re-morph the SKINNED body.
var body_state: BodyState = BodyState.new()

var _bone_index := {}     ## name -> bone index
var _rest_local := {}     ## name -> resting bone-local Transform3D (for layering)

## Animation phase, advanced by horizontal distance travelled (render-side clock).
var _phase: float = 0.0
## Smoothed speed for blend (render-side; no sim feedback).
var _smoothed_speed: float = 0.0
## Render-side idle clock (seconds), advanced by delta whenever the body is at/near
## rest. Drives the deterministic breathing / weight-shift micro-motion of the
## relaxed idle. A pure accumulator of the per-frame delta — no Math.random, no
## wall-clock: the pose is a reproducible function of (seed, accumulated idle time).
var _idle_time: float = 0.0

# --- procedural MICRO-LIFE + SECONDARY-MOTION (render-side cosmetic juice) ------
## The single TUNABLE dial-board for breathing / sway / saccades / hair / jiggle.
## Built as a conservative default if left null; override (inspector or code) to
## retune. Pure data — never feeds the sim.
@export var micro: MicroLifeParams = null
## A COSMETIC RNG stream, SEPARATE from any sim RNG: it drives only the irregular
## render-side bits (breath rate jitter, micro-saccade timing/targets). Seeded so the
## visual is reproducible, but kept OUT of the sim/event-log timeline — nothing here
## advances or is read by the deterministic sim (see apply_micro_life's contract).
var _cosmetic_rng := RandomNumberGenerator.new()
## Spring-bone instances: name -> SpringBone, for hair and soft-region jiggle.
var _hair_springs := {}
var _jiggle_springs := {}
## Micro-saccade state (render-side; advanced by delta + cosmetic rng).
var _saccade_offset: Vector2 = Vector2.ZERO
var _saccade_target: Vector2 = Vector2.ZERO
var _saccade_timer: float = 0.0
## Current breath phase (radians) — integrated with a jittered per-cycle rate so the
## breath is alive (not metronomic) yet reproducible from the cosmetic seed.
var _breath_phase: float = 0.0
var _breath_cycle_rate: float = 1.0   # current cycle's rate multiplier (jittered)
## Exertion multiplier on breath rate (1 = calm; raise it later when winded).
var exertion_breath_mult: float = 1.0

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
	# A simple skin material so the body reads as a body (not a flat silhouette). The
	# genital proxy shares THIS material (see _proxy_material) so its tone follows the
	# body skin, eliminating the former pale-genital mismatch at the seam.
	_skin_material = StandardMaterial3D.new()
	_skin_material.albedo_color = SKIN_ALBEDO
	_skin_material.roughness = SKIN_ROUGHNESS
	mesh_instance.material_override = _skin_material
	skeleton.add_child(mesh_instance)
	mesh_instance.skin = skin
	mesh_instance.skeleton = mesh_instance.get_path_to(skeleton)

	# --- proxy pieces: eyes / teeth / tongue / genitals ----------------------
	# A second skinned MeshInstance3D sharing THIS skeleton + the SAME body Skin (the
	# proxy verts carry ARRAY_BONES indexing the same bone order). It completes the face
	# (eyeballs in sockets, teeth + tongue in the mouth) and serves the NSFW-first
	# full-body goal (genitals, attachable). Morph-followed via ProxyMorph in
	# apply_body_state(). Absent artifact => skipped (body still renders).
	_build_proxies(skin)

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

	# --- procedural micro-life + secondary-motion layer ----------------------
	# Build the tunable params (conservative default if none supplied) and register
	# the spring-bone chains for hair + soft-region jiggle. RENDER-SIDE / cosmetic.
	_setup_micro_life()

	return true


## Initialise the micro-life layer: default params if none, seed the COSMETIC rng,
## and register spring-bones for any present hair / soft-region bones. Idempotent.
func _setup_micro_life(p_seed: int = 0) -> void:
	if micro == null:
		micro = MicroLifeParams.new()
	_cosmetic_rng.seed = p_seed
	_breath_cycle_rate = 1.0 + _cosmetic_rng.randf_range(-1.0, 1.0) * micro.breath_rate_jitter
	_hair_springs.clear()
	_jiggle_springs.clear()
	if skeleton == null:
		return
	# Hair: register any bone whose name marks it as hair. The CC0 default rig has none
	# (bald-rigged) -> this stays empty and hair motion is a documented gap.
	for i in skeleton.get_bone_count():
		var bn := skeleton.get_bone_name(i)
		for frag in HAIR_BONE_FRAGMENTS:
			if bn.to_lower().contains(frag):
				_hair_springs[bn] = _make_spring(i)
				break
	# Soft-region jiggle: breast.L/R exist; belly/glute are absent in this rig (gap).
	for bn in SOFT_REGION_BONES:
		if _bone_index.has(bn):
			_jiggle_springs[bn] = _make_spring(_bone_index[bn])


## Build a SpringBone for `idx`, tracking a tip one bone-length down the bone's local
## Y (the MakeHuman bone axis). Length is estimated from the child bone if present, so
## the tracked tip is at the soft region's free end (where swing is visible).
func _make_spring(idx: int) -> SpringBone:
	var sb := SpringBone.new()
	sb.bone_idx = idx
	sb.rest_local = _rest_local.get(skeleton.get_bone_name(idx), Transform3D.IDENTITY)
	# Estimate bone length from the first child's local offset; fall back to 8 cm.
	var length := 0.08
	for c in skeleton.get_bone_count():
		if skeleton.get_bone_parent(c) == idx:
			length = maxf(length, skeleton.get_bone_pose_position(c).length())
			break
	sb.tip_local = Vector3(0.0, length, 0.0)
	return sb


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
	# Morph-follow the proxy pieces (eyes/teeth/tongue/genitals) through the SAME
	# BodyState projection, so they stay seated + correctly lit under every morph.
	if proxy_instance != null and proxy_instance.mesh != null:
		ProxyMorph.apply(body_state, proxy_instance)
		# ProxyMorph rebuilds the ArrayMesh surfaces (no in-place update exists), which
		# resets the instance's surface-override materials — re-assert them after each bake.
		_apply_proxy_materials()
	# METRIC HEIGHT (§4): height_cm is a UNIFORM SCALE orthogonal to the shape morphs, applied
	# to the skeleton (mesh + bones) about the foot origin (y=0). The mesh has feet at local
	# y=0, so a uniform scale about the node origin scales stature while keeping feet planted.
	# Changing height_cm only changes this scalar — it never touches the morph deltas, so
	# proportions (the shape) and stature (the scale) are genuinely independent.
	if skeleton != null:
		var s := body_state.height_scale()
		skeleton.scale = Vector3(s, s, s)


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


## Build the proxy MeshInstance3D (eyes/teeth/tongue/genitals) as a child of `skeleton`
## sharing `skin`. One multi-surface mesh; each surface gets a sensible material and a
## per-piece visibility (genitals follow `show_genitals`; eyes/teeth/tongue always on).
## Hidden pieces are made invisible by collapsing their triangles via a transparent
## material is fragile — instead we DROP hidden surfaces' material to transparent AND
## flag them; for a clean hide we set the surface override material's alpha. The simplest
## robust hide: keep the surface but make its material fully transparent + no shadow. We
## use that for genitals-off so the single MeshInstance stays one draw with stable indices.
func _build_proxies(skin: Skin) -> void:
	var pmesh = load(PROXY_MESH_PATH)
	if pmesh == null or not (pmesh is ArrayMesh):
		return   # no proxy artifact — body renders without eyeballs/teeth/tongue
	# PER-INSTANCE copy (ProxyMorph bakes morphed positions/normals in place, like the body).
	var mesh := (pmesh as ArrayMesh).duplicate(true)
	proxy_instance = MeshInstance3D.new()
	proxy_instance.name = "Proxies"
	proxy_instance.mesh = mesh
	for si in mesh.get_surface_count():
		_proxy_surface[str(mesh.surface_get_name(si))] = si
	skeleton.add_child(proxy_instance)
	proxy_instance.skin = skin
	proxy_instance.skeleton = proxy_instance.get_path_to(skeleton)
	_apply_proxy_materials()


## (Re)assign each proxy surface's override material + visibility. Called on build and
## after every ProxyMorph bake (which rebuilds the surfaces and drops instance overrides).
## eyes/teeth/tongue are always visible (the face must look complete); genitals follow
## `show_genitals` (the NSFW-first attachable piece).
func _apply_proxy_materials() -> void:
	if proxy_instance == null or proxy_instance.mesh == null:
		return
	var mesh := proxy_instance.mesh as ArrayMesh
	var surfaces := ProxyMorph.surfaces()
	for si in mesh.get_surface_count():
		var sname := str(mesh.surface_get_name(si))
		var mat_kind := "default"
		for s in surfaces:
			if String(s["name"]) == sname:
				mat_kind = String(s["material"])
				break
		var visible := true
		if sname == "genitals":
			visible = show_genitals
		proxy_instance.set_surface_override_material(si, _proxy_material(mat_kind, visible))


## A sensible material per proxy kind. Eyes get a PROCEDURAL shader material (iris/pupil/
## sclera computed analytically from the proxy UVs — resolution-independent, no baked
## texture); teeth a hard off-white; tongue a muted pink; genitals a skin tone.
## `visible=false` returns a fully transparent material (the surface stays in the
## single-draw mesh with stable indices, but renders nothing).
func _proxy_material(kind: String, visible: bool) -> Material:
	if kind == "eye" and visible:
		return _build_eye_material()
	var mat := StandardMaterial3D.new()
	if not visible:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0, 0, 0, 0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = false
		return mat
	match kind:
		"lashes", "brows":
			# A dark keratin tone for the PROJECT-AUTHORED brow/lash hair strips. These are
			# thin 2-sided cards, so cull is disabled (visible from either face); rough +
			# no specular so they read as matte hair mass, not plastic.
			mat.albedo_color = Color(0.14, 0.10, 0.08)
			mat.roughness = 0.9
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"teeth":
			mat.albedo_color = Color(0.93, 0.92, 0.86)
			mat.roughness = 0.4
		"tongue":
			mat.albedo_color = Color(0.82, 0.36, 0.40)
			mat.roughness = 0.55
		"genitals":
			# SHARE the body skin material so the genital tone tracks skin tone exactly
			# (no fixed paler colour → no tone mismatch at the seam). Falls back to the
			# skin colour if the body material hasn't been built yet.
			if _skin_material != null:
				return _skin_material
			mat.albedo_color = SKIN_ALBEDO
			mat.roughness = SKIN_ROUGHNESS
		_:
			mat.albedo_color = SKIN_ALBEDO
			mat.roughness = SKIN_ROUGHNESS
	return mat


## Build the procedural eye ShaderMaterial from the current _eye_params. Every visual
## knob is a shader uniform, so an arbitrary effective resolution comes for free (the
## iris fibres / limbal ring / pupil are analytic, not sampled from a texture).
func _build_eye_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = EYE_SHADER
	for key in _eye_params:
		mat.set_shader_parameter(key, _eye_params[key])
	return mat


## Override eye appearance (a subset of EYE_PARAMS_DEFAULT keys is enough — e.g.
## {"iris_color": Color(...), "pupil_aspect": 0.25} for a vertical-slit exotic eye) and
## re-apply the eye material if the proxy is already built. Deterministic: pure data in.
func set_eye_params(params: Dictionary) -> void:
	for key in params:
		_eye_params[key] = params[key]
	if proxy_instance != null and _proxy_surface.has("eyes"):
		proxy_instance.set_surface_override_material(_proxy_surface["eyes"], _build_eye_material())


## Show/hide a proxy piece at runtime (e.g. toggling genitals). Re-applies the material.
func set_proxy_visible(piece: String, visible: bool) -> void:
	if proxy_instance == null or not _proxy_surface.has(piece):
		return
	if piece == "genitals":
		show_genitals = visible   # so a later morph re-bake keeps the chosen visibility
	var si: int = _proxy_surface[piece]
	var kind := "default"
	for s in ProxyMorph.surfaces():
		if String(s["name"]) == piece:
			kind = String(s["material"]); break
	proxy_instance.set_surface_override_material(si, _proxy_material(kind, visible))


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
	# Advance the deterministic idle clock (drives the relaxed-idle micro-motion).
	# A pure delta accumulator — no Math.random, no wall-clock; the idle pose is a
	# reproducible function of accumulated idle time. Bounded to keep it stable.
	_idle_time = fposmod(_idle_time + delta, TAU * 1000.0)
	# Advance the breath phase by the (jittered, exertion-scaled) breath rate. When a
	# breath cycle completes (phase wraps past TAU), redraw the next cycle's rate jitter
	# from the COSMETIC rng so the breath is never perfectly periodic — yet stays
	# reproducible from the cosmetic seed. Pure render-side.
	if micro != null and micro.breathing_enabled:
		var rate := TAU * micro.breath_rate_hz * exertion_breath_mult * _breath_cycle_rate
		_breath_phase += rate * delta
		if _breath_phase >= TAU:
			_breath_phase = fposmod(_breath_phase, TAU)
			_breath_cycle_rate = 1.0 + _cosmetic_rng.randf_range(-1.0, 1.0) * micro.breath_rate_jitter

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
		apply_micro_life(delta)
		return

	# Seed the layered bones with the captured MOCAP IDLE stance before re-posing (so
	# the pose is a pure function of state, not an accumulation, AND so the idle floor
	# of this procedural fallback is the genuine still-standing mocap pose — never the
	# bind pose). The walk/run swing layers additively on top and dominates as speed
	# rises. The idle frame is the deterministic zero-goal match (Neutral_ID); if no DB
	# is loaded we fall back to rest + micro-motion (degraded, but never bind-frozen).
	var idle_frame := matcher.search(Vector2.ZERO, 0.0) if matcher != null and motion_db != null else -1
	for bname in [HIP_L, HIP_R, KNEE_L, KNEE_R, SHOULDER_L, SHOULDER_R, FOOT_L, FOOT_R, ROOT_BONE]:
		if _rest_local.has(bname):
			var rest: Transform3D = _rest_local[bname]
			var rq := rest.basis.get_rotation_quaternion()
			var seed_q := rq
			if idle_frame >= 0:
				var dbi := motion_db.bone_names.find(bname)
				if dbi >= 0:
					seed_q = (rq * motion_db.pose_quat(idle_frame, dbi)).normalized()
			seed_q = (seed_q * _idle_micro(bname, 1.0)).normalized()
			skeleton.set_bone_pose_position(_bone_index[bname], rest.origin)
			skeleton.set_bone_pose_rotation(_bone_index[bname], seed_q)

	# --- procedural walk/run cycle -------------------------------------------
	# Phase advances with DISTANCE (speed * dt / stride) so cadence scales with
	# speed; at rest the phase freezes and the swing blend -> 0 (relaxed idle).
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
	# the back-swing (a cheap, readable gait). Arms counter-swing the legs. Applied
	# ADDITIVELY onto the relaxed-idle baseline seeded above (so at rest the body
	# holds the relaxed stand, and the swing fades in over it as speed rises).
	_rotate_bone_local(HIP_L, Vector3.RIGHT, s * swing, true)
	_rotate_bone_local(HIP_R, Vector3.RIGHT, s_opp * swing, true)
	_rotate_bone_local(KNEE_L, Vector3.RIGHT, maxf(0.0, -s) * swing * 1.4, true)
	_rotate_bone_local(KNEE_R, Vector3.RIGHT, maxf(0.0, -s_opp) * swing * 1.4, true)
	_rotate_bone_local(SHOULDER_L, Vector3.RIGHT, s_opp * arm, true)
	_rotate_bone_local(SHOULDER_R, Vector3.RIGHT, s * arm, true)

	if grounded and foot_ik_enabled and _space != null:
		_apply_foot_ik()

	apply_micro_life(delta)


# --- Slice 4: Motion-Matching pose ------------------------------------------
# Deterministically search the feature DB for the frame best matching the current
# MovementState-derived goal, then apply that frame's per-bone local rotations to
# the skeleton. RENDER-SIDE; pure function of (goal, DB). Resets the MM-driven
# bones to rest first so the pose is a pure function of the matched frame.
var _mm_frame: int = 0

## Below this planar speed (m/s) the body is treated as standing still: Motion
## Matching resolves the zero-velocity goal to a genuine 100STYLE idle (Neutral_ID)
## frame, and the deterministic micro-motion below is layered at full strength so
## the still body is ALIVE (breathing / weight-shift), never frozen and never the
## skeleton's neutral/bind pose. Between idle_speed and idle_blend_top the micro-
## motion fades out as the captured locomotion swing takes over. Render-side only.
##
## This replaces the former HAND-AUTHORED relaxed stance (commit 66e7d47): that was
## a stopgap only because the BVH→MakeHuman retarget carried a frame-of-reference
## error (it used BVH MOTION frame 0 — an arbitrary posed frame — as the bind
## reference, throwing the matched idle's root ~65° and forearm ~94° off). The
## retarget now transfers the de-yawed GLOBAL orientation against each skeleton's
## true bind (tools/motion_ingest.gd), so a zero goal resolves to a NATURAL captured
## stand and no authored stance is needed.
@export var idle_speed: float = 0.15
@export var idle_blend_top: float = 0.9

func _apply_motion_matching() -> void:
	# Step the matcher (deterministic argmin / clip-advance) with the goal. A zero
	# goal deterministically resolves to a Neutral_ID idle frame (correct now that the
	# retarget frame-of-reference is fixed); a locomotion goal resolves to walk/run.
	var vel := local_velocity
	if not grounded:
		# Airborne: the locomotion DB has no fall clips; freeze the goal at idle so
		# MM holds the captured stand (foot-IK is also skipped while airborne).
		vel = Vector2.ZERO
	_mm_frame = matcher.step(vel, turn_rate)

	# Micro-motion weight: 1 at/below idle_speed (full breathing/weight-shift over the
	# captured stand), 0 at/above idle_blend_top (locomotion carries its own motion).
	# Pure function of the render-side smoothed speed — no accumulation, no sim feedback.
	var idle_w := 1.0 - clampf((_smoothed_speed - idle_speed) / maxf(idle_blend_top - idle_speed, 1e-3), 0.0, 1.0)

	# Stamp the matched captured pose (the genuine mocap frame) on every MM-driven bone,
	# then layer the deterministic idle micro-motion scaled by idle_w. The pose is a pure
	# function of (matched frame, _idle_time) — same seed + sim-time -> same pose.
	var nb := motion_db.bone_count
	for bi in nb:
		var bname := motion_db.bone_names[bi]
		if not _bone_index.has(bname):
			continue
		var rest: Transform3D = _rest_local.get(bname, Transform3D.IDENTITY)
		var rest_q := rest.basis.get_rotation_quaternion()
		# The DB quats are MH-bone-local pose rotations (rest bases are identity); compose
		# onto rest to be robust to any future non-identity rest.
		var q := (rest_q * motion_db.pose_quat(_mm_frame, bi)).normalized()
		if idle_w > 0.0:
			q = (q * _idle_micro(bname, idle_w)).normalized()
		# Keep the bone's rest position (sim owns root translation); supply orientation.
		var idx: int = _bone_index[bname]
		skeleton.set_bone_pose_position(idx, rest.origin)
		skeleton.set_bone_pose_rotation(idx, q)


## Deterministic breathing / weight-shift micro-motion as a small LOCAL rotation
## offset for a bone, scaled by `w` (0 fades it out as locomotion takes over). Pure
## function of (bone, _idle_time, w): same idle time -> same offset — the determinism
## invariant for this render layer. NO authored stance: this only ADDS life (a faint
## breath + sway) on top of the captured mocap pose; the stand itself is the mocap.
func _idle_micro(bname: String, w: float) -> Quaternion:
	# Breath uses the JITTERED render-side breath phase (alive, not metronomic); sway
	# uses the plain idle clock. Both amplitudes/enables come from the tunable params,
	# so the rates are dialable rather than the former hardcoded sin() frequencies.
	var p := micro if micro != null else MicroLifeParams.new()
	var breath := 0.0
	if p.breathing_enabled:
		breath = sin(_breath_phase) * w * p.breath_amplitude
	var sway := 0.0
	if p.sway_enabled:
		sway = sin(_idle_time * (TAU * p.sway_rate_hz)) * w * p.sway_amplitude
	match bname:
		"spine01":
			return Quaternion(Vector3.RIGHT, -breath * 0.015) * Quaternion(Vector3.BACK, sway * 0.01)
		"spine03":
			return Quaternion(Vector3.RIGHT, -breath * 0.012)
		"clavicle.L", "clavicle.R":
			return Quaternion(Vector3.RIGHT, breath * 0.012)
		"upperarm01.L":
			return Quaternion(Vector3.RIGHT, breath * 0.02)
		"upperarm01.R":
			return Quaternion(Vector3.RIGHT, breath * 0.02)
		"upperleg01.L":
			return Quaternion(Vector3.BACK, sway * 0.012)
		"upperleg01.R":
			return Quaternion(Vector3.FORWARD, sway * 0.012)
		"head":
			return Quaternion(Vector3.BACK, -sway * 0.01)
		_:
			return Quaternion.IDENTITY


## Expose the matched frame for tests (which DB frame the MM search chose).
func motion_matched_frame() -> int:
	return _mm_frame


# ---------------------------------------------------------------------------
# §micro-life — procedural SECONDARY MOTION (hair + soft-region jiggle) and the
# eye-saccade jitter. RENDER-SIDE / COSMETIC.
#
# === HOW THIS IS KEPT OFF THE SIM-DETERMINISM PATH ===
# 1. It is called ONLY at the tail of apply_pose() — itself a documented render-side
#    read of MovementState that never writes the sim (movement-substrate §6 excludes
#    animation from the sim hash).
# 2. The irregular bits (breath-rate jitter, micro-saccade timing/targets) draw from
#    `_cosmetic_rng` — a stream SEPARATE from any sim RNG. It is seeded (reproducible
#    visuals) but the sim never advances it and never reads it, so it cannot perturb
#    the seeded sim timeline.
# 3. The spring-bones are explicitly FRAME-DRIVEN (real delta) — allowed because their
#    state is private to this node, layered onto bone poses only, and NEVER read back
#    into any sim quantity. Nothing here returns into MovementState or the event log.
# Net: same as the rest of the render layer, the golden-trace / behavioral suites are
# the regression guard — they construct a body-less player so this path can't touch them.
# ---------------------------------------------------------------------------

## Advance + apply the secondary-motion layer for this frame. Layers ADDITIVELY on top
## of the already-computed gross pose (locomotion/MM + foot-IK), so it never fights the
## base animation — it only adds the lag/settle of soft tissue and hair.
func apply_micro_life(delta: float) -> void:
	if skeleton == null or micro == null or delta <= 0.0:
		return
	# Eye micro-saccades (advances the offset the face rig layers under its gaze).
	if micro.saccade_enabled:
		_step_saccade(delta)
	# Hair spring-bones (gap on the CC0 default rig — empty registry, no-op there).
	if micro.hair_enabled:
		for bn in _hair_springs:
			var sb: SpringBone = _hair_springs[bn]
			var q := sb.step(skeleton, delta, micro.hair_stiffness, micro.hair_damping,
				micro.hair_inertia, micro.hair_max_angle)
			if q != Quaternion.IDENTITY:
				var i: int = sb.bone_idx
				skeleton.set_bone_pose_rotation(i, (skeleton.get_bone_pose_rotation(i) * q).normalized())
	# Soft-region jiggle (breast.L/R present; conservative gain by default).
	if micro.jiggle_enabled:
		for bn in _jiggle_springs:
			var sb2: SpringBone = _jiggle_springs[bn]
			var q2 := sb2.step(skeleton, delta, micro.jiggle_stiffness, micro.jiggle_damping,
				micro.jiggle_gain, micro.jiggle_max_angle)
			if q2 != Quaternion.IDENTITY:
				var j: int = sb2.bone_idx
				skeleton.set_bone_pose_rotation(j, (skeleton.get_bone_pose_rotation(j) * q2).normalized())


## Advance the micro-saccade: small, irregular eye darts. New target chosen at jittered
## intervals from the COSMETIC rng; the offset eases toward it each frame. Exposed via
## saccade_offset() so the FaceRig can ADD it under its gaze/LookWander (never fights).
func _step_saccade(delta: float) -> void:
	_saccade_timer -= delta
	if _saccade_timer <= 0.0:
		# Next interval jittered ±50% around the mean; small new target.
		_saccade_timer = micro.saccade_interval_s * _cosmetic_rng.randf_range(0.5, 1.5)
		var a := micro.saccade_amplitude
		_saccade_target = Vector2(_cosmetic_rng.randf_range(-a, a), _cosmetic_rng.randf_range(-a, a))
	# Fast ease (saccades are quick darts).
	var t := clampf(delta * 25.0, 0.0, 1.0)
	_saccade_offset = _saccade_offset.lerp(_saccade_target, t)


## The current micro-saccade eye offset in normalized look units (~[-amp, amp]).
## The FaceRig adds this UNDER its gaze/LookWander so the eyes are never dead-still.
func saccade_offset() -> Vector2:
	return _saccade_offset


## Snapshot the micro-life layer (for tests / debug). Pure read.
func micro_life_state() -> Dictionary:
	return {
		"breath_phase": _breath_phase,
		"saccade_offset": _saccade_offset,
		"hair_springs": _hair_springs.size(),
		"jiggle_springs": _jiggle_springs.size(),
	}


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
