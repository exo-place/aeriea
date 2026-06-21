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
## ============================ SHOW, DON'T TELL =============================
## This body is the SHOW-DON'T-TELL FLOOR named in docs/decisions/prose-generation.md:
## still-good, state-driven prose, explicitly NOT slot-mad-libs and NOT a hot-loop
## LLM. Its governing rule, beyond determinism+faithfulness, is that it never NAMES
## the emotional/relationship state — no "mood", "rapport", "trust", "content",
## "happy", "guard down", "warms to it" as labels of her interior. It renders state
## through CONCRETE OBSERVABLE DETAIL — gaze and eye contact, the set of her
## shoulders, what her hands do, her breath, the distance she keeps, a micro-action,
## the cadence of her voice, a short beat of dialogue — and lets the reader infer the
## feeling. Memory is shown as a concrete callback (a reference to the specific prior
## act or its accumulation through behaviour), never as "she remembers".
##
## It varies on state BANDS and COMBINATIONS (mood x rapport x last_act), so the same
## verb shows differently as the relationship moves: low-rapport warmth reads guarded
## and surprised; high-rapport warmth reads easy and unguarded. Combinations, not 1:1
## templates per verb.
##
## DEPTH IS UPSTREAM. This realizer is a lens: its repertoire is bounded by the
## (currently thin) state — four fields. Richer showing — interiority, history with
## texture, contradiction — needs richer state, not a richer realizer; per
## docs/decisions/prose-generation.md ("Depth is upstream") the realizer cannot
## manufacture depth the substrate lacks without confabulating, which faithfulness
## forbids. So the showing here will repeat and strain at the edges of four numbers;
## that ceiling is the substrate's, not the lens's. The richer climb — figuration/
## subtext resources, then a constrain-then-generate substrate — replaces the
## INTERNALS of these two functions over a deeper state; callers never change.
## ===========================================================================
class_name NpcRealizer
extends RefCounted


# ---------------------------------------------------------------------------
# Public interface (the stable seam).
# ---------------------------------------------------------------------------

## Faithful present-state description. Pure function of `state`.
## SHOWS the state through behaviour: a body-tell read off the COMBINATION of mood
## (affect) x rapport (the distance she keeps), then a concrete echo of the last act
## or the carried memory of compliments. The reader infers the feeling.
static func describe_npc(state: Dictionary, _rng: RandomNumberGenerator = null) -> String:
	var mood := float(state.get("mood", 0.5))
	var rapport := float(state.get("rapport", 0.3))
	var last := str(state.get("last_social_act", "none"))
	var complimented := int(round(float(state.get("times_complimented", 0.0))))

	var parts: Array[String] = []

	# The primary tell is read from mood x rapport TOGETHER: the same affect shows
	# differently by how close she lets you stand. Close-and-low reads as a friend
	# out of sorts; far-and-low reads as a wary stranger — distinct behaviours, not
	# the same line relabelled.
	parts.append(_present_tell(mood, rapport))

	# A concrete callback to the most recent act, shown only when it still marks her
	# behaviour now (faithfulness: assert the act only when it is recorded and its
	# echo is consistent with the present affect).
	var echo := _last_act_echo(last, mood, rapport)
	if echo != "":
		parts.append(echo)
	# When there is no fresh act-echo, accumulated compliments can surface instead —
	# memory shown as a glance toward a kept thing, not stated as "she remembers".
	elif complimented >= 2 and rapport >= 0.45:
		parts.append(_compliment_callback(complimented, mood))

	return _join(parts)


## Prose for the change one interaction produced. Pure function of before/after.
## SHOWS the DELTA as a reaction — a flinch, a step nearer, breath let out, eyes
## dropping then lifting — off the action the verb names. Never raw numbers, never a
## named feeling.
static func describe_outcome(before: Dictionary, after: Dictionary, verb: String, _rng: RandomNumberGenerator = null) -> String:
	var dmood := float(after.get("mood", 0.0)) - float(before.get("mood", 0.0))
	var drap := float(after.get("rapport", 0.0)) - float(before.get("rapport", 0.0))
	var mood_after := float(after.get("mood", 0.5))
	var rapport_after := float(after.get("rapport", 0.3))
	var tc_after := int(round(float(after.get("times_complimented", 0.0))))

	# The verb gives the player ACTION its surface; the deltas give her REACTION,
	# banded on sign+size of the change and where the relationship now sits — so the
	# SAME verb shows as an easy unguarded reaction when she's close and as a
	# startled, half-checked one when she barely knows you.
	var action := _verb_action(verb)
	var reaction := _reaction_for(verb, dmood, drap, mood_after, rapport_after, tc_after)

	if reaction == "":
		# Nothing measurable moved (a guarded effect clamped / did nothing). Faithful:
		# show the act landing flat rather than overclaiming a shift that didn't happen.
		return "%s %s" % [action, _no_change_tail(mood_after, rapport_after)]
	return "%s %s" % [action, reaction]


# ---------------------------------------------------------------------------
# FLOOR internals (replaced behind the seam by the figuration/subtext climb).
# Each helper is a BANDED function of values + combinations — and every line is a
# BEHAVIOUR (gaze/posture/hands/breath/distance/voice/dialogue), never a label of
# the interior. No "mood"/"rapport"/"trust"/"content" as state names anywhere below.
# ---------------------------------------------------------------------------

## The resting body-tell, read from mood x rapport together. mood selects the affect
## register (lit / easy / flat / stung / shut); rapport selects how near she stands
## and where her eyes go within that register. Combinations, not a grid of labels.
static func _present_tell(mood: float, rapport: float) -> String:
	# rapport bands: how close, where the eyes sit, what the hands do at rest.
	# mood bands within each: the cast of the face / set of the shoulders.
	if rapport >= 0.7:
		# Close. She faces you, no buffer of space, hands unhurried.
		if mood >= 0.8:
			return "She's turned full toward you, eyes bright and holding yours, the corner of her mouth already going"
		if mood >= 0.55:
			return "She stands easy at your side, shoulders loose, her gaze drifting back to your face and staying there"
		if mood >= 0.35:
			return "She's close still, but her eyes keep cutting to the middle distance, her jaw set"
		return "She hasn't stepped back, but her arms are folded and she's looking somewhere past your shoulder"
	if rapport >= 0.45:
		# Half a pace off, learning to settle. Hands find something to hold.
		if mood >= 0.8:
			return "She leans in a little, a quick smile breaking before she can school it, fingers worrying the hem of her sleeve"
		if mood >= 0.55:
			return "She's stopped angling toward the door; her hands have gone still at her sides and she meets your eye for a beat at a time"
		if mood >= 0.35:
			return "She holds the half-step of space between you, gaze flicking to you and away, one thumb rubbing her knuckles"
		return "She's drawn back to arm's length, eyes lowered, her mouth a thin line"
	if rapport >= 0.2:
		# A polite gap. Glances, not gazes.
		if mood >= 0.6:
			return "She keeps a careful arm's length, but there's a glance — quick, almost surprised — before she looks away"
		if mood >= 0.35:
			return "She stands a step back, hands clasped in front of her, offering you a level, measured look"
		return "She's angled half away, weight on her back foot, watching you sidelong"
	# A stranger's distance. Wary, guarded posture.
	if mood >= 0.5:
		return "She keeps the room between you, polite and unhurried, hands loose but ready"
	return "She's planted out of reach, shoulders squared, eyes tracking you and not softening"


## A concrete callback to the last act, shown as behaviour and only when it still
## marks the present read (faithfulness: consistent with the current affect).
static func _last_act_echo(last: String, mood: float, rapport: float) -> String:
	match last:
		"greeted":
			# A bare greeting leaves little mark; only at real closeness is there a beat.
			return "\"Hey,\" she says again, softer the second time." if (mood >= 0.6 and rapport >= 0.7) else ""
		"complimented":
			if mood >= 0.6:
				return "Color is still high on her cheeks, and she keeps not-quite-looking at you."
			return ""
		"teased":
			if mood >= 0.55:
				return "She shoves your shoulder, the laugh still in her throat — \"You're the worst.\""
			return "The line lands wrong; she doesn't smile, and the quiet stretches a beat too long."
		"pushed_away":
			# The gap you opened is still physically there until rapport recovers.
			return "There's a body's width of cold air where you put it, and she hasn't closed it." if rapport < 0.5 else "She's kept a careful handspan of distance since, watching to see what you do."
		"given_gift":
			return "Whatever you gave her is held in both hands, turned once, set carefully against her chest." if mood >= 0.5 else ""
		_:
			return ""


## Accumulated compliments, shown as carried memory — a behaviour toward the count,
## never "she remembers". Surfaces only when no fresher act-echo took the slot.
static func _compliment_callback(n: int, mood: float) -> String:
	if n >= 5:
		if mood >= 0.5:
			return "Each kind word you've spent on her has landed somewhere it stayed; you can see her bracing a little for the next one, half-hoping."
		return "All the soft things you said before hang in the air between you, gone flat now, and she won't meet them."
	return "She catches the shape of the compliment before it's out — she's heard you build to this before."


## The player action surface for a verb.
static func _verb_action(verb: String) -> String:
	match verb:
		"greet": return "You greet her."
		"compliment": return "You offer her a compliment."
		"tease": return "You tease her."
		"push_away": return "You push her away."
		"offer_gift": return "You hold out a gift."
		_: return "You act."


## Her REACTION, shown as behaviour, banded on the sign+size of the deltas and the
## resulting closeness. Returns "" when nothing measurable changed.
## Combinations: cooling dominates when it happens; warming reads guarded/surprised
## at low rapport and easy/unguarded at high rapport — same delta, shown differently.
static func _reaction_for(verb: String, dmood: float, drap: float, mood_after: float, rapport_after: float, tc_after: int) -> String:
	# Cooling (a real drop in mood) takes the read.
	if dmood <= -0.12:
		if rapport_after >= 0.55:
			return "She rocks back half a step, and the warmth goes out of her face all at once — it costs more, from you."
		return "Her shoulders square and she goes still, the line of her mouth flattening."
	if dmood <= -0.04:
		return "Her smile stalls halfway and doesn't finish; she looks down at her hands."

	var warmed := dmood >= 0.04
	var closer := drap >= 0.04

	if warmed and closer:
		if rapport_after >= 0.7:
			# Easy, unguarded — and at a real history of compliments, a callback.
			if verb == "compliment" and tc_after >= 3:
				return "She laughs under her breath — \"You keep saying that\" — but she leans into your side as she says it."
			return "She lets out a breath she'd been holding and her whole frame loosens, closing the last of the gap between you."
		if rapport_after >= 0.45:
			return "Her eyes come up to yours and hold there a beat longer than before; one shoulder drops out of its guard."
		# Low rapport: the warmth reads as surprise, a tell she didn't mean to give.
		return "She blinks, caught off guard, and a flush climbs her neck before she can look away."
	if warmed:
		if mood_after >= 0.8:
			return "Her face opens wide — she ducks her head, but the grin gets away from her."
		return "Something at the corner of her mouth lifts; she doesn't quite hide it."
	if closer:
		return "She doesn't say anything, but her weight shifts and she's a half-step nearer than she was."
	return ""


## Tail for when the act landed but moved nothing measurable — shown, still.
static func _no_change_tail(mood_after: float, rapport_after: float) -> String:
	if rapport_after >= 0.6:
		return "She takes it without breaking stride, nodding once."
	if mood_after < 0.4:
		return "She barely shifts; her eyes stay where they were."
	return "She acknowledges it with a small, even nod and nothing more."


# ---------------------------------------------------------------------------
# Joining. With no rng this is fully fixed; the seam keeps the optional seeded
# rng for the climb's upstream (salience/structure) variation, unused at the floor.
# ---------------------------------------------------------------------------

static func _join(parts: Array[String]) -> String:
	var kept: Array[String] = []
	for p in parts:
		if p != "":
			kept.append(_terminate(p))
	if kept.is_empty():
		return "She's here, saying nothing."
	return " ".join(kept)


## Ensure a fragment ends as a sentence (the body-tells are written without a final
## stop so they compose; dialogue beats already carry their own punctuation).
static func _terminate(s: String) -> String:
	if s.is_empty():
		return s
	var tail := s.substr(s.length() - 1, 1)
	if tail == "." or tail == "!" or tail == "?" or tail == "\"":
		return s
	return s + "."
