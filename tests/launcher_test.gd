## Launcher test — proves the launcher shell can instance each of the three mode scenes
## and free them on switch, without error, and that the persistent top bar survives the
## switches. Does NOT exercise mouse-capture (headless-ish under xvfb), only the
## instance/free mechanism the shell relies on.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/launcher_test.tscn --quit-after 8000
extends Node

const LauncherScene := preload("res://scenes/launcher.tscn")

var _pass := 0
var _fail := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok: ", label)
	else:
		_fail += 1
		print("  FAIL: ", label)


func _ready() -> void:
	print("\n=== aeriea LAUNCHER — mode instance/free + persistent bar ===\n")
	await _run()
	print("\n=== RESULTS: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _content_child(launcher: Node) -> Node:
	var holder := launcher.get_node_or_null("ModeContent")
	if holder == null or holder.get_child_count() == 0:
		return null
	return holder.get_child(0)


func _run() -> void:
	var launcher: Node = LauncherScene.instantiate()
	add_child(launcher)
	# Let _ready run and the default mode instance.
	await get_tree().process_frame
	await get_tree().process_frame

	_check(launcher.get_node_or_null("TopBar") != null, "persistent top bar exists")
	_check(launcher._current_mode == launcher.DEFAULT_MODE, "boots to default mode")
	_check(_content_child(launcher) != null, "default mode scene instanced")

	# Switch through every mode; each should free the previous and instance the next.
	for i in launcher.MODES.size():
		launcher.switch_to(i)
		await get_tree().process_frame
		await get_tree().process_frame
		var child := _content_child(launcher)
		_check(child != null, "mode %d (%s) instanced" % [i, launcher.MODES[i]["label"]])
		_check(launcher._content.get_child_count() == 1,
			"mode %d: exactly one mode child (previous freed)" % i)
		_check(launcher.get_node_or_null("TopBar") != null,
			"mode %d: top bar survives switch" % i)

	# Re-selecting the active mode is a no-op (no reload / no orphan).
	var before := _content_child(launcher)
	launcher.switch_to(launcher._current_mode)
	await get_tree().process_frame
	_check(_content_child(launcher) == before, "re-selecting active mode is a no-op")

	launcher.queue_free()
	await get_tree().process_frame
