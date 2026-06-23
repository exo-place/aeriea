## CharacterCreator — third-person, orbitable viewer of the player body with live
## morph sliders. This is BOTH a wanted feature and the tool to actually SEE the
## body: the first-person camera sits inside the head (eye at ~1.75 m), so the
## player cannot inspect their own body in-game. The creator sidesteps that by
## rendering the body in THIRD PERSON with a free orbit camera.
##
## It builds the real player body via BodyRig (the same Skeleton3D + skinned mesh
## the game uses), but holds it in the authored NEUTRAL REST/BIND pose — it does
## NOT attach the locomotion / Motion-Matching pose driver (this is a static
## viewer, not a movement preview). The morph panel drives the BodyState record
## (the single source of truth) and projects it onto the body's blendshapes via
## BodyState.apply_to() every time a slider changes.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://scenes/character_creator.tscn
extends Node3D

# ---------------------------------------------------------------------------
# Orbit camera tuning. The camera orbits a pivot at the body's vertical CENTER at
# a yaw/pitch/distance the mouse drives. 1u = 1m (units-and-scale.md).
#
# CONTROL SCHEME (creator camera):
#   left-drag: orbit · right-drag: pan · scroll: zoom · WASD: fly in the camera's
#   local plane (W/S forward/back, A/D left/right) · Space: fly up · Ctrl: fly down
#   WHILE a fly key is held (otherwise Ctrl is the legend hold-to-peek / tap-to-pin).
# ---------------------------------------------------------------------------
const MIN_PITCH := deg_to_rad(-85.0)
const MAX_PITCH := deg_to_rad(85.0)
const MIN_DIST := 0.35       ## metres — close enough for a face inspection
const MAX_DIST := 8.0
const ORBIT_SPEED := 0.0075  ## radians per pixel of mouse drag
const ZOOM_STEP := 0.88      ## multiplicative zoom per scroll notch
const PAN_SPEED := 0.0025    ## metres per pixel of right-drag pan
const FLY_SPEED := 2.4       ## metres/second — WASD/Space/Ctrl free-fly speed

var _rig: BodyRig
var _body_state: BodyState = BodyState.new()

var _camera: Camera3D
var _pivot: Vector3 = Vector3(0.0, 0.85, 0.0)   ## orbit target — recomputed to the body's
                                                ## vertical CENTER in _recenter_pivot()
var _yaw: float = 0.0          ## radians; CANONICAL FORWARD: the un-rotated rig's
                               ## anatomical face points +Z. yaw=0 puts the camera on
                               ## +Z (in front of the face), so the creator opens on the
                               ## FACE, not the back. (Verified by render.)
var _pitch: float = deg_to_rad(-8.0)             ## slightly above
var _distance: float = 3.2     ## metres

var _dragging_orbit: bool = false
var _dragging_pan: bool = false

## Free-fly key state (WASD + Space/Ctrl). Polled per-frame in _process to translate the
## camera frame-rate-independently. Ctrl only counts as "fly down" while a WASD/Space key is
## held (otherwise Ctrl is the legend hold-to-peek / tap-to-pin — see _unhandled_input).
var _fly_fwd: bool = false   ## W
var _fly_back: bool = false  ## S
var _fly_left: bool = false  ## A
var _fly_right: bool = false ## D
var _fly_up: bool = false    ## Space
var _fly_down: bool = false  ## Ctrl (only when another fly key is active)

# ---------------------------------------------------------------------------
# DRAG-TO-MODIFY (Slice D, body-parameterization.md). Asian-MMO-style direct
# manipulation: hover the body to GLOW the region a modifier would edit, then drag the
# surface to engage exactly the modifiers that produce that motion. The geometry core
# (pick + drag-decomposition) lives in the scene-free MorphDrag module; THIS script is
# the input/UI glue (raycast, glow overlay, mouse events, history commit).
#
# CAMERA-vs-MORPH disambiguation (the chosen scheme, documented in the decision doc):
#   - A "Sculpt mode" TOGGLE (button + the M key) gates morph editing. OFF = the body is
#     a pure orbit/pan/zoom viewer (unchanged Slice-A behaviour).
#   - In Sculpt mode, the LEFT button discriminates by WHAT IT HITS: left-press ON THE
#     BODY starts a morph DRAG (raycast hits a triangle -> pick the nearest vertex ->
#     decompose the drag across that vertex's candidate modifiers). Left-press on the
#     BACKGROUND (ray misses the body) ORBITS as before. Right-drag still pans, scroll
#     still zooms, in both modes — so the camera is always reachable without leaving
#     sculpt mode (drag empty space to orbit).
# ---------------------------------------------------------------------------
const MorphDragScript := preload("res://scripts/body/morph_drag.gd")
const DetailLibraryScript := preload("res://scripts/body/detail_library.gd")
const CpuAccelPickerScript := preload("res://scripts/util/cpu_accel_picker.gd")
const GpuIdPickerScript := preload("res://scripts/util/gpu_id_picker.gd")

var _morph                       ## MorphDrag (untyped: the class_name isn't visible at parse)
var _sculpt_mode: bool = false
## MIRROR (contralateral symmetry) toggle — DEFAULT ON (SYNTHESIS §1.3 / decision §2.3). When
## ON, a ONE-SIDED edit (a sculpt drag on one arm/leg, or a lateral slider whose resolved name
## has an l-/r- twin) ALSO applies the same capped write to the contralateral twin(M) — so the
## body stays symmetric by default (the user disliked asymmetry-on-by-default). When OFF, the
## edit applies only to the touched side. ORTHOGONAL to bilateral RESOLUTION (resolve_full_names
## drives both sides of a bare bilateral stem at all times, mirror-independent — a bilateral
## slider always drives both). The midline guard (twin(M) == M) suppresses a double-apply on
## midline modifiers, which are unaffected by the toggle.
var _mirror: bool = true
var _mirror_btn: CheckBox
var _sculpt_btn: Button
var _sculpt_state_lbl: Label     ## live "Sculpt: ON/OFF" state indicator next to the toggle
var _t3_main_section: Control    ## main-panel T3 section (sculpt + extremeness; tier-revealed)

## A morph drag in progress: the picked render-vertex, its world hit position, and the
## accumulated modifier value-deltas (so ONE history node is committed on drag-end).
var _dragging_morph: bool = false
var _drag_vertex: int = -1
var _drag_hit_pos: Vector3 = Vector3.ZERO
var _drag_accum: Dictionary = {}    ## full_name -> total applied delta this drag (for the label)

## The hover-glow overlay: a copy of the body triangles, unshaded + additive, with per-vertex
## alpha driven by MorphDrag.glow_weights. Rebuilt cheaply on hover move (sparse highlight).
var _glow_overlay: MeshInstance3D
var _glow_base_pos: PackedVector3Array   ## the body's rest-space vertex positions (for glow + pick)
var _glow_base_nrm: PackedVector3Array   ## the body's rest-space vertex normals (for the outward glow offset)
var _glow_tris: PackedInt32Array         ## the body's triangle index list (for pick + overlay)
## The glow geometry (positions + normals) is captured from the MORPHED surface, not once at
## build: a morph bake sets this dirty so the next glow rebuild re-reads the current baked
## ARRAY_VERTEX/ARRAY_NORMAL (the same arrays the renderer + picker use). Without this the glow
## stamps stale neutral positions and floats off the morphed body (§2.3 / §6.6).
var _glow_geom_dirty: bool = true
## Outward offset of the glow shell above the skin, in WORLD metres (so it reads the same across
## the height range). Applied in rest space as ε/height_scale() since the overlay is a child of
## the scaled skeleton (§6.6: a fixed rest-space epsilon mis-renders across stature).
const GLOW_WORLD_OFFSET := 0.003
var _hover_vertex: int = -1

## The picking backend (default the deterministic CPU uniform-grid). The Picker interface
## keeps MorphDrag + the input glue backend-agnostic; _pick_body delegates to it. A
## debug/dev toggle (the P key, set_picker_backend) swaps in the GPU ID-buffer backend —
## the same "pick what's rendered" primitive reused for future in-world picking.
var _picker: Picker
var _cpu_picker: CpuAccelPicker
var _gpu_picker                  ## GpuIdPicker (untyped: class_name not visible at parse)
var _use_gpu_picker: bool = false

var _value_labels: Dictionary = {}   ## field -> Label showing current value
var _sliders: Dictionary = {}        ## field -> HSlider
var _axis_spins: Dictionary = {}     ## field -> SpinBox (headline numeric entry, natural units)
var _extreme_slider: HSlider         ## the global extremeness 0..1 slider
var _extreme_check: CheckBox         ## "allow extreme proportions" gate
var _extreme_lbl: Label              ## extremeness % readout
## EYE COLOR (procedural iris_color uniform, §6.3): the live color + its picker widget. Drives
## BodyRig.set_eye_params({"iris_color": …}); no texture, no gaze change.
var _eye_color: Color = BodyRig.EYE_PARAMS_DEFAULT["iris_color"]
var _eye_color_btn: ColorPickerButton

## DATA-DRIVEN per-region detail sliders (RegionSliders). Kept SEPARATE from `_sliders`
## (the headline-axis dials) because these write BodyState.modifiers[<full_name>] rather
## than a BodyState field. spec_name -> { slider, value_lbl, full_names:PackedStringArray,
## kind:String }. Restored from state via _restore_modifier_sliders.
var _modifier_sliders: Dictionary = {}

# ---------------------------------------------------------------------------
# PROGRESSIVE-REFINE TIERS (Phase 3b, SYNTHESIS §2.2). The creator surfaces edit depth in
# four ADDITIVE/MONOTONE tiers — opening a deeper tier REVEALS more, never hides shallower:
#   T0 Pick    — the archetype pick grid (BodyArchetypes roster), one button per archetype.
#   T1 Headline— the 6 natural-unit axes (always visible once past T0).
#   T2 Detail  — a curated subset of the region groups (high-impact, low-footgun).
#   T3 Full    — the complete region tree + the visible Sculpt control + the extremeness gate.
# The current tier is the MAX depth revealed; a tier selector raises it. T1 is always shown.
# ---------------------------------------------------------------------------
const TIER_T1 := 1
const TIER_T2 := 2
const TIER_T3 := 3
var _tier: int = TIER_T1            ## the deepest tier currently revealed (monotone via UI)
var _archetypes: Array = []         ## the loaded first-party roster (T0 pick grid source)
var _tier_buttons: Dictionary = {}  ## tier int -> the selector Button (for pressed-state)
var _t2_section: Control            ## the T2-curated-detail region panel section
var _t3_section: Control            ## the T3-full region tree + sculpt section
## Region groups surfaced at T2 (curated detail); the rest are T3-only (full registry tree).
## A monotone reveal: T3 shows T2's groups PLUS these. (SYNTHESIS §2.2 — T2 is a curated
## projection of registry entries; T3 is the complete tree.)
const T2_GROUPS := ["Breasts", "Glutes & pelvis", "Belly & stomach", "Waist & hips",
	"Torso & shoulders", "Head & face shape"]

# ---------------------------------------------------------------------------
# Edit HISTORY — a branching undo TREE over BodyState dicts (HistoryTree). Every
# settled axis change commits a node; undo/redo walk the tree; the history panel
# visualizes branches and jump_to lets you click any node to restore that state.
# DESIGN.md "lived history" / variety power-fantasy: explore an edit, back up,
# explore another, keep both branches — that is why this is a tree, not a stack.
# ---------------------------------------------------------------------------
const HistoryTreeScript := preload("res://scripts/util/history_tree.gd")
const CreatorIOScript := preload("res://scripts/body/creator_io.gd")
const RegionSlidersScript := preload("res://scripts/body/region_sliders.gd")
const BodyCapsScript := preload("res://scripts/body/body_caps.gd")
const BodyArchetypesScript := preload("res://scripts/body/body_archetypes.gd")

## The cap-model foundation (SYNTHESIS.md §3): the global extremeness + the per-control
## allowed intervals + the apply_capped choke every LIVE write path routes through, with
## the gesture-scoped held-interval map. No UI control for extremeness yet (Phase 3).
## Untyped: the BodyCaps class_name is not visible at this file's parse time (same pattern
## as `_morph` / `_gpu_picker`); methods are called dynamically.
var _caps = BodyCapsScript.new()

## Deterministic randomize state (§2.3): a fixed creator seed + a monotonic counter feed every
## randomize gesture's RNG, so a recorded sequence of randomize ops replays byte-identically
## against a fixed caps version + extremeness. The seed is fixed (not time-based) for replay.
var _random_seed: int = 0x5eed_a4_1a
var _random_counter: int = 0

var _history: HistoryTree
## Per-axis pending value during a slider drag — committed once on drag-end so we
## record ONE node per settled change, not one per pixel.
var _drag_pending: Dictionary = {}   ## field -> bool (a drag is in progress)
var _suspend_commit: bool = false    ## true while applying a restored state (no commit)
## True while a RAW restore/load is rewriting widgets (§3.2 paths 6/7). Setting a slider's
## min/max while tightening the cap interval below the prior value makes Godot's Range
## clamp-and-EMIT value_changed; the live capped callback would then WRITE a stepped value into
## the model (commit suppressed by _suspend_commit, but the model write is NOT) and corrupt the
## restore. This flag makes every live slider/spin callback a hard no-op during restore — the
## restore writes the model itself, raw. Surfaces when a load LOWERS extremeness (import/autosave),
## narrowing caps below the loaded values.
var _restoring: bool = false

var _history_list: VBoxContainer     ## the linear branch-nav node list (rebuilt on change)
var _history_panel: Control          ## the whole history panel (hidden by default; toggled)
var _undo_btn: Button                ## corner icon button
var _redo_btn: Button                ## corner icon button
var _status_lbl: Label               ## transient export/import toast (no persistent path text)
var _legend_panel: Control           ## the controls legend (Ctrl hold-to-peek / tap-to-pin)
var _legend_pinned: bool = false     ## tap-Ctrl pin state
var _ctrl_down: bool = false         ## Ctrl currently held (hold-to-peek)
var _ctrl_used_combo: bool = false   ## a Ctrl-combo fired this hold (so release isn't a tap)

## The image format the export actions use (one of CreatorIO/ImageMetadata FORMAT_* keys).
var _image_format: String = "png"

## True once _ready finished restoring (so the build-time _refresh_history_panel calls and the
## restore itself don't autosave the default over a saved character before it is loaded, §6).
var _persistence_armed: bool = false


func _ready() -> void:
	# Build-time gate (§8 #11b): neutral ∈ [a,b] for EVERY control (authored + derived).
	# A violating default interval is a build defect — fail loudly (the test suite asserts
	# this too, but at scene load it surfaces a bad caps asset immediately).
	var cap_errs: PackedStringArray = _caps.validate_neutral_in_interval()
	if not cap_errs.is_empty():
		push_error("BodyCaps gate FAILED (neutral∉[a,b]): %s" % ", ".join(cap_errs))
	# Build-time gate #11a (§8 / §2.1): every shipped first-party archetype must lie within
	# every control's DEFAULT interval cap(control, 0), so picking one at extremeness 0 — the
	# most common first action — can never exceed default caps. A violation is a build defect.
	_archetypes = BodyArchetypesScript.load_roster()
	var arch_errs: PackedStringArray = _caps.validate_archetype_containment(
		BodyArchetypesScript.roster_states())
	if not arch_errs.is_empty():
		push_error("Archetype containment gate #11a FAILED: %s" % ", ".join(arch_errs))
	_history = HistoryTreeScript.new(_body_state.to_dict(), "initial")
	_build_environment()
	_build_body()
	_build_morph_drag()
	_build_camera()
	_build_ui()
	_recenter_pivot()
	_update_camera()
	# PERSISTENCE (Phase 4 / SYNTHESIS §6): restore the autosaved character if one exists —
	# this is what makes creator → parkour → creator (cross-scene; the launcher FREES this scene
	# on switch) AND an app restart keep the body. Restored RAW through the same path import uses
	# (beyond-cap persists). Absent → the default new character built above stands.
	_restore_from_autosave()
	# Arm persistence only AFTER the restore, so the build-time panel refreshes + the restore's
	# own commit don't autosave the default state over the saved character before it loads.
	_persistence_armed = true


## Restore the autosaved character (cross-scene + restart persistence, §6). The autosave store
## is the CharacterAutosave autoload (survives scene frees) mirrored to user://. Applies the
## payload via the RAW restore path (replaces the history tree if the save carried one, else
## seeds a fresh tree from the body), and restores the global extremeness. No-op (keeps the
## default new character) if nothing is saved.
func _restore_from_autosave() -> void:
	var store := get_node_or_null("/root/CharacterAutosave")
	if store == null or not store.has_save():
		return
	var res: Dictionary = store.restore()
	if not bool(res.get("ok", false)) or res.get("body", null) == null:
		return
	_apply_imported(res, "restored")


# ---------------------------------------------------------------------------
# Scene construction
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	# Key light from the front-upper-left.
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	key.light_energy = 1.1
	key.shadow_enabled = true
	add_child(key)

	# Fill light from the opposite side so the far side of the body isn't black.
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-25.0, 140.0, 0.0)
	fill.light_energy = 0.4
	add_child(fill)

	# Neutral environment: soft sky-ish background + neutral ambient so the body
	# reads clearly from every angle (no harsh black far side).
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.46, 0.50)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)

	# Simple neutral ground so the feet read as planted (not floating in void).
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.32, 0.33, 0.36)
	gmat.roughness = 0.95
	ground.material_override = gmat
	add_child(ground)


func _build_body() -> void:
	# The real player body, in the authored rest/bind pose. BodyRig.build() (run
	# from its _ready) constructs the Skeleton3D + skinned mesh and leaves every
	# bone at its rest pose — a clean neutral stand. We deliberately do NOT call
	# set_movement_state / apply_pose / setup_ik: this is a static viewer, so the
	# locomotion + Motion-Matching driver stays detached and the body holds bind.
	_rig = BodyRig.new()
	_rig.name = "BodyRig"
	# Disable the procedural-cycle entry points by leaving them unused; also turn
	# off MM so even an accidental apply_pose call would not contort the stand.
	_rig.use_motion_matching = false
	_rig.foot_ik_enabled = false
	# Drive the rig with THIS creator's BodyState (the single source of truth the
	# sliders edit). BodyRig already holds a per-instance mesh copy and morphs through
	# the correct-normals CPU bake (apply_body_state), so the creator no longer
	# duplicates or bakes itself — it just edits the shared record and re-applies it.
	_rig.body_state = _body_state
	add_child(_rig)


## Build the drag-to-modify core: the MorphDrag accel structure (per-render-vertex ->
## candidate modifiers, from the registry + sparse DetailLibrary) and the hover-glow
## overlay mesh. The accel structure is built ONCE here (deterministic, cached). The body
## mesh's rest-space positions + triangle list are cached for CPU picking + glow.
func _build_morph_drag() -> void:
	_morph = MorphDragScript.new()
	var reg := BodyState.registry()
	if not reg.is_empty() and DetailLibraryScript.ensure_loaded():
		_morph.build_accel(reg, DetailLibraryScript, DetailLibraryScript.render_vertex_count())
	# Cache the body's baked rest-space positions + triangle index list for CPU raycast +
	# glow. The creator holds the body in bind pose, so the morphed surface arrays ARE the
	# pickable geometry (skeleton scale is the only world transform — applied at pick time).
	if _rig != null and _rig.mesh_instance != null and _rig.mesh_instance.mesh is ArrayMesh:
		var arrays := (_rig.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
		_glow_base_pos = arrays[Mesh.ARRAY_VERTEX]
		_glow_base_nrm = arrays[Mesh.ARRAY_NORMAL]
		_glow_tris = arrays[Mesh.ARRAY_INDEX]
		_glow_geom_dirty = false
	# Build the CPU spatial-grid picker over the rest-space baked triangles. Deterministic;
	# rebuilt lazily on the next pick after a morph bake marks it dirty (_apply_state).
	_cpu_picker = CpuAccelPickerScript.new()
	if not _glow_base_pos.is_empty() and not _glow_tris.is_empty():
		_cpu_picker.build(_glow_base_pos, _glow_tris)
	# The GPU ID-buffer backend (selectable via the P key). Its off-screen SubViewport is
	# parented under this creator node; it renders the SAME skinned/morphed surface the player
	# sees, so it generalises to in-world picking of animated targets (the CPU grid cannot).
	_gpu_picker = GpuIdPickerScript.new()
	_gpu_picker.set_host(self)
	_picker = _gpu_picker if _use_gpu_picker else _cpu_picker
	_build_glow_overlay()


## Swap the active picking backend at runtime (debug/dev). The Picker interface means
## MorphDrag + the input glue are untouched — only which strategy resolves a screen pick.
func set_picker_backend(use_gpu: bool) -> void:
	_use_gpu_picker = use_gpu
	_picker = _gpu_picker if use_gpu else _cpu_picker


## The hover-glow overlay: a sibling MeshInstance3D under the body's skeleton (so it inherits
## the same stature scale), sharing the body's triangle topology, rendered UNSHADED + ADDITIVE
## with per-vertex alpha from the glow weights. A soft additive glow reads as a region
## highlight, not a hard mask. Starts empty (no glow until hover).
func _build_glow_overlay() -> void:
	if _rig == null or _rig.skeleton == null:
		return
	_glow_overlay = MeshInstance3D.new()
	_glow_overlay.name = "MorphGlow"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.35, 0.85, 1.0, 1.0)   # cyan glow tint
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	_glow_overlay.material_override = mat
	_glow_overlay.visible = false
	_rig.skeleton.add_child(_glow_overlay)
	# The world-space outward offset (§6.6) divides ε by the skeleton's uniform scale to land a
	# constant world thickness. That math assumes scale is UNIFORM (one scalar). Assert it so a
	# future non-uniform skeleton scale can't silently re-break the offset.
	var sc := _rig.skeleton.scale
	assert(absf(sc.x - sc.y) < 1e-4 and absf(sc.x - sc.z) < 1e-4,
		"glow outward-offset assumes uniform skeleton scale; got %s" % sc)


## Re-read the glow geometry (positions + normals) from the CURRENT morphed body surface — the
## same baked ARRAY_VERTEX/ARRAY_NORMAL the renderer + picker use. Lazy: only does work when a
## morph bake (_apply_state) has marked the geometry dirty. This is what makes the glow TRACK
## the morph instead of stamping a stale once-at-build neutral capture (§2.3 / §6.6).
func _refresh_glow_geometry() -> void:
	if not _glow_geom_dirty:
		return
	if _rig == null or _rig.mesh_instance == null or not (_rig.mesh_instance.mesh is ArrayMesh):
		return
	var arrays := (_rig.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	_glow_base_pos = arrays[Mesh.ARRAY_VERTEX]
	_glow_base_nrm = arrays[Mesh.ARRAY_NORMAL]
	_glow_geom_dirty = false


## Feed the CPU picker the CURRENT morphed rest-space surface (B2 correctness). The owner
## (this creator) reads the SAME baked ARRAY_VERTEX the renderer + glow + locality read and
## pushes it into the picker on every morph bake, so the next pick raycasts the morphed body
## rather than the picker's stale build-time neutral source. Topology (ARRAY_INDEX) is invariant
## under morph, so the cached _glow_tris stays correct. set_geometry() only updates the source +
## marks dirty — the grid rebuild stays lazy (once on the next pick), preserving the no-per-
## drag-frame-rebuild guarantee.
func _refresh_picker_geometry() -> void:
	if _cpu_picker == null:
		return
	if _rig == null or _rig.mesh_instance == null or not (_rig.mesh_instance.mesh is ArrayMesh):
		return
	var morphed: PackedVector3Array = (_rig.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if morphed.is_empty() or _glow_tris.is_empty():
		return
	_cpu_picker.set_geometry(morphed, _glow_tris)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "OrbitCamera"
	_camera.fov = 50.0
	_camera.near = 0.05
	add_child(_camera)


func _update_camera() -> void:
	# Spherical orbit around the pivot. yaw=0,pitch=0 places the camera on +Z, which
	# is in FRONT of the un-rotated rig (its anatomical face points +Z), looking back
	# toward -Z at the body. (Creator rig is NOT 180°-rotated; the parkour player is.)
	var dir := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch),
	)
	var pos := _pivot + dir * _distance
	_camera.global_position = pos
	_camera.look_at(_pivot, Vector3.UP)


## Set the orbit pivot to the body's VERTICAL CENTER (mid-torso/navel height) so orbiting is
## maximally useful — derived from the body's ACTUAL standing extent, not a hardcoded torso
## height, so it tracks height_cm changes. We use the POSED skeleton's bone world-y extremes
## (feet bone ↔ head bone) rather than the un-skinned mesh AABB: the mesh's bind-pose AABB sits
## in a rotated/offset frame and overstates the extent, whereas the posed bone positions give
## the true standing span (verified: ~0.02 m feet → ~1.66 m head → center ~0.84 m for the
## neutral build). The pivot is centred on x=0 (the body's sagittal plane), y at half-height.
func _recenter_pivot() -> void:
	if _rig == null or _rig.skeleton == null:
		return
	var sk := _rig.skeleton
	if sk.get_bone_count() == 0:
		return
	var ymin := INF
	var ymax := -INF
	for bi in sk.get_bone_count():
		var gp_y: float = (sk.global_transform * sk.get_bone_global_pose(bi)).origin.y
		ymin = minf(ymin, gp_y)
		ymax = maxf(ymax, gp_y)
	if ymin == INF:
		return
	_pivot = Vector3(0.0, (ymin + ymax) * 0.5, 0.0)


## Per-frame free-fly: poll the WASD/Space/Ctrl key state and translate the camera in its own
## local plane (W/S = forward/back, A/D = left/right) plus world up/down, frame-rate-independent.
## Free-fly is ADDITIVE — it moves both the camera and the orbit pivot together so the next
## orbit/pan/zoom keeps working from the new vantage (the spherical relationship is preserved).
func _process(delta: float) -> void:
	if _camera == null:
		return
	var move := Vector3.ZERO
	var basis := _camera.global_transform.basis
	if _fly_fwd:
		move += -basis.z   # camera forward
	if _fly_back:
		move += basis.z
	if _fly_left:
		move += -basis.x
	if _fly_right:
		move += basis.x
	if _fly_up:
		move += Vector3.UP
	# Ctrl is "fly down" ONLY while another fly key is active (otherwise Ctrl = legend peek/pin).
	var horiz_active := _fly_fwd or _fly_back or _fly_left or _fly_right or _fly_up
	if _fly_down and horiz_active:
		move += Vector3.DOWN
	if move == Vector3.ZERO:
		return
	var step := move.normalized() * FLY_SPEED * delta
	# Shift the pivot by the same step so the orbit radius/angles stay valid; _update_camera
	# then places the camera at pivot + dir*distance, i.e. the camera moves by `step` too.
	_pivot += step
	_update_camera()


# ---------------------------------------------------------------------------
# Drag-to-modify picking + glow (Slice D). CPU raycast against the body's baked rest-space
# triangles (the body is static in the creator), nearest-vertex pick, glow overlay update,
# and the per-drag modifier application.
# ---------------------------------------------------------------------------

## Raycast a screen position against the body mesh. Returns { vertex:int, pos:Vector3 } for
## the nearest base vertex of the hit triangle (world space), or {} on a miss. Delegates to
## the Picker backend (default the deterministic CPU uniform grid) and adapts its richer
## hit shape ({render_vertex_index, world_pos, ...}) back to the {vertex, pos} the glow +
## drag-start consumers expect. The body is static in the creator (bind pose), so the rig's
## skeleton global_transform — the stature scale — is the only world transform.
func _pick_body(screen_pos: Vector2) -> Dictionary:
	if _picker == null or _camera == null or _glow_base_pos.is_empty() or _glow_tris.is_empty() \
			or _rig == null or _rig.skeleton == null:
		return {}
	var target := {
		"world_xf": _rig.skeleton.global_transform,
		"rest_positions": _glow_base_pos,
		"tris": _glow_tris,
		"mesh_instance": _rig.mesh_instance,   # GPU backend: the rendered surface
		"skeleton": _rig.skeleton,             # GPU backend: skinning source
	}
	var hit := _picker.pick(screen_pos, _camera, target)
	if hit.is_empty():
		return {}
	return {"vertex": int(hit["render_vertex_index"]), "pos": hit["world_pos"]}


## Update the hover glow for a screen position (sculpt mode, not currently dragging). Picks
## the body; if hit, builds the glow overlay from MorphDrag.glow_weights at the hit vertex;
## on a miss, hides the glow. Cheap (a sparse highlight).
func _update_hover_glow(screen_pos: Vector2) -> void:
	if _morph == null or not _morph.is_built():
		return
	var hit := _pick_body(screen_pos)
	if hit.is_empty():
		_hover_vertex = -1
		if _glow_overlay != null:
			_glow_overlay.visible = false
		return
	_hover_vertex = int(hit["vertex"])
	_refresh_glow_geometry()   # use the current morphed positions for the weight radius
	# glow_weights works in the SAME space as the positions we pass — use rest-space positions
	# (the overlay is a child of the skeleton, so it inherits the scale; weights are computed in
	# rest space and the hit pos is converted back to rest space for a consistent radius).
	var inv := _rig.skeleton.global_transform.affine_inverse()
	var hit_local: Vector3 = inv * (hit["pos"] as Vector3)
	var weights: Dictionary = _morph.glow_weights(_hover_vertex, hit_local, _glow_base_pos)
	_rebuild_glow_mesh(weights)


## Rebuild the glow overlay ArrayMesh from a sparse {render_vertex -> weight} map: the body's
## triangles, with per-vertex COLOR alpha = the glow weight (0 for unlit verts). Triangles with
## all-zero alpha contribute nothing (additive). Empty map -> hide. Rest-space positions (the
## overlay is parented to the scaled skeleton).
func _rebuild_glow_mesh(weights: Dictionary) -> void:
	if _glow_overlay == null:
		return
	if weights.is_empty():
		_glow_overlay.visible = false
		return
	# Track the morph: re-read the current baked surface if a bake marked it dirty.
	_refresh_glow_geometry()
	var n := _glow_base_pos.size()
	# OUTWARD OFFSET (§6.6): push each glow vertex a constant WORLD distance off the skin along
	# its morphed normal, so the additive shell sits just ABOVE the surface instead of z-fighting
	# it. The overlay is a child of the scaled skeleton, so a world ε must be divided by the
	# uniform stature scale to land the same world thickness across the height range.
	var hscale := 1.0
	if _body_state != null:
		hscale = maxf(_body_state.height_scale(), 1e-4)
	var eps := GLOW_WORLD_OFFSET / hscale
	var have_nrm := _glow_base_nrm.size() == n
	var pos := PackedVector3Array()
	pos.resize(n)
	var colors := PackedColorArray()
	colors.resize(n)
	for i in n:
		var w := float(weights.get(i, 0.0))
		colors[i] = Color(1, 1, 1, w)   # tinted by the material albedo; alpha = glow strength
		pos[i] = _glow_base_pos[i] + (_glow_base_nrm[i] * eps if have_nrm else Vector3.ZERO)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_INDEX] = _glow_tris
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_glow_overlay.mesh = mesh
	_glow_overlay.visible = true


## Apply a morph drag step: decompose the screen drag across the picked vertex's candidates,
## add the deltas to the BodyState.modifiers map (clamped by the core), re-bake LIVE, and
## accumulate per-modifier totals for the drag-end history label. NOT committed per frame.
func _apply_morph_drag(drag_screen: Vector2) -> void:
	if _morph == null or _drag_vertex < 0:
		return
	var cam_basis := _camera.global_transform.basis
	# Locality bias needs the hit + render-vertex positions in ONE consistent frame; use the
	# skeleton-local rest space (the same frame glow_weights uses), converting the world hit in.
	var inv := _rig.skeleton.global_transform.affine_inverse()
	var hit_local: Vector3 = inv * _drag_hit_pos
	_refresh_glow_geometry()   # decompose_drag biases against the CURRENT morphed positions
	# ZOOM/DEPTH-ADAPTIVE sensitivity: the world-metres a screen pixel spans at the hit's depth.
	# Perspective camera: world_per_px = 2·z·tan(fov_y/2) / viewport_height, where z is the
	# hit's view-space depth (distance along the camera's forward -Z). So a pixel of drag maps
	# to a CONSISTENT on-screen surface motion whether zoomed in or out.
	var world_per_px := _world_per_pixel_at(_drag_hit_pos)
	# Current modifier values so the core clamps against the live state.
	var deltas: Dictionary = _morph.decompose_drag(_drag_vertex, drag_screen, cam_basis,
		_body_state.modifiers, MorphDragScript.DEFAULT_PX_PER_UNIT, hit_local, _glow_base_pos,
		world_per_px)
	if deltas.is_empty():
		return
	for full_name in deltas:
		_apply_sculpt_delta_mirrored(full_name, float(deltas[full_name]))
	_apply_state()
	# Keep the glow on the active region while dragging (re-pick the vertex's footprint).
	var weights: Dictionary = _morph.glow_weights(_drag_vertex, hit_local, _glow_base_pos)
	_rebuild_glow_mesh(weights)


## Apply a sculpt delta to a touched modifier AND — when MIRROR is ON — to its contralateral
## twin(M) (decision §2.3). This is the sculpt write the per-frame drag loop runs for each
## decomposed modifier. The touched side always writes; with mirror ON the SAME delta also
## applies to twin(M) (capped against ITS OWN cur), so sculpting one arm/leg shapes the other —
## the user's "sculpted one arm, the other didn't change" fix. The midline guard (twin == self)
## suppresses a double-apply on midline modifiers, which the toggle leaves unaffected.
func _apply_sculpt_delta_mirrored(full_name: String, delta: float) -> void:
	_apply_sculpt_delta(full_name, delta)
	if _mirror:
		var tw := RegionSlidersScript.twin(full_name)
		if tw != full_name:
			_apply_sculpt_delta(tw, delta)


## Apply ONE sculpt delta to ONE modifier through the choke (§3.2 path 1): req = cur + delta,
## capped against the modifier's own cur (held cur_start after first touch this gesture), stored
## with the erase-at-neutral housekeeping, the bound region slider synced, and the drag-accum
## updated by the ACTUAL applied delta. Shared by the touched modifier and its mirror twin.
func _apply_sculpt_delta(full_name: String, delta: float) -> void:
	var cur := float(_body_state.modifiers.get(full_name, 0.0))
	var req := cur + delta
	var nv: float = _caps.apply_capped(full_name, req, cur)
	if absf(nv) < 1e-6:
		_body_state.modifiers.erase(full_name)
	else:
		_body_state.modifiers[full_name] = nv
	# Sync the bound region slider's value + bounds to the clamped result (B10-1) — the
	# modifier may be bound to a T2/T3 slider; bounds-first then no-signal value write.
	_sync_modifier_slider(full_name, nv)
	_drag_accum[full_name] = float(_drag_accum.get(full_name, 0.0)) + (nv - cur)


## World metres that one screen pixel spans at `world_pos`'s DEPTH, under the current camera —
## the zoom/depth-adaptive drag scale. Perspective: at view-space depth z (the hit's distance
## along the camera's forward axis), the viewport's vertical extent in world units is
## 2·z·tan(fov_y/2), so each pixel spans that over the viewport height. Falls back to a fixed
## small value if the camera/viewport is unavailable (keeps the drag responsive, not frozen).
func _world_per_pixel_at(world_pos: Vector3) -> float:
	if _camera == null:
		return 0.0
	var vp_size := _camera.get_viewport().get_visible_rect().size
	var vh := vp_size.y
	if vh <= 0.0:
		return 0.0
	# View-space depth: project the hit onto the camera's forward (-Z) axis.
	var fwd := -_camera.global_transform.basis.z
	var z := absf((world_pos - _camera.global_position).dot(fwd))
	if z <= 0.0:
		return 0.0
	var fov_y := deg_to_rad(_camera.fov)
	return 2.0 * z * tan(fov_y * 0.5) / vh


## End a morph drag: commit ONE history node labelled by the dominant modifier(s).
func _end_morph_drag() -> void:
	_dragging_morph = false
	# End the gesture: clear the held-interval map and recompute bounds from the settled
	# values (§3.2 — the ratchet collapses inward once, on commit). Recompute BEFORE the
	# clear so held_interval still reads the gesture's cur_start for any leftover sync.
	_caps.end_gesture()
	_recompute_modifier_slider_bounds()
	if _drag_accum.is_empty():
		_drag_vertex = -1
		return
	# Dominant modifier(s): the largest |accumulated delta|. Label with the top 1–2.
	var names := _drag_accum.keys()
	names.sort_custom(func(a, b): return absf(_drag_accum[a]) > absf(_drag_accum[b]))
	var top := []
	for i in mini(2, names.size()):
		top.append("%s %+.2f" % [_short_modifier_name(String(names[i])), float(_drag_accum[names[i]])])
	var label := "sculpt: " + ", ".join(top)
	if not _suspend_commit:
		_rebake_tangents_on_commit()
		_history.commit(_body_state.to_dict(), label)
		_refresh_history_panel()
	_drag_accum = {}
	_drag_vertex = -1


## A compact display name for a modifier fullName ("nose/nose-hump-decr|incr" -> "nose-hump").
func _short_modifier_name(full_name: String) -> String:
	var name := full_name.get_slice("/", 1)
	if name == "":
		name = full_name
	# strip the "-decr|incr" bidirectional suffix for readability.
	var bar := name.find("-decr|incr")
	if bar < 0:
		bar = name.find("|")
		if bar >= 0:
			# generic "<a>|<b>" -> trim from the last '-' before the bar
			var dash := name.rfind("-", bar)
			if dash >= 0:
				return name.substr(0, dash)
	return name.substr(0, bar) if bar >= 0 else name


## Toggle sculpt mode (the camera-vs-morph gate). Updates the button + hint label; clears any
## stale glow when leaving the mode.
func _set_sculpt_mode(on: bool) -> void:
	_sculpt_mode = on
	if _sculpt_btn != null:
		_sculpt_btn.button_pressed = on
		_sculpt_btn.text = _sculpt_btn_text(on)
	if _sculpt_state_lbl != null:
		_sculpt_state_lbl.text = _sculpt_state_text(on)
	# Cursor change as a second visible state indicator (§2.3): a cross in sculpt mode, the
	# default arrow otherwise.
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)
	if not on and _glow_overlay != null:
		_glow_overlay.visible = false
		_hover_vertex = -1


## Set the MIRROR (contralateral symmetry) toggle (decision §2.3). Pure state — it changes only
## how SUBSEQUENT one-sided edits apply (it does not re-symmetrize the existing body). Keeps the
## CheckBox in sync without re-firing.
func _set_mirror(on: bool) -> void:
	_mirror = on
	if _mirror_btn != null:
		_mirror_btn.set_pressed_no_signal(on)


## Build the EYE-COLOR control (§6.3): a ColorPickerButton bound to the procedural `iris_color`
## uniform, plus a row of common preset swatches. Both route through _set_eye_color, which calls
## BodyRig.set_eye_params({"iris_color": …}) — the only eye-color control needed (no texture).
func _build_eye_color_ui(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = "eye color"
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)
	_eye_color_btn = ColorPickerButton.new()
	_eye_color_btn.color = _eye_color
	_eye_color_btn.edit_alpha = false
	_eye_color_btn.custom_minimum_size = Vector2(64, 0)
	_eye_color_btn.tooltip_text = "Procedural iris color (drives the eye shader's iris_color uniform)"
	_eye_color_btn.color_changed.connect(func(c: Color) -> void: _set_eye_color(c))
	row.add_child(_eye_color_btn)
	# Quick preset swatches (a small set, per §6.3 "a color picker or a small set of presets").
	for preset in [
		["brown", Color(0.36, 0.20, 0.09)],
		["amber", Color(0.55, 0.34, 0.10)],
		["green", Color(0.20, 0.42, 0.20)],
		["blue", Color(0.20, 0.40, 0.62)],
		["grey", Color(0.45, 0.47, 0.50)],
	]:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(20, 20)
		sw.tooltip_text = String(preset[0])
		var sb := StyleBoxFlat.new()
		sb.bg_color = preset[1]
		sw.add_theme_stylebox_override("normal", sb)
		sw.add_theme_stylebox_override("hover", sb)
		sw.add_theme_stylebox_override("pressed", sb)
		var col: Color = preset[1]
		sw.pressed.connect(func() -> void: _set_eye_color(col))
		row.add_child(sw)
	parent.add_child(row)


## Set the procedural iris color (§6.3): drive the eye shader's `iris_color` uniform via the
## BodyRig API and keep the picker widget in sync without re-firing. Gaze is left alone.
func _set_eye_color(c: Color) -> void:
	_eye_color = c
	if _rig != null:
		_rig.set_eye_params({"iris_color": c})
	if _eye_color_btn != null and _eye_color_btn.color != c:
		_eye_color_btn.color = c


## The Sculpt toggle button's label (a clearly-labeled visible control; M is only an
## accelerator hint, never the only way in — §2.3).
func _sculpt_btn_text(on: bool) -> String:
	return "● Sculpt mode: ON" if on else "○ Sculpt mode: OFF"


## The live state-indicator line under the Sculpt toggle.
func _sculpt_state_text(on: bool) -> String:
	if on:
		return "drag the body to morph · drag empty space to orbit (M toggles)"
	return "orbit/pan/zoom viewer — enable to drag-sculpt the body (M toggles)"


# ---------------------------------------------------------------------------
# Input — orbit (left drag), pan (right drag), zoom (scroll wheel)
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Ctrl+Z = undo, Ctrl+Shift+Z = redo (history navigation).
	if event is InputEventKey:
		var k := event as InputEventKey
		# CONTROLS-LEGEND Ctrl hold-to-peek / tap-to-pin. Track Ctrl press/release; a quick
		# tap (press then release with no Ctrl-combo consumed in between) toggles the pin,
		# while merely HOLDING Ctrl peeks the legend. This is display-only — it changes no
		# binding. (The keycode for the modifier itself is KEY_CTRL.)
		if k.keycode == KEY_CTRL:
			# Ctrl drives BOTH the legend peek/pin AND free-fly "down" (the latter only takes
			# effect while a WASD/Space key is also held — see _process). Tracking _fly_down here
			# keeps the two uses non-conflicting: a bare Ctrl tap still pins the legend.
			if k.pressed and not k.echo:
				_ctrl_down = true
				_fly_down = true
				_ctrl_used_combo = false
				_update_legend_visibility()
			elif not k.pressed:
				_ctrl_down = false
				_fly_down = false
				if not _ctrl_used_combo:
					_legend_pinned = not _legend_pinned
				_update_legend_visibility()
			return
		if k.pressed and not k.echo and k.keycode == KEY_Z and k.ctrl_pressed:
			_ctrl_used_combo = true
			if k.shift_pressed:
				_do_redo()
			else:
				_do_undo()
			get_viewport().set_input_as_handled()
			return
		# H toggles the history panel (hidden by default).
		if k.pressed and not k.echo and k.keycode == KEY_H and not k.ctrl_pressed:
			_toggle_history_panel()
			get_viewport().set_input_as_handled()
			return
		# M toggles sculpt mode (the camera-vs-morph gate).
		if k.pressed and not k.echo and k.keycode == KEY_M and not k.ctrl_pressed:
			_set_sculpt_mode(not _sculpt_mode)
			get_viewport().set_input_as_handled()
			return
		# P — toggle the picking backend (CPU grid <-> GPU ID-buffer). Dev/debug: the GPU
		# backend picks the rendered surface (the in-world primitive); CPU is the default.
		if k.pressed and not k.echo and k.keycode == KEY_P and not k.ctrl_pressed:
			set_picker_backend(not _use_gpu_picker)
			if _status_lbl != null:
				_status_lbl.text = "picker: %s" % ("GPU ID-buffer" if _use_gpu_picker else "CPU grid")
			get_viewport().set_input_as_handled()
			return
		# FREE-FLY keys (WASD = move in the camera's local plane, Space = up; Ctrl = down is
		# handled in the KEY_CTRL block above). Track press/release state; _process applies the
		# translation per-frame. Skip while Ctrl is held so Ctrl-combos (e.g. Ctrl+Z, Ctrl+S) and
		# typing in text fields aren't hijacked as fly input.
		if not k.ctrl_pressed and not k.echo:
			match k.keycode:
				KEY_W:
					_fly_fwd = k.pressed
					get_viewport().set_input_as_handled()
					return
				KEY_S:
					_fly_back = k.pressed
					get_viewport().set_input_as_handled()
					return
				KEY_A:
					_fly_left = k.pressed
					get_viewport().set_input_as_handled()
					return
				KEY_D:
					_fly_right = k.pressed
					get_viewport().set_input_as_handled()
					return
				KEY_SPACE:
					_fly_up = k.pressed
					get_viewport().set_input_as_handled()
					return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					# In sculpt mode, a left-press ON THE BODY starts a morph drag; a press on
					# the BACKGROUND (ray misses) falls through to orbit. Outside sculpt mode
					# the left button always orbits (Slice-A behaviour).
					if _sculpt_mode:
						var hit := _pick_body(mb.position)
						if not hit.is_empty():
							_dragging_morph = true
							_drag_vertex = int(hit["vertex"])
							_drag_hit_pos = hit["pos"]
							_drag_accum = {}
							# A sculpt drag IS an active edit gesture (§3.2): the held-interval
							# map captures each touched modifier's cur_start on first touch.
							_caps.start_gesture()
							get_viewport().set_input_as_handled()
							return
					_dragging_orbit = true
				else:
					if _dragging_morph:
						_end_morph_drag()
					_dragging_orbit = false
			MOUSE_BUTTON_RIGHT:
				_dragging_pan = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_distance = clampf(_distance * ZOOM_STEP, MIN_DIST, MAX_DIST)
					_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_distance = clampf(_distance / ZOOM_STEP, MIN_DIST, MAX_DIST)
					_update_camera()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging_morph:
			_apply_morph_drag(mm.relative)
		elif _dragging_orbit:
			_yaw = wrapf(_yaw - mm.relative.x * ORBIT_SPEED, -PI, PI)
			_pitch = clampf(_pitch - mm.relative.y * ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
			_update_camera()
		elif _dragging_pan:
			# Pan the pivot in the camera's right/up plane.
			var right := _camera.global_transform.basis.x
			var up := _camera.global_transform.basis.y
			_pivot += (-right * mm.relative.x + up * mm.relative.y) * PAN_SPEED * _distance
			_update_camera()
		elif _sculpt_mode:
			# Hover (no button) in sculpt mode -> live region glow under the cursor.
			_update_hover_glow(mm.position)


# ---------------------------------------------------------------------------
# Morph UI — sliders for the BodyState natural-unit headline axes (age in years,
# masculinity 0–100 (feminine←→masculine), muscle %, weight %, proportions),
# live-driving the blendshapes through the rig's correct-normals CPU morph bake.
# (body-parameterization.md §2/§7 — natural units on the public surface.)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Main slider panel — TOP-LEFT corner. No persistent controls-legend clutter (that
	# moved to its own Ctrl-peek panel) and no persistent internal export-path text.
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(430, 0)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "aeriea — character creator"
	vbox.add_child(title)

	# TIER SELECTOR (Phase 3b, SYNTHESIS §2.2): the progressive-refine depth control. The
	# tiers are ADDITIVE/MONOTONE — picking a deeper tier reveals more without hiding T1. T1
	# (the headline axes) is ALWAYS visible; T2 reveals the curated detail region groups; T3
	# reveals the full registry tree + the visible Sculpt control + the extremeness gate.
	_build_tier_selector(vbox)

	vbox.add_child(HSeparator.new())

	# T0 PICK (SYNTHESIS §2.2): the archetype pick grid. Picking an archetype loads its frozen
	# BodyState via the RAW restore path (Phase-1 raw/restore semantics; aborts any active
	# gesture). Every shipped archetype is within default caps (gate #11a), so a pick at
	# extremeness 0 never exceeds default caps.
	_build_archetype_grid(vbox)

	vbox.add_child(HSeparator.new())

	var t1_hdr := Label.new()
	t1_hdr.text = "T1 — headline (always visible)"
	t1_hdr.add_theme_font_size_override("font_size", 10)
	vbox.add_child(t1_hdr)

	# [field, min, max, step, label, lo_pole, hi_pole] — the BodyState natural-unit
	# headline axes (body-parameterization.md §2). age is in YEARS (the gate reads
	# >= 18); masculinity is the single macro sex axis 0–100 (0=feminine,
	# 50=androgynous, 100=masculine); muscle/weight in %; proportions is the
	# dimensionless 0..1-about-0.5 bidirectional envelope; height is the Slice A
	# provisional normalized macro-height amount (Slice C makes it metric cm, §4).
	#
	# Slice C restores the FULL muscle/weight ranges (0–100 / 50–150): the below-average
	# (minmuscle / minweight) anchors are now imported in the sparse macro factor-cube, so
	# the lean/light half is functional. height is now a METRIC cm axis (§4), driving a
	# uniform stature scale orthogonal to proportions.
	var axes := [
		["age_years",   1.0, 90.0,  0.5,  "age",         "young",    "old"],
		["masculinity", 0.0, 100.0, 1.0,  "masculinity",  "feminine", "masculine"],
		["muscle",      0.0, 100.0, 1.0,  "muscle",       "lean",     "muscular"],
		["weight",      50.0, 150.0, 1.0, "weight",       "light",    "heavy"],
		["proportions", 0.0, 1.0,   0.01, "proportions",  "uncommon", "idealized"],
		["height_cm",   50.0, 230.0, 0.5, "height",       "shorter",  "taller"],
	]
	for spec in axes:
		_build_axis_row(vbox, spec[0], spec[1], spec[2], spec[3], spec[4], spec[5], spec[6])

	# EYE COLOR (decision §6.3 / SYNTHESIS §5.2): the procedural iris color is a SHADER UNIFORM
	# (eye.gdshader `iris_color`), not a texture — surfaced here as a color picker + preset swatches
	# that drive BodyRig.set_eye_params({"iris_color": …}). Base-creation identity (ungated, §3).
	# Gaze is NOT touched (the eyes track via the eye bones; §6.3).
	_build_eye_color_ui(vbox)

	# T3 MAIN-PANEL SECTION (SYNTHESIS §2.2): the power-user controls — the VISIBLE Sculpt
	# control and the global extremeness gate. Wrapped in a section the tier selector reveals
	# at T3 (hidden at T1/T2). T1/T2 stay uncluttered; sculpt is never reachable ONLY via a
	# hidden key — it is a clearly-labeled toggle in this revealed section (§2.3).
	var t3_main := VBoxContainer.new()
	t3_main.add_theme_constant_override("separation", 6)
	_t3_main_section = t3_main
	vbox.add_child(t3_main)

	t3_main.add_child(HSeparator.new())
	var t3_hdr := Label.new()
	t3_hdr.text = "T3 — full control (sculpt + extremeness)"
	t3_hdr.add_theme_font_size_override("font_size", 10)
	t3_main.add_child(t3_hdr)

	# Sculpt-mode toggle (Slice D / §2.3): the camera-vs-morph gate, surfaced as a VISIBLE,
	# clearly-labeled toggle button with a live state indicator — NOT a hidden keybind (M
	# remains only an accelerator). ON => left-drag ON the body morphs (drag-to-modify with
	# region glow); left-drag on the BACKGROUND still orbits, and orbit stays instant (no pick
	# latency) outside sculpt mode.
	_sculpt_btn = Button.new()
	_sculpt_btn.toggle_mode = true
	_sculpt_btn.text = _sculpt_btn_text(false)
	_sculpt_btn.tooltip_text = "Toggle sculpt mode — drag the body to morph it (accelerator: M)"
	_sculpt_btn.toggled.connect(func(on: bool) -> void: _set_sculpt_mode(on))
	t3_main.add_child(_sculpt_btn)

	_sculpt_state_lbl = Label.new()
	_sculpt_state_lbl.add_theme_font_size_override("font_size", 10)
	_sculpt_state_lbl.text = _sculpt_state_text(false)
	t3_main.add_child(_sculpt_state_lbl)

	# MIRROR toggle (decision §2.3) — DEFAULT ON. Governs whether a one-sided edit (a sculpt drag
	# on one arm/leg, or a lateral slider with an l-/r- twin) ALSO applies to the contralateral
	# side, keeping the body symmetric by default. OFF allows asymmetry (edit only the touched
	# side). It does NOT touch bilateral RESOLUTION (a bare-stem bilateral slider drives both sides
	# regardless) or midline controls (twin == self → unaffected). A visible labeled CheckBox.
	_mirror_btn = CheckBox.new()
	_mirror_btn.text = "Mirror (symmetric edits)"
	_mirror_btn.button_pressed = _mirror
	_mirror_btn.tooltip_text = "When on, editing one side (sculpt or a lateral slider) also shapes the other side symmetrically. Off = edit one side only."
	_mirror_btn.toggled.connect(func(on: bool) -> void: _set_mirror(on))
	t3_main.add_child(_mirror_btn)

	# EXTREMENESS control (§4 / §6): the single global scalar that widens every control's cap
	# interval toward its hard range. Non-destructive — lowering it does NOT snap existing
	# beyond-cap values (Phase-1 ratchet). A checkbox ("Allow extreme proportions") gates the
	# 0..1 slider; both drive _caps.extremeness through _set_extremeness (a state-replacing op
	# that aborts any gesture, then sweeps every control's widget bounds).
	var ex_hdr := Label.new()
	ex_hdr.text = "extremeness (widens all caps; lowering keeps existing values)"
	ex_hdr.add_theme_font_size_override("font_size", 10)
	t3_main.add_child(ex_hdr)
	var ex_row := HBoxContainer.new()
	ex_row.add_theme_constant_override("separation", 4)
	_extreme_check = CheckBox.new()
	_extreme_check.text = "allow"
	_extreme_check.button_pressed = _caps.extremeness > 0.0
	_extreme_check.toggled.connect(func(on: bool) -> void:
		# Toggling on jumps to full unlock; off returns to 0 (existing beyond-cap persists).
		_set_extremeness(1.0 if on else 0.0))
	ex_row.add_child(_extreme_check)
	_extreme_slider = HSlider.new()
	_extreme_slider.min_value = 0.0
	_extreme_slider.max_value = 1.0
	_extreme_slider.step = 0.01
	_extreme_slider.value = _caps.extremeness
	_extreme_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_extreme_slider.value_changed.connect(func(v: float) -> void: _set_extremeness(v))
	ex_row.add_child(_extreme_slider)
	_extreme_lbl = Label.new()
	_extreme_lbl.custom_minimum_size = Vector2(40, 0)
	_extreme_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_extreme_lbl.text = "%.0f%%" % (_caps.extremeness * 100.0)
	ex_row.add_child(_extreme_lbl)
	t3_main.add_child(ex_row)

	vbox.add_child(HSeparator.new())

	var reset := Button.new()
	reset.text = "Reset to neutral"
	reset.pressed.connect(_reset_all)
	vbox.add_child(reset)

	# GLOBAL randomize (§2.3): bounded seeded randomize of every control within the live cap.
	var rand_all := Button.new()
	rand_all.text = "Randomize (within extremeness)"
	rand_all.pressed.connect(_randomize_all)
	vbox.add_child(rand_all)

	# History-toggle button lives in the main panel; the history nav itself is a SEPARATE
	# corner panel hidden by default (toggled by this button or the H hotkey).
	var hist_toggle := Button.new()
	hist_toggle.text = "History (H)"
	hist_toggle.pressed.connect(_toggle_history_panel)
	vbox.add_child(hist_toggle)

	_build_export_ui(vbox)

	# Corner panels (own CanvasLayer-sibling Controls, anchored to other screen corners).
	_build_undo_redo_corner(canvas)
	_build_region_sliders_panel(canvas)
	_build_history_panel(canvas)
	_build_legend_panel(canvas)

	# Apply the initial tier visibility (T1 only — T2/T3 sections hidden until revealed).
	_apply_tier()
	_apply_state()
	_refresh_history_panel()


# ---------------------------------------------------------------------------
# PROGRESSIVE-REFINE TIERS (Phase 3b, SYNTHESIS §2.2). The tier selector + the T0 pick grid,
# and the monotone reveal: raising the tier shows more, never hides T1.
# ---------------------------------------------------------------------------

## The tier selector — three radio-like buttons (T1 / T2 / T3) that raise the revealed depth.
## Monotone: the tier IS the max depth shown. T1 (headline) is always visible regardless.
func _build_tier_selector(parent: VBoxContainer) -> void:
	var hdr := Label.new()
	hdr.text = "detail tier (deeper reveals more; T1 always shown)"
	hdr.add_theme_font_size_override("font_size", 10)
	parent.add_child(hdr)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for spec in [[TIER_T1, "T1 headline"], [TIER_T2, "T2 detail"], [TIER_T3, "T3 full"]]:
		var t := int(spec[0])
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = String(spec[1])
		btn.button_pressed = (t == _tier)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: _set_tier(t))
		row.add_child(btn)
		_tier_buttons[t] = btn
	parent.add_child(row)


## Raise (or set) the revealed tier and re-apply visibility. Additive/monotone reveal.
func _set_tier(t: int) -> void:
	_tier = clampi(t, TIER_T1, TIER_T3)
	_apply_tier()


## Apply the current tier to every tier-gated section's visibility (T1 always on; T2 section
## shown at tier >= T2; T3 section + the main-panel T3 controls shown at tier == T3). The
## tier-selector buttons reflect the active tier.
func _apply_tier() -> void:
	for t in _tier_buttons:
		(_tier_buttons[t] as Button).button_pressed = (int(t) == _tier)
	if _t2_section != null:
		_t2_section.visible = _tier >= TIER_T2
	if _t3_section != null:
		_t3_section.visible = _tier >= TIER_T3
	if _t3_main_section != null:
		_t3_main_section.visible = _tier >= TIER_T3
	# Leaving T3 also leaves sculpt mode (its control is no longer visible — no orphaned mode).
	if _tier < TIER_T3 and _sculpt_mode:
		_set_sculpt_mode(false)


## The T0 ARCHETYPE PICK GRID (SYNTHESIS §2.2 / §2.1): one button per first-party archetype,
## grouped by family. Picking one loads its frozen BodyState via the raw restore path
## (Phase-1 raw/restore semantics) — every archetype is within default caps (gate #11a), so a
## pick at extremeness 0 never exceeds default caps. Whether an archetype LOOKS GOOD is
## USER-taste-gated content; the grid surfaces the system + representative set.
func _build_archetype_grid(parent: VBoxContainer) -> void:
	var hdr := Label.new()
	hdr.text = "T0 — pick an archetype"
	hdr.add_theme_font_size_override("font_size", 10)
	parent.add_child(hdr)
	if _archetypes.is_empty():
		var empty := Label.new()
		empty.text = "(no archetypes installed)"
		empty.add_theme_font_size_override("font_size", 10)
		parent.add_child(empty)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for arch in _archetypes:
		var btn := Button.new()
		btn.text = String(arch["name"])
		btn.tooltip_text = "Load the '%s' archetype (raw — replaces the current body)" % arch["name"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var state: Dictionary = arch["state"]
		btn.pressed.connect(func() -> void: _pick_archetype(state, String(arch["name"])))
		grid.add_child(btn)
	parent.add_child(grid)


## Load an archetype's frozen BodyState (T0 pick). This is the RAW restore path (§2.1 / §4.3
## path 7a): it commits the archetype state into the history tree as a new node, then restores
## it via _restore_current — which aborts any active gesture and writes the model RAW (no
## re-clamp). Because the archetype is within default caps by construction (gate #11a), raw ==
## capped at extremeness 0 and no slider bound ratchets open on the pick.
func _pick_archetype(state: Dictionary, name: String) -> void:
	# Commit the archetype as a history node so the pick is undoable + recorded, then restore.
	_caps.abort_gesture()
	_history.commit(state.duplicate(true), "archetype: %s" % name)
	_restore_current()
	_refresh_history_panel()


## UNDO / REDO as compact ICON buttons in the TOP-RIGHT corner (a different corner from
## the sliders), out of the main panel. Glyph arrows keep them small; tooltips name the
## hotkeys. (Ctrl-Z / Ctrl-Shift-Z still drive them — see _unhandled_input.)
func _build_undo_redo_corner(canvas: CanvasLayer) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-96, 16)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	canvas.add_child(box)

	_undo_btn = Button.new()
	_undo_btn.text = "↶"   # ↶ undo glyph
	_undo_btn.tooltip_text = "Undo (Ctrl+Z)"
	_undo_btn.custom_minimum_size = Vector2(40, 40)
	_undo_btn.pressed.connect(_do_undo)
	box.add_child(_undo_btn)

	_redo_btn = Button.new()
	_redo_btn.text = "↷"   # ↷ redo glyph
	_redo_btn.tooltip_text = "Redo (Ctrl+Shift+Z)"
	_redo_btn.custom_minimum_size = Vector2(40, 40)
	_redo_btn.pressed.connect(_do_redo)
	box.add_child(_redo_btn)


## The history panel — its OWN corner panel (BOTTOM-LEFT), HIDDEN by default, toggled by the
## main-panel button or the H hotkey. The body is a ChatGPT-style pseudo-linear branch nav
## (see _refresh_history_panel): the root→current spine rendered LINEARLY top-to-bottom, with
## a `‹ i/n ›` branch selector at any junction. No indentation, no diagonal tree.
func _build_history_panel(canvas: CanvasLayer) -> void:
	_history_panel = PanelContainer.new()
	_history_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_history_panel.position = Vector2(16, -16)
	_history_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_history_panel.custom_minimum_size = Vector2(360, 0)
	_history_panel.visible = false   # HIDDEN by default
	canvas.add_child(_history_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_history_panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "history — branch nav (root → current)"
	vbox.add_child(hdr)

	# Scrollable LINEAR path list (no indentation). Built in _refresh_history_panel.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_history_list)


## Toggle the history panel's visibility (the H hotkey + the main-panel button).
func _toggle_history_panel() -> void:
	if _history_panel != null:
		_history_panel.visible = not _history_panel.visible


## The CONTROLS LEGEND — its own corner panel (BOTTOM-RIGHT). Not persistent clutter: shown
## only while HOLDING Ctrl (hold-to-peek), and TAP Ctrl toggles it pinned on/off. The legend
## is display-only; it does not change any binding (M sculpt, P picker, Ctrl-Z undo, etc.).
func _build_legend_panel(canvas: CanvasLayer) -> void:
	_legend_panel = PanelContainer.new()
	_legend_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_legend_panel.position = Vector2(-16, -16)
	_legend_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_legend_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_legend_panel.visible = false   # hidden until Ctrl held / pinned
	canvas.add_child(_legend_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_legend_panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "controls (hold Ctrl to peek · tap Ctrl to pin)"
	hdr.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hdr)

	for line in [
		"drag: orbit    right-drag: pan    scroll: zoom",
		"WASD: fly    Space: up    Ctrl(+WASD): down",
		"M: sculpt mode (drag body to morph)",
		"P: picker backend (CPU grid / GPU id)",
		"H: toggle history panel",
		"Ctrl+Z: undo    Ctrl+Shift+Z: redo",
		"sculpt: hover to glow the region, drag the surface to pull it",
	]:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 10)
		vbox.add_child(l)


## Refresh the legend's VISIBILITY from the hold/pin state (pinned OR Ctrl-held shows it).
func _update_legend_visibility() -> void:
	if _legend_panel != null:
		_legend_panel.visible = _legend_pinned or _ctrl_down


## INDIVIDUAL export actions (no "export all"): JSON, JSON+history, image, image+history —
## with a FORMAT picker (PNG / JPG / WEBP). image+history is enabled only for formats that
## can actually carry the embedded history (all three here); were one unable, it would be
## honestly disabled, offering image-only. No persistent internal-path text — a transient
## toast (_status_lbl) reports results.
var _img_history_btn: Button
func _build_export_ui(vbox: VBoxContainer) -> void:
	vbox.add_child(HSeparator.new())

	var hdr := Label.new()
	hdr.text = "export"
	vbox.add_child(hdr)

	# Format picker (drives the image / image+history actions).
	var fmt_row := HBoxContainer.new()
	fmt_row.add_theme_constant_override("separation", 4)
	var fmt_lbl := Label.new()
	fmt_lbl.text = "image format"
	fmt_lbl.custom_minimum_size = Vector2(96, 0)
	fmt_row.add_child(fmt_lbl)
	var fmt := OptionButton.new()
	fmt.add_item("PNG", 0)
	fmt.add_item("JPG", 1)
	fmt.add_item("WEBP", 2)
	fmt.item_selected.connect(_on_image_format_selected)
	fmt_row.add_child(fmt)
	vbox.add_child(fmt_row)

	var json_btn := Button.new()
	json_btn.text = "Export JSON (current)"
	json_btn.pressed.connect(func() -> void: _export_json(false))
	vbox.add_child(json_btn)

	var json_h_btn := Button.new()
	json_h_btn.text = "Export JSON + history"
	json_h_btn.pressed.connect(func() -> void: _export_json(true))
	vbox.add_child(json_h_btn)

	var img_btn := Button.new()
	img_btn.text = "Export image (current)"
	img_btn.pressed.connect(func() -> void: _export_image(false))
	vbox.add_child(img_btn)

	_img_history_btn = Button.new()
	_img_history_btn.text = "Export image + history"
	_img_history_btn.pressed.connect(func() -> void: _export_image(true))
	vbox.add_child(_img_history_btn)

	# IMPORT (Phase 4 / SYNTHESIS §6 slice 1): pair the export actions with an Import affordance
	# that loads a previously-EXPORTED character — a JSON payload (current or with-history) OR an
	# image (PNG/JPG/WEBP) carrying the embedded history — via the EXISTING creator_io.gd read
	# functions (parse_payload / extract_history_from_image). Applied RAW (a beyond-cap value
	# persists). A FileDialog is the picker; drag-and-drop of a file onto the window is the second
	# affordance (see _on_files_dropped). No new parser — pure wiring over the read side.
	vbox.add_child(HSeparator.new())
	var imp_hdr := Label.new()
	imp_hdr.text = "import"
	vbox.add_child(imp_hdr)
	var imp_btn := Button.new()
	imp_btn.text = "Import character… (JSON / image)"
	imp_btn.tooltip_text = "Load a previously-exported character (or drag a saved file onto the window)"
	imp_btn.pressed.connect(_open_import_dialog)
	vbox.add_child(imp_btn)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 10)
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.text = ""
	vbox.add_child(_status_lbl)

	_update_image_history_enabled()
	# Wire window file-drop as the drag-and-drop import affordance (§6 slice 1).
	if get_window() != null and not get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.connect(_on_files_dropped)


# ---------------------------------------------------------------------------
# IMPORT (§6 slice 1) — the read side EXISTS in creator_io.gd; this is the scene wiring: a
# FileDialog picker + window drag-and-drop, both funneling a chosen file through _import_file →
# the existing CreatorIO parse/extract functions → _apply_imported (the RAW restore path).
# ---------------------------------------------------------------------------

var _import_dialog: FileDialog

## Open (lazily building) the import FileDialog filtered to the exportable character formats.
func _open_import_dialog() -> void:
	if _import_dialog == null:
		_import_dialog = FileDialog.new()
		_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_import_dialog.use_native_dialog = false
		_import_dialog.add_filter("*.json", "Character JSON")
		_import_dialog.add_filter("*.png", "Character image (PNG)")
		_import_dialog.add_filter("*.jpg,*.jpeg", "Character image (JPG)")
		_import_dialog.add_filter("*.webp", "Character image (WEBP)")
		_import_dialog.size = Vector2i(640, 480)
		_import_dialog.file_selected.connect(_import_file)
		# Parent under a CanvasLayer so it draws above the 3D view.
		var layer := CanvasLayer.new()
		add_child(layer)
		layer.add_child(_import_dialog)
	# Default to the creator's own export dir if it exists (where the export buttons write).
	var exp_dir := ProjectSettings.globalize_path(CreatorIOScript.EXPORT_DIR)
	if DirAccess.dir_exists_absolute(exp_dir):
		_import_dialog.current_dir = exp_dir
	_import_dialog.popup_centered()


## The window drag-and-drop import handler (§6 slice 1): import the FIRST dropped file.
func _on_files_dropped(files: PackedStringArray) -> void:
	if files.size() > 0:
		_import_file(files[0])


## Import a character from an absolute file path. JSON → CreatorIO.parse_payload directly; an
## image (PNG/JPG/WEBP) → extract the embedded history JSON via CreatorIO.extract_history_from_image
## then parse it. Applies the result RAW via _apply_imported. Reports failures honestly (a toast).
func _import_file(path: String) -> void:
	var ext := path.get_extension().to_lower()
	var text := ""
	if ext == "json":
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_toast("import failed: cannot open %s" % path.get_file())
			return
		text = f.get_as_text()
		f.close()
	elif ext in ["png", "jpg", "jpeg", "webp"]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_toast("import failed: cannot open %s" % path.get_file())
			return
		var bytes := f.get_buffer(f.get_length())
		f.close()
		var fmt := "jpg" if ext == "jpeg" else ext
		text = CreatorIOScript.extract_history_from_image(bytes, fmt)
		if text == "":
			_toast("import failed: %s carries no embedded character" % path.get_file())
			return
	else:
		_toast("import failed: unsupported file type .%s" % ext)
		return
	var res: Dictionary = CreatorIOScript.parse_payload(text)
	if not bool(res.get("ok", false)) or res.get("body", null) == null:
		_toast("import failed: not a valid character file")
		return
	_apply_imported(res, "imported")


func _on_image_format_selected(idx: int) -> void:
	_image_format = ["png", "jpg", "webp"][idx]
	_update_image_history_enabled()


## Honestly enable/disable "image + history" for the chosen format: disabled (with a hint)
## if the format genuinely can't carry the metadata. image-only stays available regardless.
func _update_image_history_enabled() -> void:
	if _img_history_btn == null:
		return
	var ok := CreatorIOScript.supports_image_history(_image_format)
	_img_history_btn.disabled = not ok
	_img_history_btn.tooltip_text = "" if ok else "%s cannot carry embedded history — use image-only" % _image_format.to_upper()


## ChatGPT-style pseudo-LINEAR branch nav: render the root→current path top-to-bottom as a
## flat list (NO indentation, NO diagonal). At any node that is a JUNCTION (more than one
## child) show a `‹ i/n ›` selector whose arrows switch which child branch is followed from
## that junction (switch_branch = jump current onto that child's preferred-child leaf).
func _refresh_history_panel() -> void:
	# Autosave on every state change (§6): this is the universal "the current state moved" funnel
	# — every commit AND every navigation (undo/redo/jump/branch/restore) routes through here, so
	# the autosave always reflects the live character. Guarded by _persistence_armed so the
	# build-time + restore-time calls don't clobber a saved character before it loads.
	_autosave()
	if _undo_btn != null:
		_undo_btn.disabled = not _history.can_undo()
	if _redo_btn != null:
		_redo_btn.disabled = not _history.can_redo()
	if _history_list == null:
		return
	for c in _history_list.get_children():
		c.queue_free()
	var path: Array = _history.path_to_current()
	var current := _history.current_id()
	for step_i in path.size():
		var nid := int(path[step_i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		# The node entry (click to jump to it). Marked when it is the current node.
		var marker := "● " if nid == current else "○ "
		var btn := Button.new()
		btn.text = "%s%s" % [marker, _history.label_of(nid)]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		btn.flat = nid != current
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: _jump_to_node(nid))
		row.add_child(btn)

		# Junction selector: `‹ i/n ›` over which child branch is followed from this node.
		if _history.is_junction(nid):
			# The IMMEDIATE child currently followed from this junction: the next node on
			# the path if any, else this junction's preferred immediate child (current sits
			# on the junction itself). sibling_index gives its branch position among siblings.
			var followed := -1
			if step_i + 1 < path.size():
				followed = int(path[step_i + 1])
			else:
				var pref := _history.leaf_following_preferred(nid)
				# Walk pref's ancestry up to the immediate child of nid.
				while pref >= 0 and _history.parent_of(pref) != nid:
					pref = _history.parent_of(pref)
				followed = pref
			var si := _history.sibling_index(followed) if followed >= 0 else {"index": 0, "count": 0}
			var idx := int(si["index"])
			var cnt := int(_history.sibling_index(_history.child_at(nid, 0))["count"])
			var prev := Button.new()
			prev.text = "‹"
			prev.add_theme_font_size_override("font_size", 11)
			prev.disabled = idx <= 0
			prev.pressed.connect(func() -> void: _switch_branch(nid, idx - 1))
			row.add_child(prev)
			var ic := Label.new()
			ic.text = "%d/%d" % [idx + 1, cnt]
			ic.add_theme_font_size_override("font_size", 11)
			row.add_child(ic)
			var nxt := Button.new()
			nxt.text = "›"
			nxt.add_theme_font_size_override("font_size", 11)
			nxt.disabled = idx >= cnt - 1
			nxt.pressed.connect(func() -> void: _switch_branch(nid, idx + 1))
			row.add_child(nxt)

		_history_list.add_child(row)


## Switch the branch followed from a junction and restore the resulting state.
func _switch_branch(junction_id: int, child_index: int) -> void:
	if _history.switch_branch(junction_id, child_index) >= 0:
		_restore_current()


func _build_axis_row(parent: VBoxContainer, field: String, _lo: float, _hi: float,
		step: float, label: String, lo_pole: String, hi_pole: String) -> void:
	# _lo/_hi (the old hard min/max from the axes table) are no longer the slider bounds —
	# the slider's min/max come from the LIVE cap interval (§3.2), set after registration.
	# Row layout (per axis):
	#   [label (110)] [lo-pole (54)] [slider (expand)] [hi-pole (54)] [value (46)]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(name_lbl)

	var lo_lbl := Label.new()
	lo_lbl.text = lo_pole
	lo_lbl.custom_minimum_size = Vector2(54, 0)
	lo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lo_lbl.add_theme_font_size_override("font_size", 10)
	row.add_child(lo_lbl)

	var slider := HSlider.new()
	# Slider bounds reflect the LIVE cap interval (§3.2), not the hard registry range. The
	# step is kept; the cap interval is set after the slider is registered (below).
	slider.step = step
	slider.value = float(_body_state.get(field))
	slider.custom_minimum_size = Vector2(100, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# value_changed fires continuously during a drag: update the live morph each
	# frame (so the body tracks the slider) but DEBOUNCE the history commit. We
	# commit one node only when the value SETTLES — on drag-end (drag_ended) or,
	# for keyboard/click steps that don't drag, on the value_changed itself when no
	# drag is in progress. The write routes through the apply_capped choke (§3.2 path 3):
	# the requested v is clamped to the headline axis's allowed interval; the clamped
	# `new` is written back to the thumb + label via set_value_no_signal (no re-entry).
	slider.value_changed.connect(func(v: float) -> void:
		if _restoring:
			return   # raw restore is rewriting widgets; ignore the clamp-emitted callback
		var one_write := not bool(_drag_pending.get(field, false))
		if one_write:
			_caps.start_gesture()
		var cur := float(_body_state.get(field))
		var nv: float = _caps.apply_capped(field, v, cur)
		_body_state.set(field, nv)
		_apply_state()
		_write_back_axis_widget(field, slider, nv)
		if one_write:
			_caps.end_gesture()
			_apply_axis_slider_bounds(field, slider)
		if one_write and not _suspend_commit:
			_commit_axis(field, nv)
	)
	slider.drag_started.connect(func() -> void:
		_drag_pending[field] = true
		_caps.start_gesture()
	)
	slider.drag_ended.connect(func(value_changed: bool) -> void:
		_drag_pending[field] = false
		_caps.end_gesture()
		_apply_axis_slider_bounds(field, slider)
		if value_changed and not _suspend_commit:
			_commit_axis(field, float(_sliders[field].value))
	)
	row.add_child(slider)
	_sliders[field] = slider
	# Drive the slider's min/max from the live cap interval (held-aware, but at build time
	# there is no active gesture, so this is the settled-value interval). Widened to contain
	# the current value so the value write above is in range (§3.2 step 4 ordering).
	_apply_axis_slider_bounds(field, slider)

	var hi_lbl := Label.new()
	hi_lbl.text = hi_pole
	hi_lbl.custom_minimum_size = Vector2(54, 0)
	hi_lbl.add_theme_font_size_override("font_size", 10)
	row.add_child(hi_lbl)

	var value_lbl := Label.new()
	value_lbl.custom_minimum_size = Vector2(46, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.text = _format_value(field)
	row.add_child(value_lbl)
	_value_labels[field] = value_lbl

	# NUMERIC ENTRY (§2.3 / §4.3): a SpinBox in NATURAL UNITS (age yr / height cm / %; the same
	# units _format_value shows). Editing routes the request through the apply_capped choke and
	# re-displays the CLAMPED stored value, so an out-of-cap entry visibly clamps at the field.
	var spin := SpinBox.new()
	spin.min_value = _lo
	spin.max_value = _hi
	spin.step = step
	spin.custom_minimum_size = Vector2(64, 0)
	spin.add_theme_font_size_override("font_size", 10)
	spin.set_value_no_signal(float(_body_state.get(field)))
	spin.value_changed.connect(func(v: float) -> void:
		if _restoring:
			return
		_caps.start_gesture()
		var cur := float(_body_state.get(field))
		var nv: float = _caps.apply_capped(field, v, cur)
		_body_state.set(field, nv)
		_apply_state()
		_write_back_axis_widget(field, slider, nv)
		_caps.end_gesture()
		_apply_axis_slider_bounds(field, slider)
		if not _suspend_commit:
			_commit_axis(field, nv))
	row.add_child(spin)
	_axis_spins[field] = spin

	# Per-axis RESET (↺) + RANDOMIZE (⚄) (§2.3).
	var rst := Button.new()
	rst.text = "↺"
	rst.tooltip_text = "Reset %s to neutral" % label
	rst.custom_minimum_size = Vector2(22, 0)
	rst.add_theme_font_size_override("font_size", 10)
	rst.pressed.connect(func() -> void: _reset_axis(field))
	row.add_child(rst)

	var rnd := Button.new()
	rnd.text = "⚄"
	rnd.tooltip_text = "Randomize %s (within current extremeness)" % label
	rnd.custom_minimum_size = Vector2(22, 0)
	rnd.add_theme_font_size_override("font_size", 10)
	rnd.pressed.connect(func() -> void: _randomize_axis(field))
	row.add_child(rnd)

	parent.add_child(row)


# ---------------------------------------------------------------------------
# DATA-DRIVEN per-region detail sliders (RegionSliders). A scrollable corner panel
# (TOP-RIGHT, under the undo/redo icons) with one collapsible group per body region and
# one slider per RegionSliders spec. Each slider writes BodyState.modifiers[<full_name>]
# (signed [-1,1] for bidirectional axes, [0,1] for unipolar) and re-bakes the morph LIVE
# through the SAME BodyState→registry→DetailLibrary path the macro axes and drag-to-modify
# use. Pure DATA: the panel is generated from the RegionSliders table, never hand-listed.
# ---------------------------------------------------------------------------
func _build_region_sliders_panel(canvas: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-16, 64)   # below the undo/redo corner icons
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(320, 0)
	canvas.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	panel.add_child(outer)

	var hdr := Label.new()
	hdr.text = "body regions — detail sliders"
	outer.add_child(hdr)

	# Scroll so the deep table never overruns the screen.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	# T2 CURATED DETAIL (SYNTHESIS §2.2): a curated subset of the region groups (high-impact,
	# low-footgun). Revealed at tier >= T2. The remaining groups (the full registry tree) live
	# in the T3 section below — a monotone reveal: T3 shows T2's groups PLUS the rest.
	var t2 := VBoxContainer.new()
	t2.add_theme_constant_override("separation", 2)
	_t2_section = t2
	list.add_child(t2)
	var t2_hdr := Label.new()
	t2_hdr.text = "T2 — curated detail"
	t2_hdr.add_theme_font_size_override("font_size", 10)
	t2.add_child(t2_hdr)

	# T3 FULL REGISTRY TREE (SYNTHESIS §2.2): every remaining region group (the long tail of
	# the registry). Revealed at tier == T3. Sculpt + extremeness live in the main-panel T3
	# section; this is the full slider tree.
	var t3 := VBoxContainer.new()
	t3.add_theme_constant_override("separation", 2)
	_t3_section = t3
	list.add_child(t3)
	var t3_hdr := Label.new()
	t3_hdr.text = "T3 — full registry tree"
	t3_hdr.add_theme_font_size_override("font_size", 10)
	t3.add_child(t3_hdr)

	for grp in RegionSlidersScript.GROUPS:
		var group_label: String = grp[0]
		var dest: VBoxContainer = t2 if T2_GROUPS.has(group_label) else t3
		# Collapsible region group: a header button that toggles its contents.
		var group_box := VBoxContainer.new()
		group_box.add_theme_constant_override("separation", 1)
		var contents := VBoxContainer.new()
		contents.add_theme_constant_override("separation", 1)
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.button_pressed = true
		toggle.text = "▾ %s" % group_label
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.toggled.connect(func(on: bool) -> void:
			contents.visible = on
			toggle.text = "%s %s" % ["▾" if on else "▸", group_label])
		group_box.add_child(toggle)
		for spec in grp[1]:
			_build_modifier_row(contents, spec[0], spec[1], spec[2], spec[3])
		group_box.add_child(contents)
		dest.add_child(group_box)
		dest.add_child(HSeparator.new())


## One detail-slider row, bound to a RegionSliders spec. The slider's range/default come from
## the modifier KIND (bidirectional → [-1,1] @ 0; unipolar → [0,1] @ 0). value_changed writes
## EVERY resolved full_name (a bilateral stem drives both L/R) into BodyState.modifiers and
## re-bakes; history is committed once on drag-end (or immediately for a click/keyboard step).
func _build_modifier_row(parent: VBoxContainer, spec_name: String, display: String,
		lo_pole: String, hi_pole: String) -> void:
	var full_names := RegionSlidersScript.resolve_full_names(spec_name)
	# Kind/range from the registry (first resolved modifier; a bilateral pair shares a kind).
	var reg := BodyState.registry()
	var by: Dictionary = reg.get("by_full_name", {})
	var kind := RegionSlidersScript.KIND_BIDIRECTIONAL
	if full_names.size() > 0 and by.has(full_names[0]):
		kind = String(by[full_names[0]]["kind"])
	# Slider min/max are no longer the static hard range — they come from the LIVE cap
	# interval via _apply_modifier_slider_bounds after the slider is registered (§3.2).

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var name_lbl := Label.new()
	name_lbl.text = display
	name_lbl.custom_minimum_size = Vector2(94, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(name_lbl)

	var lo_lbl := Label.new()
	lo_lbl.text = lo_pole
	lo_lbl.custom_minimum_size = Vector2(44, 0)
	lo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lo_lbl.add_theme_font_size_override("font_size", 9)
	row.add_child(lo_lbl)

	var slider := HSlider.new()
	slider.step = RegionSlidersScript.STEP
	slider.value = float(_body_state.modifiers.get(full_names[0], 0.0))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(70, 0)
	# The write routes through the apply_capped choke for EVERY resolved full_name (§3.2
	# path 2). A bilateral stem drives L+R: each side caps against its OWN cur; the single
	# thumb's value write-back uses the clamped result for full_names[0]. Bounds reflect the
	# CONSERVATIVE intersection of the resolved sides (§3.2 step 4, MI14-1).
	slider.value_changed.connect(func(v: float) -> void:
		if _restoring:
			return   # raw restore is rewriting widgets; ignore the clamp-emitted callback
		var one_write := not bool(_drag_pending.get(spec_name, false))
		if one_write:
			_caps.start_gesture()
		var primary := _set_modifier_capped(full_names, v)
		_apply_state()
		_write_back_modifier_widget(spec_name, slider, primary)
		if one_write:
			_caps.end_gesture()
			_apply_modifier_slider_bounds(spec_name)
		if one_write and not _suspend_commit:
			_commit_modifier(spec_name, display, primary))
	slider.drag_started.connect(func() -> void:
		_drag_pending[spec_name] = true
		_caps.start_gesture())
	slider.drag_ended.connect(func(changed: bool) -> void:
		_drag_pending[spec_name] = false
		_caps.end_gesture()
		_apply_modifier_slider_bounds(spec_name)
		if changed and not _suspend_commit:
			_commit_modifier(spec_name, display, float(slider.value)))
	row.add_child(slider)

	var hi_lbl := Label.new()
	hi_lbl.text = hi_pole
	hi_lbl.custom_minimum_size = Vector2(44, 0)
	hi_lbl.add_theme_font_size_override("font_size", 9)
	row.add_child(hi_lbl)

	# NUMERIC ENTRY (SYNTHESIS §2.3 / §4.3): a SpinBox bound to the SAME value, DISPLAY-REMAPPED
	# (bidirectional [-1,1] → ±100; unipolar [0,1] → 0..100). Editing it routes the un-remapped
	# request through the apply_capped choke and re-displays the CLAMPED stored value (so an
	# out-of-cap entry visibly clamps). This is BOTH the value display and the typeable field —
	# the old static label is gone.
	var is_bidir := kind == RegionSlidersScript.KIND_BIDIRECTIONAL
	var spin := SpinBox.new()
	spin.min_value = -100.0 if is_bidir else 0.0
	spin.max_value = 100.0
	spin.step = 1.0
	spin.custom_minimum_size = Vector2(56, 0)
	spin.add_theme_font_size_override("font_size", 10)
	spin.set_value_no_signal(_modifier_to_display(float(slider.value), is_bidir))
	spin.value_changed.connect(func(disp: float) -> void:
		if _restoring:
			return
		# A numeric commit is a one-write gesture through the choke (§4.3 path 4).
		_caps.start_gesture()
		var req := _display_to_modifier(disp, is_bidir)
		var primary := _set_modifier_capped(full_names, req)
		_apply_state()
		_write_back_modifier_widget(spec_name, slider, primary)
		_caps.end_gesture()
		_apply_modifier_slider_bounds(spec_name)
		if not _suspend_commit:
			_commit_modifier(spec_name, display, primary))
	row.add_child(spin)

	# Per-control RESET (↺, raw to neutral) + RANDOMIZE (⚄, seeded, within cap) buttons (§2.3).
	var rst := Button.new()
	rst.text = "↺"
	rst.tooltip_text = "Reset %s to neutral" % display
	rst.custom_minimum_size = Vector2(22, 0)
	rst.add_theme_font_size_override("font_size", 10)
	rst.pressed.connect(func() -> void: _reset_modifier(spec_name, display))
	row.add_child(rst)

	var rnd := Button.new()
	rnd.text = "⚄"
	rnd.tooltip_text = "Randomize %s (within current extremeness)" % display
	rnd.custom_minimum_size = Vector2(22, 0)
	rnd.add_theme_font_size_override("font_size", 10)
	rnd.pressed.connect(func() -> void: _randomize_modifier(spec_name, display))
	row.add_child(rnd)

	_modifier_sliders[spec_name] = {
		"slider": slider, "spin": spin, "is_bidir": is_bidir,
		"full_names": full_names, "kind": kind, "display": display,
	}
	parent.add_child(row)
	# Drive the slider's min/max from the live cap interval (conservative intersection of
	# the resolved sides). No active gesture at build time → settled-value interval.
	_apply_modifier_slider_bounds(spec_name)


## Write `v` into BodyState.modifiers for every resolved full_name (clearing near-zero so a
## neutral body stays a tiny dict — matching the drag path's housekeeping). RAW write, used
## by restore/load paths only; live edits go through _set_modifier_capped.
func _set_modifier(full_names: PackedStringArray, v: float) -> void:
	for fn in full_names:
		if absf(v) < 1e-6:
			_body_state.modifiers.erase(fn)
		else:
			_body_state.modifiers[fn] = v


## CAPPED region-slider write (§3.2 path 2): route every resolved full_name through the
## apply_capped choke against ITS OWN current value (so an asymmetric/ratcheted L/R side
## caps independently), then store via the same erase-at-neutral housekeeping. Returns the
## clamped value of the PRIMARY (first) resolved name — what the single thumb displays.
##
## MIRROR (decision §2.3): when mirror is ON, each resolved name's contralateral twin(M) is
## ALSO written (capped against ITS OWN cur), so a lateral edit stays symmetric. The midline
## guard (twin(M) == M) and the already-resolved guard keep midline + bare-bilateral-stem
## sliders writing each modifier exactly once. The mirrored write IS just another apply_capped
## call (the choke captures the twin's held interval per the gesture-capture invariant).
func _set_modifier_capped(full_names: PackedStringArray, req: float) -> float:
	var primary := req
	var targets := _mirror_targets(full_names)
	for i in targets.size():
		var fn: String = targets[i]
		var cur := float(_body_state.modifiers.get(fn, 0.0))
		var nv: float = _caps.apply_capped(fn, req, cur)
		if absf(nv) < 1e-6:
			_body_state.modifiers.erase(fn)
		else:
			_body_state.modifiers[fn] = nv
		# The PRIMARY (thumb-displayed) value is the first RESOLVED name (targets[0] is always
		# full_names[0]; appended twins follow), so this only fires for the primary.
		if fn == full_names[0]:
			primary = nv
	return primary


## The full set of modifier names a write should touch: the resolved names, plus — when MIRROR
## is ON — each resolved name's contralateral twin(M) (added once, only when twin(M) != M and not
## already resolved). Mirror OFF, or all-midline names, returns the resolved set unchanged.
## Resolution (resolve_full_names) is structural and mirror-INDEPENDENT; this only ADDS the
## contralateral application the toggle governs.
func _mirror_targets(full_names: PackedStringArray) -> PackedStringArray:
	var targets := PackedStringArray(full_names)
	if not _mirror:
		return targets
	for fn in full_names:
		var tw := RegionSlidersScript.twin(fn)
		if tw != fn and not targets.has(tw):
			targets.append(tw)
	return targets


## Set a region slider's bounds to its live cap interval — the CONSERVATIVE intersection of
## the resolved sides (held during a gesture, settled-value otherwise; §3.2 step 4 / MI14-1).
func _apply_modifier_slider_bounds(spec_name: String) -> void:
	var e = _modifier_sliders.get(spec_name, null)
	if e == null:
		return
	var slider := e["slider"] as HSlider
	var full_names := e["full_names"] as PackedStringArray
	var lo := -INF
	var hi := INF
	for fn in full_names:
		var iv: Array
		if _caps.has_held(fn):
			iv = _caps.held_interval(fn)
		else:
			var cur := float(_body_state.modifiers.get(fn, 0.0))
			var ci: Array = _caps.cap(fn)
			iv = [minf(float(ci[0]), cur), maxf(float(ci[1]), cur)]
		lo = maxf(lo, float(iv[0]))   # conservative intersection: tightest floor
		hi = minf(hi, float(iv[1]))   # conservative intersection: tightest ceiling
	# Bounds-FIRST (widened to contain the value), so the value write can't clamp-and-emit.
	slider.min_value = lo
	slider.max_value = hi


## Recompute EVERY region slider's bounds from the settled values (gesture-end / load).
func _recompute_modifier_slider_bounds() -> void:
	for spec_name in _modifier_sliders:
		_apply_modifier_slider_bounds(spec_name)


## Write the clamped `new` back to a region slider's thumb (no-signal) + numeric SpinBox
## WITHOUT re-firing value_changed (§3.2 step 4): bounds-first, then set_value_no_signal on
## both widgets, so the SpinBox shows the CLAMPED stored value (remapped), never the request.
func _write_back_modifier_widget(spec_name: String, slider: HSlider, new_value: float) -> void:
	_apply_modifier_slider_bounds(spec_name)
	slider.set_value_no_signal(new_value)
	var e = _modifier_sliders.get(spec_name, null)
	if e != null:
		(e["spin"] as SpinBox).set_value_no_signal(_modifier_to_display(new_value, bool(e["is_bidir"])))


## Set a headline-axis slider's bounds to its live cap interval (held during a gesture,
## settled-value otherwise; §3.2 step 4).
func _apply_axis_slider_bounds(field: String, slider: HSlider) -> void:
	var iv: Array
	if _caps.has_held(field):
		iv = _caps.held_interval(field)
	else:
		var cur := float(_body_state.get(field))
		var ci: Array = _caps.cap(field)
		iv = [minf(float(ci[0]), cur), maxf(float(ci[1]), cur)]
	slider.min_value = float(iv[0])
	slider.max_value = float(iv[1])


## Write the clamped `new` back to a headline slider's thumb (no-signal) + numeric label
## WITHOUT re-firing value_changed (§3.2 step 4): bounds-first, then set_value_no_signal,
## then the label reads the clamped value.
func _write_back_axis_widget(field: String, slider: HSlider, new_value: float) -> void:
	_apply_axis_slider_bounds(field, slider)
	slider.set_value_no_signal(new_value)
	var lbl = _value_labels.get(field, null)
	if lbl != null:
		(lbl as Label).text = _format_value(field)
	var spin = _axis_spins.get(field, null)
	if spin != null:
		(spin as SpinBox).set_value_no_signal(new_value)


## Sync a single modifier's bound region slider to a clamped sculpt-driven value WITHOUT
## re-firing its value_changed (§3.2 path 1 sculpt→slider sync, B10-1). No-op if the
## modifier is not bound to a curated region slider (the uncurated-sculpt case).
func _sync_modifier_slider(full_name: String, new_value: float) -> void:
	for spec_name in _modifier_sliders:
		var e = _modifier_sliders[spec_name]
		var fns := e["full_names"] as PackedStringArray
		if fns.has(full_name):
			_write_back_modifier_widget(spec_name, e["slider"] as HSlider, new_value)
			return


## Display-remap helpers (§2.3 numeric entry): modifier stored value ↔ the typed/shown number.
## Bidirectional [-1,1] ↔ ±100; unipolar [0,1] ↔ 0..100.
func _modifier_to_display(stored: float, is_bidir: bool) -> float:
	return stored * 100.0 if is_bidir else stored * 100.0


func _display_to_modifier(disp: float, _is_bidir: bool) -> float:
	return disp / 100.0


## Re-bake ARRAY_TANGENT on the morphed body at a morph COMMIT (§6.1 creator-body
## decision). The live drag/slider path (_apply_state) bakes positions + normals every
## frame but NOT tangents (a per-frame tangent rebake over 14,517 verts is too costly), so
## ARRAY_TANGENT would otherwise keep the neutral-base basis and a tangent-space skin
## detail-normal would shear under the morph. Called from every commit funnel
## (_commit_modifier / _commit_axis / _end_morph_drag) — drag release / settled slider /
## numeric / committed sculpt — so the committed surface carries a morph-correct tangent
## basis. During a drag the detail-normal uses pre-commit tangents (slightly off mid-drag,
## snaps correct on release — the user-judged drag-time-look call in §6.1).
func _rebake_tangents_on_commit() -> void:
	if _rig != null and _rig.mesh_instance != null:
		_rig.apply_body_state(_body_state, true)
		# Re-bake changed the rest-space positions → feed the picker the morphed surface (B2).
		_refresh_picker_geometry()


## RESET one region control to neutral (§2.3): a RESTORE-class op (raw write, no re-clamp) —
## abort any active gesture, write neutral (0) to every resolved full_name via the erase-at-
## neutral raw write site, re-sync the widget without re-firing, commit.
func _reset_modifier(spec_name: String, display: String) -> void:
	var e = _modifier_sliders.get(spec_name, null)
	if e == null:
		return
	_caps.abort_gesture()
	var full_names := e["full_names"] as PackedStringArray
	_set_modifier(full_names, 0.0)   # raw to neutral (erases the keys)
	_apply_state()
	# Raw widget write-back (recompute bounds from settled, widen to contain 0, no-signal).
	_apply_modifier_slider_bounds(spec_name)
	var slider := e["slider"] as HSlider
	slider.min_value = minf(slider.min_value, 0.0)
	slider.max_value = maxf(slider.max_value, 0.0)
	slider.set_value_no_signal(0.0)
	(e["spin"] as SpinBox).set_value_no_signal(0.0)
	if not _suspend_commit:
		_commit_modifier(spec_name, display, 0.0)


## RANDOMIZE one region control (§2.3): a bounded SEEDED sample WITHIN cap(·, extremeness),
## routed through the choke (so it can never exceed the live interval). Deterministic for a
## given seed + spec + extremeness. A one-write gesture.
func _randomize_modifier(spec_name: String, display: String) -> void:
	var e = _modifier_sliders.get(spec_name, null)
	if e == null:
		return
	var full_names := e["full_names"] as PackedStringArray
	var rng := _seeded_rng_for(spec_name)
	_caps.start_gesture()
	# Sample uniformly within the PRIMARY side's current cap interval, then route through the
	# choke (which clamps each resolved side to its own interval — the bilateral case).
	var ci: Array = _caps.cap(full_names[0])
	var req := rng.randf_range(float(ci[0]), float(ci[1]))
	var primary := _set_modifier_capped(full_names, req)
	_apply_state()
	_write_back_modifier_widget(spec_name, e["slider"] as HSlider, primary)
	_caps.end_gesture()
	_apply_modifier_slider_bounds(spec_name)
	if not _suspend_commit:
		_commit_modifier(spec_name, display, primary)


## A DETERMINISTIC RNG for a randomize op: seeded from a global creator seed + the control key
## + a monotonic counter, so a sequence of randomize gestures is reproducible (action-logged,
## SYNTHESIS §2.3 "deterministic + shareable") and independent per control.
func _seeded_rng_for(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d" % [_random_seed, key, _random_counter])
	_random_counter += 1
	return rng


## Commit one settled region-slider change as a history node.
func _commit_modifier(spec_name: String, display: String, value: float) -> void:
	_rebake_tangents_on_commit()
	_history.commit(_body_state.to_dict(), "%s = %+.2f" % [display, value])
	_refresh_history_panel()


## Restore every region slider from the live BodyState.modifiers (called by _restore_current
## after a headline-axis restore). RAW (§3.2 paths 6/7): writes via set_value_no_signal so
## the capped callback never re-fires and a persisted beyond-cap value is NOT re-clamped.
## Bounds are widened to contain the raw value first, so the no-signal write is in range.
func _restore_modifier_sliders() -> void:
	for spec_name in _modifier_sliders:
		var e = _modifier_sliders[spec_name]
		var fn := (e["full_names"] as PackedStringArray)[0]
		var v := float(_body_state.modifiers.get(fn, 0.0))
		var slider := e["slider"] as HSlider
		# Recompute bounds from the (now restored) settled values, then widen to contain v.
		_apply_modifier_slider_bounds(spec_name)
		slider.min_value = minf(slider.min_value, v)
		slider.max_value = maxf(slider.max_value, v)
		slider.set_value_no_signal(v)
		(e["spin"] as SpinBox).set_value_no_signal(_modifier_to_display(v, bool(e["is_bidir"])))


func _format_value(field: String) -> String:
	var v := float(_body_state.get(field))
	match field:
		"age_years":
			# Floor display only — the stored value and gate stay continuous.
			return "%d" % int(floor(v))
		"height_cm":
			return "%dcm" % int(round(v))
		"masculinity", "muscle", "weight":
			return "%.0f%%" % v
		_:
			return "%.2f" % v


## Project the current BodyState onto the body's blendshapes and refresh labels.
## After driving the GPU blendshape weights (which morph POSITIONS), recompute the
## per-vertex NORMALS on the CPU for the new morph and bake them into this viewer's
## per-instance mesh copy. Godot 4 stores blendshape normals octahedral-compressed,
## which cannot carry normal deltas, so the GPU morph alone leaves stale normals that
## light the morphed surface wrongly (blotches / inside-out). The CPU bake fixes that
## (BodyState.bake_morphed_normals). Only runs on slider changes, so it's cheap.
func _apply_state() -> void:
	if _rig != null and _rig.mesh_instance != null:
		# Route through the rig's correct-normals CPU morph bake (the same path the
		# in-game skinned body uses). Godot's octahedral blendshape-normal storage can't
		# carry normal deltas, so a GPU-only morph is mis-lit (see BodyState/BodyRig).
		_rig.apply_body_state(_body_state)
		# The rest-space baked positions just changed → both the CPU pick grid AND the glow
		# overlay are stale. Mark the glow dirty so its next rebuild re-fetches the morphed
		# positions+normals (§2.3 / §6.6), and FEED the picker the SAME morphed surface so its
		# next lazy rebuild raycasts the morphed body — NOT its stale neutral source cache
		# (B2 correctness: a bare mark_dirty() would re-grid the build-time neutral positions).
		_glow_geom_dirty = true
		_refresh_picker_geometry()
	for field in _value_labels:
		(_value_labels[field] as Label).text = _format_value(field)
	for field in _axis_spins:
		(_axis_spins[field] as SpinBox).set_value_no_signal(float(_body_state.get(field)))


## RESET-TO-NEUTRAL: branch from the ROOT (HistoryTree.reset_to), and be IDEMPOTENT — a
## neutral branch off root is REUSED if it already exists, so repeated resets never accrete
## duplicate empty branches. The body + sliders are then restored from the (new or reused)
## neutral node.
func _reset_all() -> void:
	var neutral := BodyState.new()
	_history.reset_to(neutral.to_dict(), "reset to neutral")
	_restore_current()


## RESET one headline axis to its neutral (§2.3): a RESTORE-class raw write (abort gesture,
## set the field neutral, no-signal widget write-back, commit).
func _reset_axis(field: String) -> void:
	_caps.abort_gesture()
	var neutral := float(_caps.neutral_of(field))
	_body_state.set(field, neutral)
	_apply_state()
	var slider := _sliders[field] as HSlider
	_apply_axis_slider_bounds(field, slider)
	slider.min_value = minf(slider.min_value, neutral)
	slider.max_value = maxf(slider.max_value, neutral)
	slider.set_value_no_signal(neutral)
	var lbl = _value_labels.get(field, null)
	if lbl != null:
		(lbl as Label).text = _format_value(field)
	var spin = _axis_spins.get(field, null)
	if spin != null:
		(spin as SpinBox).set_value_no_signal(neutral)
	if not _suspend_commit:
		_commit_axis(field, neutral)


## RANDOMIZE one headline axis (§2.3): a bounded SEEDED sample WITHIN cap(field, extremeness),
## through the choke (deterministic for a given seed + field + extremeness).
func _randomize_axis(field: String) -> void:
	var rng := _seeded_rng_for(field)
	_caps.start_gesture()
	var ci: Array = _caps.cap(field)
	var req := rng.randf_range(float(ci[0]), float(ci[1]))
	var cur := float(_body_state.get(field))
	var nv: float = _caps.apply_capped(field, req, cur)
	_body_state.set(field, nv)
	_apply_state()
	var slider := _sliders[field] as HSlider
	_write_back_axis_widget(field, slider, nv)
	_caps.end_gesture()
	_apply_axis_slider_bounds(field, slider)
	if not _suspend_commit:
		_commit_axis(field, nv)


## SET the global extremeness (§4 / §6): a STATE-REPLACING op — abort any active gesture
## FIRST (gesture-lifecycle-interruption invariant), set the scalar, then sweep EVERY control's
## widget bounds (each interval widens/narrows with extremeness). NON-DESTRUCTIVE: stored values
## are NOT touched, so a beyond-cap value set at higher extremeness persists when it is lowered.
func _set_extremeness(e: float) -> void:
	_caps.abort_gesture()
	_caps.extremeness = clampf(e, 0.0, 1.0)
	# Keep the two widgets + readout in sync without re-firing each other.
	if _extreme_slider != null:
		_extreme_slider.set_value_no_signal(_caps.extremeness)
	if _extreme_check != null:
		_extreme_check.set_pressed_no_signal(_caps.extremeness > 0.0)
	if _extreme_lbl != null:
		_extreme_lbl.text = "%.0f%%" % (_caps.extremeness * 100.0)
	# All-controls bounds sweep: every slider's reachable range now reflects the new extremeness
	# (widened to still contain the current stored value, so nothing snaps).
	for field in _sliders:
		_apply_axis_slider_bounds(field, _sliders[field] as HSlider)
	_recompute_modifier_slider_bounds()


## GLOBAL randomize (§2.3): randomize every headline axis and region control within the live
## cap, deterministically. Suspends per-control commits and records ONE history node for the
## whole gesture, so a global randomize is a single undoable step.
func _randomize_all() -> void:
	_suspend_commit = true
	for field in _sliders:
		_randomize_axis(field)
	for spec_name in _modifier_sliders:
		var e = _modifier_sliders[spec_name]
		_randomize_modifier(spec_name, String(e["display"]))
	_suspend_commit = false
	_rebake_tangents_on_commit()
	_history.commit(_body_state.to_dict(), "randomize all")
	_refresh_history_panel()


# ---------------------------------------------------------------------------
# History actions
# ---------------------------------------------------------------------------

## Commit the current BodyState as a new history node, labelled by the axis change.
func _commit_axis(field: String, value: float, override_label: String = "") -> void:
	var label := override_label
	if label == "":
		label = "%s = %s" % [field, _format_value(field)]
	_rebake_tangents_on_commit()
	_history.commit(_body_state.to_dict(), label)
	_refresh_history_panel()


func _do_undo() -> void:
	if _history.undo():
		_restore_current()


func _do_redo() -> void:
	if _history.redo():
		_restore_current()


func _jump_to_node(id: int) -> void:
	if _history.jump_to(id):
		_restore_current()


## Apply a parsed import/restore payload ({ body: BodyState, tree: HistoryTree-or-null,
## extremeness: float }) onto the live creator. The single funnel for BOTH the Import button
## and the autosave restore (§6). RAW (paths 7 / 7-import): aborts any active gesture, replaces
## the history tree (or seeds a fresh one from the body when the payload carried no history),
## restores the global extremeness, then restores the body + widgets via _restore_current
## (no re-clamp → a beyond-cap value persists). `verb` labels the transient toast.
func _apply_imported(res: Dictionary, verb: String) -> void:
	var body: BodyState = res.get("body", null)
	if body == null:
		return
	# Gesture-lifecycle-interruption invariant (§3.2): a load is a state-replacing op — abort any
	# in-flight gesture and clear sculpt accumulators BEFORE replacing the model underneath it.
	_caps.abort_gesture()
	_dragging_morph = false
	_drag_accum = {}
	_drag_vertex = -1
	# Restore the global extremeness FIRST so the bounds sweep in _restore_current uses the
	# loaded cap envelope. Set the scalar directly (not via _set_extremeness, which aborts the
	# gesture again + sweeps before the body is loaded); the widgets sync below.
	_caps.extremeness = clampf(float(res.get("extremeness", 0.0)), 0.0, 1.0)
	if _extreme_slider != null:
		_extreme_slider.set_value_no_signal(_caps.extremeness)
	if _extreme_check != null:
		_extreme_check.set_pressed_no_signal(_caps.extremeness > 0.0)
	if _extreme_lbl != null:
		_extreme_lbl.text = "%.0f%%" % (_caps.extremeness * 100.0)
	# Replace the history tree: a with-history payload carries the whole branching tree; a
	# current-only payload seeds a fresh single-node tree from the body (so undo still works).
	var tree = res.get("tree", null)
	if tree != null:
		_history = tree
	else:
		_history = HistoryTreeScript.new(body.to_dict(), verb)
	# _restore_current reads the tree's CURRENT node and writes it raw onto the body + widgets.
	_restore_current()
	_refresh_history_panel()
	_toast("%s character" % verb)


## Autosave the current character to the CharacterAutosave store (cross-scene + restart, §6).
## Called on every committed change funnel and on _exit_tree. Serializes BodyState + the whole
## HistoryTree + the global extremeness (RAW). Cheap; the store mirrors to user://.
func _autosave() -> void:
	if not _persistence_armed:
		return
	var store := get_node_or_null("/root/CharacterAutosave")
	if store != null:
		store.save(_body_state, _history, _caps.extremeness)


## On scene free (the launcher frees this mode on a tab switch, and the app frees it on close),
## persist the final character so re-entering the creator restores it (§6).
func _exit_tree() -> void:
	_autosave()


## Apply the history's current node state onto the body + sliders WITHOUT committing.
## A RAW restore/load (§3.2 paths 6/7) — it BYPASSES the choke (set_value_no_signal, no
## re-clamp, beyond-cap persists) AND, per the gesture-lifecycle-interruption invariant
## (§3.2), ABORTS any active gesture FIRST so no held cur_start references the stale model.
func _restore_current() -> void:
	var d = _history.current_state()
	if typeof(d) != TYPE_DICTIONARY:
		return
	# Gesture-lifecycle-interruption invariant: abort any in-flight gesture before replacing
	# the model underneath it (also clears the sculpt brackets/accumulators).
	_caps.abort_gesture()
	_dragging_morph = false
	_drag_accum = {}
	_drag_vertex = -1
	var bs := BodyState.from_dict(d)
	_suspend_commit = true
	# Raw-restore guard (§3.2 paths 6/7): tightening a slider's bounds below its prior value makes
	# Godot's Range clamp-and-EMIT value_changed; _restoring makes the live callback a no-op so the
	# emit can't write a stepped value into the model. The restore writes the model itself, raw.
	_restoring = true
	for field in _sliders:
		var v := float(bs.get(field))
		_body_state.set(field, v)
		var slider := _sliders[field] as HSlider
		# Bounds first (recompute, then widen to contain the raw v), then no-signal write so
		# the capped callback never re-fires and a beyond-cap headline value persists.
		_apply_axis_slider_bounds(field, slider)
		slider.min_value = minf(slider.min_value, v)
		slider.max_value = maxf(slider.max_value, v)
		slider.set_value_no_signal(v)
		var lbl = _value_labels.get(field, null)
		if lbl != null:
			(lbl as Label).text = _format_value(field)
	# The detail envelope is a whole-map replacement (restored dict's modifiers), then the
	# region sliders re-sync to it. Replace the live map so cleared modifiers actually clear.
	_body_state.modifiers = bs.modifiers.duplicate()
	_restore_modifier_sliders()
	_restoring = false
	_suspend_commit = false
	_apply_state()
	_refresh_history_panel()


# ---------------------------------------------------------------------------
# Export — INDIVIDUAL actions (JSON / JSON+history / image / image+history), the image
# in the user-chosen format (PNG / JPG / WEBP). image+history embeds the history JSON via
# the format's metadata carrier (ImageMetadata); the button is disabled for any format
# that can't carry it. A transient toast (_status_lbl) reports the result — no path text.
# ---------------------------------------------------------------------------

func _toast(msg: String) -> void:
	if _status_lbl != null:
		_status_lbl.text = msg
	print("[creator] ", msg)


func _export_basename() -> String:
	var stamp := str(Time.get_unix_time_from_system()).replace(".", "")
	return "creator_%s" % stamp


## Export JSON — current-only or with the full history tree embedded.
func _export_json(with_history: bool) -> void:
	CreatorIOScript.ensure_export_dir()
	var base := _export_basename()
	if with_history:
		var path := "%s/%s.history.json" % [CreatorIOScript.EXPORT_DIR, base]
		_write_text(path, CreatorIOScript.history_to_json(_body_state, _history, _caps.extremeness))
		_toast("exported JSON + history")
	else:
		var path := "%s/%s.json" % [CreatorIOScript.EXPORT_DIR, base]
		_write_text(path, CreatorIOScript.body_to_json(_body_state, _caps.extremeness))
		_toast("exported JSON (current)")


## Export an image in the chosen format — optionally with the history JSON embedded via the
## format's metadata carrier. Honors the disabled state for formats that can't carry it.
func _export_image(with_history: bool) -> void:
	if with_history and not CreatorIOScript.supports_image_history(_image_format):
		_toast("%s cannot carry history — use image-only" % _image_format.to_upper())
		return
	var img := await _capture_image()
	if img == null:
		_toast("image capture failed")
		return
	CreatorIOScript.ensure_export_dir()
	var base := _export_basename()
	var bytes := CreatorIOScript.encode_image(img, _image_format)
	if bytes.is_empty():
		_toast("image encode failed (%s)" % _image_format.to_upper())
		return
	var suffix := ".history" if with_history else ""
	if with_history:
		bytes = CreatorIOScript.embed_history_in_image(bytes, _image_format,
			CreatorIOScript.history_to_json(_body_state, _history, _caps.extremeness))
	var path := "%s/%s%s.%s" % [CreatorIOScript.EXPORT_DIR, base, suffix, _image_format]
	_write_bytes(path, bytes)
	_toast("exported %s%s" % [_image_format.to_upper(), " + history" if with_history else ""])


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()


## Render the 3D body to an Image, excluding the UI overlay. The UI lives on CanvasLayers,
## so we hide them for one frame, grab the viewport image, then restore them.
func _capture_image() -> Image:
	var vp := get_viewport()
	var canvases: Array = []
	for c in get_children():
		if c is CanvasLayer:
			canvases.append(c)
			(c as CanvasLayer).visible = false
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	for c in canvases:
		(c as CanvasLayer).visible = true
	return img
