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

var _value_labels: Dictionary = {}   ## field -> Label showing current value
var _sliders: Dictionary = {}        ## field -> HSlider


func _ready() -> void:
	_build_environment()
	_build_body()
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
	add_child(_rig)

	# Use a PER-INSTANCE copy of the mesh: _apply_state bakes recomputed normals into
	# the surface (the morphed-normal fix), which mutates the ArrayMesh. The rig loads
	# the SHARED cached asset via load(); mutating that would corrupt every other user
	# (and persist across runs in the cache). Duplicate so the bake is local to this
	# viewer. The skin/skeleton binding is unaffected (same vertex/bone arrays).
	if _rig.mesh_instance != null and _rig.mesh_instance.mesh != null:
		_rig.mesh_instance.mesh = (_rig.mesh_instance.mesh as ArrayMesh).duplicate(true)


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
# Input — orbit (left drag), pan (right drag), zoom (scroll wheel)
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging_orbit = mb.pressed
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
		if _dragging_orbit:
			_yaw = wrapf(_yaw - mm.relative.x * ORBIT_SPEED, -PI, PI)
			_pitch = clampf(_pitch - mm.relative.y * ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
			_update_camera()
		elif _dragging_pan:
			# Pan the pivot in the camera's right/up plane.
			var right := _camera.global_transform.basis.x
			var up := _camera.global_transform.basis.y
			_pivot += (-right * mm.relative.x + up * mm.relative.y) * PAN_SPEED * _distance
			_update_camera()


# ---------------------------------------------------------------------------
# Morph UI — sliders for the BodyState macro axes (gender/age/muscle/weight/
# height/proportions), live-driving the blendshapes through BodyState.apply_to.
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(360, 0)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "aeriea — character creator"
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "drag: orbit   right-drag: pan   scroll: zoom"
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	# [field, min, max] — the BodyState macro axes. age is the continuous axis;
	# proportions is carried in the record (no Slice-1 blendshape yet) but exposed
	# so the full macro vector is editable.
	var axes := [
		["gender", 0.0, 1.0],
		["age", 0.0, 1.0],
		["muscle", 0.0, 1.0],
		["weight", 0.0, 1.0],
		["height", 0.0, 1.0],
		["proportions", 0.0, 1.0],
	]
	for spec in axes:
		_build_axis_row(vbox, spec[0], spec[1], spec[2])

	vbox.add_child(HSeparator.new())

	var reset := Button.new()
	reset.text = "Reset to neutral"
	reset.pressed.connect(_reset_all)
	vbox.add_child(reset)

	_apply_state()


func _build_axis_row(parent: VBoxContainer, field: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = field
	name_lbl.custom_minimum_size = Vector2(95, 0)
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 0.01
	slider.value = float(_body_state.get(field))
	slider.custom_minimum_size = Vector2(170, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		_body_state.set(field, v)
		_apply_state()
	)
	row.add_child(slider)
	_sliders[field] = slider

	var value_lbl := Label.new()
	value_lbl.custom_minimum_size = Vector2(46, 0)
	value_lbl.text = "%.2f" % float(_body_state.get(field))
	row.add_child(value_lbl)
	_value_labels[field] = value_lbl

	parent.add_child(row)


## Project the current BodyState onto the body's blendshapes and refresh labels.
## After driving the GPU blendshape weights (which morph POSITIONS), recompute the
## per-vertex NORMALS on the CPU for the new morph and bake them into this viewer's
## per-instance mesh copy. Godot 4 stores blendshape normals octahedral-compressed,
## which cannot carry normal deltas, so the GPU morph alone leaves stale normals that
## light the morphed surface wrongly (blotches / inside-out). The CPU bake fixes that
## (BodyState.bake_morphed_normals). Only runs on slider changes, so it's cheap.
func _apply_state() -> void:
	if _rig != null and _rig.mesh_instance != null:
		# CPU morph (positions + recomputed normals), GPU blend weights zeroed. This is
		# the correct path for the creator: Godot's octahedral blendshape-normal storage
		# can't carry normal deltas, so a GPU-only morph is mis-lit (see BodyState).
		_body_state.apply_morph_cpu(_rig.mesh_instance)
	for field in _value_labels:
		(_value_labels[field] as Label).text = "%.2f" % float(_body_state.get(field))


func _reset_all() -> void:
	var neutral := BodyState.new()
	for field in _sliders:
		var v := float(neutral.get(field))
		_body_state.set(field, v)
		(_sliders[field] as HSlider).value = v
	_apply_state()
