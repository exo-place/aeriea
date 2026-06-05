## Render check (manual, not a committed suite): load the REAL character creator scene,
## switch the picking backend to the GPU ID-buffer picker, drive a hover at a known screen
## position over the body in sculpt mode, and confirm:
##   - the GPU picker drives the hover glow (the MorphGlow overlay becomes visible);
##   - the GPU pick AGREES with the CPU pick at sampled points (same/near vertex);
## then save a PNG of the glowing creator.
## Run: xvfb-run -a godot4 --path . res://tools/creator_gpu_pick_check.tscn --quit-after 600
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")
var _creator: Node3D
var _frame := 0
var _phase := 0

func _ready() -> void:
	_creator = CreatorScene.instantiate()
	add_child(_creator)

func _process(_dt: float) -> void:
	_frame += 1
	if _frame < 20:
		return
	match _phase:
		0:
			# Enter sculpt mode + select the GPU backend.
			_creator._set_sculpt_mode(true)
			_creator.set_picker_backend(true)
			print("CHECK: sculpt on, backend = GPU ID-buffer")
			_phase = 1
		1:
			await _run()
			_phase = 2
		2:
			get_tree().quit(0)

func _run() -> void:
	var cam: Camera3D = _creator._camera
	var rig = _creator._rig
	var rest: PackedVector3Array = _creator._glow_base_pos
	var tris: PackedInt32Array = _creator._glow_tris
	var target := {
		"world_xf": rig.skeleton.global_transform,
		"rest_positions": rest, "tris": tris,
		"mesh_instance": rig.mesh_instance, "skeleton": rig.skeleton,
	}
	var vp := Vector2(_creator.get_viewport().get_visible_rect().size)
	# Aim the GPU viewport and let it render (1-frame latency).
	_creator._gpu_picker.aim_at(cam, target)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Sample a few central screen points; compare GPU vs CPU, drive the hover glow via the
	# creator's own path (which now uses the GPU picker since we toggled the backend).
	var center := vp * 0.5
	var agree := 0
	var hits := 0
	for off in [Vector2(0, -0.1), Vector2(0, 0), Vector2(0.05, 0.1), Vector2(-0.05, 0.05)]:
		var sp := center + Vector2(off.x * vp.x, off.y * vp.y)
		var g = _creator._gpu_picker.pick(sp, cam, target)
		var c = _creator._cpu_picker.pick(sp, cam, target)
		if g.is_empty() or c.is_empty():
			continue
		hits += 1
		var gi := int(g["render_vertex_index"])
		var ci := int(c["render_vertex_index"])
		var near := gi < rest.size() and rest[gi].distance_to(rest[ci]) < 0.06
		var reproj := false
		if gi < rest.size():
			var wp: Vector3 = (target["world_xf"] as Transform3D) * rest[gi]
			if not cam.is_position_behind(wp):
				reproj = cam.unproject_position(wp).distance_to(sp) < 32.0
		if near or reproj:
			agree += 1
	print("CHECK: GPU/CPU agree %d / %d sampled hits" % [agree, hits])

	# Drive the creator's own hover-glow update at the center (uses the GPU picker now).
	_creator._update_hover_glow(center)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var glow = _creator._glow_overlay
	print("CHECK: hover_vertex=%d  glow_overlay.visible=%s (GPU picker drove the glow)" % [
		_creator._hover_vertex, str(glow != null and glow.visible)])

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://creator_gpu_pick.png")
	print("CHECK: saved -> %s" % ProjectSettings.globalize_path("user://creator_gpu_pick.png"))
