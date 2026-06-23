## Manual render harness (NOT a committed test): Phase-2b before/after.
## Renders three views for the USER to judge (visual quality is USER-gated, never self-certified):
##   * eye_closeup  — a tight shot of the eye (the procedural iris look).
##   * mouth        — a lower-face front close-up (teeth + the re-seated tongue in the cavity).
##   * glow         — a sculpt-glow region on a MORPHED body (the glow tracks + sits above skin).
## Run windowed under xvfb:
##   PHASE2B_OUT=/tmp/phase2b/after xvfb-run -a godot4 --path . res://tools/phase2b_render.tscn --quit-after 400
extends Node3D

const CreatorScene := preload("res://scenes/character_creator.tscn")

var _rig: BodyRig
var _cam: Camera3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _creator
var _out_dir := ""
var _frame := 0
var _stage := 0


func _ready() -> void:
	_out_dir = OS.get_environment("PHASE2B_OUT")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-22, 18, 0)
	_key.light_energy = 1.3
	add_child(_key)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-10, -150, 0)
	_fill.light_energy = 0.55
	add_child(_fill)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 1.0
	we.environment = env
	add_child(we)

	_rig = BodyRig.new()
	_rig.show_genitals = false
	add_child(_rig)
	_cam = Camera3D.new()
	add_child(_cam)

	# A young-adult face — common creator default; good for eyes + mouth readout.
	var subj := BodyState.new()
	subj.age_years = 24.0
	subj.masculinity = 35.0
	subj.weight = 100.0
	_rig.apply_body_state(subj)


func _process(_dt: float) -> void:
	_frame += 1
	if _frame < 8:
		return
	if _frame % 6 != 0:
		return
	match _stage:
		0:
			await _shoot_eye()
			_stage = 1
		1:
			await _shoot_mouth()
			_stage = 2
		2:
			_setup_glow_scene()
			_stage = 3
		3:
			await _shoot_glow()
			_stage = 4
		_:
			print("phase2b_render: ALL SHOTS DONE; dir = %s" % _out_dir)
			get_tree().quit(0)


func _scale_y() -> float:
	return _rig.skeleton.scale.y if _rig.skeleton != null else 1.0


func _shoot_eye() -> void:
	# The eye landmark in WORLD space (bone pose origin × skeleton scale). Look at the LEFT
	# eye from just in front of the face, tight FOV for a close iris read.
	var sc := _scale_y()
	var eye_y := _rig.eye_height() * sc
	# the face looks +Z; nudge to the character's left eye (mesh -X is anatomical right; pick
	# a small +X offset so we frame one eyeball, not the bridge).
	var eye_x := 0.032 * sc
	var target := Vector3(eye_x, eye_y, 0.085 * sc)
	var camp := Vector3(eye_x + 0.01, eye_y + 0.01, 0.32 * sc)
	_cam.look_at_from_position(camp, target, Vector3.UP)
	_cam.fov = 14
	await RenderingServer.frame_post_draw
	_save("eye_closeup")


func _shoot_mouth() -> void:
	# Lower-face front close-up: the mouth region. The base mesh's rest mouth is near-closed,
	# so this shot confirms NO tongue protrusion past the lips (the external read).
	var sc := _scale_y()
	var eye_y := _rig.eye_height() * sc
	var mouth_y := eye_y - 0.075 * sc
	var target := Vector3(0.0, mouth_y, 0.10 * sc)
	var camp := Vector3(0.0, mouth_y - 0.02, 0.30 * sc)
	_cam.look_at_from_position(camp, target, Vector3.UP)
	_cam.fov = 16
	await RenderingServer.frame_post_draw
	_save("mouth")
	# PROXY-ONLY mouth view: hide the body skin so the teeth + the re-seated tongue are
	# DIRECTLY visible inside the cavity (the rest mouth is closed, so this is the only way
	# to see the tongue seating). Restore the body skin afterward.
	_rig.mesh_instance.visible = false
	_rig.set_proxy_visible("genitals", false)
	_rig.set_proxy_visible("hair", false)
	_rig.set_proxy_visible("eyebrows", false)
	_rig.set_proxy_visible("eyelashes", false)
	_rig.set_proxy_visible("eyes", false)
	# Pull back + 3/4-from-below so the teeth arch + the re-seated tongue both read in frame.
	var t2 := Vector3(0.0, mouth_y - 0.01 * sc, 0.08 * sc)
	_cam.look_at_from_position(Vector3(0.10 * sc, mouth_y - 0.06 * sc, 0.40 * sc), t2, Vector3.UP)
	_cam.fov = 22
	await RenderingServer.frame_post_draw
	_save("mouth_proxy_tongue")
	_rig.mesh_instance.visible = true


func _setup_glow_scene() -> void:
	# Hide the standalone rig; bring up the real creator scene so the live glow overlay path runs.
	_rig.visible = false
	_key.visible = false
	_fill.visible = false
	_creator = CreatorScene.instantiate()
	add_child(_creator)


func _shoot_glow() -> void:
	# Morph the creator body hard, then light a sculpt-glow region (a belly/torso vertex) and
	# frame it. Proves the glow shell tracks the morphed surface and floats above the skin.
	await get_tree().process_frame
	_creator._body_state.weight = 100.0
	_creator._body_state.masculinity = 80.0
	_creator._body_state.muscle = 40.0
	_creator._apply_state()
	_creator._refresh_glow_geometry()
	# Pick a belly-region vertex (mid front torso) and build a broad glow there.
	var base: PackedVector3Array = _creator._glow_base_pos
	var best := 0
	var best_z := -INF
	# choose a front (max +z) mid-height NEAR-CENTRELINE vertex — the belly bulge (|x| small
	# excludes the arms/hands, which also reach this height at rest).
	for i in base.size():
		var p := base[i]
		if p.y > 0.95 and p.y < 1.2 and absf(p.x) < 0.10 and p.z > best_z:
			best_z = p.z
			best = i
	var weights := {}
	var c := base[best]
	for i in base.size():
		var d := c.distance_to(base[i])
		if d < 0.12:
			weights[i] = clampf(1.0 - d / 0.12, 0.0, 1.0)
	_creator._rebuild_glow_mesh(weights)
	# Use OUR camera (make it current) so we control framing.
	_cam.make_current()
	var skel: Skeleton3D = _creator._rig.skeleton
	var world_c: Vector3 = skel.global_transform * c
	_cam.look_at_from_position(world_c + Vector3(0.25, 0.10, 0.85), world_c, Vector3.UP)
	_cam.fov = 30
	await RenderingServer.frame_post_draw
	_save("glow")


func _save(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("phase2b_render: wrote %s" % path)
