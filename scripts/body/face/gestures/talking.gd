## Talking — transient mouth-on-speech pulse.
##
## PORTED (Path A) from BDCC2 `Gestures/Talking.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
## Path-A cut: BDCC2 drove the talk envelope with a Tween (ramp up / hold / ramp
## down). Here the envelope is a per-frame state machine over a remaining-time
## counter — a pure function of dt. `do_talk(length)` arrives via the seam's
## do_talk -> on_event("talk", [length]) path.
extends FaceGesture

var talk_value: float = 0.0
var _remaining: float = 0.0     # seconds of talk left (incl. ramps)
var _total: float = 0.0

const RAMP := 0.3


func _init() -> void:
	id = "Talking"
	priority = 75.0


func on_event(event_id: String, args: Array) -> void:
	if event_id == "talk":
		var how_long: float = args[0] if args.size() > 0 else 3.0
		_total = maxf(how_long, 2.0 * RAMP)
		_remaining = _total


func process_values(rig, dt: float) -> void:
	if _remaining > 0.0:
		var elapsed := _total - _remaining
		if elapsed < RAMP:
			talk_value = clampf(elapsed / RAMP, 0.0, 1.0)
		elif _remaining < RAMP:
			talk_value = clampf(_remaining / RAMP, 0.0, 1.0)
		else:
			talk_value = 1.0
		_remaining -= dt
		if _remaining <= 0.0:
			_remaining = 0.0
			talk_value = 0.0
	else:
		talk_value = 0.0
	# Talk does not stack onto an already-open mouth (BDCC2 semantics preserved).
	rig.val_talking = maxf(rig.val_talking, talk_value - maxf(0.0, rig.val_mouth_open))
