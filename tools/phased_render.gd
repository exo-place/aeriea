## Manual render harness (NOT a committed test): Phase-D renders for the USER to judge — the
## history overlay (human labels + collapse), the single Share/Open top bar, and the Advanced
## popup's plain "Allow beyond-human extremes" toggle (no extremeness slider / % readout).
## Aesthetics are USER-gated; this only produces frames + reports objective facts.
##
## Run windowed under xvfb:
##   PHASED_OUT=/tmp/buildD xvfb-run -a godot4 --path . res://tools/phased_render.tscn --quit-after 900
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")
const HistoryTreeScript := preload("res://scripts/util/history_tree.gd")

var _creator
var _out_dir := ""
var _frame := 0
var _done := false


func _ready() -> void:
	_out_dir = OS.get_environment("PHASED_OUT")
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
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var bs: BodyState = _creator.get("_body_state")
	# Fresh history so the rendered overlay shows THIS session's labels, not a persisted autosave.
	var hist = HistoryTreeScript.new(bs.to_dict(), "initial")
	_creator.set("_history", hist)

	# (a) Several edits incl. RE-EDITING one value many times (collapse) + a different value.
	for v in [40.0, 52.0, 61.0, 70.0]:        # four edits to gender — should collapse to ONE node
		bs.masculinity = v
		_creator.call("_commit_axis", "masculinity", v)
	bs.age_years = 28.0                         # a different value -> a NEW node
	_creator.call("_commit_axis", "age_years", 28.0)
	bs.height_cm = 178.0                        # another value -> a NEW node
	_creator.call("_commit_axis", "height_cm", 178.0)
	_creator.call("_refresh_history_panel")

	var labels: Array = []
	for e in hist.structure():
		labels.append(String(e["label"]))
	print("phased_render: history labels = %s" % str(labels))
	print("phased_render: node_count (root + 3 settled edits expected = 4) = %d" % hist.node_count())

	# (b) The TOP BAR — count Share / Open buttons.
	var ui: Array = []
	_collect_text(_creator, ui)
	print("phased_render: Share buttons=%d  Open buttons=%d" % [ui.count("Share"), ui.count("Open")])
	print("phased_render: 'Allow beyond-human extremes' present = %s" %
		ui.has("Allow beyond-human extremes"))
	print("phased_render: extremeness amount slider member = %s (expect <null>)" %
		str(_creator.get("_extreme_slider")))

	# Frame the body, then shoot the entry surface + top bar.
	await get_tree().process_frame
	await _shoot("creator_topbar_share_open")

	# (c) The HISTORY overlay — human labels + collapsed gender node.
	_creator.call("_toggle_history_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot("creator_history_human_labels")

	# (d) The beyond-human opt-in is now INLINE at the value (§8.4; the Advanced popup is dissolved
	# — Phase E). Push a dial to its human edge so its inline "Allow beyond-human extremes" toggle
	# appears under it.
	_creator.call("_toggle_history_panel")   # close history
	var bs = _creator.get("_body_state")
	var caps = _creator.get("_caps")
	bs.masculinity = float(caps.cap("masculinity", 0.0)[1])
	_creator.call("_apply_state")
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot("creator_inline_plain_limit")


func _collect_text(n: Node, out: Array) -> void:
	if n is Button or n is Label or n is CheckBox:
		out.append(String((n as Control).text))
	if n is PopupMenu:
		var pm := n as PopupMenu
		for i in pm.item_count:
			out.append(pm.get_item_text(i))
	for c in n.get_children():
		_collect_text(c, out)


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("phased_render: wrote %s" % path)
