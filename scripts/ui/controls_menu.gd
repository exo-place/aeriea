## ControlsMenu — rebind UI panel.
##
## Listed from InputSettings.REBINDABLE_ACTIONS. Each row shows the
## human-readable label and a button that displays the current binding.
## Clicking a binding button enters "press a key…" capture mode;
## the next keyboard key or mouse button press becomes the new binding.
## Escape cancels the capture without changing anything.
##
## A per-row reset button and a global "Reset All" button are included.

extends Control

## Emitted when the menu wants to close (back button pressed).
signal close_requested

@onready var _rows_container: VBoxContainer = %RowsContainer
@onready var _reset_all_button: Button = %ResetAllButton
@onready var _capture_label: Label = %CaptureLabel
@onready var _back_button: Button = %BackButton

## The action currently waiting for a rebind input, or "" if not capturing.
var _capturing_action: String = ""
## The button that was pressed to start capture (so we can restore its text on cancel).
var _capturing_button: Button = null

## Map action name → bind button node, so we can update after a change.
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	_reset_all_button.pressed.connect(_on_reset_all)
	_back_button.pressed.connect(_on_back)
	_capture_label.visible = false

	InputSettings.bindings_changed.connect(_refresh_all_labels)
	_build_rows()


func _build_rows() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	_bind_buttons.clear()

	for entry in InputSettings.REBINDABLE_ACTIONS:
		var action: String = entry["action"]
		var label_text: String = entry["label"]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = label_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_stretch_ratio = 2.0
		row.add_child(lbl)

		var bind_btn := Button.new()
		bind_btn.text = InputSettings.get_display_text(action)
		bind_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bind_btn.pressed.connect(_on_bind_button_pressed.bind(action, bind_btn))
		row.add_child(bind_btn)

		var reset_btn := Button.new()
		reset_btn.text = "Reset"
		reset_btn.pressed.connect(_on_reset_action.bind(action))
		row.add_child(reset_btn)

		_rows_container.add_child(row)
		_bind_buttons[action] = bind_btn


func _refresh_all_labels() -> void:
	for action in _bind_buttons:
		var btn: Button = _bind_buttons[action]
		btn.text = InputSettings.get_display_text(action)


func _on_bind_button_pressed(action: String, btn: Button) -> void:
	if _capturing_action != "":
		# Already capturing — cancel previous and start fresh on this action.
		_cancel_capture()
	_capturing_action = action
	_capturing_button = btn
	btn.text = "Press a key…"
	_capture_label.visible = true
	set_process_unhandled_input(true)


func _cancel_capture() -> void:
	if _capturing_button != null:
		_capturing_button.text = InputSettings.get_display_text(_capturing_action)
	_capturing_action = ""
	_capturing_button = null
	_capture_label.visible = false
	set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if _capturing_action == "":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		if kev.physical_keycode == KEY_ESCAPE:
			# Cancel — restore previous label without rebinding.
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return
		# Accept the key — use physical_keycode so binding is layout-independent.
		var new_event := InputEventKey.new()
		new_event.physical_keycode = kev.physical_keycode
		InputSettings.set_event(_capturing_action, new_event)
		_finish_capture()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		var mev := event as InputEventMouseButton
		InputSettings.set_event(_capturing_action, mev.duplicate())
		_finish_capture()
		get_viewport().set_input_as_handled()
		return


func _finish_capture() -> void:
	_capturing_action = ""
	_capturing_button = null
	_capture_label.visible = false
	set_process_unhandled_input(false)
	# Labels are refreshed via bindings_changed signal.


func _on_reset_action(action: String) -> void:
	if _capturing_action == action:
		_cancel_capture()
	InputSettings.reset_action(action)


func _on_reset_all() -> void:
	if _capturing_action != "":
		_cancel_capture()
	InputSettings.reset_all()


func _on_back() -> void:
	if _capturing_action != "":
		_cancel_capture()
	close_requested.emit()
