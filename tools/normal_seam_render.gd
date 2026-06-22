## Manual render harness (NOT a committed test): verifies the body normal computation
## produces NO shading seams along UV-island edges. Renders the real BodyRig LIT from
## front + 3/4 + back-of-head close-up + inner-leg close-up, at NEUTRAL and at a
## non-neutral MORPH (exercises the runtime CPU re-bake path). Saves PNGs to OUT.
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tools/normal_seam_render.tscn --quit-after 240
extends Node3D

var _rig: BodyRig
var _cam: Camera3D
var _shots := []
var _frame := 0
var _out_dir := ""


func _ready() -> void:
	_out_dir = OS.get_environment("SEAM_OUT")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://")

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 20, 0)
	key.light_energy = 1.3
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -150, 0)
	fill.light_energy = 0.5
	add_child(fill)
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-20, 180, 0)
	back.light_energy = 0.7
	add_child(back)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.ambient_light_energy = 1.0
	we.environment = env
	add_child(we)

	_rig = BodyRig.new()
	_rig.show_genitals = false
	add_child(_rig)

	_cam = Camera3D.new()
	add_child(_cam)

	var neutral := BodyState.new()
	# non-neutral morph: heavy old masculine body — exercises the runtime CPU re-bake.
	var morphed := BodyState.new()
	morphed.age_years = 65.0
	morphed.masculinity = 90.0
	morphed.weight = 140.0
	morphed.muscle = 80.0
	_shots = [
		{"label": "neutral_front", "state": neutral, "mode": "front"},
		{"label": "neutral_34", "state": neutral, "mode": "34"},
		{"label": "neutral_backhead", "state": neutral, "mode": "backhead"},
		{"label": "neutral_innerleg", "state": neutral, "mode": "innerleg"},
		{"label": "morph_front", "state": morphed, "mode": "front"},
		{"label": "morph_34", "state": morphed, "mode": "34"},
		{"label": "morph_backhead", "state": morphed, "mode": "backhead"},
		{"label": "morph_innerleg", "state": morphed, "mode": "innerleg"},
	]


func _process(_dt: float) -> void:
	_frame += 1
	if _frame < 6:
		return
	if _shots.is_empty():
		print("normal_seam_render: ALL SHOTS DONE; dir = %s" % _out_dir)
		get_tree().quit(0)
		return
	if _frame % 4 != 0:
		return
	var shot = _shots.pop_front()
	_rig.apply_body_state(shot["state"])
	_frame_camera(shot["mode"])
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("seam_%s.png" % shot["label"])
	img.save_png(path)
	print("normal_seam_render: wrote %s" % path)


func _frame_camera(mode: String) -> void:
	var top := _rig.head_top() if _rig.skeleton != null else 1.7
	var sc := _rig.skeleton.scale.y if _rig.skeleton != null else 1.0
	var head_y := top * sc - 0.06 * sc
	match mode:
		"front":
			var cy := head_y * 0.55
			_cam.look_at_from_position(Vector3(0, cy, 3.2), Vector3(0, cy, 0), Vector3.UP)
			_cam.fov = 38
		"34":
			var cy2 := head_y * 0.55
			_cam.look_at_from_position(Vector3(1.6, cy2, 2.6), Vector3(0, cy2, 0), Vector3.UP)
			_cam.fov = 38
		"backhead":
			# close-up on the BACK of the head (the back-of-head centre seam).
			_cam.look_at_from_position(Vector3(0, head_y, -0.42), Vector3(0, head_y, 0), Vector3.UP)
			_cam.fov = 30
		"innerleg":
			# close-up on the inner thigh / crotch region (inner-leg seam), from front-below.
			var ly := head_y * 0.42
			_cam.look_at_from_position(Vector3(0.0, ly + 0.05, 0.6), Vector3(0, ly, 0), Vector3.UP)
			_cam.fov = 40
