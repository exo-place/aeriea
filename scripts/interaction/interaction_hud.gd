## InteractionHUD — the diegetic-legibility surface for the interaction system.
##
## Low affordance opacity, Miller-compliant: it shows ONLY the contextual verb
## prompt for what is possible right now (one short line under the reticle) and
## tints a small reticle dot when an interactable is focused. There is NO standing
## menu, no list of everything — the edge set is surfaced by REMOVAL (only the live
## verbs), exactly the affordance-surfaces.md prescription. The player perceives
## what they can do by looking; the prompt text is data handed up from the
## Interactor (prompt_changed), so this HUD is a pure projection of interaction
## state. (Slightly more than pure-diegetic — a real build would put this on the
## hand/object — but it is contextual, minimal, and state-driven, which is the
## legibility property being proven here.)
extends CanvasLayer

@export var interactor_path: NodePath

var _label: Label
var _reticle: Control
var _focused: bool = false


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Focus reticle dot, centred. Changes colour on focus (diegetic look-at cue).
	_reticle = _FocusDot.new()
	_reticle.hud = self
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reticle)

	# Contextual prompt line, just below centre.
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.position = Vector2(-200, 28)
	_label.size = Vector2(400, 24)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	var interactor := get_node_or_null(interactor_path)
	if interactor:
		interactor.prompt_changed.connect(_on_prompt_changed)
		interactor.focus_changed.connect(_on_focus_changed)


func _on_prompt_changed(text: String) -> void:
	if _label:
		_label.text = text


func _on_focus_changed(focused: bool) -> void:
	_focused = focused
	if _reticle:
		_reticle.queue_redraw()


func is_focused() -> bool:
	return _focused


## Small center dot that brightens/recolours when an interactable is focused —
## the minimal diegetic "you can act on this" signal (no text needed to read it).
class _FocusDot:
	extends Control

	var hud

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		if hud != null and hud.is_focused():
			# Focused: larger, warm ring — reads as "actionable".
			draw_circle(c, 5.0, Color(1.0, 0.85, 0.2, 0.95))
			draw_arc(c, 9.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.2, 0.8), 2.0)
		else:
			# Idle: small neutral dot.
			draw_circle(c, 2.0, Color(1, 1, 1, 0.7))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
