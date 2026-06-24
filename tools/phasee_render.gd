## Manual render harness (NOT a committed test): Phase-E renders for the USER to judge the
## cross-seam UI de-defecting — Advanced popup dissolved, Mirror as a top-bar toggle, the
## beyond-human opt-in inline at the value, the history overlay de-overlapped from the pinned
## strip, and no redundant undo/redo icons. Aesthetics are USER-gated; this only produces frames
## + reports objective facts.
##
## Run windowed under xvfb:
##   BUILDE_OUT=/tmp/buildE xvfb-run -a -s "-screen 0 1280x800x24" godot4 --path . \
##     res://tools/phasee_render.tscn --quit-after 1200
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")

var _creator
var _out_dir := ""
var _frame := 0
var _done := false


func _ready() -> void:
	_out_dir = OS.get_environment("BUILDE_OUT")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	get_window().size = Vector2i(1280, 800)
	_creator = CreatorScene.instantiate()
	add_child(_creator)


func _process(_dt: float) -> void:
	_frame += 1
	if _done or _frame < 16:
		return
	_done = true

	var bs = _creator.get("_body_state")
	var caps = _creator.get("_caps")

	# (1) ENTRY — top bar shows the Mirror toggle; no dock; no inline opt-in (no value at edge).
	var optin_dials = _creator.get("_edge_optin_dials")
	var vis := 0
	for f in optin_dials:
		if (optin_dials[f] as CheckButton).visible:
			vis += 1
	print("buildE: entry inline opt-ins visible = %d (expect 0)" % vis)
	await _shoot("entry_topbar_mirror")

	# (2) VALUE AT EDGE — push masculinity to its human cap; its inline opt-in appears under the
	# Gender presentation dial in the pinned strip.
	bs.masculinity = float(caps.cap("masculinity", 0.0)[1])
	_creator.call("_apply_state")
	await get_tree().process_frame
	var mo = optin_dials.get("masculinity", null)
	print("buildE: masculinity inline opt-in visible = %s (expect true)" % str((mo as CheckButton).visible))
	await _shoot("value_at_edge_inline_optin")

	# (3) HISTORY OPEN — overlay anchored top-left, well clear of the bottom pinned strip.
	_creator.call("_toggle_history_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	var hp = _creator.get("_history_panel") as Control
	print("buildE: history rect = %s" % str(hp.get_global_rect()))
	await _shoot("history_open_no_overlap")

	# (4) REGION FOCUSED with a value at edge — the inline opt-in inside the dock too.
	_creator.call("_toggle_history_panel")   # close history
	await get_tree().process_frame
	_creator.call("_focus_into", 0)          # Face
	await get_tree().process_frame
	_creator.call("_focus_into", 0)          # Jaw & chin
	await get_tree().process_frame
	await _shoot("region_focused_dock")

	get_tree().quit(0)


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("buildE: wrote %s" % path)
