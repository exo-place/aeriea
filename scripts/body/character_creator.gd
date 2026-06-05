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

# ---------------------------------------------------------------------------
# Edit HISTORY — a branching undo TREE over BodyState dicts (HistoryTree). Every
# settled axis change commits a node; undo/redo walk the tree; the history panel
# visualizes branches and jump_to lets you click any node to restore that state.
# DESIGN.md "lived history" / variety power-fantasy: explore an edit, back up,
# explore another, keep both branches — that is why this is a tree, not a stack.
# ---------------------------------------------------------------------------
const HistoryTreeScript := preload("res://scripts/util/history_tree.gd")
const CreatorIOScript := preload("res://scripts/body/creator_io.gd")

var _history: HistoryTree
## Per-axis pending value during a slider drag — committed once on drag-end so we
## record ONE node per settled change, not one per pixel.
var _drag_pending: Dictionary = {}   ## field -> bool (a drag is in progress)
var _suspend_commit: bool = false    ## true while applying a restored state (no commit)

var _history_list: VBoxContainer     ## the history-panel node list (rebuilt on change)
var _undo_btn: Button
var _redo_btn: Button
var _status_lbl: Label               ## export/import feedback


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
	# Current modifier values so the core clamps against the live state.
	var deltas: Dictionary = _morph.decompose_drag(_drag_vertex, drag_screen, cam_basis, _body_state.modifiers)
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
	var inv := _rig.skeleton.global_transform.affine_inverse()
	var weights: Dictionary = _morph.glow_weights(_drag_vertex, inv * _drag_hit_pos, _glow_base_pos)
	_rebuild_glow_mesh(weights)


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
		if k.pressed and not k.echo and k.keycode == KEY_Z and k.ctrl_pressed:
			if k.shift_pressed:
				_do_redo()
			else:
				_do_undo()
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

	var hint := Label.new()
	hint.text = "drag: orbit   right-drag: pan   scroll: zoom   M: sculpt mode"
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	# Sculpt-mode toggle (Slice D): the camera-vs-morph gate. ON => left-drag ON the body
	# morphs (drag-to-modify with region glow); left-drag on the BACKGROUND still orbits.
	_sculpt_btn = Button.new()
	_sculpt_btn.toggle_mode = true
	_sculpt_btn.text = "Sculpt mode: OFF (press M)"
	_sculpt_btn.toggled.connect(func(on: bool) -> void: _set_sculpt_mode(on))
	vbox.add_child(_sculpt_btn)

	var sculpt_hint := Label.new()
	sculpt_hint.text = "sculpt: hover body to glow the editable region, then drag the surface to pull it"
	sculpt_hint.add_theme_font_size_override("font_size", 10)
	sculpt_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sculpt_hint)

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

	_build_history_ui(vbox)
	_build_export_ui(vbox)

	_apply_state()
	_refresh_history_panel()


## Undo/redo buttons + the branching history node list (click a node to jump_to it).
func _build_history_ui(vbox: VBoxContainer) -> void:
	vbox.add_child(HSeparator.new())

	var hdr := Label.new()
	hdr.text = "history (branching undo tree)"
	vbox.add_child(hdr)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	_undo_btn = Button.new()
	_undo_btn.text = "Undo (Ctrl+Z)"
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.pressed.connect(_do_undo)
	nav.add_child(_undo_btn)
	_redo_btn = Button.new()
	_redo_btn.text = "Redo (Ctrl+Shift+Z)"
	_redo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_redo_btn.pressed.connect(_do_redo)
	nav.add_child(_redo_btn)
	vbox.add_child(nav)

	# Scrollable indented node list. Branches read as deeper indentation; the
	# current node is marked. Clicking a node jumps_to it (restores that state).
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_history_list)


## Export (JSON / JSON+history / PNG / PNG+history) and import (JSON or PNG-with-history).
func _build_export_ui(vbox: VBoxContainer) -> void:
	vbox.add_child(HSeparator.new())

	var hdr := Label.new()
	hdr.text = "export / import"
	vbox.add_child(hdr)

	var export_btn := Button.new()
	export_btn.text = "Export all 4 (JSON / +history / PNG / PNG+history)"
	export_btn.pressed.connect(_do_export)
	vbox.add_child(export_btn)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 10)
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.text = "exports -> user://creator_exports/"
	vbox.add_child(_status_lbl)


func _refresh_history_panel() -> void:
	if _history_list == null:
		return
	for c in _history_list.get_children():
		c.queue_free()
	for n in _history.structure():
		var btn := Button.new()
		var indent := "    ".repeat(int(n["depth"]))
		var marker := "* " if bool(n["is_current"]) else "  "
		var fork := "  <branch>" if int(n["child_count"]) > 1 else ""
		btn.text = "%s%s%s%s" % [indent, marker, str(n["label"]), fork]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		btn.flat = not bool(n["is_current"])
		var nid := int(n["id"])
		btn.pressed.connect(func() -> void: _jump_to_node(nid))
		_history_list.add_child(btn)
	if _undo_btn != null:
		_undo_btn.disabled = not _history.can_undo()
	if _redo_btn != null:
		_redo_btn.disabled = not _history.can_redo()


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


func _reset_all() -> void:
	_suspend_commit = true
	var neutral := BodyState.new()
	for field in _sliders:
		var v := float(neutral.get(field))
		_body_state.set(field, v)
		(_sliders[field] as HSlider).value = v
	_apply_state()
	_suspend_commit = false
	# Reset is itself a settled edit -> one history node (preserves prior branch).
	_commit_axis("reset", 0.0, "reset to neutral")
	_refresh_history_panel()


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
	_suspend_commit = false
	_apply_state()
	_refresh_history_panel()


# ---------------------------------------------------------------------------
# Export — captures the viewport render and writes the four variants.
# ---------------------------------------------------------------------------

func _do_export() -> void:
	var png_bytes := await _capture_png_bytes()
	var stamp := str(Time.get_unix_time_from_system()).replace(".", "")
	var basename := "creator_%s" % stamp
	var paths := CreatorIOScript.export_all(_body_state, _history, basename, png_bytes)
	var lines: Array = []
	for k in paths:
		lines.append("%s: %s" % [k, paths[k]])
	if _status_lbl != null:
		_status_lbl.text = "exported:\n" + "\n".join(lines)
	print("[creator] exported:\n", "\n".join(lines))


## Render the 3D body to a PNG byte stream, excluding the UI overlay. The UI lives on
## a CanvasLayer, so a SubViewport-free capture of the root viewport would include it;
## instead we hide the CanvasLayer for one frame, grab the viewport image, restore it.
func _capture_png_bytes() -> PackedByteArray:
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
	if img == null:
		return PackedByteArray()
	return img.save_png_to_buffer()
