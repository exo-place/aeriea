## MoodValues — a small affect-scalar bank (the additive mood vector).
##
## PORTED (Path A) from BDCC2 `Game/PawnAI/Mood/MoodValues.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
##
## What is ported (the reusable MODEL): the four affect scalars + clear/combineWith
## additive aggregation. This is the currency a memory's mood-EFFECT contributes and
## the MemoryHolder accumulates (decay-weighted, stacked). System 4 (Mood) reads the
## aggregate and projects it to an ExprState.
##
## Path-A cuts: dropped the MoodStat enum getStat() switch (BDCC2 indexed these by an
## int enum for its mood-name registry; aeriea reads the named fields directly) and
## the chained setters (replaced by the _init signature). Pure data, no couplings.
##
## Channels (each roughly -1..+1 after a single contribution; the aggregate can exceed
## that range before the Mood projection clamps/squashes it):
##   mood       sad (-) .. happy (+)
##   anger      friendly (-) .. angry (+)   [NOTE: + is angry, matching BDCC2]
##   lust       chaste (0) .. horny (+)
##   dominance  subby (-) .. dominant (+)
class_name MoodValues
extends RefCounted

var mood: float = 0.0
var anger: float = 0.0
var lust: float = 0.0
var dominance: float = 0.0


func _init(p_mood: float = 0.0, p_anger: float = 0.0, p_lust: float = 0.0,
		p_dominance: float = 0.0) -> void:
	mood = p_mood
	anger = p_anger
	lust = p_lust
	dominance = p_dominance


func clear() -> void:
	mood = 0.0
	anger = 0.0
	lust = 0.0
	dominance = 0.0


## Additively fold another bank in, scaled by `mult` (the decay/stack weight).
func combine_with(other: MoodValues, mult: float = 1.0) -> void:
	mood += other.mood * mult
	anger += other.anger * mult
	lust += other.lust * mult
	dominance += other.dominance * mult


func duplicate_values() -> MoodValues:
	return MoodValues.new(mood, anger, lust, dominance)


func to_dict() -> Dictionary:
	return {"mood": mood, "anger": anger, "lust": lust, "dominance": dominance}


static func from_dict(d: Dictionary) -> MoodValues:
	return MoodValues.new(
		float(d.get("mood", 0.0)), float(d.get("anger", 0.0)),
		float(d.get("lust", 0.0)), float(d.get("dominance", 0.0)))
