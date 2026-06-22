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
# Orbit camera tuning. The camera orbits a pivot (the body's torso height) at a
# yaw/pitch/distance the mouse drives. 1u = 1m (units-and-scale.md).
# ---------------------------------------------------------------------------
const MIN_PITCH := deg_to_rad(-85.0)
const MAX_PITCH := deg_to_rad(85.0)
const MIN_DIST := 0.35       ## metres — close enough for a face inspection
const MAX_DIST := 8.0
const ORBIT_SPEED := 0.0075  ## radians per pixel of mouse drag
const ZOOM_STEP := 0.88      ## multiplicative zoom per scroll notch
const PAN_SPEED := 0.0025    ## metres per pixel of right-drag pan

var _rig: BodyRig
var _body_state: BodyState = BodyState.new()

var _camera: Camera3D
var _pivot: Vector3 = Vector3(0.0, 0.95, 0.0)   ## orbit target (torso height)
var _yaw: float = PI           ## radians; PI = camera in front of the body (the
                               ## MakeHuman base faces -Z, so the camera sits on -Z)
var _pitch: float = deg_to_rad(-8.0)             ## slightly above
var _distance: float = 3.2     ## metres

var _dragging_orbit: bool = false
var _dragging_pan: bool = false

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
var _sculpt_btn: Button

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
var _glow_tris: PackedInt32Array         ## the body's triangle index list (for pick + overlay)
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

## DATA-DRIVEN per-region detail sliders (RegionSliders). Kept SEPARATE from `_sliders`
## (the headline-axis dials) because these write BodyState.modifiers[<full_name>] rather
## than a BodyState field. spec_name -> { slider, value_lbl, full_names:PackedStringArray,
## kind:String }. Restored from state via _restore_modifier_sliders.
var _modifier_sliders: Dictionary = {}

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

var _history: HistoryTree
## Per-axis pending value during a slider drag — committed once on drag-end so we
## record ONE node per settled change, not one per pixel.
var _drag_pending: Dictionary = {}   ## field -> bool (a drag is in progress)
var _suspend_commit: bool = false    ## true while applying a restored state (no commit)

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


func _ready() -> void:
	_history = HistoryTreeScript.new(_body_state.to_dict(), "initial")
	_build_environment()
	_build_body()
	_build_morph_drag()
	_build_camera()
	_build_ui()
	_update_camera()


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
		_glow_tris = arrays[Mesh.ARRAY_INDEX]
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


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "OrbitCamera"
	_camera.fov = 50.0
	_camera.near = 0.05
	add_child(_camera)


func _update_camera() -> void:
	# Spherical orbit around the pivot. yaw=0,pitch=0 places the camera on +Z
	# (in front of the body, which faces +Z), looking back toward -Z at the body.
	var dir := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch),
	)
	var pos := _pivot + dir * _distance
	_camera.global_position = pos
	_camera.look_at(_pivot, Vector3.UP)


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
	var n := _glow_base_pos.size()
	var colors := PackedColorArray()
	colors.resize(n)
	for i in n:
		var w := float(weights.get(i, 0.0))
		colors[i] = Color(1, 1, 1, w)   # tinted by the material albedo; alpha = glow strength
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _glow_base_pos
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
		var nv := float(_body_state.modifiers.get(full_name, 0.0)) + float(deltas[full_name])
		if absf(nv) < 1e-6:
			_body_state.modifiers.erase(full_name)
		else:
			_body_state.modifiers[full_name] = nv
		_drag_accum[full_name] = float(_drag_accum.get(full_name, 0.0)) + float(deltas[full_name])
	_apply_state()
	# Keep the glow on the active region while dragging (re-pick the vertex's footprint).
	var weights: Dictionary = _morph.glow_weights(_drag_vertex, hit_local, _glow_base_pos)
	_rebuild_glow_mesh(weights)


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
		_sculpt_btn.text = "Sculpt mode: ON (drag body to morph)" if on else "Sculpt mode: OFF (press M)"
	if not on and _glow_overlay != null:
		_glow_overlay.visible = false
		_hover_vertex = -1


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
			if k.pressed and not k.echo:
				_ctrl_down = true
				_ctrl_used_combo = false
				_update_legend_visibility()
			elif not k.pressed:
				_ctrl_down = false
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

	# Sculpt-mode toggle (Slice D): the camera-vs-morph gate. ON => left-drag ON the body
	# morphs (drag-to-modify with region glow); left-drag on the BACKGROUND still orbits.
	_sculpt_btn = Button.new()
	_sculpt_btn.toggle_mode = true
	_sculpt_btn.text = "Sculpt mode: OFF (press M)"
	_sculpt_btn.toggled.connect(func(on: bool) -> void: _set_sculpt_mode(on))
	vbox.add_child(_sculpt_btn)

	vbox.add_child(HSeparator.new())

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

	vbox.add_child(HSeparator.new())

	var reset := Button.new()
	reset.text = "Reset to neutral"
	reset.pressed.connect(_reset_all)
	vbox.add_child(reset)

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

	_apply_state()
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

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 10)
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.text = ""
	vbox.add_child(_status_lbl)

	_update_image_history_enabled()


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


func _build_axis_row(parent: VBoxContainer, field: String, lo: float, hi: float,
		step: float, label: String, lo_pole: String, hi_pole: String) -> void:
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
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = float(_body_state.get(field))
	slider.custom_minimum_size = Vector2(100, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# value_changed fires continuously during a drag: update the live morph each
	# frame (so the body tracks the slider) but DEBOUNCE the history commit. We
	# commit one node only when the value SETTLES — on drag-end (drag_ended) or,
	# for keyboard/click steps that don't drag, on the value_changed itself when no
	# drag is in progress.
	slider.value_changed.connect(func(v: float) -> void:
		_body_state.set(field, v)
		_apply_state()
		if not bool(_drag_pending.get(field, false)) and not _suspend_commit:
			_commit_axis(field, v)
	)
	slider.drag_started.connect(func() -> void:
		_drag_pending[field] = true
	)
	slider.drag_ended.connect(func(value_changed: bool) -> void:
		_drag_pending[field] = false
		if value_changed and not _suspend_commit:
			_commit_axis(field, float(_sliders[field].value))
	)
	row.add_child(slider)
	_sliders[field] = slider

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

	for grp in RegionSlidersScript.GROUPS:
		var group_label: String = grp[0]
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
		list.add_child(group_box)
		list.add_child(HSeparator.new())


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
	var lo := RegionSlidersScript.BIDIR_MIN if kind == RegionSlidersScript.KIND_BIDIRECTIONAL else RegionSlidersScript.UNIPOLAR_MIN
	var hi := RegionSlidersScript.BIDIR_MAX if kind == RegionSlidersScript.KIND_BIDIRECTIONAL else RegionSlidersScript.UNIPOLAR_MAX

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
	slider.min_value = lo
	slider.max_value = hi
	slider.step = RegionSlidersScript.STEP
	slider.value = float(_body_state.modifiers.get(full_names[0], 0.0))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(70, 0)
	slider.value_changed.connect(func(v: float) -> void:
		_set_modifier(full_names, v)
		_apply_state()
		_update_modifier_value_label(spec_name)
		if not bool(_drag_pending.get(spec_name, false)) and not _suspend_commit:
			_commit_modifier(spec_name, display, v))
	slider.drag_started.connect(func() -> void: _drag_pending[spec_name] = true)
	slider.drag_ended.connect(func(changed: bool) -> void:
		_drag_pending[spec_name] = false
		if changed and not _suspend_commit:
			_commit_modifier(spec_name, display, float(slider.value)))
	row.add_child(slider)

	var hi_lbl := Label.new()
	hi_lbl.text = hi_pole
	hi_lbl.custom_minimum_size = Vector2(44, 0)
	hi_lbl.add_theme_font_size_override("font_size", 9)
	row.add_child(hi_lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(34, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.text = "%+.2f" % float(slider.value)
	row.add_child(val_lbl)

	_modifier_sliders[spec_name] = {
		"slider": slider, "value_lbl": val_lbl, "full_names": full_names, "kind": kind,
	}
	parent.add_child(row)


## Write `v` into BodyState.modifiers for every resolved full_name (clearing near-zero so a
## neutral body stays a tiny dict — matching the drag path's housekeeping).
func _set_modifier(full_names: PackedStringArray, v: float) -> void:
	for fn in full_names:
		if absf(v) < 1e-6:
			_body_state.modifiers.erase(fn)
		else:
			_body_state.modifiers[fn] = v


## Update one region slider's numeric value label from its current slider value.
func _update_modifier_value_label(spec_name: String) -> void:
	var e = _modifier_sliders.get(spec_name, null)
	if e != null:
		(e["value_lbl"] as Label).text = "%+.2f" % float((e["slider"] as HSlider).value)


## Commit one settled region-slider change as a history node.
func _commit_modifier(spec_name: String, display: String, value: float) -> void:
	_history.commit(_body_state.to_dict(), "%s = %+.2f" % [display, value])
	_refresh_history_panel()


## Restore every region slider from the live BodyState.modifiers (called by _restore_current
## after a headline-axis restore). Suspends commits while syncing.
func _restore_modifier_sliders() -> void:
	for spec_name in _modifier_sliders:
		var e = _modifier_sliders[spec_name]
		var fn := (e["full_names"] as PackedStringArray)[0]
		var v := float(_body_state.modifiers.get(fn, 0.0))
		(e["slider"] as HSlider).value = v
		(e["value_lbl"] as Label).text = "%+.2f" % v


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
		# The rest-space baked positions just changed → the CPU pick grid is stale. Mark it
		# dirty; the picker rebuilds lazily on the next pick (no per-bake-frame rebuild cost).
		if _cpu_picker != null:
			_cpu_picker.mark_dirty()
	for field in _value_labels:
		(_value_labels[field] as Label).text = _format_value(field)


## RESET-TO-NEUTRAL: branch from the ROOT (HistoryTree.reset_to), and be IDEMPOTENT — a
## neutral branch off root is REUSED if it already exists, so repeated resets never accrete
## duplicate empty branches. The body + sliders are then restored from the (new or reused)
## neutral node.
func _reset_all() -> void:
	var neutral := BodyState.new()
	_history.reset_to(neutral.to_dict(), "reset to neutral")
	_restore_current()


# ---------------------------------------------------------------------------
# History actions
# ---------------------------------------------------------------------------

## Commit the current BodyState as a new history node, labelled by the axis change.
func _commit_axis(field: String, value: float, override_label: String = "") -> void:
	var label := override_label
	if label == "":
		label = "%s = %s" % [field, _format_value(field)]
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


## Apply the history's current node state onto the body + sliders WITHOUT committing.
func _restore_current() -> void:
	var d = _history.current_state()
	if typeof(d) != TYPE_DICTIONARY:
		return
	var bs := BodyState.from_dict(d)
	_suspend_commit = true
	for field in _sliders:
		var v := float(bs.get(field))
		_body_state.set(field, v)
		(_sliders[field] as HSlider).value = v
	# The detail envelope is a whole-map replacement (restored dict's modifiers), then the
	# region sliders re-sync to it. Replace the live map so cleared modifiers actually clear.
	_body_state.modifiers = bs.modifiers.duplicate()
	_restore_modifier_sliders()
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
		_write_text(path, CreatorIOScript.history_to_json(_body_state, _history))
		_toast("exported JSON + history")
	else:
		var path := "%s/%s.json" % [CreatorIOScript.EXPORT_DIR, base]
		_write_text(path, CreatorIOScript.body_to_json(_body_state))
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
			CreatorIOScript.history_to_json(_body_state, _history))
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
