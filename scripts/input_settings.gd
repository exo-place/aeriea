## InputSettings — autoload singleton for rebindable input persistence.
##
## Single source of truth for all user input bindings.
## Loads saved bindings from user://input_bindings.cfg on startup,
## captures project defaults before applying overrides so "reset" always works,
## and exposes a clean API used by the rebind UI and controls overlay.
##
## Conflict policy: REPLACE — if a new event is already bound to another
## action in REBINDABLE_ACTIONS, the old binding is cleared first. This is the
## simplest correct behaviour: no two rebindable actions share the same key.

extends Node

## Ordered list of rebindable actions with human-readable labels.
## Only discrete keyboard/mouse-button actions; mouse-look axis and
## automatic verbs (wall-run, vault) are not included.
const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_forward",  "label": "Move Forward"},
	{"action": "move_backward", "label": "Move Backward"},
	{"action": "move_left",     "label": "Move Left"},
	{"action": "move_right",    "label": "Move Right"},
	{"action": "jump",          "label": "Jump"},
	{"action": "sprint",        "label": "Sprint"},
	{"action": "crouch",        "label": "Crouch / Slide"},
	{"action": "ui_pause",      "label": "Pause"},
	{"action": "toggle_controls_overlay", "label": "Controls Overlay"},
]

const SAVE_PATH := "user://input_bindings.cfg"

## Default events captured at startup (before any overrides are applied).
## Dictionary[action_name -> Array[InputEvent]]
var _defaults: Dictionary = {}

## Emitted after any binding changes, so UI can refresh.
signal bindings_changed


func _ready() -> void:
	_capture_defaults()
	_load_and_apply()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns a copy of the current event list for an action (may be empty).
func get_events(action: String) -> Array[InputEvent]:
	if not InputMap.has_action(action):
		return []
	return InputMap.action_get_events(action)


## Rebind an action to a single new InputEvent.
## Clears the old event list first (we keep one binding per action for
## keyboard/mouse). If the event is already assigned to another rebindable
## action, that action's binding is cleared first (REPLACE conflict policy).
func set_event(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return

	# Conflict resolution: clear the event from any other rebindable action.
	for entry in REBINDABLE_ACTIONS:
		var other: String = entry["action"]
		if other == action:
			continue
		if not InputMap.has_action(other):
			continue
		for existing in InputMap.action_get_events(other):
			if existing.is_match(event, true):
				InputMap.action_erase_event(other, existing)

	# Apply new binding.
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_save()
	bindings_changed.emit()


## Reset a single action to its project defaults.
func reset_action(action: String) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	if _defaults.has(action):
		for ev in _defaults[action]:
			InputMap.action_add_event(action, ev)
	_save()
	bindings_changed.emit()


## Reset ALL rebindable actions to project defaults.
func reset_all() -> void:
	for entry in REBINDABLE_ACTIONS:
		var a: String = entry["action"]
		if not InputMap.has_action(a):
			continue
		InputMap.action_erase_events(a)
		if _defaults.has(a):
			for ev in _defaults[a]:
				InputMap.action_add_event(a, ev)
	_save()
	bindings_changed.emit()


## Returns a display string for the first event bound to an action,
## or "(unbound)" if none.
func get_display_text(action: String) -> String:
	var events := get_events(action)
	if events.is_empty():
		return "(unbound)"
	return _event_display(events[0])


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _capture_defaults() -> void:
	for entry in REBINDABLE_ACTIONS:
		var a: String = entry["action"]
		if InputMap.has_action(a):
			# Store deep copies so later changes don't affect defaults.
			var copies: Array[InputEvent] = []
			for ev in InputMap.action_get_events(a):
				copies.append(ev.duplicate())
			_defaults[a] = copies
		else:
			_defaults[a] = []


func _load_and_apply() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		# No saved file — use project defaults as-is.
		return

	for entry in REBINDABLE_ACTIONS:
		var a: String = entry["action"]
		if not cfg.has_section_key("bindings", a):
			continue
		if not InputMap.has_action(a):
			continue
		var stored = cfg.get_value("bindings", a, null)
		if stored == null or not (stored is InputEvent):
			continue
		InputMap.action_erase_events(a)
		InputMap.action_add_event(a, stored)


func _save() -> void:
	var cfg := ConfigFile.new()
	for entry in REBINDABLE_ACTIONS:
		var a: String = entry["action"]
		if not InputMap.has_action(a):
			continue
		var events := InputMap.action_get_events(a)
		if events.is_empty():
			cfg.set_value("bindings", a, null)
		else:
			cfg.set_value("bindings", a, events[0])
	cfg.save(SAVE_PATH)


func _event_display(event: InputEvent) -> String:
	if event is InputEventKey:
		var kev := event as InputEventKey
		# physical_keycode gives layout-independent labels
		var kc := kev.physical_keycode
		if kc != KEY_NONE:
			return OS.get_keycode_string(kc)
		return OS.get_keycode_string(kev.keycode)
	if event is InputEventMouseButton:
		var mev := event as InputEventMouseButton
		match mev.button_index:
			MOUSE_BUTTON_LEFT:   return "LMB"
			MOUSE_BUTTON_RIGHT:  return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP:   return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			_: return "Mouse %d" % mev.button_index
	return event.as_text()
