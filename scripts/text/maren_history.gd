## MarenHistory — wires npc_maren's AFFORDANCE EVENTS into the history stack and back
## out to the face (ExprState) and the realizer (memory callbacks).
##
## NEW (aeriea-owned). This is System 5: the integration that makes Maren genuinely
## REMEMBER the player and reflect it. The chain it closes:
##
##   affordance verb fires  ->  record_event(verb, state)
##        -> MemorySystem (per-NPC memory, decay/stack)   [scripts/sim/memory.gd]
##        -> Relationship (affection / annoyance)          [scripts/sim/relationship.gd]
##   advance time (leave/return) -> advance(seconds): clock advances, memory decays,
##        relationship decays — all off the seeded timeline (deterministic)
##   read back:
##        -> Mood.read(memory_mood, affection, lust, annoyance, emphasis) -> ExprState
##           feeds the EXPRESSION RIG (the face) — show-don't-tell affect
##        -> memory_callback(...) -> a DIALOGUE/CALLBACK line for the realizer
##           ("you keep saying that") — memory surfaced as prose, not narrated reaction
##
## Path-A discipline: this module holds NO BDCC2 registries and reaches for NO global
## clock — it OWNS a SimClock + Memory.MemoryHolder + Relationship and drives them
## explicitly off the host's timeline (each event/advance is a logged step). It keys
## everything by plain ids (npc_maren / player). Same seed + same event sequence ->
## identical clock, memory, relationship, ExprState, and callback (deterministic).
class_name MarenHistory
extends RefCounted

const SimClock := preload("res://scripts/sim/sim_clock.gd")
const Memory := preload("res://scripts/sim/memory.gd")
const MemoryDefs := preload("res://scripts/sim/memory_defs.gd")
const Relationship := preload("res://scripts/sim/relationship.gd")
const Mood := preload("res://scripts/sim/mood.gd")

const MAREN := "npc_maren"
const PLAYER := "player"
const HOUR := 3600

var clock: SimClock
var holder: Memory.MemoryHolder
var rel: Relationship
var _lib: Dictionary

## Affordance verb -> (memory def id, affection delta, annoyance delta). The verb a
## tease becomes depends on outcome (warm vs sour) — resolved in record_event from the
## post-fire state. AS DATA.
const EVENT_AFFECTION := {
	"greet": 0.05, "compliment": 0.25, "tease": 0.0,
	"push_away": -0.4, "offer_gift": 0.35,
}


func _init(seed_value: int = 0) -> void:
	clock = SimClock.new()
	holder = Memory.MemoryHolder.new()
	rel = Relationship.new()
	_lib = MemoryDefs.build()
	# seed_value reserved for any future seeded variation; the history itself is
	# deterministic without RNG (recorded here so callers can thread a seed through).


## Record one fired affordance verb. `post_state` is npc_maren's interactable record
## AFTER the verb fired (mood/rapport/last_social_act) — used to resolve outcome-
## dependent memories (a tease that landed warm vs sour). Time does NOT advance here;
## one interaction is one timeline step the host advances explicitly (see advance()).
func record_event(verb: String, post_state: Dictionary) -> void:
	var mem_id := _memory_id_for(verb, post_state)
	if mem_id != "" and _lib.has(mem_id):
		holder.add_memory(clock, _lib[mem_id], PLAYER)
	# Long-term affection from the act.
	var aff: float = EVENT_AFFECTION.get(verb, 0.0)
	# A tease that landed wrong is a slight; a warm one is a small positive.
	if verb == "tease":
		aff = 0.1 if _tease_was_warm(post_state) else -0.15
	if aff != 0.0:
		rel.add_affection(PLAYER, MAREN, aff)
	# A push-away also spikes short-term annoyance (fades over time).
	if verb == "push_away":
		rel.add_annoyance(MAREN, PLAYER, 0.9)
	elif verb == "tease" and not _tease_was_warm(post_state):
		rel.add_annoyance(MAREN, PLAYER, 0.4)


## Advance the timeline by `seconds` (the host's "leave / wait / return"). The clock
## advances, memories decay + expire, the relationship decays — all deterministically.
func advance(seconds: int) -> void:
	clock.advance(seconds)
	holder.expire_old(clock)
	rel.decay(seconds)


## The current affect read as an ExprState (feeds the face). Pure function of the
## live memory + relationship state. `emphasis` is the transient discrete overlay from
## the most-recent act (passed through to the face).
func current_expr(last_social_act: String = "") -> ExprState:
	var mv := holder.mood_values(clock)
	var aff := rel.get_affection(PLAYER, MAREN)
	var lust := rel.get_lust(PLAYER, MAREN)
	var ann := rel.get_annoyance(MAREN, PLAYER)
	var emphasis := _emphasis_for(last_social_act, aff, mv.mood)
	return Mood.read(mv, aff, lust, ann, emphasis)


## A memory CALLBACK line for the realizer — memory surfaced as DIALOGUE, not as a
## narrated reaction (show-don't-tell). Returns "" when nothing is worth calling back.
## Reads the per-type memory counts about the player + the strongest recent memory.
func memory_callback() -> String:
	var compliments := holder.count_with("complimented", PLAYER)
	var slights := holder.count_with("pushed_away", PLAYER)
	var gifts := holder.count_with("given_gift", PLAYER)
	var aff := rel.get_affection(PLAYER, MAREN)

	# A real history of compliments -> the "you keep saying that" callback.
	if compliments >= 3:
		if aff >= 0.5:
			return "\"You keep saying that,\" she murmurs — but she doesn't look away this time."
		return "\"That's the third time you've told me that,\" she says, flatter each time."
	if compliments == 2 and aff >= 0.3:
		return "\"You said that before,\" she notes, the corner of her mouth twitching."

	# A remembered slight she hasn't let go of.
	if slights >= 1 and aff < 0.2:
		return "\"Last time you didn't want me here,\" she says, not quite meeting your eye."

	# A remembered gift.
	if gifts >= 1 and aff >= 0.4:
		return "She still has the thing you gave her — you can see the shape of it in her pocket."

	return ""


# --- internals ----------------------------------------------------------------

func _memory_id_for(verb: String, post_state: Dictionary) -> String:
	match verb:
		"greet": return "greeted"
		"compliment": return "complimented"
		"push_away": return "pushed_away"
		"offer_gift": return "given_gift"
		"tease": return "teased_warm" if _tease_was_warm(post_state) else "teased_sour"
		_: return ""


## A tease lands WARM at high rapport (the kit's own branch: rapport>=0.7 nudges mood
## up, else down). Read off the post-fire state to stay faithful to the substrate.
func _tease_was_warm(post_state: Dictionary) -> bool:
	return float(post_state.get("rapport", 0.0)) >= 0.7


## Transient discrete face overlay from the most recent act (mirrors maren_affect.gd).
func _emphasis_for(last_social_act: String, aff: float, mood: float) -> String:
	match last_social_act:
		"complimented":
			return "shy" if aff < 0.5 else ""
		"teased":
			return "snarl" if mood < 0.0 else ""
		"pushed_away", "rebuffed":
			return "snarl"
	return ""
