## AffectExpression — the conversational-emotion base layer.
##
## NEW (authored for aeriea — BDCC2 had the FaceValue PARAMS but NOT Happy/Sad/
## Angry/Surprised gesture classes; its eval flagged this gap). This is the
## ExprState -> FaceValue ADAPTER, the place where aeriea's seam stays independent
## of BDCC2: it reads aeriea's affect vocabulary (valence/arousal/tension/
## attention/emphasis) and writes the rig's continuous channels. Authored AS DATA
## (EMOTIONS table) so the named reads are a lookup, not control flow.
##
## Priority 0 = the BASE layer: blink/look-wander/talk composite ON TOP of it.
## Deterministic: pure function of the pushed ExprState (no RNG, no clock).
extends FaceGesture

## The current pushed affect (set by FaceRig.apply_expression). Smoothed toward
## per-frame so expression transitions read as easing, not snapping.
var target: ExprState = ExprState.new()
var _smoothed: ExprState = ExprState.new()

const SMOOTH_RATE := 6.0   # per-second approach of channels toward target

## Named emphasis reads, AS DATA. Each maps to additive channel nudges applied on
## top of the continuous valence/tension reads. Values are FaceValue weights.
const EMPHASIS := {
	"surprise": {"mouth_open": 0.55, "eyes_closed": -0.3, "brows_shy": 0.25},
	"snarl": {"mouth_snarl": 0.7, "brows_angry": 0.4},
	"shy": {"brows_shy": 0.6, "mouth_smile": 0.2, "eyes_closed": 0.15},
}


func _init() -> void:
	id = "AffectExpression"
	priority = 0.0


func _approach_state(dt: float) -> void:
	var t := clampf(SMOOTH_RATE * dt, 0.0, 1.0)
	_smoothed.valence += (target.valence - _smoothed.valence) * t
	_smoothed.arousal += (target.arousal - _smoothed.arousal) * t
	_smoothed.tension += (target.tension - _smoothed.tension) * t
	_smoothed.attention += (target.attention - _smoothed.attention) * t
	# talking/emphasis are read live (transient), not smoothed.
	_smoothed.emphasis = target.emphasis


func process_values(rig, dt: float) -> void:
	_approach_state(dt)
	var v := _smoothed.valence
	var ten := _smoothed.tension
	var att := _smoothed.attention
	var aro := _smoothed.arousal

	# --- continuous affect -> face channels (the adapter, §2.1 mapping) --------
	# Valence: +ve -> smile; -ve -> sad mouth + a touch of shy/down brows.
	rig.val_mouth_smile = clampf(maxf(0.0, v) * (0.5 + 0.5 * att), 0.0, 1.0)
	rig.val_mouth_sad = clampf(maxf(0.0, -v), 0.0, 1.0)
	rig.val_brows_shy = clampf(maxf(0.0, -v) * 0.6, 0.0, 1.0)
	# Tension: guarded/tense -> angry brows + a hint of snarl at high tension.
	rig.val_brows_angry = clampf(ten, 0.0, 1.0)
	rig.val_mouth_snarl = clampf(maxf(0.0, ten - 0.6) * 1.5, 0.0, 1.0)
	# Attention: withdrawn -> eyes drift toward lidded (lower openness).
	#   eyes_closed base from low attention; arousal widens the eyes (negative).
	rig.val_eyes_closed = clampf((1.0 - att) * 0.35 - aro * 0.15, 0.0, 1.0)
	# Arousal opens the mouth slightly (animated/excited speech-ready face).
	rig.val_mouth_open = maxf(rig.val_mouth_open, clampf(aro * 0.25, 0.0, 1.0))

	# --- discrete emphasis overlay (AS DATA) ----------------------------------
	var emp: Dictionary = EMPHASIS.get(_smoothed.emphasis, {})
	if emp.has("mouth_open"):
		rig.val_mouth_open = clampf(rig.val_mouth_open + emp["mouth_open"], 0.0, 1.0)
	if emp.has("mouth_smile"):
		rig.val_mouth_smile = clampf(rig.val_mouth_smile + emp["mouth_smile"], 0.0, 1.0)
	if emp.has("mouth_snarl"):
		rig.val_mouth_snarl = clampf(rig.val_mouth_snarl + emp["mouth_snarl"], 0.0, 1.0)
	if emp.has("brows_shy"):
		rig.val_brows_shy = clampf(rig.val_brows_shy + emp["brows_shy"], 0.0, 1.0)
	if emp.has("brows_angry"):
		rig.val_brows_angry = clampf(rig.val_brows_angry + emp["brows_angry"], 0.0, 1.0)
	if emp.has("eyes_closed"):
		rig.val_eyes_closed = clampf(rig.val_eyes_closed + emp["eyes_closed"], 0.0, 1.0)
