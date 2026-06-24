## Manual render harness (NOT a committed test): Phase-5a renders of the MIRROR toggle + the
## procedural EYE-COLOR control, plus an eye-color change. Renders the real creator viewport for
## the USER to judge. Visual aesthetics (does the iris read right, panel layout) are USER-gated
## and NOT self-certified here — this only produces frames + reports objective facts (which
## controls are present, that the iris color changed).
##
## Run windowed under xvfb:
##   PHASE5A_OUT=/tmp/phase5a xvfb-run -a godot4 --path . res://tools/phase5a_render.tscn --quit-after 600
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")

var _creator
var _out_dir := ""
var _frame := 0
var _done := false


func _ready() -> void:
	_out_dir = OS.get_environment("PHASE5A_OUT")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_creator = CreatorScene.instantiate()
	add_child(_creator)


func _process(_dt: float) -> void:
	_frame += 1
	if _done or _frame < 12:
		return
	_done = true
	# Projection shell: open the Advanced popup (mirror toggle lives there now) and focus
	# Face → Eyes & brow so the eye-color control is built into the dock.
	_creator.call("_open_advanced")
	_creator.call("_focus_into", 0)   # Face
	await get_tree().process_frame
	_creator.call("_focus_into", 3)   # Eyes & brow (index 3 under Face)
	await get_tree().process_frame

	# (1) The UI with the mirror toggle + the eye-color control visible, default (brown) eyes.
	var mirror_on: bool = bool(_creator.get("_mirror"))
	var mirror_btn = _creator.get("_mirror_btn")
	var eye_btn = _creator.get("_eye_color_btn")
	print("phase5a_render: mirror default ON = %s; mirror_btn present = %s; eye_color_btn present = %s"
		% [mirror_on, mirror_btn != null, eye_btn != null])
	await _shoot("creator_t3_mirror_eyecolor_ui")

	# Frame the FACE so the eye-color change reads in the render (close, eye-level, front).
	_creator.set("_distance", 0.6)
	_creator.set("_pitch", deg_to_rad(-2.0))
	_creator.set("_yaw", 0.0)
	# Lift the pivot to head height for a face shot.
	var pv: Vector3 = _creator.get("_pivot")
	_creator.set("_pivot", Vector3(pv.x, 1.62, pv.z))
	_creator.call("_update_camera")
	await get_tree().process_frame

	# (2) Default (brown) iris — the face, before the color change.
	await _shoot("face_eyes_brown_default")

	# (3) Change the eye color to a distinct blue and re-shoot the same framing.
	_creator.call("_set_eye_color", Color(0.18, 0.42, 0.70))
	var rig = _creator.get("_rig")
	var iris = (rig.get("_eye_params") as Dictionary)["iris_color"]
	print("phase5a_render: iris_color after change = %s" % str(iris))
	await get_tree().process_frame
	await _shoot("face_eyes_blue_changed")

	get_tree().quit(0)


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("phase5a_render: wrote %s" % path)
