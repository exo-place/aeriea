extends Node
## Launcher shell — the app's main scene. A persistent top bar of mode tabs plus a
## content area that instances ONE mode scene at a time, freeing the previous one on
## switch. This is a persistent shell that swaps a child mode-scene (NOT change_scene),
## so the bar and switching logic survive across mode changes.
##
## Modes:
##   - Character Creator (scenes/character_creator.tscn) — 3rd-person body viewer/editor.
##   - Parkour Sandbox   (scenes/test_level.tscn)        — captures the mouse for FP look.
##   - Text Sandbox      (scenes/text_sandbox.tscn)      — transcript + input scaffold.
##   - TF Playground     (tools/tf_play.tscn)            — drives the transformation system live.
##
## Mouse-capture handoff: the parkour mode captures the mouse on its own _ready and
## recaptures on left-click. While captured the GUI bar isn't clickable, so the launcher
## intercepts Escape (BEFORE the mode sees input) to release capture back to VISIBLE — the
## bar is then usable to switch out. On every switch we also force MOUSE_MODE_VISIBLE so a
## newly-shown non-parkour mode never inherits a captured cursor, and the parkour mode's
## own _ready re-captures when it is the one being entered.
##
## The mode scenes remain standalone-runnable; nothing here is required for them to run
## directly — the launcher only instances them and frees them.

const MODES := [
	{ "label": "Character Creator", "scene": "res://scenes/character_creator.tscn" },
	{ "label": "Parkour Sandbox", "scene": "res://scenes/test_level.tscn" },
	{ "label": "Text Sandbox", "scene": "res://scenes/text_sandbox.tscn" },
	{ "label": "TF Playground", "scene": "res://tools/tf_play.tscn" },
]

const DEFAULT_MODE := 0  # Character Creator — sensible default (no mouse capture).

var _content: Node          # holder; the current mode scene is its single child
var _current_mode := -1
var _current_scene: Node = null
var _buttons: Array[Button] = []


func _ready() -> void:
	# Content holder sits UNDER the bar in tree order so the bar's CanvasLayer draws on top.
	_content = Node.new()
	_content.name = "ModeContent"
	add_child(_content)

	_build_top_bar()
	switch_to(DEFAULT_MODE)


## Build the persistent top bar on its own CanvasLayer so it always renders above the
## mode content (including the parkour 3D world and its own HUD CanvasLayers).
func _build_top_bar() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TopBar"
	layer.layer = 128  # well above any mode's HUD layers
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "BarPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	layer.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	var title := Label.new()
	title.text = "  aeriea  "
	title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	row.add_child(title)

	for i in MODES.size():
		var b := Button.new()
		b.text = MODES[i]["label"]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE  # don't steal focus from a mode's own UI
		b.pressed.connect(switch_to.bind(i))
		row.add_child(b)
		_buttons.append(b)


## Switch to mode `index`: free the current mode scene cleanly, reset mouse state, then
## instance the next. Re-selecting the active mode is a no-op (no needless reload).
func switch_to(index: int) -> void:
	if index == _current_mode:
		_sync_button_state()
		return

	# Free the outgoing mode. Freeing the parkour player ends its input handling; we
	# also reset mouse mode below so the cursor returns regardless of which mode it was.
	if is_instance_valid(_current_scene):
		_current_scene.queue_free()
		_current_scene = null

	# Reset shared global input state so no mode inherits a captured cursor. The parkour
	# mode re-captures in its own _ready; everything else wants a visible cursor.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A mode (e.g. via its pause menu) may have left the tree paused; clear it.
	get_tree().paused = false

	_current_mode = index
	var packed: PackedScene = load(MODES[index]["scene"])
	if packed == null:
		push_error("Launcher: failed to load mode scene: %s" % MODES[index]["scene"])
		return
	_current_scene = packed.instantiate()
	_content.add_child(_current_scene)
	_sync_button_state()


func _sync_button_state() -> void:
	for i in _buttons.size():
		_buttons[i].button_pressed = (i == _current_mode)


## Intercept input BEFORE the mode scene's _input runs. Escape releases a captured mouse
## back to the bar so the player can switch out of the parkour sandbox. (The parkour
## mode's pause menu also uses Escape, but it reads it in _unhandled_input AFTER us; we
## only consume Escape when the mouse is actually captured, leaving the pause flow intact
## when the cursor is already free.)
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_viewport().set_input_as_handled()
