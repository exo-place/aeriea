## MemoryDefs — aeriea's memory-type library (DATA), replacing GlobalRegistry.getMemory.
##
## NEW (aeriea-owned). BDCC2 pulled memory defs from GlobalRegistry; aeriea declares
## them AS DATA here (a plain table), the same data-over-code posture as the affordance
## kit and the EMPHASIS/EMOTIONS tables in the face rig. Each entry is one
## social-event memory type npc_maren can accumulate; the affordance substrate's events
## (greet/compliment/tease/push_away/offer_gift) map 1:1 onto these ids.
##
## The mood EFFECT each carries (MoodValues) is what the MemoryHolder aggregates
## (decay+stack weighted) and System 4's Mood projects to an ExprState — so a history
## of compliments visibly warms Maren, a history of being pushed away sours and guards
## her, all through the SAME face seam the prose realizer's affect feeds.
##
## Tuning lives here AS DATA: durations (how long remembered / how long it colours the
## mood) and the mood vector per event. Deterministic; no RNG, no clock.
class_name MemoryDefs
extends Object

const Memory := preload("res://scripts/sim/memory.gd")

const HOUR := 3600
const DAY := 24 * 3600


## Build the library: id -> MemoryDef. Pure; rebuilt fresh each call (defs are shared
## by reference within one store, so build once per store and reuse).
static func build() -> Dictionary:
	var lib := {}
	# greeted — a faint warm trace; remembered a day, colours mood ~half a day.
	lib["greeted"] = _def("greeted", DAY, 12 * HOUR, 0.7, 8, 0.4,
		MoodValues.new(0.10, -0.02, 0.0, 0.0))
	# complimented — a real warm mark; remembered 3 days, stacks (diminishing).
	lib["complimented"] = _def("complimented", 3 * DAY, 2 * DAY, 0.8, 12, 1.0,
		MoodValues.new(0.35, -0.10, 0.05, 0.0))
	# teased (landed well) — playful warmth, short-lived.
	lib["teased_warm"] = _def("teased_warm", DAY, 8 * HOUR, 0.8, 8, 0.6,
		MoodValues.new(0.20, -0.05, 0.05, 0.0))
	# teased (landed wrong) — a sting; remembered, sours and slightly angers.
	lib["teased_sour"] = _def("teased_sour", 2 * DAY, DAY, 0.85, 8, 0.8,
		MoodValues.new(-0.25, 0.20, 0.0, 0.0))
	# pushed_away — a real wound; remembered 4 days, strong sour + anger, slow decay.
	lib["pushed_away"] = _def("pushed_away", 4 * DAY, 3 * DAY, 0.9, 12, 1.2,
		MoodValues.new(-0.45, 0.35, 0.0, 0.0))
	# given_gift — a warm, lasting mark; remembered 5 days.
	lib["given_gift"] = _def("given_gift", 5 * DAY, 4 * DAY, 0.85, 8, 1.1,
		MoodValues.new(0.45, -0.15, 0.10, 0.0))
	return lib


static func _def(id: String, duration: int, dur_effects: int, stack_mult: float,
		stack_max: int, priority: float, mood: MoodValues) -> Memory.MemoryDef:
	var d := Memory.MemoryDef.new(id)
	d.duration = duration
	d.duration_effects = dur_effects
	d.stack_mult = stack_mult
	d.stack_max = stack_max
	d.priority = priority
	d.mood = mood
	return d
