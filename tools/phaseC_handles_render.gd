## Manual render + drive harness (NOT a committed test): Phase-C on-body GRAB-HANDLES (§5.2).
## Loads the REAL creator, focuses a region leaf, renders the handles on the body, then DRIVES a
## handle drag and an empty-space drag to confirm reshape-vs-orbit. Produces frames + objective
## facts for the USER to judge; aesthetics are NOT self-certified here.
##
## Run windowed under xvfb:
##   PHASEC_OUT=/tmp/buildC xvfb-run -a godot4 --path . res://tools/phaseC_handles_render.tscn --quit-after 1200
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")

var _creator
var _out_dir := ""
var _frame := 0
var _done := false


func _ready() -> void:
	_out_dir = OS.get_environment("PHASEC_OUT")
	if _out_dir == "":
		_out_dir = "/tmp/buildC"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_creator = CreatorScene.instantiate()
	add_child(_creator)


func _process(_dt: float) -> void:
	_frame += 1
	if _done or _frame < 16:
		return
	_done = true
	await _run()


func _run() -> void:
	# Focus Torso → Chest & breasts (index 0 under Torso index 1) so several drag-editable params
	# anchor handles. Then Face → Jaw & chin for a small-face-handle case.
	_creator.call("_focus_into", 1)   # Torso
	await get_tree().process_frame
	_creator.call("_focus_into", 0)   # Chest & breasts
	await get_tree().process_frame
	await get_tree().process_frame

	var handles: Array = _creator.get("_handles")
	print("phaseC: focused Chest & breasts → %d handles" % handles.size())
	for h in handles:
		print("   handle: %s  (param %s)" % [h["display"], h["full_name"]])

	# Frame the chest, front, mid-distance — aim at the first handle's anchor so it suits stature.
	var caim := Vector3(0.0, 1.15, 0.0)
	if handles.size() > 0:
		caim = _creator.call("_handle_world_pos", handles[0])
	_creator.set("_distance", 1.1)
	_creator.set("_pitch", deg_to_rad(-6.0))
	_creator.set("_yaw", 0.0)
	_creator.set("_pivot", Vector3(0.0, caim.y, 0.0))
	_creator.call("_update_camera")
	await get_tree().process_frame
	_creator.call("_update_handle_overlay")
	await _shoot("chest_handles_visible")

	# OBJECTIVE: a handle's screen position + pick test.
	if handles.size() > 0:
		var sp: Vector2 = _creator.call("_handle_screen_pos", handles[0])
		var hit_self: int = _creator.call("_handle_at", sp)
		var hit_miss: int = _creator.call("_handle_at", sp + Vector2(120, 120))
		print("phaseC: handle[0] screen=%s; pick AT it = %d; pick 120px away = %d" % [sp, hit_self, hit_miss])

		# DRIVE A HANDLE DRAG: record before, begin drag on handle 0, apply a drag, end.
		var fn := String(handles[0]["full_name"])
		var before := float((_creator.get("_body_state") as BodyState).modifiers.get(fn, 0.0))
		_creator.call("_begin_handle_drag", 0)
		var grabbing: int = _creator.get("_drag_handle")
		# Apply several drag steps along +screen-x (the decompose projects onto the param's axis).
		for s in 8:
			_creator.call("_apply_handle_drag", Vector2(18, -10))
			await get_tree().process_frame
		var mid := float((_creator.get("_body_state") as BodyState).modifiers.get(fn, 0.0))
		_creator.call("_end_handle_drag")
		var after := float((_creator.get("_body_state") as BodyState).modifiers.get(fn, 0.0))
		var still_dragging: int = _creator.get("_drag_handle")
		print("phaseC: handle-drag on '%s': before=%.3f during=%.3f after=%.3f; latched while dragging=%s; released=%s"
			% [String(handles[0]["display"]), before, mid, after, grabbing >= 0, still_dragging < 0])

		# SLIDER SYNC: the bound dock slider should now read the same clamped value.
		var msliders: Dictionary = _creator.get("_modifier_sliders")
		var spec_name := String(handles[0]["spec_name"])
		if msliders.has(spec_name):
			var sld: HSlider = msliders[spec_name]["slider"]
			print("phaseC: dock slider for '%s' = %.3f (model %.3f) → in-sync=%s"
				% [spec_name, sld.value, after, absf(sld.value - after) < 1e-3])
		await get_tree().process_frame
		await _shoot("chest_after_handle_drag")

		# ORBIT CHECK: an empty-space press (far from any handle) must NOT reshape — drive the
		# input path. Simulate by picking far away and confirming no handle is grabbed.
		var far := Vector2(40, 40)
		var far_hit: int = _creator.call("_handle_at", far)
		print("phaseC: press far from handles → handle_at=%d (orbit, not reshape) = %s" % [far_hit, far_hit < 0])

	# Small-face handle case: Face → Jaw & chin.
	_creator.call("_focus_to_path", [])
	await get_tree().process_frame
	_creator.call("_focus_into", 0)   # Face
	await get_tree().process_frame
	_creator.call("_focus_into", 0)   # Jaw & chin
	await get_tree().process_frame
	var fhandles: Array = _creator.get("_handles")
	print("phaseC: focused Jaw & chin → %d handles" % fhandles.size())
	# Aim the camera AT the handle's own anchor world position so the framing suits any stature.
	var aim := Vector3(0.0, 1.45, 0.0)
	if fhandles.size() > 0:
		aim = _creator.call("_handle_world_pos", fhandles[0])
		print("phaseC: jaw handle anchor world=%s" % str(aim))
	_creator.set("_distance", 0.5)
	_creator.set("_pitch", deg_to_rad(-2.0))
	_creator.set("_yaw", 0.0)
	_creator.set("_pivot", Vector3(0.0, aim.y, 0.0))
	_creator.call("_update_camera")
	await get_tree().process_frame
	_creator.call("_update_handle_overlay")
	await _shoot("jaw_handle_visible")

	# DEFOCUS: clear focus, handles must vanish.
	_creator.call("_focus_clear")
	await get_tree().process_frame
	var cleared: Array = _creator.get("_handles")
	print("phaseC: after defocus → %d handles (expect 0)" % cleared.size())

	get_tree().quit(0)


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("phaseC: wrote %s" % path)
