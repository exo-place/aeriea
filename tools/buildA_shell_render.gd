## Manual render harness (NOT a committed test): Phase-A projection-shell renders for the USER
## to judge. Captures the full creator viewport (UI included) at three states: the entry screen
## (body foregrounded, pinned strip, no dock), a region focused (Face → Jaw & chin, dock shows
## only that region), and the archetype gallery overlay. Aesthetics are USER-gated; this only
## produces frames + reports objective facts.
##
## Run windowed under xvfb (1280x800 default; set BUILDA_OUT):
##   BUILDA_OUT=/tmp/buildA xvfb-run -a -s "-screen 0 1280x800x24" godot4 --path . \
##     res://tools/buildA_shell_render.tscn --quit-after 900
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")

var _creator
var _out_dir := ""
var _frame := 0
var _done := false


func _ready() -> void:
	_out_dir = OS.get_environment("BUILDA_OUT")
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

	# (1) ENTRY SCREEN — no focus → no dock; body centered; pinned strip + top bar.
	var dock = _creator.get("_dock_panel")
	print("buildA: entry dock.visible = %s (expect false)" % (dock as Control).visible)
	print("buildA: pinned dials = %d (expect 6)" % (_creator.get("_sliders") as Dictionary).size())
	await _shoot("entry")

	# (2) REGION FOCUSED — Face → Jaw & chin: the dock shows only that region's controls.
	_creator.call("_focus_into", 0)                       # Face
	await get_tree().process_frame
	# Find Jaw & chin and focus it.
	var face_children = _creator.call("_focus_to_path", [0])
	# Re-enter Face, then its first child (Jaw & chin is index 0 per the tree).
	_creator.call("_focus_into", 0)                       # Jaw & chin
	await get_tree().process_frame
	var bc = _creator.get("_breadcrumb_box")
	print("buildA: focused dock.visible = %s (expect true)" % (dock as Control).visible)
	await _shoot("region_focused_jaw")

	# (3) A deeper leaf with more controls — Torso → Chest & breasts.
	_creator.call("_focus_clear")
	await get_tree().process_frame
	_creator.call("_focus_into", 1)                       # Torso
	await get_tree().process_frame
	_creator.call("_focus_into", 0)                       # Chest & breasts
	await get_tree().process_frame
	await _shoot("region_focused_chest")

	# (4) ARCHETYPE GALLERY overlay.
	_creator.call("_focus_clear")
	await get_tree().process_frame
	_creator.call("_open_gallery")
	await get_tree().process_frame
	var gal = _creator.get("_gallery_panel")
	print("buildA: gallery.visible = %s (expect true)" % (gal as Control).visible)
	await _shoot("gallery")

	get_tree().quit(0)


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("buildA: wrote %s" % path)
