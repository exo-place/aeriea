## Mood — the BRIDGE: aggregate memory + relationship into an affect read whose
## OUTPUT IS AN ExprState (feeds the already-built expression rig).
##
## PORTED-IN-SPIRIT (Path A) from BDCC2 `Game/PawnAI/Mood/MoodHandler.gd`:
##   BDCC2's MoodHandler combined a decaying `temporary*` short-term bank WITH the
##   memoryHolder's aggregated `moodValues`, then ran a mood-NAME registry. aeriea
##   keeps the AGGREGATION IDEA (memory mood + short-term + relationship) but
##   REPLACES the mood-name/MoodBase/GlobalRegistry.getMoods registry with a single
##   projection to aeriea's OWN ExprState vocabulary — the seam the face rig already
##   consumes (bdcc2-mining-backlog.md #3: "Mood output IS an ExprState").
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
##
## Path-A cuts:
##   - `GlobalRegistry.getMoods()` + `MoodBase`/`MoodStage` mood-NAME registry +
##     `Network.isServer()` gate -> DELETED. aeriea does not name moods; it projects
##     scalars to the continuous ExprState channels the face renders.
##   - `pawn:CharacterPawn` + `pawn.getCharacter().memoryHolder` pull -> DELETED.
##     Inputs are PUSHED in (memory MoodValues, relationship affection/lust/annoyance);
##     Mood is a pure function of them, never a puller off a character locus.
##   - `GM.GB.moodDecayRate` temporary-bank tick -> DROPPED here; short-term decay
##     already lives in Relationship.decay (time-driven). Mood is a stateless read.
##
## THE SEAM (aeriea owns it): a single pure function
##   read(mood_values, affection, lust, annoyance, emphasis) -> ExprState
## same inputs -> same ExprState (deterministic; no RNG, no clock, no state).
class_name Mood
extends Object


## Project the aggregated affect into aeriea's ExprState (the expression-seam record).
## Inputs:
##   mv         MoodValues — the memory-aggregated mood bank (mood/anger/lust/dominance)
##   affection  pairwise long-term affection (Relationship range ~ -3..+3)
##   lust       pairwise lust (0..1)
##   annoyance  short-term directional annoyance (>= 0, fades over time)
##   emphasis   optional discrete overlay passed through to the face ("", "shy", ...)
static func read(mv: MoodValues, affection: float = 0.0, lust: float = 0.0,
		annoyance: float = 0.0, emphasis: String = "") -> ExprState:
	var e := ExprState.new()

	# VALENCE — happy/sad. Memory mood is the primary driver; long-term affection
	# lifts the baseline (a friend reads warmer at the same event-mood); annoyance and
	# memory-anger pull it down. Squashed to -1..+1.
	var valence_raw := mv.mood + affection * 0.25 - mv.anger * 0.3 - annoyance * 0.5
	e.valence = _squash(valence_raw)

	# TENSION — guarded/tense. Anger and fresh annoyance tighten; affection eases.
	# Negative affection (active dislike) is itself guarding.
	var tension_raw := mv.anger * 0.6 + annoyance * 0.8 + maxf(0.0, -affection) * 0.4 \
		- maxf(0.0, affection) * 0.2
	e.tension = clampf(tension_raw, 0.0, 1.0)

	# ATTENTION — engaged/averted. Affection draws her in (meets your eyes); strong
	# annoyance or a sour mood averts. Baseline mildly engaged.
	var attention_raw := 0.5 + _squash(affection) * 0.4 - annoyance * 0.3 + minf(0.0, mv.mood) * 0.2
	e.attention = clampf(attention_raw, 0.0, 1.0)

	# AROUSAL — general animation. Positive mood + lust + closeness animate the face.
	var arousal_raw := maxf(0.0, mv.mood) * 0.6 + lust * 0.5 + maxf(0.0, affection) * 0.15 + mv.lust * 0.4
	e.arousal = clampf(arousal_raw, 0.0, 1.0)

	e.emphasis = emphasis
	return e


## Squash an unbounded scalar to (-1, +1) smoothly (tanh-like via x/(1+|x|)).
static func _squash(x: float) -> float:
	return x / (1.0 + absf(x))
