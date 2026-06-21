## Blinking — autonomous deterministic blink.
##
## PORTED (Path A) from BDCC2 `Gestures/Blinking.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
## Path-A cuts: BDCC2 used the global `RNG` autoload + a Tween for the lid sweep.
## Here the inter-blink interval is drawn from the rig's SEEDED rng, and the lid
## sweep is integrated per-frame (a small state machine) — a pure function of
## (seed, accumulated dt). No wall-clock, no global RNG.
extends FaceGesture

var blink: float = 0.0          # 0 open .. 1 closed
var blink_timer: float = 0.0
# 0 idle, 1 closing, 2 holding, 3 opening
var _phase: int = 0
var _phase_t: float = 0.0

const CLOSE_TIME := 0.06
const HOLD_TIME := 0.05
const OPEN_TIME := 0.14


func _init() -> void:
	id = "Blinking"
	priority = 5.0


func _next_interval() -> float:
	if rng == null:
		return 7.0
	return rng.randf_range(5.0, 15.0)


func process_values(rig, dt: float) -> void:
	if blink_timer <= 0.0 and _phase == 0:
		blink_timer = _next_interval()
	blink_timer -= dt
	if blink_timer <= 0.0 and _phase == 0:
		_phase = 1
		_phase_t = 0.0
		blink_timer = _next_interval()

	_phase_t += dt
	match _phase:
		1:  # closing
			blink = clampf(_phase_t / CLOSE_TIME, 0.0, 1.0)
			if _phase_t >= CLOSE_TIME:
				_phase = 2; _phase_t = 0.0
		2:  # holding closed
			blink = 1.0
			if _phase_t >= HOLD_TIME:
				_phase = 3; _phase_t = 0.0
		3:  # opening
			blink = clampf(1.0 - _phase_t / OPEN_TIME, 0.0, 1.0)
			if _phase_t >= OPEN_TIME:
				_phase = 0; _phase_t = 0.0; blink = 0.0

	# Composite: blink forces eyes toward closed over whatever the base set.
	rig.val_eyes_closed = rig.val_eyes_closed * (1.0 - blink) + blink
