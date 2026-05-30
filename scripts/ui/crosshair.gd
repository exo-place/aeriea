## Crosshair — minimal center-screen reticle.
##
## A self-contained HUD component: its own scene (crosshair.tscn) + script,
## drawn on its own CanvasLayer so it sits above the 3D viewport and below
## menus. Kept deliberately simple — a single small dot/cross drawn with
## _draw() — so a configurable crosshair style (shape, size, colour, gap,
## dynamic spread) can be layered on later WITHOUT reworking this scaffold.
##
## It never captures input (the Control uses MOUSE_FILTER_IGNORE) and it stays
## visible while the game is paused only if desired; by default it hides while
## paused so it doesn't sit on top of menus. Process mode is ALWAYS so the
## pause-visibility toggle still runs while the tree is paused.

extends CanvasLayer

## Reticle styling. These are plain vars (not a config resource yet) — the
## extension point for a future crosshair-style system is to drive these from
## GameSettings / a CrosshairStyle resource.
@export var color: Color = Color(1, 1, 1, 0.85)
## Length of each arm of the cross (px).
@export var arm_length: float = 6.0
## Gap between the center and the start of each arm (px).
@export var center_gap: float = 3.0
## Stroke thickness (px).
@export var thickness: float = 2.0
## Optional center dot radius (px). 0 disables the dot.
@export var dot_radius: float = 1.0
## Hide the crosshair while the game is paused.
@export var hide_when_paused: bool = true

var _reticle: Control


func _ready() -> void:
	# Above the 3D world; below pause menu (layer 10) and controls overlay (5).
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS

	_reticle = _Reticle.new()
	_reticle.crosshair = self
	# Fill the screen so its center is the viewport center; never eat input.
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reticle)


func _process(_delta: float) -> void:
	if hide_when_paused:
		var paused := get_tree().paused
		if _reticle.visible == paused:
			_reticle.visible = not paused


## Inner Control that does the actual drawing. Kept private to this component.
class _Reticle:
	extends Control

	var crosshair  # back-reference to the owning CanvasLayer for style values.

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var col: Color = crosshair.color
		var gap: float = crosshair.center_gap
		var arm: float = crosshair.arm_length
		var w: float = crosshair.thickness

		# Four arms (up, down, left, right) leaving a center gap.
		draw_line(c + Vector2(0, -gap), c + Vector2(0, -gap - arm), col, w)
		draw_line(c + Vector2(0,  gap), c + Vector2(0,  gap + arm), col, w)
		draw_line(c + Vector2(-gap, 0), c + Vector2(-gap - arm, 0), col, w)
		draw_line(c + Vector2( gap, 0), c + Vector2( gap + arm, 0), col, w)

		if crosshair.dot_radius > 0.0:
			draw_circle(c, crosshair.dot_radius, col)

	func _notification(what: int) -> void:
		# Redraw on resize so the reticle stays centered.
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
