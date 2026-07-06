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
## visibility follows the NSFW flag. Hair is hidden by default: the only proxy "hair"
## surface is the CC0 helper-hair guide mesh (a long mid-back/chest drape, NOT a scalp
## cap — see docs/artifacts/diagnosis/hair-parts.md), which renders as black slabs over
## the face. So the default body shows the FACE; a real BDCC2 hairstyle (a separate GLB
## attachment) is opt-in. (Not the hair-system redesign — just stop defaulting to the
## broken cap.)
const PROXY_DEFAULT_HIDDEN := {"genitals": true, "hair": true}
## The single SKIN tone, shared by the body mesh AND the genital proxy so the genitals
## follow skin tone/masculinity (not a fixed paler colour) — fixing the pale-genital seam.
const SKIN_ALBEDO := Color(0.86, 0.68, 0.58)
## Fallback flat roughness for proxy/part materials that derive from the skin colour but
## don't carry the full Tier-A map set. The body skin itself uses SKIN_ROUGHNESS_TIER_A.
const SKIN_ROUGHNESS := 0.7

# --- Skin Tier-A material tuning (§6.2 creator-body decision) -------------------
## A skin base roughness lower than the old flat 0.7 — real skin is semi-matte but not as
## diffuse as 0.7 (which reads chalky/plastic-flat); 0.55 gives a subtle sheen without a
## hard specular hotspot. The detail-normal breaks the specular up across the micro-surface.
const SKIN_ROUGHNESS_TIER_A := 0.55
## Detail-normal UV tiling: how many times the generated pore normal repeats across the
## body UV atlas. High enough that pores read as micro-surface, not macro blobs.
const SKIN_DETAIL_UV_SCALE := 48.0
## Detail-normal strength (normal_scale on the detail layer) — subtle, skin-like, not a
## reptilian relief. 0.35 is a gentle micro-pore break-up.
const SKIN_DETAIL_NORMAL_STRENGTH := 0.35
## Generated detail-normal texture resolution + noise frequency. A small seamless tile
## (it repeats SKIN_DETAIL_UV_SCALE× over the body), procedurally generated at build (no
## skin PBR map ships with MakeHuman). Seeded so the tile is byte-reproducible.
const SKIN_DETAIL_TEX_SIZE := 256
const SKIN_DETAIL_NOISE_FREQ := 0.18
const SKIN_DETAIL_NOISE_SEED := 1337
## Subsurface scattering strength + skin tint (warm red, the classic skin SSS look).
## Forward+ only — gated OFF on Quest/Mobile (SSS is a screen-space Forward+ effect).
const SKIN_SSS_STRENGTH := 0.25
const SKIN_SSS_TINT := Color(0.80, 0.30, 0.22)
## Slice 4 — the committed Motion-Matching feature DB (100STYLE CC BY 4.0). When
## present, MM drives the gross body pose (replacing the procedural sine cycle);
## foot-IK stays the ground-adaptation layer on top. When absent, the Slice-3
## procedural cycle is the graceful-degradation floor (decision doc §3.2).
const MOTION_DB_PATH := "res://assets/body/locomotion_mm.res"

## Mined BDCC2 animation clips (alexofp/Rahi, MIT — see NOTICE.md), retargeted onto
## this same MH rig (tools/bdcc2_clip_ingest.gd -> scripts/body/clip_db.gd). These
## AUGMENT locomotion: idle variants/fidgets bound to the standing state, plus
## gestures (wave/nod/talk/...) playable as one-shot emotes. Locomotion stays the
## MM/procedural layer; the clip layer overlays the upper body on top via aeriea's
## OWN pose stamp (NOT BDCC2's anim architecture). RENDER-SIDE + deterministic.
const CLIP_DB_PATH := "res://assets/body/bdcc2_clips.res"
const ClipDB := preload("res://scripts/body/clip_db.gd")

## Upper-body bones the clip layer overlays (gestures/idles drive these). The legs/
## root stay owned by the locomotion layer so a gesture never disturbs the gait or
## body heading; an idle-fidget while STANDING also overlays only these (the still
## stance's legs come from the MM idle frame underneath).
const CLIP_UPPER_BONES := [
	"spine04", "spine02", "spine01", "neck01", "head",
	"clavicle.L", "upperarm01.L", "lowerarm01.L", "wrist.L",
	"clavicle.R", "upperarm01.R", "lowerarm01.R", "wrist.R",
]

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

# Arm chain bone names (MakeHuman default rig). Analytic two-bone arm-IK uses
# shoulder(upperarm)/elbow(lowerarm)/wrist — mirroring the leg's hip/knee/ankle.
const UPPERARM_L := "upperarm01.L"
const UPPERARM_R := "upperarm01.R"
const LOWERARM_L := "lowerarm01.L"
const LOWERARM_R := "lowerarm01.R"
const WRIST_L := "wrist.L"
const WRIST_R := "wrist.R"

const SpringBone := preload("res://scripts/body/spring_bone.gd")
const MicroLifeParams := preload("res://scripts/body/micro_life_params.gd")
const PartLibrary := preload("res://scripts/body/part_library.gd")

## A sentinel collapse point well below the feet; verts collapsed here form degenerate
## (zero-area) triangles that render no fragments and sit off-screen under the floor. Used by
## _hide_proxy_surfaces to hide cosmetic face proxy pieces (e.g. eyes/brows/lashes) without
## touching the index buffer.
const MASK_COLLAPSE_POINT := Vector3(0.0, -1000.0, 0.0)

## Soft-region bones the jiggle layer drives (spring-bones). breast.L/R come straight
## from the CC0 MakeHuman default rig; belly + glute.L/R are INJECTED by the body
## pipeline (tools/body_converter.gd) — deterministic bones placed from the existing
## joint cubes, with belly/glute-region body-mesh verts re-weighted onto them — so the
## jiggle springs actually deform geometry. All five resolve to real bones today.
const SOFT_REGION_BONES := ["breast.L", "breast.R", "belly", "glute.L", "glute.R"]
## Name fragments that mark a HAIR bone for the hair spring-bone chain. The base mesh is
## bald-RIGGED (no hair bones in the stock CC0 rig), so the pipeline injects a hair01/02/
## 03 chain off the head and re-skins the CC0 helper-hair scalp cap (rendered as the
## "hair" proxy surface) onto it — so this fragment now resolves to a real chain and the
## hair spring physics animates the cap. (See tools/body_converter + body_proxy_build.)
const HAIR_BONE_FRAGMENTS := ["hair"]

## Tuning (render-side only).
@export var stride_length: float = 0.9      ## metres of speed-phase per cycle
@export var max_leg_swing_deg: float = 35.0  ## peak thigh swing at run speed
@export var max_arm_swing_deg: float = 28.0
@export var run_speed_ref: float = 9.0       ## speed at which swing/cadence peak
@export var ik_ray_up: float = 0.6           ## ray origin above ankle
@export var ik_ray_down: float = 0.9         ## ray reach below ankle
@export var foot_ik_enabled: bool = true

## --- Foot-lock locomotion (kills foot-skate under Motion-Matching) -----------
## The captured 100STYLE clip's leg swing does NOT match the sim's ground travel, so the
## stance foot conveyor-belts backward at body speed (skate) and the clip's static section
## glides. Foot-lock replaces the MM leg pose with a distance-phased, sagittal-plane
## two-bone IK whose stance foot is WORLD-ANCHORED: the foot target is expressed in the
## pelvis frame with a backward stance sweep at the nominal locomotion speed, so when the
## body translates at that speed the planted foot holds its world position (the body passes
## over it — no skate), and when previewed in place (creator) the same sweep reads as a
## legible treadmill stride. Cadence matches travel BY CONSTRUCTION: the gait phase advances
## with distance (speed·dt / stride), never a fixed clip cadence. Deterministic (phase +
## smoothed speed only; no wall-clock/RNG). The MM pose still owns the upper body/arms.
@export var foot_lock_enabled: bool = true
## Metres of ground travel per full L+R gait cycle (one stride = two steps). Kept short
## enough that the per-foot stance sweep stays inside the leg's reach.
@export var gait_stride: float = 0.7
## Fraction of each foot's cycle spent planted (stance). >0.5 gives a double-support overlap
## (both feet down) like a real walk; the airborne swing gets the rest.
@export var stance_duty: float = 0.6
## Peak swing-foot lift (metres) above the ground during the airborne phase.
@export var foot_lift_height: float = 0.10
## Locomotion crouch (metres the pelvis lowers while walking). DISABLED (0.0): it was
## applied by TRANSLATING the root BONE (see _apply_foot_lock), but the root bone's
## translation is reserved for the sim ("sim owns root translation" — _apply_motion_matching)
## and driving it here desynced the skinned body mesh — the head visibly SPLIT into a
## skull + a dropped face during locomotion (the "double head" defect, distinct from the
## corrupt-DB double head; see docs/decisions/locomotion-upper-body-posture.md). The legs
## still plant without skating without it (the world-anchored foot-IK targets are what kill
## the skate, not the pelvis drop — verified by rendered walk cycles). A proper lowered-COM
## crouch that offsets the skeleton NODE (feet re-anchored by IK) instead of the root bone
## is a future refinement.
@export var gait_crouch: float = 0.0
## Planar speed (m/s) below which foot-lock is inactive (the MM idle stand holds); it eases
## in between this and foot_lock_full_speed so a start/stop never pops.
@export var foot_lock_min_speed: float = 0.2
@export var foot_lock_full_speed: float = 1.2

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
## Proxy pieces EXPLICITLY force-hidden via set_proxy_visible(piece, false) (a manual override on
## top of the authoritative derive). piece name -> true. Honoured by _proxy_piece_visible so a
## morph re-bake keeps a manually-hidden piece hidden. (genitals use show_genitals, not this.)
var _proxy_force_hidden := {}

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
## Spring-bone instances for soft-region jiggle: name -> SpringBone (all on `skeleton`).
var _jiggle_springs := {}
## Part spring entries, keyed "slot:partid:bonename". Each value is {"skel": Skeleton3D,
## "sb": SpringBone}. The springs may live on `skeleton` itself (the CC0 hair cap's
## hair01/02/03 chain) OR on the little Skeleton3D shipped INSIDE a BDCC2 part GLB
## (DEF-Tail1..N / DEF-Ear.* bones). step() takes the skeleton as a parameter, so the
## SAME spring physics drives either source. This is the generalized replacement for the
## former hair-only registry: hair, ears, and tails all register here.
var _part_springs := {}
## The currently applied part id PER SLOT (PartLibrary). Defaults to each slot's default
## (hair -> CC0 cap; ears/tail/horns -> none).
var _current_part := {}
## Per slot: the BoneAttachment3D node(s) parenting the loaded part GLB(s) under the
## slot's bone (so the part rides that bone). slot -> Array[BoneAttachment3D]. Empty for a
## slot showing its empty/default. Freed + cleared on a swap.
var _part_attachments := {}
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

## --- BDCC2 clip layer ---------------------------------------------------------
## Loaded in build() iff CLIP_DB_PATH loads. The upper-body overlay (idles/gestures).
var clip_db: ClipDB
## Master enable for the clip overlay (render-side cosmetic toggle).
var clip_layer_enabled: bool = true
## The currently-playing clip index (-1 = none), its clip-local time, and whether it
## loops. Gestures play once (loop=false) then clear; idle fidgets loop.
var _clip_idx: int = -1
var _clip_time: float = 0.0
var _clip_loop: bool = false
## Overlay weight 0..1, eased in/out so a gesture blends onto the body rather than
## snapping. A one-shot gesture eases back to 0 as it ends.
var _clip_weight: float = 0.0
## Clip-to-clip crossfade: when play_clip replaces an already-driving clip, the
## OUTGOING clip's pose is retained (its index + the time it was interrupted at,
## frozen) and blended into the incoming clip's pose over clip_crossfade_dur via
## per-bone quaternion slerp, so A->B eases instead of popping. -1 = no crossfade
## active. This is orthogonal to _clip_weight (the overlay-vs-base ease), which
## still handles fade-in from rest and fade-out at a one-shot's end.
var _xfade_idx: int = -1
var _xfade_prev_time: float = 0.0
var _xfade_time: float = 0.0
## Idle-fidget scheduler: how long the body has been standing still (sim-time accum),
## and the next scheduled fidget time. Deterministic (pure delta accumulator + the
## cosmetic rng), so the same standing duration -> the same fidget — never wall-clock.
var _stand_time: float = 0.0
var _next_fidget_at: float = 0.0
## Idle-variant clip ids picked for fidgets while standing (subset of the mined idles).
const IDLE_FIDGET_CLIPS := ["idle_long", "idle_long_idle", "idle_sexy", "sigh", "look_away", "thinking"]
## Seconds of continuous standing before the first idle fidget, and the spacing range.
@export var fidget_first_delay: float = 4.0
@export var fidget_min_gap: float = 6.0
@export var fidget_max_gap: float = 14.0
## Speed (m/s) under which the body counts as "standing" for fidget scheduling.
@export var clip_stand_speed: float = 0.3
## How fast the overlay weight eases in/out (per second).
@export var clip_blend_speed: float = 4.0
## Duration (seconds) of the clip-to-clip pose crossfade when one clip replaces
## another that is already driving the overlay. Short by design (a gesture swap, not
## a locomotion blend); 0 disables the crossfade (hard switch). Default 0.15s.
@export var clip_crossfade_dur: float = 0.15

## The space state used for foot-IK raycasts; the host supplies its world.
var _space: PhysicsDirectSpaceState3D
var _ik_exclude: Array = []

## --- arm IK/FK layer ----------------------------------------------------------
## Per-arm reach state, keyed "L"/"R". When a side has an entry the analytic two-
## bone arm-IK overrides that arm's shoulder→elbow→wrist toward a WORLD target,
## blended by `weight` (0 = pure FK/anim base, 1 = full IK). Empty side => weight 0,
## the arm follows the locomotion/clip/MM base pose unchanged. Fields per entry:
##   target  : Vector3   world-space goal for the wrist
##   pole    : Vector3   world-space elbow hint (the elbow is pushed toward this);
##                       Vector3.INF => auto (a default down/out hint per side)
##   weight  : float     0..1 IK/FK blend
## Pure render-side: a function of (target, pole, current pose) — off the sim path,
## same contract as foot-IK / clip / micro-life (excluded from the sim hash).
var _arm_reach := {}
## Master enable for the arm-IK layer (render-side cosmetic toggle, like clip/foot IK).
@export var arm_ik_enabled: bool = true


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
	# Skin Tier-A material (§6.2 creator-body decision): a generated tiling detail-normal
	# (micro-surface pores — MakeHuman ships NO skin PBR maps, so it is generated), a skin
	# roughness (kills the flat plastic sheen), and subsurface scattering (Forward+ only,
	# gated OFF on Quest/Mobile). The genital proxy shares THIS material (see
	# _proxy_material) so its tone follows the body skin (no pale-genital seam).
	_skin_material = _build_skin_material()
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

	# BDCC2 clip layer — load the committed retargeted clip DB if present. Absent =>
	# the body still locomotes (MM/procedural); only the idle-fidget / gesture overlay
	# is skipped. RENDER-SIDE only.
	if ResourceLoader.exists(CLIP_DB_PATH):
		var cdb = load(CLIP_DB_PATH)
		if cdb is ClipDB and cdb.frame_count > 0:
			clip_db = cdb

	# Bake the initial BodyState morph (default = neutral) with correct normals. This
	# establishes the neutral-base capture on the MeshInstance metadata so later
	# re-morphs are stable and non-cumulative.
	apply_body_state(body_state)

	# --- procedural micro-life + secondary-motion layer ----------------------
	# Build the tunable params (conservative default if none supplied) and register
	# the spring-bone chains for hair + soft-region jiggle. RENDER-SIDE / cosmetic.
	_setup_micro_life()

	return true


## Whether the active renderer supports the Forward+ subsurface-scattering screen-space
## effect. SSS is NOT available on the Mobile / GL-compatibility renderers (Quest standalone
## runs the Mobile renderer), so it must be gated OFF there per §6.2 — the body then renders
## with normal + roughness only (the rest of Tier-A is renderer-agnostic). Reads the
## CONFIGURED rendering method ("forward_plus" / "mobile" / "gl_compatibility"); a Quest /
## mobile build sets this to "mobile" via its platform render override, so SSS is dropped
## there by construction. (RenderingServer has no static rendering-method getter in this
## Godot build, so the project setting is the available, correct tier signal.)
static func _supports_sss() -> bool:
	var method := str(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "forward_plus"))
	# On a mobile platform Godot uses the .mobile override key when present.
	if OS.has_feature("mobile"):
		method = str(ProjectSettings.get_setting(
			"rendering/renderer/rendering_method.mobile", method))
	return method == "forward_plus"


## Build the Tier-A skin material (§6.2 creator-body decision): albedo + a generated tiling
## DETAIL NORMAL (micro-surface pores — no skin PBR map ships with MakeHuman) + a skin
## ROUGHNESS (kills the flat plastic sheen) + SUBSURFACE SCATTERING (Forward+ only, gated
## OFF on Quest/Mobile). A StandardMaterial3D so the genital/part materials can keep
## deriving from it. NOT a per-instance random look — the detail tile is seeded, so the
## skin is byte-reproducible across runs.
func _build_skin_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SKIN_ALBEDO
	mat.roughness = SKIN_ROUGHNESS_TIER_A
	# (a) DETAIL NORMAL — a generated, tiling micro-pore normal layered on top of the base
	# (the base mesh ships no skin normal map). The detail layer multiplies/overlays onto the
	# main surface; with no main normal map the detail normal IS the surface micro-relief.
	mat.detail_enabled = true
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	mat.detail_normal = _generate_skin_detail_normal()
	# A neutral white detail albedo so the detail layer changes only the surface normal,
	# not the skin colour (the albedo break-up is left subtle / for Tier-B). An opaque-white
	# tile makes the detail-albedo MIX a no-op so only the detail NORMAL contributes.
	var di := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	di.fill(Color(1, 1, 1, 1))
	mat.detail_albedo = ImageTexture.create_from_image(di)
	# Tile the detail map densely so pores read as micro-surface (uv1_scale also scales the
	# DETAIL_UV_1 layer — the detail normal repeats SKIN_DETAIL_UV_SCALE× across the atlas).
	mat.uv1_scale = Vector3(SKIN_DETAIL_UV_SCALE, SKIN_DETAIL_UV_SCALE, 1.0)
	mat.normal_enabled = true
	mat.normal_scale = SKIN_DETAIL_NORMAL_STRENGTH
	# (c) SUBSURFACE SCATTERING — the warm under-skin light bleed. Forward+ ONLY; on
	# Quest/Mobile (the Mobile renderer) it is not available, so gate it OFF there (§6.2).
	if _supports_sss():
		mat.subsurf_scatter_enabled = true
		mat.subsurf_scatter_strength = SKIN_SSS_STRENGTH
		mat.subsurf_scatter_skin_mode = true
		mat.subsurf_scatter_transmittance_color = SKIN_SSS_TINT
	return mat


## Generate the tiling skin DETAIL NORMAL texture (§6.2). No skin normal map ships with
## MakeHuman, so a subtle micro-pore normal is generated procedurally from seamless noise.
## NoiseTexture2D with as_normal_map=true converts the height noise to a tangent-space
## normal map at build; seamless so it tiles across the densely-repeated detail UVs without
## a visible seam. Seeded → byte-reproducible.
func _generate_skin_detail_normal() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = SKIN_DETAIL_NOISE_SEED
	noise.frequency = SKIN_DETAIL_NOISE_FREQ
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = SKIN_DETAIL_TEX_SIZE
	tex.height = SKIN_DETAIL_TEX_SIZE
	tex.seamless = true
	tex.as_normal_map = true
	# A gentle bump depth — the perceived strength is normal_scale on the material; this
	# keeps the generated normals from being a harsh relief at the source.
	tex.bump_strength = 1.2
	tex.noise = noise
	return tex


## Initialise the micro-life layer: default params if none, seed the COSMETIC rng,
## and register spring-bones for any present hair / soft-region bones. Idempotent.
func _setup_micro_life(p_seed: int = 0) -> void:
	if micro == null:
		micro = MicroLifeParams.new()
	_cosmetic_rng.seed = p_seed
	_breath_cycle_rate = 1.0 + _cosmetic_rng.randf_range(-1.0, 1.0) * micro.breath_rate_jitter
	_jiggle_springs.clear()
	if skeleton == null:
		return
	# Default each slot to its fallback id the first time (idempotent: keeps any already-
	# applied part across a re-seat). Hair defaults to the CC0 cap; others to "none".
	for slot in PartLibrary.slots():
		if not _current_part.has(slot):
			_current_part[slot] = PartLibrary.default_id(slot)
	# Register springs for whatever parts are active across ALL slots (the CC0 hair cap
	# chain on the body skeleton, OR each BDCC2 part GLB's own skeleton bones). Re-
	# registering here re-seats the springs after a rebuild; the swap API re-registers on
	# a part change.
	_register_part_springs()
	# Soft-region jiggle: breast.L/R (stock rig) + belly/glute.L/R (pipeline-injected,
	# skinned to the abdomen/buttock body verts) all resolve to real bones now.
	for bn in SOFT_REGION_BONES:
		if _bone_index.has(bn):
			_jiggle_springs[bn] = _make_spring(skeleton, _bone_index[bn])


## (Re)build _part_springs across ALL slots for the currently-applied parts.
##   - The CC0 hair cap registers the injected hair01/02/03 chain on the BODY skeleton
##     (matched by HAIR_BONE_FRAGMENTS) — the legacy default, unchanged.
##   - Every BDCC2 part marked `sway` registers a spring on every non-Root physics bone of
##     each of its attached GLB skeletons (DEF-Tail1..N / DEF-Ear.* etc.). BDCC2's bone
##     names don't carry "hair", so we drive ALL non-anchor bones. Rigid parts (horns:
##     `sway=false`, no skeleton) register nothing — they attach and ride the bone only.
func _register_part_springs() -> void:
	_part_springs.clear()
	for slot in PartLibrary.slots():
		var id: String = _current_part.get(slot, PartLibrary.default_id(slot))
		# The CC0 hair cap is the one part whose springs live on the BODY skeleton's
		# injected hair chain rather than on an attached GLB skeleton.
		if slot == PartLibrary.SLOT_HAIR and id == PartLibrary.HAIR_CAP:
			for i in skeleton.get_bone_count():
				var bn := skeleton.get_bone_name(i)
				for frag in HAIR_BONE_FRAGMENTS:
					if bn.to_lower().contains(frag):
						_part_springs["hair:cap:%s" % bn] = {"skel": skeleton, "sb": _make_spring(skeleton, i)}
						break
			continue
		if not PartLibrary.sways(slot, id):
			continue
		# A swaying BDCC2 part: register a spring on each attached GLB skeleton's physics bones.
		for skel_node in _part_skeletons(slot):
			for i in skel_node.get_bone_count():
				var bnm: String = skel_node.get_bone_name(i)
				var low: String = bnm.to_lower()
				if low == "root" or low.begins_with("def-root") or low == "neutral_bone":
					continue   # the anchor / blender export stub — not a physics bone
				_part_springs["%s:%s:%s:%d" % [slot, id, bnm, skel_node.get_instance_id()]] = {
					"skel": skel_node, "sb": _make_spring(skel_node, i)}


## Build a SpringBone for `idx`, tracking a tip one bone-length down the bone's local
## Y (the MakeHuman bone axis). Length is estimated from the child bone if present, so
## the tracked tip is at the soft region's free end (where swing is visible).
func _make_spring(skel: Skeleton3D, idx: int) -> SpringBone:
	var sb := SpringBone.new()
	sb.bone_idx = idx
	sb.rest_local = skel.get_bone_rest(idx)
	# Estimate bone length from the first child's local offset; fall back to 8 cm.
	var length := 0.08
	for c in skel.get_bone_count():
		if skel.get_bone_parent(c) == idx:
			length = maxf(length, skel.get_bone_pose_position(c).length())
			break
	sb.tip_local = Vector3(0.0, length, 0.0)
	return sb


# --- swappable PARTS (BDCC2 mined meshes + CC0 / empty fallbacks) ----------------
# The generalized swap system. A slot (hair / ears / tail / horns) holds one part at a
# time; apply_part(slot, id) tears down the old attachment(s), attaches the new part's
# GLB(s) under the slot's aeriea bone via BoneAttachment3D, and re-registers spring physics
# on the parts that sway. Hair keeps its legacy behaviour as the SLOT_HAIR slot (the CC0
# cap is its default; BDCC2 hairstyles are parts in that slot). apply_hairstyle() remains a
# thin shim over apply_part(SLOT_HAIR, …) so existing callers/tests are unchanged.

## The Skeleton3D(s) of the currently attached BDCC2 part GLB(s) for `slot` (each GLB ships
## its OWN little rig), or [] when the slot shows its empty/default. Found under the slot's
## BoneAttachment3D(s).
func _part_skeletons(slot: String) -> Array:
	var out := []
	for att in _part_attachments.get(slot, []):
		if is_instance_valid(att):
			var sk := att.find_child("Skeleton3D", true, false) as Skeleton3D
			if sk != null:
				out.append(sk)
	return out


## Select + apply a part by (slot, id) — the generalized swap entry point. Slots: hair,
## ears, tail, horns (PartLibrary). Behaviour:
##   - default/empty id -> tear down any attached GLB(s); for hair show the CC0 cap surface
##     + re-register the hair01/02/03 chain; for ears/tail/horns leave a clean human.
##   - BDCC2 id -> load the mined GLB(s) (runtime GLTFDocument, no editor .import dep),
##     attach each under its aeriea bone (head for hair/ears/horns, spine05 for tails) via
##     a BoneAttachment3D, hide the hair cap if it's the hair slot, and (for swaying parts)
##     register spring physics on each GLB skeleton's own physics bones so aeriea's springs
##     sway BDCC2's geometry. Horns are rigid (no skeleton) -> attach only, no sway.
## Returns true on success. Unknown slot -> false; unknown id -> falls back to the slot's
## default. RENDER-SIDE / cosmetic: touches only attached nodes + the spring registry;
## never the deterministic sim.
func apply_part(slot: String, id: String) -> bool:
	if skeleton == null or not PartLibrary.PARTS.has(slot):
		return false
	if PartLibrary.get_part(slot, id).is_empty():
		id = PartLibrary.default_id(slot)
	# Tear down any previously attached GLB(s) for this slot.
	for att in _part_attachments.get(slot, []):
		if is_instance_valid(att):
			att.queue_free()
	_part_attachments[slot] = []
	_current_part[slot] = id
	var is_bdcc2 := PartLibrary.is_bdcc2(slot, id)
	# The hair slot also drives the CC0 cap proxy surface: it shows ONLY when the cap is on.
	if slot == PartLibrary.SLOT_HAIR and _proxy_surface.has("hair"):
		_set_hair_cap_visible(not is_bdcc2)
	if is_bdcc2:
		# An accessory part attaches its own GLB skeleton under an aeriea bone.
		var attached := _attach_part_glbs(slot, id)
		if not attached:
			# Load failed — fall back to the slot default so the slot is never broken, and
			# re-show aeriea's own hair cap if this is the hair slot.
			_current_part[slot] = PartLibrary.default_id(slot)
			if slot == PartLibrary.SLOT_HAIR and _proxy_surface.has("hair"):
				_set_hair_cap_visible(true)
			_register_part_springs()
			return false
	_register_part_springs()
	return true


## Compatibility shim: the original hair entry point, now delegating to the generalized
## slot system. Existing callers/tests keep working unchanged.
func apply_hairstyle(id: String) -> bool:
	return apply_part(PartLibrary.SLOT_HAIR, id)


## The currently applied part id for a slot (PartLibrary), or the slot default if unset.
func current_part(slot: String) -> String:
	return _current_part.get(slot, PartLibrary.default_id(slot))


## Load + attach every GLB of a BDCC2 part under its aeriea bone. Returns true iff at least
## one GLB attached. Uses GLTFDocument at runtime (the GLB is standard glTF binary —
## version-independent — avoiding any dependency on the editor import of a BDCC2 .tscn).
func _attach_part_glbs(slot: String, id: String) -> bool:
	var any := false
	var atts: Array = []
	for row in PartLibrary.glbs(slot, id):
		var att := _attach_one_glb(row, slot)
		if att != null:
			atts.append(att)
			any = true
	_part_attachments[slot] = atts
	return any


## Load one GLB (a {glb, attach_bone, offset?, scale?} row) and parent it under its bone via
## a bone-tracking BoneAttachment3D, applying the row's SEATING transform. Returns the
## attachment node, or null on failure.
##
## SEATING. BDCC2 authored each accessory against ITS OWN skeleton's attach point (ear.L /
## tail / horn.L) — points offset from the skull/pelvis origin to the actual ear/horn/tail
## location. aeriea attaches to its `head`/`spine05` BONE ORIGIN, which sits elsewhere, so a
## raw attach lands the part off-anatomy. The per-row `offset` (bone-local metres) + `scale`
## re-seat the BDCC2 frame onto aeriea's anatomy. These are TUNABLE cosmetic data (in
## PartLibrary), not magic numbers in code — same discipline as the micro-life dials.
func _attach_one_glb(row: Dictionary, slot: String) -> BoneAttachment3D:
	var glb_path := String(row.get("glb", ""))
	var bone := String(row.get("attach_bone", PartLibrary.SLOT_ATTACH_BONE.get(slot, "head")))
	if glb_path == "" or not FileAccess.file_exists(glb_path):
		return null
	if skeleton.find_bone(bone) < 0:
		return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(glb_path, st) != OK:
		return null
	var part_root := doc.generate_scene(st)
	if part_root == null:
		return null
	# A BoneAttachment3D that is a DIRECT child of the Skeleton3D auto-tracks that
	# skeleton's bone (no external-skeleton wiring needed); set bone_name AFTER add_child.
	var att := BoneAttachment3D.new()
	att.name = "%sAttachment" % slot.capitalize()
	skeleton.add_child(att)
	att.bone_name = bone
	att.add_child(part_root)
	# Seat the part: scale to aeriea's anatomy, then offset into place (bone-local). The
	# attachment auto-applies the bone's global transform; we set the part_root's LOCAL
	# transform relative to that.
	var sc := float(row.get("scale", 1.0))
	# RE-CENTER (uses the attach bone's REST BASIS). The offset is no longer a raw AABB-center
	# approximation in WORLD axes; we compute the bone-local offset that lands the part's geometric
	# center on the slot's anatomical TARGET (ear: head side; horn: head top), expressing the target
	# in the bone's REST BASIS so a non-identity bone frame is honoured:
	#   offset = bone_rest_basis^-1 * (target_global - bone_global_rest_origin) - scale*part_center
	# Then BoneAttachment (bone global pose) * (scale*v + offset) lands the center on the target.
	# A row may still pin an explicit `offset` (manual override) to bypass the derive.
	var off: Vector3
	if row.has("offset"):
		off = row["offset"]
	else:
		off = _accessory_seat_offset(slot, bone, glb_path, part_root, sc)
	part_root.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(sc, sc, sc)), off)
	# Replace the GLB's plain default material so the mined part doesn't render as a light
	# untextured blob. Hair gets the matte-keratin hair material; ears/tail/horns get a
	# skin/fur material matching the body (so a swapped ear/tail reads as flesh-fur, not grey).
	var part_mat: Material = _hair_part_material() if slot == PartLibrary.SLOT_HAIR else _part_skin_material()
	_apply_material_recursive(part_root, part_mat)
	return att


## Per-slot anatomical seat TARGET for an accessory, in the attach bone's REST frame (metres,
## relative to the bone origin, +x = character's left, +y up, +z forward). The L/R variants place
## the part on the correct side (derived from the GLB filename). These are DATA (the anatomical
## landmark the part's geometric center should sit on), distinct from the part's own geometry —
## the re-center math (below) maps the part center onto this target via the bone rest basis.
## Ears: head sides at ear height, slightly back. Horns: head top, forward. Head global rest is
## (0, 1.514, 0.016); head-region center (0, 1.549, 0.064), half-width ~0.088, top ~y1.666.
const ACCESSORY_SEAT_TARGET := {
	PartLibrary.SLOT_EARS: {"L": Vector3(0.085, 0.10, 0.00), "R": Vector3(-0.085, 0.10, 0.00)},
	PartLibrary.SLOT_HORNS: {"L": Vector3(0.05, 0.16, 0.05), "R": Vector3(-0.05, 0.16, 0.05)},
}


## Bone-local offset that lands the loaded part's geometric CENTER on the slot's anatomical seat
## target, computed in the attach bone's REST BASIS (so a non-identity bone frame is honoured):
##   offset = bone_rest_basis^-1 * target_bone_local - scale * part_center
## where target_bone_local is the per-slot target already expressed relative to the bone origin.
## L vs R is read from the GLB filename (…L.glb / …R.glb). Returns ZERO if the slot has no target.
func _accessory_seat_offset(slot: String, bone: String, glb_path: String, part_root: Node, scale: float) -> Vector3:
	if not ACCESSORY_SEAT_TARGET.has(slot):
		return Vector3.ZERO
	var side := "R" if glb_path.get_file().get_basename().ends_with("R") else "L"
	var target_local: Vector3 = ACCESSORY_SEAT_TARGET[slot][side]
	var bi := skeleton.find_bone(bone)
	if bi < 0:
		return Vector3.ZERO
	var rest_basis := skeleton.get_bone_global_rest(bi).basis
	var center := _node_geometry_center(part_root)
	return rest_basis.inverse() * target_local - scale * center


## Geometric center (AABB midpoint) of all MeshInstance3D geometry under `node`, in `node`'s local
## space (composing each descendant's transform). Used to re-center an attached accessory.
func _node_geometry_center(node: Node) -> Vector3:
	var acc := {"ab": AABB(), "first": true}
	_accumulate_geometry(node, Transform3D.IDENTITY, acc)
	return (acc["ab"] as AABB).get_center() if not acc["first"] else Vector3.ZERO


func _accumulate_geometry(node: Node, xf: Transform3D, acc: Dictionary) -> void:
	var t := xf
	if node is Node3D:
		t = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		for v in ((node as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var p: Vector3 = t * v
			if acc["first"]:
				acc["ab"] = AABB(p, Vector3.ZERO); acc["first"] = false
			else:
				acc["ab"] = (acc["ab"] as AABB).expand(p)
	for c in node.get_children():
		_accumulate_geometry(c, t, acc)


## Set material_override on every MeshInstance3D under `node` (depth-first). Used to give an
## attached GLB part aeriea's own material instead of the GLB's plain default.
func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		_apply_material_recursive(c, mat)


## Show/hide the CC0 helper-hair cap surface. The cap's visibility is DERIVED authoritatively in
## _proxy_piece_visible (cap shows only when the cap is the active hair part and no animal head is
## on) and applied — material AND geometric collapse — by _apply_proxy_materials, so this just
## re-applies from current state. (`vis` is implied by the active hair part / head; the old
## transparent-only path did not actually stop the cap rendering.)
func _set_hair_cap_visible(_vis: bool) -> void:
	_apply_proxy_materials()


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
## `rebake_tangents` (default false): also recompute ARRAY_TANGENT on the morphed body
## surface (§6.1 creator-body decision). FALSE on the interactive drag path (the bake is
## the per-motion-frame hot path; a tangent rebake over 14,517 verts every frame is too
## costly), TRUE on a morph COMMIT (drag release / settled slider) so a tangent-space
## skin detail-normal does not shear under the morph. The creator calls this with true at
## each commit site; in-game NPC morphs (one-shot, not dragged) may pass true for a
## correct first bake.
func apply_body_state(state: BodyState, rebake_tangents: bool = false) -> void:
	body_state = state
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	body_state.apply_morph_cpu(mesh_instance, {}, rebake_tangents)
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
	# Hidden surfaces to collapse geometrically (transparent-material hiding alone does NOT stop
	# the surface rendering — the alpha-0 skinned surface still draws — so a hidden proxy piece
	# must also have its geometry collapsed to degenerate triangles). Collected here and applied
	# in ONE mesh rebuild below; re-evaluated on every bake (this runs after each ProxyMorph bake).
	var hide := []
	for si in mesh.get_surface_count():
		var sname := str(mesh.surface_get_name(si))
		var mat_kind := "default"
		for s in surfaces:
			if String(s["name"]) == sname:
				mat_kind = String(s["material"])
				break
		var visible := _proxy_piece_visible(sname)
		proxy_instance.set_surface_override_material(si, _proxy_material(mat_kind, visible))
		if not visible:
			hide.append(si)
	_collapse_proxy_surfaces(hide)


## The authoritative visibility of a proxy piece, the SINGLE source of truth re-evaluated on
## every bake (so a morph re-bake never wrongly re-shows a hidden piece):
##   - genitals follow show_genitals (NSFW-first attachable);
##   - the CC0 hair cap shows only when the cap style is the active hair part (a BDCC2
##     hairstyle replaces it).
func _proxy_piece_visible(sname: String) -> bool:
	# An explicit manual force-hide (set_proxy_visible(piece,false)) wins over the derive.
	if _proxy_force_hidden.has(sname):
		return false
	if sname == "genitals":
		return show_genitals
	if sname == "hair":
		# The proxy "hair" surface IS the CC0 helper-hair cap (BDCC2 styles attach as
		# separate GLBs). It is hidden by default (PROXY_DEFAULT_HIDDEN) because the cap
		# is a broken mid-back/chest drape that covers the face; selecting a BDCC2 style
		# also keeps it hidden. So the proxy cap never auto-shows — the face stays visible.
		if PROXY_DEFAULT_HIDDEN.get("hair", false):
			return false
		return not PartLibrary.is_bdcc2(PartLibrary.SLOT_HAIR, current_part(PartLibrary.SLOT_HAIR))
	return true


## Collapse the listed proxy surfaces' geometry to MASK_COLLAPSE_POINT (degenerate triangles ->
## no fragments) in ONE mesh rebuild, preserving every surface's blendshapes/format/name and the
## current override materials. Surfaces not listed keep their (just-baked) positions. This is the
## real hide — the transparent material is kept too (for the existing alpha-based tests) but does
## not by itself stop the surface drawing. Called from _apply_proxy_materials after each bake.
func _collapse_proxy_surfaces(indices: Array) -> void:
	if indices.is_empty() or proxy_instance == null or proxy_instance.mesh == null:
		return
	var mesh := proxy_instance.mesh as ArrayMesh
	var hide := {}
	for i in indices:
		hide[int(i)] = true
	# Snapshot every surface (arrays/blends/fmt/name/material), collapsing the hidden ones.
	var snap := []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if hide.has(s):
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vi in verts.size():
				verts[vi] = MASK_COLLAPSE_POINT
			arrays[Mesh.ARRAY_VERTEX] = verts
		snap.append({
			"prim": mesh.surface_get_primitive_type(s),
			"arrays": arrays,
			"blends": mesh.surface_get_blend_shape_arrays(s),
			"fmt": mesh.surface_get_format(s),
			"name": mesh.surface_get_name(s),
			"mat": proxy_instance.get_surface_override_material(s),
		})
	mesh.clear_surfaces()
	for o in snap:
		mesh.add_surface_from_arrays(o["prim"], o["arrays"], o["blends"], {}, o["fmt"])
	for s in mesh.get_surface_count():
		mesh.surface_set_name(s, snap[s]["name"])
		if snap[s]["mat"] != null:
			proxy_instance.set_surface_override_material(s, snap[s]["mat"])


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
		"hair":
			# Matte dark keratin for the CC0 helper-hair cap (same family as brows/lashes).
			# Two-sided so the thin scalp cap reads from any angle; rough + no specular so
			# it reads as a hair mass, not plastic.
			mat.albedo_color = Color(0.10, 0.07, 0.05)
			mat.roughness = 0.92
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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


## A skin material for an attached accessory part (e.g. ears / tail), derived from the body's own
## skin material so the swapped part matches the body — not the GLB's plain default. A
## duplicate of _skin_material (so per-part tweaks don't mutate the shared body material) with
## two-sided culling for the thin part shells. Falls back to a fresh skin material if the
## body material isn't built yet.
func _part_skin_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D
	if _skin_material != null:
		mat = _skin_material.duplicate() as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = SKIN_ALBEDO
		mat.roughness = SKIN_ROUGHNESS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## A hair material for an attached BDCC2 hairstyle GLB — matte dark keratin, same family as the
## CC0 cap's hair material (root/tip tint via a slight rim, two-sided so the thin hair cards
## read from any angle, rough + no specular so it reads as a hair mass not plastic). Replaces
## the GLB's plain default material so mined hair doesn't render as a light untextured blob.
## Pure data — tunable like the proxy materials.
func _hair_part_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.07, 0.05)
	mat.roughness = 0.92
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A subtle warm rim so the tips read lighter than the roots (keratin sheen, not flat black).
	mat.rim_enabled = true
	mat.rim = 0.3
	mat.rim_tint = 0.5
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


## Show/hide a proxy piece at runtime (e.g. toggling genitals). Sets the override material AND
## collapses/restores the surface geometry (the real hide — see _collapse_proxy_surfaces). For
## genitals this flips show_genitals so a later re-bake keeps the choice; for other pieces an
## explicit force-hide is tracked in _proxy_force_hidden so a re-bake honours it too.
func set_proxy_visible(piece: String, visible: bool) -> void:
	if proxy_instance == null or not _proxy_surface.has(piece):
		return
	if piece == "genitals":
		show_genitals = visible   # so a later morph re-bake keeps the chosen visibility
	elif visible:
		_proxy_force_hidden.erase(piece)
	else:
		_proxy_force_hidden[piece] = true
	if visible:
		# Showing a piece must RESTORE its (possibly-collapsed) geometry: re-bake the proxy morph
		# (rewrites every surface's positions from neutral) before re-applying materials/collapses,
		# so a previously-hidden surface's verts come back. _apply_proxy_materials (called inside
		# ProxyMorph-follow via apply_body_state? no — call it explicitly) re-collapses the rest.
		if proxy_instance.mesh != null:
			ProxyMorph.apply(body_state, proxy_instance)
	# Re-apply ALL proxy materials + collapses from authoritative state (honours the change
	# AND keeps every other piece's hide/show correct after this single rebuild).
	_apply_proxy_materials()


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
		# Kill the foot-skate: drive the legs with the world-anchored, distance-phased
		# foot-lock IK. It OVERRIDES the MM leg pose (the stance foot holds its world
		# position while the body translates over it); the MM stamp keeps the upper body.
		_apply_foot_lock(delta)
		# Foot-IK over MM: the Slice-3 two-bone solver + pelvis-drop were tuned for
		# the procedural cycle and FIGHT the MM pose (they collapse the pelvis when
		# layered on captured poses). Re-deriving foot-IK as a gentle additive
		# ground-adaptation layer that respects the MM pose is the documented
		# Slice-4 refinement (decision doc §3.2); until then MM ground contact comes
		# from the captured clips themselves, so IK is skipped under MM.
		_apply_clip_layer(delta)
		_apply_arm_ik()
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

	_apply_clip_layer(delta)
	_apply_arm_ik()
	apply_micro_life(delta)


# --- BDCC2 clip layer (mined idles + gestures, retargeted) -------------------
# Overlays a retargeted BDCC2 clip's upper-body pose on top of the locomotion pose.
# Locomotion (MM / procedural) owns legs + root + heading; the clip layer owns the
# upper body (spine/arms/neck/head) so a gesture rides the gait and an idle-fidget
# embellishes the still stand. RENDER-SIDE + DETERMINISTIC: clip time advances by
# the render delta; the fidget scheduler is a pure delta accumulator + the cosmetic
# rng (same standing duration -> same fidget), never wall-clock / Math.random; it
# never touches the seeded sim (same contract as the MM / micro-life layers).

## Play a mined BDCC2 clip by aeriea id (see ClipDB.clip_ids / bdcc2_clip_ingest
## SOURCES: "wave", "head_nod", "talking", "sigh", "thinking", "idle_long", ...).
## loop=false plays once then eases out; loop=true holds until stop_clip()/replaced.
## Returns true if the clip exists. RENDER-SIDE cosmetic — safe to call any frame.
func play_clip(id: String, loop: bool = false) -> bool:
	if clip_db == null:
		return false
	var ci := clip_db.clip_index(id)
	if ci < 0:
		return false
	# Crossfade: if a DIFFERENT clip is already driving the overlay, retain its pose
	# (index + the time it was interrupted at, frozen) so _apply_clip_layer can slerp
	# it into the incoming clip over clip_crossfade_dur instead of popping to frame 0.
	if _clip_idx >= 0 and ci != _clip_idx and _clip_weight > 0.001 and clip_crossfade_dur > 0.0:
		_xfade_idx = _clip_idx
		_xfade_prev_time = _clip_time
		_xfade_time = 0.0
	_clip_idx = ci
	_clip_time = 0.0
	_clip_loop = loop
	return true


## Stop any active clip (eases the overlay back out).
func stop_clip() -> void:
	_clip_idx = -1
	_clip_loop = false


## Whether a clip overlay is currently active (playing or easing).
func is_clip_playing() -> bool:
	return _clip_idx >= 0 or _clip_weight > 0.001


## The aeriea id of the active clip, or "" if none.
func active_clip_id() -> String:
	if clip_db == null or _clip_idx < 0:
		return ""
	return clip_db.clip_ids[_clip_idx]


func _apply_clip_layer(delta: float) -> void:
	if clip_db == null or not clip_layer_enabled:
		return
	# --- idle-fidget scheduler: while standing, periodically auto-play an idle variant.
	# Bound to the controller's STATE via _smoothed_speed (a pure read of MovementState).
	var standing := grounded and _smoothed_speed < clip_stand_speed
	if standing:
		var was := _stand_time
		_stand_time += delta
		# Schedule the first fidget once we've stood long enough; reschedule after each.
		if was == 0.0 or _next_fidget_at <= 0.0:
			_next_fidget_at = fidget_first_delay
		if _clip_idx < 0 and _stand_time >= _next_fidget_at:
			var pick: String = IDLE_FIDGET_CLIPS[_cosmetic_rng.randi() % IDLE_FIDGET_CLIPS.size()]
			play_clip(pick, false)
			var gap := fidget_min_gap + _cosmetic_rng.randf() * (fidget_max_gap - fidget_min_gap)
			_next_fidget_at = _stand_time + gap
	else:
		# Moving: clear the standing accumulator. A one-shot fidget already playing eases
		# out on its own; we don't yank it mid-gesture (it blends out below as it ends).
		_stand_time = 0.0
		_next_fidget_at = 0.0

	# --- advance the clip-to-clip crossfade timer -----------------------------
	if _xfade_idx >= 0:
		_xfade_time += delta
		if _xfade_time >= clip_crossfade_dur or clip_crossfade_dur <= 0.0:
			_xfade_idx = -1   # crossfade complete; incoming clip stands alone

	# --- advance the active clip + ease the overlay weight --------------------
	var target_w := 0.0
	if _clip_idx >= 0:
		_clip_time += delta
		var fps: float = clip_db.clip_fps[_clip_idx]
		var clen: int = clip_db.clip_len[_clip_idx]
		var dur := float(clen) / maxf(fps, 1.0)
		if not _clip_loop and _clip_time >= dur:
			# One-shot finished: stop driving (weight eases to 0, then clears).
			_clip_idx = -1
		else:
			target_w = 1.0
	_clip_weight = move_toward(_clip_weight, target_w, clip_blend_speed * delta)
	if _clip_weight <= 0.001 and _clip_idx < 0:
		_clip_weight = 0.0
		return
	if _clip_idx < 0:
		return   # easing out with no frame source — hold last (nearly-zero) weight

	# --- stamp the clip's upper-body pose, blended by weight ------------------
	var gf := clip_db.frame_at_time(_clip_idx, _clip_time)
	if gf < 0:
		return
	for bname in CLIP_UPPER_BONES:
		if not _bone_index.has(bname):
			continue
		var dbi := clip_db.bone_names.find(bname)
		if dbi < 0:
			continue
		var rest: Transform3D = _rest_local.get(bname, Transform3D.IDENTITY)
		var rest_q := rest.basis.get_rotation_quaternion()
		var clip_q := (rest_q * clip_db.pose_quat(gf, dbi)).normalized()
		# Crossfade: blend the outgoing clip's (frozen) pose into the incoming pose so
		# the switch eases rather than cuts. t: 0 = outgoing, 1 = incoming.
		if _xfade_idx >= 0:
			var pf := clip_db.frame_at_time(_xfade_idx, _xfade_prev_time)
			if pf >= 0:
				var prev_q := (rest_q * clip_db.pose_quat(pf, dbi)).normalized()
				var t := clampf(_xfade_time / maxf(clip_crossfade_dur, 1e-4), 0.0, 1.0)
				clip_q = prev_q.slerp(clip_q, t).normalized()
		var idx: int = _bone_index[bname]
		# Blend FROM the locomotion pose already on the bone TO the clip pose by weight.
		var cur := skeleton.get_bone_pose_rotation(idx)
		skeleton.set_bone_pose_rotation(idx, cur.slerp(clip_q, _clip_weight).normalized())


# --- Slice 4: Motion-Matching pose ------------------------------------------
# Deterministically search the feature DB for the frame best matching the current
# MovementState-derived goal, then apply that frame's per-bone local rotations to
# the skeleton. RENDER-SIDE; pure function of (goal, DB). Resets the MM-driven
# bones to rest first so the pose is a pure function of the matched frame.
var _mm_frame: int = 0

## Foot-lock gait phase in [0,1): position within one full L+R gait cycle. Advanced by
## DISTANCE (speed·dt / gait_stride) so cadence tracks travel — a pure accumulator, no
## wall-clock/RNG. Left foot uses this phase; the right foot is a half-cycle ahead.
var _gait_phase: float = 0.0
## Rest ankle (foot-bone) height above the feet origin, measured once from the rig — the
## planted ankle sits this far above the ground surface (the sole, not the ankle, touches).
var _ankle_rest_y: float = -1.0

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

	# POSTURE SOURCE:
	# The 100STYLE→MakeHuman retarget was fixed AT SOURCE (tools/motion_ingest.gd,
	# docs/decisions/spine-retarget-world-orientation.md): the spine/neck/head chain is
	# now solved by orientation-driven spline-IK over the CORRECTED topology (all 9 axial
	# joints driven, torso locked laterally flat, head reproduces the source world
	# orientation to ~6° — verified across ALL 24 clips incl. the previously-corrupt
	# back/strafe/StartStop set). So the former upper-body override (which drove the whole
	# upper body from a clean idle frame because the DB was corrupt — see the git history
	# of this function and docs/decisions/locomotion-upper-body-posture.md) is LIFTED:
	# motion-matching now drives the FULL body from the matched frame, which is what
	# restores real, mocap-driven arm swing (the earlier frozen/mannequin arms were a
	# symptom of the override). The LEGS are still replaced downstream by the distance-
	# phased foot-lock (_apply_foot_lock) so the stance foot stays planted (no skate).
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


## Foot-lock locomotion: replace the MM leg pose with a distance-phased sagittal-plane
## two-bone IK whose stance foot is anchored in the pelvis frame with a backward sweep at
## the nominal locomotion speed. When the body translates at that speed the stance foot
## holds its WORLD position (no skate); in place it reads as a treadmill stride. Cadence is
## matched by construction (phase advances with distance). RENDER-SIDE + deterministic:
## a pure function of (_gait_phase, smoothed speed, delta, ground) — never wall-clock/RNG.
func _apply_foot_lock(delta: float) -> void:
	if not foot_lock_enabled or not grounded or skeleton == null:
		return
	if not (_bone_index.has(HIP_L) and _bone_index.has(FOOT_L) and _bone_index.has(ROOT_BONE)):
		return
	var spd := _smoothed_speed
	# Ease foot-lock in with speed so a start/stop never pops (skate is a high-speed defect;
	# at a near-stand the MM idle stand holds).
	var fl_w := clampf((spd - foot_lock_min_speed) / maxf(foot_lock_full_speed - foot_lock_min_speed, 1e-3), 0.0, 1.0)
	if fl_w <= 0.0:
		return
	# Measure the rest ankle (foot-bone) height once: the planted ankle sits this far above
	# the ground surface (the sole, not the ankle joint, meets the floor).
	if _ankle_rest_y < 0.0:
		_ankle_rest_y = skeleton.get_bone_global_rest(_bone_index[FOOT_L]).origin.y

	# Advance the gait phase by DISTANCE (nominal speed) — cadence tracks travel by construction.
	_gait_phase = fposmod(_gait_phase + spd * delta / maxf(gait_stride, 0.05), 1.0)

	# Locomotion crouch: lower the pelvis for knee-bend headroom (the rest stance is at
	# near-full extension) and a natural lowered-COM gait. Applied before reading hip pos.
	var ri: int = _bone_index[ROOT_BONE]
	var root_rest: Transform3D = _rest_local[ROOT_BONE]
	skeleton.set_bone_pose_position(ri, root_rest.origin - Vector3(0.0, gait_crouch * fl_w, 0.0))

	var skel_xf := skeleton.global_transform
	# Sagittal forward = the body's anatomical/travel forward in world. The player rig is yawed
	# 180°, so its skeleton +Z (basis.z) points along the player's -Z travel direction — that is
	# the forward the stance sweep must cancel (verified by rendering: the resulting stance foot
	# holds its world position as the body advances). In the creator (no 180° yaw) basis.z is the
	# anatomical +Z the in-place stride sweeps along. Flattened to the horizontal plane.
	var fwd := skel_xf.basis.z
	fwd.y = 0.0
	if fwd.length() < 1e-4:
		return
	fwd = fwd.normalized()
	var sweep := gait_stride * stance_duty   # pelvis-relative stance sweep length (m)

	for side in ["L", "R"]:
		var hip: String = HIP_L if side == "L" else HIP_R
		var knee: String = KNEE_L if side == "L" else KNEE_R
		var foot: String = FOOT_L if side == "L" else FOOT_R
		var base_phase := _gait_phase if side == "L" else fposmod(_gait_phase + 0.5, 1.0)
		var o := 0.0     # forward offset in the pelvis frame (m)
		var lift := 0.0
		if base_phase < stance_duty:
			var t := base_phase / stance_duty          # 0..1 across stance
			o = sweep * (0.5 - t)                      # +sweep/2 (front) -> -sweep/2 (back)
		else:
			var sp := (base_phase - stance_duty) / maxf(1.0 - stance_duty, 1e-3)
			o = sweep * (sp - 0.5)                      # -sweep/2 -> +sweep/2 (swing forward)
			lift = foot_lift_height * sin(PI * sp)
		# Hip world pos (stable: the leg's parent; unaffected by the leg's own rotation).
		var hip_w := (skel_xf * skeleton.get_bone_global_pose(_bone_index[hip])).origin
		# Foot target: pelvis-anchored forward sweep + ground contact height. The lateral
		# (side-to-side) placement is left to the hip's own X so the foot stays under the hip.
		var target := hip_w + fwd * o
		target.y = 0.0
		var gy := _ground_y(Vector3(target.x, hip_w.y, target.z))
		target.y = gy + _ankle_rest_y + lift
		_ik_sagittal(hip, knee, foot, target, fwd, fl_w)


## Ground surface Y under a world point (raycast down; falls back to the feet-plane at the
## skeleton origin when no world / no hit). Deterministic (a physics query, no RNG).
func _ground_y(world_pos: Vector3) -> float:
	if _space != null:
		var from := world_pos + Vector3.UP * ik_ray_up
		var to := world_pos + Vector3.DOWN * (ik_ray_down + 0.5)
		var params := PhysicsRayQueryParameters3D.create(from, to)
		params.exclude = _ik_exclude
		var hit := _space.intersect_ray(params)
		if not hit.is_empty():
			return (hit["position"] as Vector3).y
	return skeleton.global_transform.origin.y


## Analytic two-bone IK by DIRECTION-AIMING: solve the hip/knee joint positions in the
## sagittal (forward/vertical) plane (law of cosines) so the ankle lands EXACTLY on
## `target_world`, then aim each leg bone's length axis (MakeHuman bones run down local -Y)
## along the solved world directions. Aiming by direction (not an angle-about-a-guessed-axis)
## makes the foot reach the target regardless of the bones' rest orientation — the property
## that actually kills the skate. Rotations are ABSOLUTE local pose, blended with the current
## MM pose by `w`. Lateral placement follows the target's own lateral component. Deterministic.
func _ik_sagittal(hip: String, knee: String, foot: String, target_world: Vector3, fwd: Vector3, w: float) -> void:
	if not (_bone_index.has(hip) and _bone_index.has(knee) and _bone_index.has(foot)):
		return
	var hi: int = _bone_index[hip]
	var ki: int = _bone_index[knee]
	var skel_xf := skeleton.global_transform
	var hip_w := (skel_xf * skeleton.get_bone_global_pose(hi)).origin
	# Bone (rigid) lengths from the rest child offsets: knee offset from hip = upper leg;
	# foot offset from knee = lower leg. skeleton.scale is folded in via skel_xf below.
	var l1 := skeleton.get_bone_rest(ki).origin.length()
	var l2 := skeleton.get_bone_rest(_bone_index[foot]).origin.length()
	if l1 < 1e-4 or l2 < 1e-4:
		return
	var up := Vector3.UP
	var lateral := fwd.cross(up).normalized()
	var d := target_world - hip_w
	# Project the target into the sagittal plane for the 2-bone solve (forward + vertical).
	var df := d.dot(fwd)
	var du := d.dot(up)
	var d_plane := fwd * df + up * du
	var c := clampf(d_plane.length(), 1e-3, (l1 + l2) - 1e-3)
	var chord_hat := d_plane.normalized()
	# Upper-leg direction: rotate the hip->ankle chord by the law-of-cosines angle about the
	# lateral axis so the knee bulges FORWARD (verified by rendering).
	var cos_a := clampf((l1 * l1 + c * c - l2 * l2) / (2.0 * l1 * c), -1.0, 1.0)
	var a := acos(cos_a)
	var upper_dir := chord_hat.rotated(lateral, a).normalized()
	var knee_w := hip_w + upper_dir * l1
	var lower_dir := (target_world - knee_w).normalized()
	# Aim each bone's local -Y (its length axis) along the solved world direction. Convert the
	# world direction into the bone's PARENT frame, then build the local rotation.
	_aim_bone_neg_y(hi, upper_dir, skel_xf, w)
	_aim_bone_neg_y(ki, lower_dir, skel_xf, w)


## Set bone `bi`'s local pose rotation so its length axis (local -Y) points along the world
## direction `dir_world`, blended from the current pose by `w`. Uses the parent's current
## global pose so it composes correctly under the spine/pelvis pose. Roll is left to the
## shortest-arc solution (irrelevant to foot placement). Deterministic.
func _aim_bone_neg_y(bi: int, dir_world: Vector3, skel_xf: Transform3D, w: float) -> void:
	var parent := skeleton.get_bone_parent(bi)
	var parent_basis := skel_xf.basis if parent < 0 else (skel_xf * skeleton.get_bone_global_pose(parent)).basis
	var dir_local := (parent_basis.inverse() * dir_world).normalized()
	# local +Y -> -dir_local, so local -Y (the bone's length axis) -> dir_local.
	var q := Quaternion(Vector3.UP, -dir_local).normalized()
	skeleton.set_bone_pose_rotation(bi, skeleton.get_bone_pose_rotation(bi).slerp(q, w).normalized())


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
	# Part spring-bones (hair + ears + tail). Each entry carries its OWN skeleton (the body
	# skeleton for the CC0 hair-cap chain, or a BDCC2 part GLB's own little skeleton). The
	# same spring physics drives any of them — step() integrates against whatever skeleton it
	# is handed, so a BDCC2 DEF-Tail/DEF-Ear bone sways exactly like the cap's hair01/02/03
	# chain. Tuned with the hair_* dials (shared secondary-motion knobs).
	if micro.hair_enabled:
		for key in _part_springs:
			var e: Dictionary = _part_springs[key]
			var hskel: Skeleton3D = e["skel"]
			var sb: SpringBone = e["sb"]
			if hskel == null or not is_instance_valid(hskel):
				continue
			var q := sb.step(hskel, delta, micro.hair_stiffness, micro.hair_damping,
				micro.hair_inertia, micro.hair_max_angle)
			if q != Quaternion.IDENTITY:
				var i: int = sb.bone_idx
				hskel.set_bone_pose_rotation(i, (hskel.get_bone_pose_rotation(i) * q).normalized())
	# Soft-region jiggle (breast.L/R + injected belly/glute; conservative gain by default).
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


## Snapshot the micro-life layer (for tests / debug). Pure read. `hair_springs` is kept
## as a name for the springs in the HAIR slot specifically (back-compat with the original
## hair test); `part_springs` is the total across all slots; `slot_springs` breaks it down.
func micro_life_state() -> Dictionary:
	return {
		"breath_phase": _breath_phase,
		"saccade_offset": _saccade_offset,
		"hair_springs": _slot_spring_count(PartLibrary.SLOT_HAIR),
		"part_springs": _part_springs.size(),
		"slot_springs": _slot_spring_counts(),
		"jiggle_springs": _jiggle_springs.size(),
	}


## Number of registered spring bones whose key belongs to `slot` (keys are "slot:…").
func _slot_spring_count(slot: String) -> int:
	var n := 0
	for key in _part_springs:
		if String(key).begins_with(slot + ":"):
			n += 1
	return n


## Per-slot spring counts, e.g. {"hair": 3, "ears": 4, "tail": 6, "horns": 0}.
func _slot_spring_counts() -> Dictionary:
	var out := {}
	for slot in PartLibrary.slots():
		out[slot] = _slot_spring_count(slot)
	return out


# --- analytic two-bone ARM-IK (reach / plant / brace) -----------------------
# Mirrors the foot-IK pattern for the arms: an analytic two-bone solver bends the
# shoulder→elbow→wrist chain so the wrist reaches a WORLD target, with a pole hint
# keeping the elbow from inverting. Unlike the leg solver (a sagittal-plane ground
# approximation), the arm solver is a FULL 3D reach: it orients the upper arm to aim
# the chain plane at both the target and the pole, then law-of-cosines for the elbow.
# It layers AFTER the locomotion/clip/MM base, overriding the arm chain toward the
# target only by the per-arm blend weight, then micro-life (jiggle/secondary) rides
# on top. RENDER-SIDE + DETERMINISTIC: a pure function of (target, pole, base pose).

## Drive an arm to REACH a WORLD-space position. `side` is "L"/"R". `pole_hint` is a
## world-space elbow hint (the elbow is pushed toward it); Vector3.INF picks a sane
## default (down + out from the shoulder, so the elbow bends like a human arm).
## `weight` is the IK/FK blend (0 = base anim, 1 = full IK). Call once or each frame;
## the reach persists until clear_reach(side). Interactions/affordances drive this.
func reach_for(side: String, world_pos: Vector3, pole_hint: Vector3 = Vector3.INF, weight: float = 1.0) -> void:
	side = side.to_upper()
	if side != "L" and side != "R":
		return
	_arm_reach[side] = {
		"target": world_pos,
		"pole": pole_hint,
		"weight": clampf(weight, 0.0, 1.0),
	}


## Drop an arm's reach (weight -> 0; the arm follows the base anim again). `side`
## "L"/"R", or "" / "ALL" to clear both arms.
func clear_reach(side: String = "ALL") -> void:
	side = side.to_upper()
	if side == "" or side == "ALL":
		_arm_reach.clear()
		return
	_arm_reach.erase(side)


## Whether `side` ("L"/"R") currently has an active reach with weight > 0.
func is_reaching(side: String) -> bool:
	side = side.to_upper()
	return _arm_reach.has(side) and float(_arm_reach[side].get("weight", 0.0)) > 0.0


## Apply arm-IK for both arms, layering over the base pose by each arm's weight.
## Called from apply_pose() AFTER the clip/locomotion/MM base and BEFORE micro-life,
## so the spring/jiggle/secondary layers settle on top of the reached pose.
func _apply_arm_ik() -> void:
	if not arm_ik_enabled or _arm_reach.is_empty():
		return
	if _arm_reach.has("L"):
		var e: Dictionary = _arm_reach["L"]
		_solve_arm_ik(UPPERARM_L, LOWERARM_L, WRIST_L, e["target"], e["pole"], e["weight"], true)
	if _arm_reach.has("R"):
		var er: Dictionary = _arm_reach["R"]
		_solve_arm_ik(UPPERARM_R, LOWERARM_R, WRIST_R, er["target"], er["pole"], er["weight"], false)


## Analytic two-bone arm IK. Bends upperarm→lowerarm→wrist so the wrist reaches
## `target_world`, with the elbow biased toward `pole_world` (Vector3.INF => a default
## down/out hint). `weight` blends FROM the current (base) pose TO the IK pose. Pure,
## closed-form (law of cosines for the elbow bend), no iteration. `left` flips the
## default pole side. Operates on global orientations, written back as bone-local
## pose rotations so it composes with the skeleton/scale unchanged.
func _solve_arm_ik(upper: String, lower: String, wrist: String, target_world: Vector3,
		pole_world: Vector3, weight: float, left: bool) -> void:
	if weight <= 0.0:
		return
	if not (_bone_index.has(upper) and _bone_index.has(lower) and _bone_index.has(wrist)):
		return
	var ui: int = _bone_index[upper]
	var li: int = _bone_index[lower]
	var wi: int = _bone_index[wrist]

	# Current global joint positions (post the base pose already on the skeleton).
	var skel_xf := skeleton.global_transform
	var shoulder_pos := (skel_xf * skeleton.get_bone_global_pose(ui)).origin
	var elbow_pos := (skel_xf * skeleton.get_bone_global_pose(li)).origin
	var wrist_pos := (skel_xf * skeleton.get_bone_global_pose(wi)).origin

	var l_upper := shoulder_pos.distance_to(elbow_pos)
	var l_lower := elbow_pos.distance_to(wrist_pos)
	if l_upper < 1e-4 or l_lower < 1e-4:
		return

	# Reach vector, CLAMPED to the chain's reachable range (just under full extension
	# so the elbow never has to fully straighten/invert, and above a small floor).
	var to_target := target_world - shoulder_pos
	var reach := to_target.length()
	var max_reach := (l_upper + l_lower) - 1e-3
	var min_reach := absf(l_upper - l_lower) + 1e-3
	reach = clampf(reach, min_reach, max_reach)
	if to_target.length() < 1e-5:
		return
	var dir := to_target.normalized()   # shoulder -> (clamped) target direction

	# Pole / elbow hint. Default: down and slightly away from the body so the elbow
	# bends like a human arm (outward for the matching side), never inverting inward.
	var pole := pole_world
	if pole == Vector3.INF:
		var out_sign := -1.0 if left else 1.0
		pole = shoulder_pos + (skel_xf.basis * Vector3(out_sign, -0.5, -0.2)).normalized() * (l_upper + l_lower)

	# Build the chain's bend plane basis. x = reach dir; the bend axis is perpendicular
	# to the reach dir in the plane spanned by (dir, shoulder->pole). The elbow lifts
	# off the reach line toward the pole side.
	var to_pole := pole - shoulder_pos
	var bend_axis := dir.cross(to_pole)
	if bend_axis.length() < 1e-5:
		# Degenerate (pole colinear with reach): fall back to a stable world axis.
		bend_axis = dir.cross(Vector3.UP)
		if bend_axis.length() < 1e-5:
			bend_axis = dir.cross(Vector3.RIGHT)
	bend_axis = bend_axis.normalized()
	# In-plane "up" toward the pole side, perpendicular to the reach dir.
	var pole_dir := bend_axis.cross(dir).normalized()

	# Law of cosines: angle at the shoulder between the reach dir and the upper arm.
	var cos_sh := clampf((l_upper * l_upper + reach * reach - l_lower * l_lower) / (2.0 * l_upper * reach), -1.0, 1.0)
	var sh_angle := acos(cos_sh)

	# Desired global joint positions: elbow lifted off the reach line by sh_angle
	# toward the pole side; wrist at the (clamped) reach point.
	var upper_dir := (dir * cos(sh_angle) + pole_dir * sin(sh_angle)).normalized()
	var new_elbow := shoulder_pos + upper_dir * l_upper
	var target_clamped := shoulder_pos + dir * reach
	var lower_dir := (target_clamped - new_elbow).normalized()

	# Convert desired global bone DIRECTIONS into bone-local pose rotations. The MH arm
	# bones do NOT point along a single fixed local axis (the upperarm's local child
	# direction is ~(0.62,-0.78,-0.04), the lowerarm's ~(0.52,-0.46,0.72)), so we aim
	# each bone's OWN local "bone axis" — the rest-frame direction from the joint to its
	# child joint — at the desired world direction. This is rig-agnostic (works for the
	# arms' skewed axes exactly as it would for the legs' near-vertical ones). Shortest-
	# arc keeps the base twist; the weight blend makes weight=0 a no-op, weight=1 a full
	# reach. Solve the upper arm first so the lower-arm aim reads the updated elbow frame.
	_aim_bone_axis(ui, _bone_axis_local(ui), upper_dir, skel_xf, weight)
	_aim_bone_axis(li, _bone_axis_local(li), lower_dir, skel_xf, weight)


## The bone's local "bone axis": the unit direction, in the bone's LOCAL pose frame,
## from this joint to its first child joint (the rest-frame child position direction).
## This is the axis the IK aims, so the solver is correct for any rig regardless of
## which local axis a given bone happens to point down. Falls back to +Y if childless.
func _bone_axis_local(idx: int) -> Vector3:
	for c in skeleton.get_bone_count():
		if skeleton.get_bone_parent(c) == idx:
			var d := skeleton.get_bone_rest(c).origin
			if d.length() > 1e-5:
				return d.normalized()
	return Vector3.UP


## Rotate bone `idx` so its LOCAL `axis` points along `world_dir`, via the shortest arc
## from its CURRENT orientation, then slerp from the current (base) pose by `weight`.
## Setting an absolute aim while preserving the base twist (shortest-arc); the weight
## blend makes weight=0 a no-op (pure base pose) and weight=1 a full reach.
func _aim_bone_axis(idx: int, axis: Vector3, world_dir: Vector3, skel_xf: Transform3D, weight: float) -> void:
	var parent := skeleton.get_bone_parent(idx)
	var parent_global_basis := skel_xf.basis
	if parent >= 0:
		parent_global_basis = (skel_xf * skeleton.get_bone_global_pose(parent)).basis
	# The bone's current GLOBAL basis and where its LOCAL bone-axis currently points.
	var cur_local := skeleton.get_bone_pose_rotation(idx)
	var cur_global_basis := parent_global_basis * Basis(cur_local)
	var cur_dir := (cur_global_basis * axis).normalized()
	var tgt_dir := world_dir.normalized()
	# Shortest-arc rotation taking cur_dir -> tgt_dir, applied in world, premultiplied.
	var delta := _shortest_arc(cur_dir, tgt_dir)
	var new_global_basis := Basis(delta) * cur_global_basis
	# Back to bone-local: local = parent_global^-1 * new_global.
	var new_local := (parent_global_basis.inverse() * new_global_basis).get_rotation_quaternion().normalized()
	# Blend FROM the base local pose TO the IK local pose by weight.
	skeleton.set_bone_pose_rotation(idx, cur_local.slerp(new_local, weight).normalized())


## Shortest-arc quaternion rotating unit vector `a` onto unit vector `b`.
func _shortest_arc(a: Vector3, b: Vector3) -> Quaternion:
	var d := clampf(a.dot(b), -1.0, 1.0)
	if d > 0.9999:
		return Quaternion.IDENTITY
	if d < -0.9999:
		# Antiparallel: rotate 180° about any axis perpendicular to a.
		var axis := a.cross(Vector3.RIGHT)
		if axis.length() < 1e-5:
			axis = a.cross(Vector3.UP)
		return Quaternion(axis.normalized(), PI)
	var axis2 := a.cross(b).normalized()
	return Quaternion(axis2, acos(d))


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
