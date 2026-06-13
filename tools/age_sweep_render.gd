## Manual render harness (NOT a committed test): an age sweep at FIXED height_cm so the
## morph-driven stature curve (body-parameterization.md §4.1) is visible. Renders the real
## BodyRig at ages 6/10/12/14/16/18/25 lined up on a common ground plane and saves one PNG.
## Run: xvfb-run -a godot4 --path . res://tools/age_sweep_render.tscn --quit-after 240
extends Node3D

const OUT := "user://age_sweep.png"
const AGES := [6.0, 10.0, 12.0, 14.0, 16.0, 18.0, 25.0]

var _cam: Camera3D
var _done := false
var _frame := 0


func _ready() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0); key.light_energy = 1.4
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -150, 0); fill.light_energy = 0.5
	add_child(fill)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55); env.ambient_light_energy = 1.0
	we.environment = env
	add_child(we)

	# ground grid lines at 0.5 m intervals so relative stature is readable.
	var spacing := 0.85
	var x0 := -(AGES.size() - 1) * 0.5 * spacing
	for i in AGES.size():
		var rig := BodyRig.new()
		rig.show_genitals = false
		add_child(rig)
		var bs := BodyState.new()
		bs.age_years = AGES[i]
		bs.masculinity = 50.0
		bs.height_cm = BodyState.DEFAULT_HEIGHT_CM   # FIXED: isolate the age MORPH on stature
		rig.apply_body_state(bs)
		rig.position = Vector3(x0 + i * spacing, 0, 0)

	_cam = Camera3D.new()
	add_child(_cam)
	# frame the whole row from the front
	var cx := 0.0
	_cam.look_at_from_position(Vector3(cx, 0.95, 4.6), Vector3(cx, 0.85, 0), Vector3.UP)
	_cam.fov = 48


func _process(_dt: float) -> void:
	_frame += 1
	if _frame < 8 or _done:
		return
	_done = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT)
	print("age_sweep_render: wrote %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit(0)
