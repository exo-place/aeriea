## FaceGesture — base class for a face gesture in the priority/influence stack.
##
## PORTED (Path A) from BDCC2 `Game/Doll/FaceAnimator/FaceGestureBase.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
##
## Path-A cuts vs the BDCC2 original (per bdcc2-integration-plan.md §3.1):
##   - DELETED the `getCharacter()/getCharState()/getArousal()` Doll-chain pulls.
##     The rig is now a SINK: affect is PUSHED in via aeriea's ExprState seam, not
##     pulled from a Doll/BaseCharacter hub. (Inverts control to match the seam.)
##   - DELETED `createTween()/doTween()` (BDCC2 used Node tweens — wall-clock,
##     non-replayable). Gestures now integrate their own values per-frame from a
##     supplied delta, so the resolved face is a pure function of (seed, sim-dt):
##     aeriea's determinism invariant. Random timing uses the seeded RNG handed in
##     via `rng`, never `randf()`.
##
## Retained from BDCC2: the priority ordering, the blend-in/out influence ramp,
## and the `processValues(rig, dt)` compositing-sink contract.
class_name FaceGesture
extends RefCounted

var id: String = ""
var enabled: bool = true

var blend_in_time: float = 0.1
var blend_out_time: float = 0.1
var influence: float = 1.0

## Higher = processed LAST (so it composites on top). BDCC2 semantics preserved.
var priority: float = 0.0

## The rig's seeded RNG (aeriea-owned). Set by FaceRig on add. NEVER use global
## randf()/RNG — determinism invariant (DESIGN.md seeded-sim).
var rng: RandomNumberGenerator = null


func start() -> void:
	enabled = true


func stop() -> void:
	enabled = false


func set_enabled(en: bool) -> void:
	if en and not enabled:
		start()
	elif not en and enabled:
		stop()


func is_enabled() -> bool:
	return enabled


## Blend the influence toward 1 (enabled) or 0 (disabled) over blend_in/out_time.
## Pure function of dt — deterministic. (BDCC2 processInfluence, renamed.)
func process_influence(dt: float) -> void:
	var target := 1.0 if enabled else 0.0
	if influence < target:
		influence += dt / maxf(blend_in_time, 1e-4)
		if influence > target:
			influence = target
	elif influence > target:
		influence -= dt / maxf(blend_out_time, 1e-4)
		if influence < target:
			influence = target


## Per-frame: integrate any internal animation, then composite onto the rig's
## live face channels. Overridden by concrete gestures. The rig calls this for
## every gesture in priority order. (BDCC2 processValues.)
func process_values(_rig, _dt: float) -> void:
	pass


## Transient event hook (e.g. "talk"). (BDCC2 onEvent.)
func on_event(_event_id: String, _args: Array) -> void:
	pass


func get_influence() -> float:
	return influence


func get_priority() -> float:
	return priority


## A frame-rate-independent exponential approach of `value` toward `target`.
## Replaces BDCC2's tween for blend-in/out of gesture-internal values while
## staying a pure function of dt (deterministic). `rate` = approach per second.
static func approach(value: float, target: float, rate: float, dt: float) -> float:
	var t := clampf(rate * dt, 0.0, 1.0)
	return value + (target - value) * t
