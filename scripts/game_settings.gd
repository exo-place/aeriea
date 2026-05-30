## GameSettings — autoload singleton for gameplay / accessibility settings.
##
## Single source of truth for non-input runtime settings:
##   - dynamic_fov_enabled  : bool   (default true)
##   - mouse_sensitivity    : float  (default 0.002)
##
## Persisted to user://game_settings.cfg via ConfigFile.
## UI reads/writes through this autoload; PlayerController reads from it.
##
## Note: coyote_time and jump_buffer_time are designer-tuning values that live
## as @export vars on PlayerController (editor-tunable) and are NOT persisted
## here or exposed to players.

extends Node

const SAVE_PATH := "user://game_settings.cfg"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

const DEFAULT_DYNAMIC_FOV := true
const DEFAULT_MOUSE_SENS  := 0.002

## Input activation mode for a hold-style action (sprint today; aim/others later).
## HOLD  — the action is active only while the key is held (default; current feel).
## TOGGLE — a TAP toggles the action on/off (accessibility: no sustained hold).
## This is a REUSABLE mechanism (see ToggleHold in interpreted_player), deliberately
## not hardcoded to sprint, so aim can reuse the same tap-vs-hold helper later.
enum InputMode { HOLD, TOGGLE }

const DEFAULT_SPRINT_MODE := InputMode.HOLD

## Usable mouse-sensitivity bounds (radians per pixel of mouse motion).
## MIN is the lowest value the slider may reach AND the floor below which a
## loaded/persisted value is treated as corrupt and healed to the default.
## A value near 0 means "cannot look around", so the floor must be usable.
const MOUSE_SENS_MIN := 0.0004
const MOUSE_SENS_MAX := 0.02

# ---------------------------------------------------------------------------
# Live values
# ---------------------------------------------------------------------------

var dynamic_fov_enabled: bool  = DEFAULT_DYNAMIC_FOV
var mouse_sensitivity:   float = DEFAULT_MOUSE_SENS
## Sprint activation: HOLD (default) or TOGGLE (tap to toggle). Accessibility (#5).
var sprint_mode:         int   = DEFAULT_SPRINT_MODE

## Emitted after any setting changes so UI can refresh.
signal settings_changed


func _ready() -> void:
	_load()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_dynamic_fov(value: bool) -> void:
	dynamic_fov_enabled = value
	_save()
	settings_changed.emit()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MOUSE_SENS_MIN, MOUSE_SENS_MAX)
	_save()
	settings_changed.emit()


func set_sprint_mode(value: int) -> void:
	sprint_mode = value if value == InputMode.HOLD or value == InputMode.TOGGLE else DEFAULT_SPRINT_MODE
	_save()
	settings_changed.emit()


func reset_all() -> void:
	dynamic_fov_enabled = DEFAULT_DYNAMIC_FOV
	mouse_sensitivity   = DEFAULT_MOUSE_SENS
	sprint_mode         = DEFAULT_SPRINT_MODE
	_save()
	settings_changed.emit()


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	dynamic_fov_enabled = cfg.get_value("gameplay", "dynamic_fov_enabled", DEFAULT_DYNAMIC_FOV)
	mouse_sensitivity   = cfg.get_value("gameplay", "mouse_sensitivity",   DEFAULT_MOUSE_SENS)
	sprint_mode         = int(cfg.get_value("accessibility", "sprint_mode", DEFAULT_SPRINT_MODE))
	if sprint_mode != InputMode.HOLD and sprint_mode != InputMode.TOGGLE:
		sprint_mode = DEFAULT_SPRINT_MODE

	# Heal corrupt/unusable persisted values. A previous bug could persist a
	# near-zero mouse sensitivity (looking around became impossible); any value
	# below the usable floor is treated as corrupt and reset to the default.
	if mouse_sensitivity < MOUSE_SENS_MIN:
		mouse_sensitivity = DEFAULT_MOUSE_SENS


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "dynamic_fov_enabled", dynamic_fov_enabled)
	cfg.set_value("gameplay", "mouse_sensitivity",   mouse_sensitivity)
	cfg.set_value("accessibility", "sprint_mode",    sprint_mode)
	cfg.save(SAVE_PATH)
