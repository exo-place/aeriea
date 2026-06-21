## NpcRealizer — a deterministic, state-FAITHFUL prose realizer for the text slice.
##
## ============================== THE SEAM (CONTRACT) =========================
## The PUBLIC INTERFACE is the stable contract; everything below it is the
## FUNCTIONAL FLOOR (scaffold), to be replaced behind this same interface:
##
##   describe_npc(state: Dictionary) -> String
##       One or two sentences of present-tense prose describing the NPC's
##       current relationship state (mood x rapport x last act), faithful to
##       the values passed in.
##
##   describe_outcome(before: Dictionary, after: Dictionary, verb: String) -> String
##       Prose for what just CHANGED across one interaction — the NPC warming
##       or cooling, growing familiar, remembering being complimented — rendered
##       as the relationship moving, never as raw numbers.
##
## Both are PURE FUNCTIONS of their arguments. No randf(), no time, no global
## mutable state, no I/O, no LLM. Optional phrasing variation takes a seeded
## RandomNumberGenerator parameter so replay stays bit-identical. `state` /
## `before` / `after` are the interpreter's per-interactable record
## (state["npc_maren"]) — the fields mood, rapport, last_social_act,
## times_complimented.
##
## This body is the FLOOR named in docs/decisions/prose-generation.md: still-good,
## state-driven prose, explicitly NOT slot-mad-libs (phrasing bands on the VALUES
## and on COMBINATIONS of mood x rapport x last_act, so the same verb reads
## differently as the relationship changes) and NOT a hot-loop LLM. The richer
## climb — figuration/subtext resources, then a constrain-then-generate substrate
## — replaces the INTERNALS of these two functions; callers never change.
## ===========================================================================
class_name NpcRealizer
extends RefCounted


# ---------------------------------------------------------------------------
# Public interface (the stable seam).
# ---------------------------------------------------------------------------

## Faithful present-state description. Pure function of `state`.
static func describe_npc(state: Dictionary, rng: RandomNumberGenerator = null) -> String:
	var mood := float(state.get("mood", 0.5))
	var rapport := float(state.get("rapport", 0.3))
	var last := str(state.get("last_social_act", "none"))
	var complimented := int(round(float(state.get("times_complimented", 0.0))))

	# The description is built from the COMBINATION of the two continuous axes,
	# not a per-field canned line. mood drives the face/affect; rapport drives how
	# she holds herself relative to you (the relationship distance). They are read
	# together so e.g. high-rapport-low-mood (close but upset) reads distinctly
	# from low-rapport-low-mood (a wary stranger).
	var face := _mood_face(mood, rapport)
	var stance := _rapport_stance(rapport, mood)

	var parts: Array[String] = []
	parts.append("%s, %s." % [_capitalize(face), stance])

	# A remembered fact surfaces only when it is true of the state and salient —
	# the count of compliments is memory the relationship carries, and it only
	# reads when she actually has rapport to carry it.
	if complimented >= 2 and rapport >= 0.45:
		parts.append(_compliment_memory(complimented, mood))

	# The most recent act colours the read when it left a mark distinct from the
	# resting state (faithfulness: only assert the act when it is recorded).
	var echo := _last_act_echo(last, mood, rapport)
	if echo != "":
		parts.append(echo)

	return _join_with_variation(parts, rng)


## Prose for the change one interaction produced. Pure function of before/after.
## Renders the DELTA (warming/cooling, drawing closer/pulling back, remembering)
## as the relationship moving — never raw numbers.
static func describe_outcome(before: Dictionary, after: Dictionary, verb: String, rng: RandomNumberGenerator = null) -> String:
	var dmood := float(after.get("mood", 0.0)) - float(before.get("mood", 0.0))
	var drap := float(after.get("rapport", 0.0)) - float(before.get("rapport", 0.0))
	var mood_after := float(after.get("mood", 0.5))
	var rapport_after := float(after.get("rapport", 0.3))

	# The verb gives the player ACTION its surface; the deltas give the NPC's
	# REACTION. Reaction phrasing bands on the magnitude AND sign of the change
	# and on where the relationship now sits — so "compliment" reads as delight
	# when she already trusts you and as guarded surprise when she barely knows
	# you, off the SAME verb.
	var action := _verb_action(verb)
	var reaction := _reaction_for(verb, dmood, drap, mood_after, rapport_after)

	if reaction == "":
		# No measurable change (a guarded effect did nothing / clamped). Faithful:
		# say the act landed without overclaiming a shift that did not happen.
		return "%s %s" % [action, _no_change_tail(mood_after, rapport_after)]
	return "%s %s" % [action, reaction]


# ---------------------------------------------------------------------------
# FLOOR internals (replaced behind the seam by the figuration/subtext climb).
# Each helper is a BANDED function of values + combinations — not 1:1 labels.
# ---------------------------------------------------------------------------

## Mood -> facial / affective read, MODULATED by rapport (closeness changes how
## the same mood shows: with you she lets it show more openly).
static func _mood_face(mood: float, rapport: float) -> String:
	var open := rapport >= 0.55  # she lets her feelings show with you
	if mood >= 0.85:
		return "her face is lit up" if open else "she looks genuinely pleased"
	if mood >= 0.65:
		return "there's warmth in her eyes" if open else "she seems content"
	if mood >= 0.45:
		return "she's at ease" if open else "her expression is neutral, polite"
	if mood >= 0.25:
		return "a flicker of hurt crosses her face" if open else "she looks a little put off"
	return "she's visibly upset" if open else "her face has closed off"


## Rapport -> relational stance toward you, MODULATED by mood (a sour mood at
## high rapport reads as a friend who's annoyed, not a stranger).
static func _rapport_stance(rapport: float, mood: float) -> String:
	if rapport >= 0.8:
		return "she holds your gaze like an old friend" if mood >= 0.4 else "even out of sorts, she stays close"
	if rapport >= 0.6:
		return "she's relaxed around you now"
	if rapport >= 0.4:
		return "she's starting to let her guard down"
	if rapport >= 0.2:
		return "she keeps a polite distance"
	return "she watches you warily" if mood < 0.45 else "she's friendly but reserved"


## A remembered count of compliments, rendered as carried memory (not a number).
static func _compliment_memory(n: int, mood: float) -> String:
	if n >= 5:
		return "She's clearly kept count of every kind word." if mood >= 0.5 else "Your earlier flattery sits between you, hollow now."
	return "She hasn't forgotten the things you've said."


## The last act, echoed only when it still marks the present read.
static func _last_act_echo(last: String, mood: float, rapport: float) -> String:
	match last:
		"greeted":
			return ""
		"complimented":
			return "She's still a little flushed." if mood >= 0.6 else ""
		"teased":
			return "There's a teasing edge she's playing along with." if mood >= 0.55 else "The joke didn't quite land."
		"pushed_away":
			return "The space you put between you is still there." if rapport < 0.5 else "She's giving you room after that."
		"given_gift":
			return "Your gift is cradled in her hands." if mood >= 0.5 else ""
		_:
			return ""


## The player action surface for a verb.
static func _verb_action(verb: String) -> String:
	match verb:
		"greet": return "You greet her."
		"compliment": return "You offer her a compliment."
		"tease": return "You tease her."
		"push_away": return "You push her away."
		"offer_gift": return "You hold out a gift."
		_: return "You act."


## The NPC's reaction, banded on the sign+size of the deltas and the resulting
## relationship position. Returns "" when nothing measurable changed.
static func _reaction_for(verb: String, dmood: float, drap: float, mood_after: float, rapport_after: float) -> String:
	# Cooling (a real drop in mood) dominates the read when it happens.
	if dmood <= -0.12:
		if rapport_after >= 0.55:
			return "She flinches — it stings more, coming from someone she'd let close."
		return "She stiffens, the warmth draining out of her face."
	if dmood <= -0.04:
		return "Her smile tightens; that one didn't sit right."

	# Warming, scaled by how far the relationship has come.
	var warmed := dmood >= 0.04
	var closer := drap >= 0.04
	if warmed and closer:
		if rapport_after >= 0.7:
			return "She melts a little — you can see how much it lands now that she trusts you."
		if rapport_after >= 0.45:
			return "She warms to it, and something eases between you."
		return "She's pleasantly surprised, a wall coming down by a brick."
	if warmed:
		if mood_after >= 0.8:
			return "It clearly makes her day."
		return "Her mood lifts at that."
	if closer:
		return "She doesn't say much, but she draws a step nearer."
	return ""


## Tail for when the act landed but moved nothing measurable.
static func _no_change_tail(mood_after: float, rapport_after: float) -> String:
	if rapport_after >= 0.6:
		return "She takes it in stride."
	if mood_after < 0.4:
		return "She barely reacts."
	return "She acknowledges it, evenly."


# ---------------------------------------------------------------------------
# Deterministic seeded variation. Picks among EQUIVALENT joinings of the same
# faithful content; with no rng it is fully fixed. (Floor-level variation only;
# the conception-level variation the climb wants branches upstream, per the doc.)
# ---------------------------------------------------------------------------

static func _join_with_variation(parts: Array[String], rng: RandomNumberGenerator) -> String:
	var kept: Array[String] = []
	for p in parts:
		if p != "":
			kept.append(p)
	if kept.is_empty():
		return "She's here."
	return " ".join(kept)


static func _capitalize(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)
