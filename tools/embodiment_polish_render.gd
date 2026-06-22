## Visual verification render for the embodiment-polish pass:
##   - base-mesh masking (swapped head/legs replace the base region cleanly, no double-render)
##   - materials on mined assets (head/legs share the body skin; hair gets a keratin material)
##
## Renders a matrix of PNGs to user:// so the masking + materials can be eyeballed:
##   embodiment_head_human.png / _canine.png   (skull masked under the canine head)
##   embodiment_legs_human.png / _digi.png     (human legs masked under the digi legs)
##   embodiment_hair.png                        (mined hairstyle with the keratin material)
##
## Run: xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --rendering-driver vulkan \
##        res://tools/embodiment_polish_render.tscn --quit-after 40
extends Node3D

var _rig: BodyRig
var _frame := 0
var _shots := []   ## queued {name, head, legs, hair, cam}


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.2, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.62, 0.68)
	e.ambient_light_energy = 1.2
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -40, 0)
	add_child(light)

	_rig = BodyRig.new()
	# add_child triggers BodyRig._ready -> build() ONCE. Do NOT call build() again: a second
	# build leaves an orphaned first Body+Proxies pair in the tree that still renders (the cause
	# of a stale hair cap co-rendering even after the live proxy's hair surface is hidden).
	add_child(_rig)
	_rig.use_motion_matching = false
	_rig.foot_ik_enabled = false
	_rig._setup_micro_life(0)

	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	_cam = cam

	# Head shots framed on the head WITH HAIR HIDDEN (so the skull/head is visible, not the
	# cap); leg shots framed on the legs; the hair shot keeps a mined hairstyle to show its
	# material. hide_hair collapses the cap so the head-mask comparison is unobstructed.
	_shots = [
		{"name": "head_human", "head": "human",  "legs": "human", "hair": "cap", "hide_hair": true, "frame": "head"},
		{"name": "head_canine", "head": "canine", "legs": "human", "hair": "cap", "hide_hair": true, "frame": "head"},
		{"name": "legs_human", "head": "human",  "legs": "human", "hair": "cap", "hide_hair": true, "frame": "legs"},
		{"name": "legs_digi", "head": "human",  "legs": "digitigrade", "hair": "cap", "hide_hair": true, "frame": "legs"},
		{"name": "hair", "head": "human",  "legs": "human", "hair": "long", "hide_hair": false, "frame": "head"},
	]


var _cam: Camera3D
var _shot_idx := 0
var _settle := 0


func _frame_camera(which: String) -> void:
	if which == "legs":
		_cam.position = Vector3(0.6, 0.5, 2.0)
		_cam.look_at(Vector3(0, 0.45, 0), Vector3.UP)
		_cam.fov = 45.0
	else:
		_cam.position = Vector3(0.35, 1.62, 0.9)
		_cam.look_at(Vector3(0, 1.55, 0), Vector3.UP)
		_cam.fov = 38.0


func _apply_shot(s: Dictionary) -> void:
	_rig.apply_part("head", s["head"])
	_rig.apply_part("legs", s["legs"])
	_rig.apply_part("hair", s["hair"])
	_frame_camera(s["frame"])
	for i in 12:
		_rig.apply_pose(1.0 / 60.0)
	# Hide the CC0 hair cap LAST (after pose/any re-bake) so the head-mask comparison shows
	# the head, not the cap. Done here at the end of shot setup so nothing re-shows it.
	if s.get("hide_hair", false):
		_rig.set_proxy_visible("hair", false)


func _process(_delta: float) -> void:
	_frame += 1
	if _shot_idx >= _shots.size():
		print("=== embodiment polish render: %d shots written ===" % _shots.size())
		get_tree().quit(0)
		return
	if _settle == 0:
		_apply_shot(_shots[_shot_idx])
		_settle = 1
		return
	# Re-assert the hair hide every settle frame (nothing should re-show it, but this is
	# belt-and-suspenders against any per-frame proxy re-assert) before capturing.
	if _shots[_shot_idx].get("hide_hair", false):
		_rig.set_proxy_visible("hair", false)
	# one frame after applying, capture (gives the renderer a frame to draw the new mesh).
	if _settle < 3:
		_settle += 1
		return
	var s: Dictionary = _shots[_shot_idx]
	var img := get_viewport().get_texture().get_image()
	var path := "user://embodiment_%s.png" % s["name"]
	img.save_png(path)
	print("RENDERED %s  head=%s legs=%s hair=%s  head_masked=%s legs_masked=%s  png=%s" % [
		s["name"], s["head"], s["legs"], s["hair"],
		_rig.is_region_masked("head"), _rig.is_region_masked("legs"),
		ProjectSettings.globalize_path(path)])
	_shot_idx += 1
	_settle = 0
