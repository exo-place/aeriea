## Render a frame of aeriea wearing a BDCC2 hairstyle, save a PNG, and report the
## on-screen hair AABB so we have visual evidence the mined mesh is on the head.
## Run: xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --rendering-driver vulkan \
##        res://tools/hair_render.tscn --quit-after 30
extends Node3D

@export var style: String = "long"      ## hair-slot part id (legacy export name)
@export var ears: String = ""            ## optional ears-slot part id
@export var tail: String = ""            ## optional tail-slot part id
@export var horns: String = ""           ## optional horns-slot part id
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
	_rig.apply_part("hair", style)
	if ears != "":
		_rig.apply_part("ears", ears)
	if tail != "":
		_rig.apply_part("tail", tail)
	if horns != "":
		_rig.apply_part("horns", horns)

	# Camera framed to show the whole body when accessories are present, else the head.
	var cam := Camera3D.new()
	if tail != "":
		cam.position = Vector3(0.9, 1.0, 2.6)
		cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
		cam.fov = 45.0
	else:
		cam.position = Vector3(0.35, 1.62, 0.85)
		cam.look_at(Vector3(0, 1.6, 0), Vector3.UP)
		cam.fov = 35.0
	add_child(cam)
	cam.make_current()

	# settle a few frames so the springs are at rest, then a shake to show motion
	for i in 20:
		_rig.apply_pose(1.0 / 60.0)


@export var shake: bool = true   ## false => still pose (assess seating, not swing)

func _process(delta: float) -> void:
	_frame += 1
	# shake the body so the hair is mid-swing in the captured frame (unless disabled)
	if shake:
		_rig.global_position = Vector3(0.04 * sin(_frame * 1.7), 0.05 * sin(_frame * 1.4), 0.0)
	_rig.apply_pose(1.0 / 60.0)
	if _frame == 6:
		var img := get_viewport().get_texture().get_image()
		var path := "user://hair_%s.png" % style
		img.save_png(path)
		var abs := ProjectSettings.globalize_path(path)
		var st := _rig.micro_life_state()
		print("RENDERED hair=%s ears=%s tail=%s horns=%s slot_springs=%s png=%s" % [
			style, ears, tail, horns, str(st["slot_springs"]), abs])
		get_tree().quit(0)
