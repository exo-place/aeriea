## FaceDemo — runnable show-don't-tell view: Maren's CC0 head emoting from affect.
##
## Builds a BodyRig (CC0 MakeHuman head/body), attaches the ported FaceRig behind
## aeriea's apply_expression seam, and cycles npc_maren affect states (warm/cool/
## guarded) so the face visibly shifts. Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://scenes/face_demo.tscn --quit-after 240
extends Node3D

const BodyRig := preload("res://scripts/body/body_rig.gd")
const FaceRig := preload("res://scripts/body/face/face_rig.gd")
const MarenAffect := preload("res://scripts/body/face/maren_affect.gd")

# A few npc_maren states spanning the relationship space (mood x rapport).
const STATES := [
	{"label": "guarded/low", "mood": 0.5, "rapport": 0.15, "last_social_act": "greeted"},
	{"label": "stung", "mood": 0.2, "rapport": 0.3, "last_social_act": "teased"},
	{"label": "warming", "mood": 0.7, "rapport": 0.5, "last_social_act": "complimented"},
	{"label": "at ease/lit", "mood": 0.92, "rapport": 0.85, "last_social_act": "chatted"},
]
const STATE_SECONDS := 2.0

## When set (via --capture-dir=PATH on the command line), the demo holds each
## state for a fixed number of frames and writes one PNG per state, then quits.
var _capture_dir := ""
var _rig: BodyRig
var _face: FaceRig
var _t := 0.0
var _idx := -1


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.12, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.62)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, 25, 0)
	add_child(light)

	_rig = BodyRig.new()
	add_child(_rig)

	_face = FaceRig.new()
	add_child(_face)
	_face.setup(1234, _rig.skeleton, _rig.mesh_instance)

	# Camera framed on the head (eye height from the rig).
	var cam := Camera3D.new()
	var eye_y := _rig.eye_height() if _rig.skeleton != null else 1.6
	cam.fov = 45
	add_child(cam)
	cam.position = Vector3(0, eye_y, 0.55)
	cam.look_at(Vector3(0, eye_y, 0), Vector3.UP)

	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.split("=", true, 1)[1]

	print("\n=== aeriea FaceDemo: Maren emotes from affect ===")
	print("blendshape coverage: ", FaceRig.channel_coverage())
	if _capture_dir != "":
		_run_capture()


## Capture one PNG per affect state (deterministic): push the state, settle the
## rig a fixed number of steps, render, save. Confirms the head visibly emotes.
func _run_capture() -> void:
	for s in STATES:
		var e := MarenAffect.to_expr(s)
		_face.apply_expression(e)
		var tl := MarenAffect.talk_length_for(String(s["last_social_act"]))
		if tl > 0.0:
			_face.do_talk(tl)
		# Settle the rig deterministically (no _process; step manually).
		_face.set_process(false)
		for i in 30:
			_face.step(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/maren_%s.png" % [_capture_dir, String(s["label"]).replace("/", "_").replace(" ", "_")]
		img.save_png(path)
		print("captured %s -> %s" % [s["label"], path])
	get_tree().quit(0)


func _process(delta: float) -> void:
	_t += delta
	var idx := int(_t / STATE_SECONDS) % STATES.size()
	if idx != _idx:
		_idx = idx
		var s: Dictionary = STATES[idx]
		var e := MarenAffect.to_expr(s)
		_face.apply_expression(e)
		var tl := MarenAffect.talk_length_for(String(s["last_social_act"]))
		if tl > 0.0:
			_face.do_talk(tl)
		print("[%5.1fs] state=%-12s -> valence=%+.2f tension=%.2f attention=%.2f emphasis='%s'"
			% [_t, s["label"], e.valence, e.tension, e.attention, e.emphasis])
	# FaceRig._process drives itself; we only push affect on state change.
