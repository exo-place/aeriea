## ControlsOverlay — in-game HUD listing current bindings.
##
## Toggled by the toggle_controls_overlay action (default: F1).
## Always reads bindings live from InputSettings / InputMap so it reflects
## any rebind immediately.
## A small "Press F1 for controls" hint is shown at startup; it fades after
## a few seconds so it doesn't clutter the screen permanently.

extends CanvasLayer

@onready var _panel: PanelContainer = %OverlayPanel
@onready var _rows_container: VBoxContainer = %OverlayRows
@onready var _hint_label: Label = %HintLabel

## Automatic, non-rebindable parkour verbs. These have no key — they trigger
## from movement context. Listed so players understand wall-run is automatic
## (triggered by moving fast alongside a wall) and NOT bound to Crouch/Ctrl.
const AUTOMATIC_VERBS: Array[Dictionary] = [
	{"label": "Wall-run", "trigger": "Automatic — run fast alongside a wall"},
	{"label": "Wall-jump", "trigger": "Automatic — Jump while wall-running"},
	{"label": "Vault / Mantle", "trigger": "Automatic — approach a ledge with speed"},
	{"label": "Slide", "trigger": "Automatic — Crouch while moving fast"},
]

const HINT_FADE_DURATION := 4.0
const HINT_VISIBLE_DURATION := 3.0
var _hint_timer: float = 0.0
var _hint_fading: bool = false
var _overlay_visible: bool = false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_hint_label.visible = true
	_hint_label.modulate = Color(1, 1, 1, 1)

	# Update the hint label to show the actual toggle key.
	_refresh_hint_label()

	InputSettings.bindings_changed.connect(_refresh_rows)
	_build_rows()


func _process(delta: float) -> void:
	# Fade out the hint label.
	if _hint_label.visible:
		_hint_timer += delta
		if _hint_timer >= HINT_VISIBLE_DURATION:
			var fade_progress := (_hint_timer - HINT_VISIBLE_DURATION) / HINT_FADE_DURATION
			_hint_label.modulate.a = 1.0 - clampf(fade_progress, 0.0, 1.0)
			if fade_progress >= 1.0:
				_hint_label.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls_overlay"):
		_overlay_visible = not _overlay_visible
		_panel.visible = _overlay_visible
		if _overlay_visible:
			_refresh_rows()
		get_viewport().set_input_as_handled()


func _refresh_hint_label() -> void:
	var key_text := InputSettings.get_display_text("toggle_controls_overlay")
	_hint_label.text = "Press %s for controls" % key_text


func _build_rows() -> void:
	for child in _rows_container.get_children():
		child.queue_free()

	for entry in InputSettings.REBINDABLE_ACTIONS:
		var action: String = entry["action"]
		var label_text: String = entry["label"]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = label_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_stretch_ratio = 2.0

		var key_lbl := Label.new()
		key_lbl.text = InputSettings.get_display_text(action)
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		row.add_child(lbl)
		row.add_child(key_lbl)
		_rows_container.add_child(row)

	# Automatic verbs section — these have no binding and are NOT on Crouch/Ctrl.
	var sep := HSeparator.new()
	_rows_container.add_child(sep)

	var header := Label.new()
	header.text = "Automatic (no key)"
	_rows_container.add_child(header)

	for entry in AUTOMATIC_VERBS:
		var auto_row := HBoxContainer.new()
		auto_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var auto_lbl := Label.new()
		auto_lbl.text = entry["label"]
		auto_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto_lbl.size_flags_stretch_ratio = 2.0

		var trig_lbl := Label.new()
		trig_lbl.text = entry["trigger"]
		trig_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trig_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		auto_row.add_child(auto_lbl)
		auto_row.add_child(trig_lbl)
		_rows_container.add_child(auto_row)


func _refresh_rows() -> void:
	_build_rows()
	_refresh_hint_label()


## Called by PauseMenu to show the controls overlay from the pause UI.
func show_overlay() -> void:
	_overlay_visible = true
	_panel.visible = true
	_refresh_rows()


## Called by PauseMenu to hide the overlay when unpausing.
func hide_overlay() -> void:
	_overlay_visible = false
	_panel.visible = false
