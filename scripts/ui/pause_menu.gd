## PauseMenu — pause overlay with resume, controls, and quit buttons.
##
## The pause menu is a CanvasLayer (layer=10) that becomes visible on ui_pause.
## While open the mouse is freed and gameplay is paused via get_tree().paused.
## The player controller must have process_mode = PROCESS_MODE_PAUSABLE (default)
## so it stops while paused.
##
## This node is the single handler of ui_pause; the PlayerController no longer
## handles Escape / ui_cancel for mouse toggling — that is handled here.

extends CanvasLayer

@onready var _pause_panel: Control = %PausePanel
@onready var _controls_menu_scene: Control = %ControlsMenuScene
@onready var _resume_button: Button = %ResumeButton
@onready var _controls_button: Button = %ControlsButton
@onready var _quit_button: Button = %QuitButton

var _is_paused: bool = false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_pause_panel.visible = true
	_controls_menu_scene.visible = false

	_resume_button.pressed.connect(_on_resume)
	_controls_button.pressed.connect(_on_open_controls)
	_quit_button.pressed.connect(_on_quit)

	_controls_menu_scene.close_requested.connect(_on_controls_closed)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if _is_paused:
			if _controls_menu_scene.visible:
				_on_controls_closed()
			else:
				_unpause()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	_is_paused = true
	visible = true
	_pause_panel.visible = true
	_controls_menu_scene.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unpause() -> void:
	_is_paused = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume() -> void:
	_unpause()


func _on_open_controls() -> void:
	_pause_panel.visible = false
	_controls_menu_scene.visible = true


func _on_controls_closed() -> void:
	_controls_menu_scene.visible = false
	_pause_panel.visible = true


func _on_quit() -> void:
	get_tree().quit()


func is_game_paused() -> bool:
	return _is_paused
