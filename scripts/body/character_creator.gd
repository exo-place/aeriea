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
	# Drive the rig with THIS creator's BodyState (the single source of truth the
	# sliders edit). BodyRig already holds a per-instance mesh copy and morphs through
	# the correct-normals CPU bake (apply_body_state), so the creator no longer
	# duplicates or bakes itself — it just edits the shared record and re-applies it.
	_rig.body_state = _body_state
	add_child(_rig)


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
	hint.text = "drag: orbit   right-drag: pan   scroll: zoom"
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	# [field, min, max, step, label, lo_pole, hi_pole] — the BodyState natural-unit
	# headline axes (body-parameterization.md §2). age is in YEARS (the gate reads
	# >= 18); masculinity is the single macro sex axis 0–100 (0=feminine,
	# 50=androgynous, 100=masculine); muscle/weight in %; proportions is the
	# dimensionless 0..1-about-0.5 bidirectional envelope; height is the Slice A
	# provisional normalized macro-height amount (Slice C makes it metric cm, §4).
	#
	# muscle/weight slider ranges are restricted to the functional half (50–100 /
	# 100–150) because the below-average blend targets don't exist until Slice C.
	# Slice C's min-anchor import restores the full 0–100 / 50–150 ranges here.
	var axes := [
		["age_years",   1.0, 90.0,  0.5,  "age",         "young",    "old"],
		["masculinity", 0.0, 100.0, 1.0,  "masculinity",  "feminine", "masculine"],
		["muscle",      50.0, 100.0, 1.0, "muscle",       "average",  "muscular"],
		["weight",      100.0, 150.0, 1.0, "weight",      "average",  "heavy"],
		["proportions", 0.0, 1.0,   0.01, "proportions",  "uncommon", "idealized"],
		["height",      0.0, 1.0,   0.01, "height",       "shorter",  "taller"],
	]
	for spec in axes:
		_build_axis_row(vbox, spec[0], spec[1], spec[2], spec[3], spec[4], spec[5], spec[6])

	vbox.add_child(HSeparator.new())

	var reset := Button.new()
	reset.text = "Reset to neutral"
	reset.pressed.connect(_reset_all)
	vbox.add_child(reset)

	_apply_state()


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
	slider.value_changed.connect(func(v: float) -> void:
		_body_state.set(field, v)
		_apply_state()
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
	for field in _value_labels:
		(_value_labels[field] as Label).text = _format_value(field)


func _reset_all() -> void:
	var neutral := BodyState.new()
	for field in _sliders:
		var v := float(neutral.get(field))
		_body_state.set(field, v)
		(_sliders[field] as HSlider).value = v
	_apply_state()
