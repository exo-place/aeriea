## Manual render harness (NOT a committed test): Phase-2a skin Tier-A before/after.
## Renders the real BodyRig LIT from FRONT + 3/4 + a SKIN CLOSE-UP (torso/cheek), at a
## neutral-ish young adult, so the user can judge the detail-normal / roughness / SSS look.
## Also emits a FLAT-AMBIENT front shot (no directional light, pure ambient) so a
## before/after pixel-diff can confirm NO NEW SHADING SEAMS were introduced.
## Run windowed under xvfb:
##   PHASE2A_OUT=/tmp/phase2a/before xvfb-run -a godot4 --path . res://tools/phase2a_skin_render.tscn --quit-after 300
extends Node3D

var _rig: BodyRig
var _cam: Camera3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _back: DirectionalLight3D
var _shots := []
var _frame := 0
var _out_dir := ""


func _ready() -> void:
	_out_dir = OS.get_environment("PHASE2A_OUT")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-25, 20, 0)
	_key.light_energy = 1.3
	add_child(_key)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-10, -150, 0)
	_fill.light_energy = 0.5
	add_child(_fill)
	_back = DirectionalLight3D.new()
	_back.rotation_degrees = Vector3(-20, 180, 0)
	_back.light_energy = 0.7
	add_child(_back)

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

	# A young-adult feminine body — the common creator default, good for skin readout.
	var subj := BodyState.new()
	subj.age_years = 24.0
	subj.masculinity = 30.0
	subj.weight = 100.0
	subj.muscle = 50.0
	_shots = [
		{"label": "front", "state": subj, "mode": "front", "flat": false},
		{"label": "threeq", "state": subj, "mode": "34", "flat": false},
		{"label": "skin_closeup", "state": subj, "mode": "closeup", "flat": false},
		{"label": "flat_front", "state": subj, "mode": "front", "flat": true},
	]


func _process(_dt: float) -> void:
	_frame += 1
	if _frame < 6:
		return
	if _shots.is_empty():
		print("phase2a_skin_render: ALL SHOTS DONE; dir = %s" % _out_dir)
		get_tree().quit(0)
		return
	if _frame % 4 != 0:
		return
	var shot = _shots.pop_front()
	_rig.apply_body_state(shot["state"])
	# Flat-ambient mode: kill the directional lights so only uniform ambient remains —
	# any seam visible here is a geometry/normal/tangent shading discontinuity, not a
	# lighting-angle artifact.
	var flat: bool = shot["flat"]
	_key.visible = not flat
	_fill.visible = not flat
	_back.visible = not flat
	_frame_camera(shot["mode"])
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % shot["label"])
	img.save_png(path)
	print("phase2a_skin_render: wrote %s" % path)


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
		"closeup":
			# Skin close-up: the upper chest / shoulder, where pore detail + SSS read.
			var ly := head_y * 0.80
			_cam.look_at_from_position(Vector3(0.10, ly, 0.55), Vector3(0.0, ly - 0.04, 0), Vector3.UP)
			_cam.fov = 32
