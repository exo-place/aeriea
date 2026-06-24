## EVAL render harness (manual, not a test): comprehensive render set of the CURRENT
## character creator for an external visual critique. Writes PNGs to EVAL_OUT.
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")
const BodyArchetypesScript := preload("res://scripts/body/body_archetypes.gd")

var _creator
var _out := ""
var _frame := 0
var _done := false


func _ready() -> void:
	_out = OS.get_environment("EVAL_OUT")
	if _out == "":
		_out = "/tmp/eval"
	DirAccess.make_dir_recursive_absolute(_out)
	_creator = CreatorScene.instantiate()
	add_child(_creator)


func _set_cam(yaw_deg: float, pitch_deg: float, dist: float, pivot_y := -999.0) -> void:
	_creator.set("_yaw", deg_to_rad(yaw_deg))
	_creator.set("_pitch", deg_to_rad(pitch_deg))
	_creator.set("_distance", dist)
	if pivot_y > -900.0:
		var pv: Vector3 = _creator.get("_pivot")
		_creator.set("_pivot", Vector3(pv.x, pivot_y, pv.z))
	_creator.call("_update_camera")


func _process(_dt: float) -> void:
	_frame += 1
	if _done or _frame < 16:
		return
	_done = true
	await _run()
	get_tree().quit(0)


func _run() -> void:
	# --- DEFAULT character full-body shots (autosave removed -> clean default) ---
	_creator.call("_recenter_pivot")
	_creator.call("_update_camera")
	var center_y: float = (_creator.get("_pivot") as Vector3).y
	print("eval: default pivot center_y=%.3f" % center_y)

	_set_cam(0.0, -6.0, 3.4)        # front
	await _shoot("01_default_front")
	_set_cam(40.0, -6.0, 3.4)       # 3/4
	await _shoot("02_default_3q")
	_set_cam(180.0, -6.0, 3.4)      # back
	await _shoot("03_default_back")

	# --- FACE close-ups on the default head ---
	_set_cam(0.0, -2.0, 0.62, 1.62)
	await _shoot("04_face_front")
	_set_cam(35.0, -2.0, 0.62, 1.62)
	await _shoot("05_face_3q")

	# --- EYES extreme close-up ---
	_set_cam(0.0, -1.0, 0.30, 1.64)
	await _shoot("06_eyes_xcu")

	# --- SKIN close-up on torso/thigh under directional light ---
	_set_cam(20.0, -4.0, 0.55, 1.05)
	await _shoot("07_skin_torso")
	_set_cam(25.0, -10.0, 0.6, 0.62)
	await _shoot("08_skin_thigh")

	# --- UI: T1 (initial tier) full window ---
	if _creator.has_method("_set_tier"): _creator.call("_set_tier", 1)
	await get_tree().process_frame
	_set_cam(0.0, -6.0, 3.4, center_y)
	await _shoot("09_ui_t1")

	# --- UI: T3 (full controls) full window ---
	if _creator.has_method("_set_tier"): _creator.call("_set_tier", 3)
	await get_tree().process_frame
	await _shoot("10_ui_t3")

	# --- ARCHETYPE: feminine-curvy front + 3/4 ---
	var roster: Array = BodyArchetypesScript.load_roster()
	var picked := {}
	for e in roster:
		if String(e.get("name", "")).to_lower().find("curvy") >= 0:
			picked = e
			break
	if picked.is_empty() and not roster.is_empty():
		picked = roster[0]
	if not picked.is_empty():
		print("eval: archetype picked = %s" % String(picked.get("name", "?")))
		_creator.call("_pick_archetype", picked["state"], String(picked.get("name", "arch")))
		await get_tree().process_frame
		_creator.call("_recenter_pivot")
		var ay: float = (_creator.get("_pivot") as Vector3).y
		_set_cam(0.0, -6.0, 3.4, ay)
		await _shoot("11_archetype_curvy_front")
		_set_cam(40.0, -6.0, 3.4, ay)
		await _shoot("12_archetype_curvy_3q")


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s.png" % label)
	img.save_png(path)
	print("eval: wrote %s" % path)
