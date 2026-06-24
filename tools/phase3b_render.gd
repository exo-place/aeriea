## Manual render harness (NOT a committed test): Phase-3b before/after of the creator UI.
## Renders the creator's full viewport (UI panels + 3D body) for the USER to judge — the
## tier structure, the T0 archetype pick grid, and an archetype applied. Visual/UX aesthetics
## (does the panel read well, do the archetypes look good, roster expansion) are USER-gated and
## NOT self-certified here; this only produces the frames + reports objective facts.
##
## Run windowed under xvfb:
##   PHASE3B_OUT=/tmp/phase3b/before xvfb-run -a godot4 --path . res://tools/phase3b_render.tscn --quit-after 400
## Set PHASE3B_MODE=before (T0/T1 default) or after (T3 + an archetype applied).
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")

var _creator
var _out_dir := ""
var _mode := "before"
var _frame := 0
var _done := false


func _ready() -> void:
	_out_dir = OS.get_environment("PHASE3B_OUT")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_mode = OS.get_environment("PHASE3B_MODE")
	if _mode == "":
		_mode = "before"
	_creator = CreatorScene.instantiate()
	add_child(_creator)


func _process(_dt: float) -> void:
	_frame += 1
	if _done or _frame < 12:
		return
	_done = true
	if _mode == "before":
		# BEFORE: the creator as it opens — T1 (default tier), the T0 archetype grid visible,
		# no archetype applied yet, T2/T3 sections hidden.
		if _creator.has_method("_set_tier"): _creator.call("_set_tier", 1)
		await _shoot("creator_t0_t1")
	else:
		# AFTER: tier raised to T3 (every section revealed, additive), an archetype applied.
		var roster: Array = _creator.get("_archetypes")
		if not roster.is_empty():
			# Pick a clearly-distinct archetype (a curvy/heavy build) so the body change reads.
			var chosen: Dictionary = roster[0]
			for e in roster:
				if String(e["build"]) == "curvy" or String(e["build"]) == "athletic":
					chosen = e
					break
			_creator.call("_pick_archetype", chosen["state"], String(chosen["name"]))
		if _creator.has_method("_set_tier"): _creator.call("_set_tier", 3)
		await get_tree().process_frame
		await _shoot("creator_t3_archetype")
	get_tree().quit(0)


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("phase3b_render: wrote %s" % path)
