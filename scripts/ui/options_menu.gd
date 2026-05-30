## OptionsMenu — accessibility and gameplay settings panel.
##
## Exposes:
##   - Dynamic FOV toggle (on/off)
##   - Mouse sensitivity slider
##
## All values read from and write to GameSettings autoload.
## Style mirrors the existing controls_menu.gd.

extends Control

## Emitted when the menu wants to close (back button pressed).
signal close_requested

@onready var _dynamic_fov_check: CheckButton  = %DynamicFovCheck
@onready var _mouse_sens_slider: HSlider      = %MouseSensSlider
@onready var _mouse_sens_label: Label         = %MouseSensLabel
@onready var _reset_button: Button            = %ResetButton
@onready var _back_button: Button             = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back)
	_reset_button.pressed.connect(_on_reset)

	# Configure slider ranges BEFORE connecting value_changed and BEFORE
	# setting initial values. A freshly-instanced HSlider has value 0 within
	# the default 0..100 range; assigning a min_value above the current value
	# silently clamps the value and emits value_changed. If signals were
	# connected first, that spurious emission would overwrite the saved
	# sensitivity with the slider minimum — the root cause of the "mouse
	# sensitivity defaults to 0 / cannot look around" bug. Order matters.
	_mouse_sens_slider.min_value = GameSettings.MOUSE_SENS_MIN
	_mouse_sens_slider.max_value = GameSettings.MOUSE_SENS_MAX
	_mouse_sens_slider.step = 0.0001

	# Seed current values without emitting (ranges are already set).
	_dynamic_fov_check.set_pressed_no_signal(GameSettings.dynamic_fov_enabled)
	_mouse_sens_slider.set_value_no_signal(GameSettings.mouse_sensitivity)

	# Now it is safe to listen for genuine user changes.
	_dynamic_fov_check.toggled.connect(_on_dynamic_fov_toggled)
	_mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)

	GameSettings.settings_changed.connect(_refresh_from_settings)
	_update_labels()


func _refresh_from_settings() -> void:
	# Block signals while updating controls to avoid feedback loops.
	_dynamic_fov_check.set_block_signals(true)
	_mouse_sens_slider.set_block_signals(true)

	_dynamic_fov_check.button_pressed = GameSettings.dynamic_fov_enabled
	_mouse_sens_slider.value = GameSettings.mouse_sensitivity

	_dynamic_fov_check.set_block_signals(false)
	_mouse_sens_slider.set_block_signals(false)

	_update_labels()


func _update_labels() -> void:
	# Mouse sensitivity: display as a 0–100 percentage of the usable range.
	var sens_pct := GameSettings.mouse_sensitivity / GameSettings.MOUSE_SENS_MAX * 100.0
	_mouse_sens_label.text = "%.0f%%" % sens_pct


func _on_dynamic_fov_toggled(pressed: bool) -> void:
	GameSettings.set_dynamic_fov(pressed)


func _on_mouse_sens_changed(value: float) -> void:
	GameSettings.set_mouse_sensitivity(value)


func _on_reset() -> void:
	GameSettings.reset_all()


func _on_back() -> void:
	close_requested.emit()
