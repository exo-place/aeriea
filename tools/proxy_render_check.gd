## Render-verification for the proxy pieces (NOT a committed test scene — a manual
## verification harness). Builds the real BodyRig, frames the FACE, and saves PNGs:
##   front + 3/4 of the neutral face (eyes/teeth/tongue must fill sockets+mouth),
##   the same after a morph (age 60, masculinity 80),
##   and a genitals-on full-body shot.
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tools/proxy_render_check.tscn --quit-after 240
extends Node3D

const OUT := "user://"   # resolved to a real path; printed at the end

var _rig: BodyRig
var _cam: Camera3D
var _shots := []
var _frame := 0


func _ready() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 20, 0)
	key.light_energy = 1.3
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -150, 0)
	fill.light_energy = 0.5
	add_child(fill)
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

	# queue the shots (label, body_state, camera_mode)
	var neutral := BodyState.new()
	var aged := BodyState.new(); aged.age_years = 60.0; aged.masculinity = 80.0
	var young := BodyState.new(); young.age_years = 8.0   # child face — proxies must seat
	_shots = [
		{"label": "face_front_neutral", "state": neutral, "mode": "face_front"},
		{"label": "face_34_neutral", "state": neutral, "mode": "face_34"},
		{"label": "eye_closeup_front", "state": neutral, "mode": "eye_front"},
		{"label": "eye_closeup_34", "state": neutral, "mode": "eye_34"},
		# exotic parameterisation proof: vertical-slit pupil + a vivid amber iris.
		{"label": "eye_closeup_slit", "state": neutral, "mode": "eye_front",
			"eye_params": {"pupil_aspect": 0.20, "iris_color": Color(0.78, 0.52, 0.10),
				"iris_inner": Color(0.45, 0.28, 0.04), "pupil_size": 0.55}},
		{"label": "mouth_open_neutral", "state": neutral, "mode": "mouth"},
		{"label": "face_front_aged", "state": aged, "mode": "face_front"},
		{"label": "face_front_child", "state": young, "mode": "face_front"},
		{"label": "genitals_on", "state": neutral, "mode": "genitals", "genitals": true},
	]


func _process(_dt: float) -> void:
	_frame += 1
	# let the rig build + a couple frames settle before the first shot
	if _frame < 6:
		return
	if _shots.is_empty():
		print("proxy_render_check: ALL SHOTS DONE; dir = %s" % ProjectSettings.globalize_path(OUT))
		get_tree().quit(0)
		return
	# one shot every few frames so the morph + render settle
	if _frame % 4 != 0:
		return
	var shot = _shots.pop_front()
	if shot.get("genitals", false):
		_rig.show_genitals = true
		_rig.set_proxy_visible("genitals", true)
	# Reset to the natural-brown default, then apply any per-shot exotic eye params.
	_rig.set_eye_params(BodyRig.EYE_PARAMS_DEFAULT.duplicate(true))
	if shot.has("eye_params"):
		_rig.set_eye_params(shot["eye_params"])
	_rig.apply_body_state(shot["state"])
	# For the mouth shot, pose the JAW bone open so the teeth + tongue are VISIBLE inside
	# the (otherwise lip-closed) mouth — the whole point of verifying they exist + seat.
	if shot["mode"] == "mouth":
		_open_jaw()
	_frame_camera(shot["mode"])
	# render this frame, then grab on the next idle
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OUT.path_join("proxy_%s.png" % shot["label"])
	img.save_png(path)
	print("proxy_render_check: wrote %s" % ProjectSettings.globalize_path(path))


## Rotate the jaw bone open (pitch down) so the mouth gapes and the teeth/tongue show.
func _open_jaw() -> void:
	var sk := _rig.skeleton
	if sk == null:
		return
	var ji := sk.find_bone("jaw")
	if ji < 0:
		return
	var rest := sk.get_bone_rest(ji)
	sk.set_bone_pose_rotation(ji, rest.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, 0.32))


## World-space centre of the subject's right eyeball, read from the morphed proxy mesh
## (so the close-up tracks the real geometry, not a guessed offset).
func _eye_centre() -> Vector3:
	var am := _rig.proxy_instance.mesh as ArrayMesh
	for si in am.get_surface_count():
		if str(am.surface_get_name(si)) == "eyes":
			var v: PackedVector3Array = am.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			var c := Vector3.ZERO
			var n := 0
			for p in v:
				if p.x < 0.0:   # subject's right eye (negative x half)
					c += p; n += 1
			if n > 0:
				c /= n
			# push the focal point to the cornea front so the iris fills the frame
			return _rig.proxy_instance.global_transform * Vector3(c.x, c.y, maxf(c.z, 0.12))
	return Vector3(-0.044, 1.567, 0.13)


func _frame_camera(mode: String) -> void:
	# Frame off the MORPHED mesh, not the static eye bone: blendshape morphs (e.g. the
	# child shape) move the mesh verts but NOT the skeleton joints, so eye_height() (a bone
	# read) would point above a smaller morphed head. head_top() reads the morphed mesh; the
	# eyes sit ~12% of head height below the crown.
	var top := _rig.head_top() if _rig.skeleton != null else 1.7
	var sc := _rig.skeleton.scale.y if _rig.skeleton != null else 1.0
	var eye_y := top * sc - 0.085 * sc
	match mode:
		"face_front":
			_cam.look_at_from_position(Vector3(0, eye_y, 0.42), Vector3(0, eye_y, 0), Vector3.UP)
			_cam.fov = 35
		"face_34":
			_cam.look_at_from_position(Vector3(0.28, eye_y, 0.36), Vector3(0, eye_y - 0.01, 0), Vector3.UP)
			_cam.fov = 35
		"eye_front":
			# Tight on the (subject's) right eyeball. Its centre is measured from the rig:
			# x = -0.044, y = 1.567 (scale 1), front surface at z ~ 0.137. Stand back + a
			# narrow FOV (the camera clips if shoved right up to the cornea).
			var ec := _eye_centre()
			_cam.look_at_from_position(ec + Vector3(0, 0, 0.22), ec, Vector3.UP)
			_cam.fov = 12
		"eye_34":
			var ec2 := _eye_centre()
			_cam.look_at_from_position(ec2 + Vector3(0.10, 0.01, 0.20), ec2, Vector3.UP)
			_cam.fov = 13
		"mouth":
			# the mouth sits ~0.08 m below the eyes; look straight in, slightly from below.
			var my := eye_y - 0.085
			_cam.look_at_from_position(Vector3(0.0, my + 0.01, 0.34), Vector3(0, my, 0), Vector3.UP)
			_cam.fov = 26
		"genitals":
			var gy := eye_y * 0.52
			_cam.look_at_from_position(Vector3(0.0, gy + 0.05, 0.55), Vector3(0, gy, 0), Vector3.UP)
			_cam.fov = 40
		_:
			_cam.look_at_from_position(Vector3(0, eye_y, 0.5), Vector3(0, eye_y, 0), Vector3.UP)
