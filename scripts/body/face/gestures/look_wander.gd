## LookWander — autonomous deterministic eye saccades (idle eye life).
##
## PORTED (Path A) from BDCC2 `Gestures/LookDir.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
## Path-A cuts: BDCC2 used the global `RNG` autoload + a Tween to ease the eyes to
## a new random target. Here the next target is drawn from the rig's SEEDED rng
## and the eyes ease toward it per-frame (deterministic approach). No wall-clock.
extends FaceGesture

var dir_timer: float = 0.0
var look_dir: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO

const MAX_VAL := 0.2
const EASE_RATE := 18.0


func _init() -> void:
	id = "LookWander"
	priority = 3.0


func _next_interval() -> float:
	if rng == null:
		return 4.0
	return rng.randf_range(1.0, 10.0)


func process_values(rig, dt: float) -> void:
	if dir_timer <= 0.0:
		dir_timer = _next_interval()
		if rng != null:
			_target = Vector2(rng.randf_range(-MAX_VAL, MAX_VAL),
				rng.randf_range(-MAX_VAL, MAX_VAL))
	dir_timer -= dt
	var t := clampf(EASE_RATE * dt, 0.0, 1.0)
	look_dir = look_dir + (_target - look_dir) * t
	rig.val_look_dir = look_dir
