## GameSettings — autoload singleton for gameplay / accessibility settings.
##
## Single source of truth for non-input runtime settings:
##   - dynamic_fov_enabled  : bool   (default true)
##   - mouse_sensitivity    : float  (default 0.002)
##   - coyote_time          : float  (default 0.12 s)
##   - jump_buffer_time     : float  (default 0.15 s)
##
## Persisted to user://game_settings.cfg via ConfigFile.
## UI reads/writes through this autoload; PlayerController reads from it.

extends Node

const SAVE_PATH := "user://game_settings.cfg"

# ---------------------------------------------------------------------------
# Defaults (must match @export defaults in PlayerController)
# ---------------------------------------------------------------------------

const DEFAULT_DYNAMIC_FOV    := true
const DEFAULT_MOUSE_SENS     := 0.002
const DEFAULT_COYOTE_TIME    := 0.12
const DEFAULT_JUMP_BUFFER    := 0.15

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
var coyote_time:         float = DEFAULT_COYOTE_TIME
var jump_buffer_time:    float = DEFAULT_JUMP_BUFFER

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


func set_coyote_time(value: float) -> void:
	coyote_time = clampf(value, 0.0, 0.5)
	_save()
	settings_changed.emit()


func set_jump_buffer_time(value: float) -> void:
	jump_buffer_time = clampf(value, 0.0, 0.5)
	_save()
	settings_changed.emit()


func reset_all() -> void:
	dynamic_fov_enabled = DEFAULT_DYNAMIC_FOV
	mouse_sensitivity   = DEFAULT_MOUSE_SENS
	coyote_time         = DEFAULT_COYOTE_TIME
	jump_buffer_time    = DEFAULT_JUMP_BUFFER
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
	coyote_time         = cfg.get_value("gameplay", "coyote_time",         DEFAULT_COYOTE_TIME)
	jump_buffer_time    = cfg.get_value("gameplay", "jump_buffer_time",    DEFAULT_JUMP_BUFFER)

	# Heal corrupt/unusable persisted values. A previous bug could persist a
	# near-zero mouse sensitivity (looking around became impossible); any value
	# below the usable floor is treated as corrupt and reset to the default.
	if mouse_sensitivity < MOUSE_SENS_MIN:
		mouse_sensitivity = DEFAULT_MOUSE_SENS


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "dynamic_fov_enabled", dynamic_fov_enabled)
	cfg.set_value("gameplay", "mouse_sensitivity",   mouse_sensitivity)
	cfg.set_value("gameplay", "coyote_time",         coyote_time)
	cfg.set_value("gameplay", "jump_buffer_time",    jump_buffer_time)
	cfg.save(SAVE_PATH)
