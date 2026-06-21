## ExprState — aeriea's OWN expression-seam vocabulary (affect/intent -> face).
##
## This is the small, serializable, engine-neutral record that crosses aeriea's
## `apply_expression(ExprState)` seam (docs/decisions/bdcc2-integration-plan.md
## §2.1). aeriea OWNS this interface; the ported BDCC2 FaceAnimator rig is the
## FIRST implementation behind it, not the definition of it. A from-scratch /
## CC0 implementation would satisfy the same record.
##
## The channels are continuous and affect-level (not blendshape names): the
## adapter inside FaceRig maps these onto the rig's FaceValue channels, and that
## adapter is where the seam's independence from BDCC2 lives.
##
## Determinism: ExprState is pure data. Same ExprState in -> same resolved face
## out (the rig's autonomous gestures use aeriea's seeded RNG, not wall-clock).
class_name ExprState
extends RefCounted

## -1 sad/displeased .. 0 neutral .. +1 happy/pleased.
var valence: float = 0.0
## 0 calm .. 1 intense (general emotional arousal, NOT the NSFW arousal axis).
var arousal: float = 0.0
## 0 relaxed/open .. 1 tense/guarded.
var tension: float = 0.0
## 0 averted/withdrawn .. 1 engaged/meeting-your-eyes.
var attention: float = 1.0
## 0..1 transient speech mouth activity (driven by do_talk pulses).
var talking: float = 0.0
## Optional discrete overlay for a strong, named read. "" = none.
## Recognised: "surprise" | "snarl" | "shy".
var emphasis: String = ""


func _init(p_valence: float = 0.0, p_arousal: float = 0.0, p_tension: float = 0.0,
		p_attention: float = 1.0, p_talking: float = 0.0, p_emphasis: String = "") -> void:
	valence = p_valence
	arousal = p_arousal
	tension = p_tension
	attention = p_attention
	talking = p_talking
	emphasis = p_emphasis


## Serializable form (the seam artifact caches / replays / diffs as data).
func to_dict() -> Dictionary:
	return {
		"valence": valence, "arousal": arousal, "tension": tension,
		"attention": attention, "talking": talking, "emphasis": emphasis,
	}


static func from_dict(d: Dictionary) -> ExprState:
	return ExprState.new(
		float(d.get("valence", 0.0)), float(d.get("arousal", 0.0)),
		float(d.get("tension", 0.0)), float(d.get("attention", 1.0)),
		float(d.get("talking", 0.0)), String(d.get("emphasis", "")))


func duplicate_state() -> ExprState:
	return ExprState.from_dict(to_dict())
