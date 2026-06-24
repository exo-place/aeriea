## Manual render harness (NOT a committed test): extreme close-up of the eye at HEAD to VERIFY
## the user-reported non-round iris/pupil discrepancy (character-creator-ux.md §8.7 / -and-body
## §6.3). Renders the real creator viewport. Also samples the rendered frame to MEASURE the
## iris/pupil aspect ratio objectively (width-vs-height of the dark pupil region in pixels).
##
##   EYE_OUT=/tmp/buildBfix xvfb-run -a godot4 --path . res://tools/eye_iris_render.tscn --quit-after 600
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")

var _creator
var _out_dir := ""
var _frame := 0
var _done := false


func _ready() -> void:
	_out_dir = OS.get_environment("EYE_OUT")
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
	# Find the eye bone world position so we frame the actual eyeball, not a guessed height.
	var rig = _creator.get("_rig")
	var skel: Skeleton3D = rig.get("skeleton")
	var eye_world := Vector3(0.0, 1.62, 0.0)
	var eye_local_x := 0.03
	if skel != null:
		var idx := skel.find_bone("eye.L")
		if idx >= 0:
			var gp: Transform3D = skel.global_transform * skel.get_bone_global_pose(idx)
			eye_world = gp.origin
			print("eye_iris_render: eye.L world = %s" % str(eye_world))
		else:
			print("eye_iris_render: eye.L bone NOT found; bones=", skel.get_bone_count())
	# Frame an EXTREME close-up on the left eye via a TELEPHOTO fov (robust to distance clamps).
	var cam: Camera3D = _creator.get("_camera")
	var rcam := get_viewport().get_camera_3d()
	print("eye_iris_render: _creator._camera == viewport cam ? %s ; rcam fov=%s"
		% [cam == rcam, (rcam.fov if rcam != null else -1.0)])
	if rcam != null:
		cam = rcam
	cam.current = true
	cam.fov = 6.0
	_creator.set("_pivot", eye_world)
	_creator.set("_distance", 0.6)
	_creator.set("_pitch", deg_to_rad(0.0))
	_creator.set("_yaw", deg_to_rad(6.0))   # slight angle so we see the eye, not the nose bridge
	_creator.call("_update_camera")
	cam.fov = 6.0
	await get_tree().process_frame
	cam.fov = 6.0
	await _shoot("eye_closeup_front")

	# Straight-on (yaw 0) too.
	_creator.set("_yaw", 0.0)
	_creator.call("_update_camera")
	cam.fov = 6.0
	await get_tree().process_frame
	await _shoot("eye_closeup_straight")

	# Report the eye proxy node scale (a non-uniform scale would stretch the model-space-normal
	# keyed iris into an ellipse even with pupil_aspect 1.0).
	var proxy = rig.get("proxy_instance")
	if proxy != null and proxy is Node3D:
		print("eye_iris_render: proxy scale = %s; proxy gxform basis scale = %s"
			% [str((proxy as Node3D).scale), str((proxy as Node3D).global_transform.basis.get_scale())])
	print("eye_iris_render: skeleton scale = %s" % str(skel.scale if skel != null else Vector3.ONE))
	var ep: Dictionary = rig.get("_eye_params")
	print("eye_iris_render: pupil_aspect = %s ; iris_radius = %s ; pupil_size = %s"
		% [ep.get("pupil_aspect"), ep.get("iris_radius"), ep.get("pupil_size")])

	get_tree().quit(0)


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var rc := get_viewport().get_camera_3d()
	print("eye_iris_render[%s]: at-draw cam fov=%s dist-from-pivot computed; cam pos=%s"
		% [label, (rc.fov if rc != null else -1.0), str(rc.global_position if rc != null else Vector3.ZERO)])
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % label)
	img.save_png(path)
	# Also save a CENTER CROP (the eye region) upscaled, so the iris/pupil shape is legible
	# without depending on the orbit camera framing exactly.
	var cw := 420; var ch := 420
	var cx := int(img.get_width() * 0.50) - cw / 2
	var cy := int(img.get_height() * 0.26) - ch / 2
	cx = clampi(cx, 0, img.get_width() - cw)
	cy = clampi(cy, 0, img.get_height() - ch)
	var crop := img.get_region(Rect2i(cx, cy, cw, ch))
	crop.resize(cw * 2, ch * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out_dir.path_join("%s_crop.png" % label))
	print("eye_iris_render: wrote %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	_measure_pupil(img, label)


## Measure the dark pupil blob's pixel bounding box → its width/height aspect. A round pupil
## under a square-pixel viewport reads aspect ≈ 1.0; a vertical slit reads < 1; horizontal > 1.
func _measure_pupil(img: Image, label: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w; var maxx := -1; var miny := h; var maxy := -1
	var count := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			# Pupil is near-black (the shader pupil_color ~0.02) and is the darkest region in a
			# lit eye close-up. Threshold low luminance + low saturation.
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if lum < 0.08 and maxf(maxf(c.r, c.g), c.b) < 0.12:
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
				count += 1
	if maxx < 0:
		print("eye_iris_render[%s]: no pupil blob found (no dark pixels)" % label)
		return
	var bw := maxx - minx + 1
	var bh := maxy - miny + 1
	print("eye_iris_render[%s]: dark-blob bbox = %dx%d px (%d px) -> aspect w/h = %.3f"
		% [label, bw, bh, count, float(bw) / float(bh)])
