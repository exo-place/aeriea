## MarenAffect — projects npc_maren's relationship state onto aeriea's ExprState.
##
## NEW (aeriea-owned). npc_maren already computes mood x rapport affect that today
## is shown ONLY in prose (scripts/text/npc_realizer.gd). This is the SAME affect
## driving the FACE — the show-don't-tell payoff (bdcc2-integration-plan.md §6.5),
## behind aeriea's apply_expression seam. Pure function of state: same state ->
## same ExprState (deterministic, no RNG, no clock).
##
## Maren's state fields (interaction/sandbox.kit.json npc_maren):
##   mood     0..1  (affect; <0.5 reads displeased, >0.5 pleased)
##   rapport  0..1  (closeness/openness; low = guarded, high = at ease)
##   last_social_act  (enum memory; drives a transient emphasis/talk pulse)
class_name MarenAffect
extends Object


## state: the npc_maren state dict (mood, rapport, last_social_act, ...).
static func to_expr(state: Dictionary) -> ExprState:
	var mood := float(state.get("mood", 0.5))
	var rapport := float(state.get("rapport", 0.3))
	var last := String(state.get("last_social_act", ""))

	var e := ExprState.new()
	# mood centred at 0.5 -> valence in [-1, +1].
	e.valence = clampf((mood - 0.5) * 2.0, -1.0, 1.0)
	# Low rapport = guarded/tense; warmth at low rapport still reads wary. Tension
	# eases off smoothly across the WHOLE rapport range (not clamped flat at 0.5),
	# so "more open" keeps reading as "less guarded" even between close friends.
	e.tension = clampf((1.0 - rapport) * 0.9, 0.0, 1.0)
	# Rapport = how engaged/open the attention is.
	e.attention = clampf(0.4 + rapport * 0.6, 0.0, 1.0)
	# Brighter mood + closer rapport = more animated (general arousal).
	e.arousal = clampf(maxf(0.0, mood - 0.5) * 1.2 + rapport * 0.3, 0.0, 1.0)

	# last_social_act -> a transient discrete read.
	match last:
		"complimented":
			e.emphasis = "shy" if rapport < 0.5 else ""
		"teased":
			e.emphasis = "snarl" if mood < 0.4 else ""
		"pushed_away", "rebuffed":
			e.emphasis = "snarl"
	return e


## Should this act trigger a speech pulse on the face? (the host calls do_talk).
static func talk_length_for(last_social_act: String) -> float:
	match last_social_act:
		"greeted", "complimented", "teased", "chatted":
			return 2.0
		_:
			return 0.0
