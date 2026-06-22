## Render a frame of aeriea wearing a BDCC2 hairstyle, save a PNG, and report the
## on-screen hair AABB so we have visual evidence the mined mesh is on the head.
## Run: xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --rendering-driver vulkan \
##        res://tools/hair_render.tscn --quit-after 30
extends Node3D

@export var style: String = "long"
var _rig: BodyRig
var _frame := 0

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.2, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.ambient_light_energy = 1.2
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -40, 0)
	add_child(light)

	_rig = BodyRig.new()
	add_child(_rig)
	_rig.build()
	_rig.use_motion_matching = false
	_rig.foot_ik_enabled = false
	_rig._setup_micro_life(0)
	_rig.apply_hairstyle(style)

	# Camera framed on the head (eye height ~1.6m).
	var cam := Camera3D.new()
	cam.position = Vector3(0.35, 1.62, 0.85)
	cam.look_at(Vector3(0, 1.6, 0), Vector3.UP)
	cam.fov = 35.0
	add_child(cam)
	cam.make_current()

	# settle a few frames so the springs are at rest, then a shake to show motion
	for i in 20:
		_rig.apply_pose(1.0 / 60.0)


func _process(delta: float) -> void:
	_frame += 1
	# shake the body so the hair is mid-swing in the captured frame
	_rig.global_position = Vector3(0.04 * sin(_frame * 1.7), 0.05 * sin(_frame * 1.4), 0.0)
	_rig.apply_pose(1.0 / 60.0)
	if _frame == 6:
		var img := get_viewport().get_texture().get_image()
		var path := "user://hair_%s.png" % style
		img.save_png(path)
		var abs := ProjectSettings.globalize_path(path)
		var hskel := _rig._hair_skeleton()
		var aabb := AABB()
		if hskel != null:
			for c in hskel.get_children():
				if c is MeshInstance3D:
					aabb = aabb.merge((c as MeshInstance3D).get_aabb())
		print("RENDERED style=%s hair_skel=%s aabb=%s png=%s" % [
			style, hskel != null, str(aabb.size), abs])
		get_tree().quit(0)
