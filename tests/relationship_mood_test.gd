## Relationship + Mood test — pairwise affection/lust + short-term annoyance (ported
## from BDCC2 RelationshipSystem) and the Mood bridge whose OUTPUT IS AN ExprState.
##
## Asserts:
##   (a) AFFECTION — add_affection accumulates, clamps, and saturates (diminishing
##       returns past +-1); add_lust clamps 0..1.
##   (b) ANNOYANCE — add_annoyance accumulates; time-driven decay fades it to 0.
##   (c) DECAY — long-term affection decays toward 0 over the seeded timeline (no
##       frame delta); short-term entries are GC'd when fully faded.
##   (d) MOOD->ExprState — Mood.read projects (memory mood + affection + annoyance)
##       to a sane ExprState: warm history -> +valence, low tension, engaged; a
##       history of being pushed away -> -valence, high tension, averted.
##   (e) DETERMINISM — same event sequence -> identical relationship state AND
##       identical ExprState (no RNG, no wall-clock).
##   (f) INTEGRATION — a greet->compliment->slight sequence through memory+relationship
##       moves the resulting ExprState in the expected direction across the arc.
##
## Run: xvfb-run -a godot4 --path . res://tests/relationship_mood_test.tscn --quit-after 2000
extends Node

const SimClock := preload("res://scripts/sim/sim_clock.gd")
const Memory := preload("res://scripts/sim/memory.gd")
const MemoryDefs := preload("res://scripts/sim/memory_defs.gd")
const Relationship := preload("res://scripts/sim/relationship.gd")
const Mood := preload("res://scripts/sim/mood.gd")

const MAREN := "npc_maren"
const PLAYER := "player"
const DAY := 24 * 3600
const HOUR := 3600

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea relationship + mood test ===\n")
	_test_affection()
	_test_annoyance_decay()
	_test_affection_decay()
	_test_mood_to_exprstate()
	_test_determinism()
	_test_integration_arc()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


func _approx(a: float, b: float, eps := 1e-5) -> bool:
	return absf(a - b) <= eps


func _test_affection() -> void:
	var r := Relationship.new()
	r.add_affection(PLAYER, MAREN, 0.5)
	r.add_affection(PLAYER, MAREN, 0.3)
	_ok(_approx(r.get_affection(PLAYER, MAREN), 0.8), "affection accumulates (%.3f)" % r.get_affection(PLAYER, MAREN))
	# Symmetric key: order-independent.
	_ok(_approx(r.get_affection(MAREN, PLAYER), 0.8), "affection is symmetric (order-independent)")
	# Saturation: pushing past +1 has diminishing effect (BDCC2 curve).
	var r2 := Relationship.new()
	for i in 20:
		r2.add_affection(PLAYER, MAREN, 1.0)
	var sat := r2.get_affection(PLAYER, MAREN)
	_ok(sat <= Relationship.AFFECTION_MAX and sat > 1.0, "affection saturates, clamped to max (%.3f)" % sat)
	# Lust clamps 0..1.
	r.add_lust(PLAYER, MAREN, 2.0)
	_ok(_approx(r.get_lust(PLAYER, MAREN), 1.0), "lust clamps to 1.0")


func _test_annoyance_decay() -> void:
	var r := Relationship.new()
	r.add_annoyance(MAREN, PLAYER, 1.0)
	_ok(_approx(r.get_annoyance(MAREN, PLAYER), 1.0), "annoyance accumulates")
	# Annoyance is DIRECTIONAL (reactor -> target), not symmetric.
	_ok(_approx(r.get_annoyance(PLAYER, MAREN), 0.0), "annoyance is directional")
	# Time-driven fade: a big advance clears it.
	r.decay(DAY)
	_ok(r.get_annoyance(MAREN, PLAYER) < 1.0, "annoyance fades over time")
	r.decay(DAY * 30)
	_ok(_approx(r.get_annoyance(MAREN, PLAYER), 0.0), "annoyance fully fades and the entry is GC'd")


func _test_affection_decay() -> void:
	var r := Relationship.new()
	r.add_affection(PLAYER, MAREN, 0.5)
	var before := r.get_affection(PLAYER, MAREN)
	r.decay(4 * HOUR)   # time-driven, off the timeline (not frame delta)
	var after := r.get_affection(PLAYER, MAREN)
	_ok(after < before and after > 0.0, "affection decays toward 0 over time (%.4f < %.4f)" % [after, before])


func _test_mood_to_exprstate() -> void:
	# Warm history: positive memory mood + affection, no annoyance.
	var warm_mv := MoodValues.new(0.6, -0.1, 0.0, 0.0)
	var warm := Mood.read(warm_mv, 1.5, 0.2, 0.0)
	_ok(warm is ExprState, "Mood.read returns an ExprState")
	_ok(warm.valence > 0.3, "warm history -> positive valence (%.3f)" % warm.valence)
	_ok(warm.tension < 0.2, "warm history -> low tension (%.3f)" % warm.tension)
	_ok(warm.attention > 0.6, "affection -> engaged attention (%.3f)" % warm.attention)

	# Sour history: a record of being pushed away (negative mood + anger) + annoyance.
	var sour_mv := MoodValues.new(-0.5, 0.4, 0.0, 0.0)
	var sour := Mood.read(sour_mv, -0.8, 0.0, 0.6)
	_ok(sour.valence < -0.2, "sour history -> negative valence (%.3f)" % sour.valence)
	_ok(sour.tension > 0.5, "sour + annoyance -> high tension (%.3f)" % sour.tension)
	_ok(sour.attention < warm.attention, "sour history averts attention relative to warm")


func _test_determinism() -> void:
	var a := _run_arc()
	var b := _run_arc()
	_ok(_approx(a["valence"], b["valence"]) and _approx(a["tension"], b["tension"])
		and _approx(a["attention"], b["attention"]) and _approx(a["affection"], b["affection"]),
		"same event sequence -> identical relationship state AND ExprState (deterministic)")


# A small canonical arc shared by determinism + integration: greet, compliment x2,
# then a slight (pushed_away), with time between. Returns the final read.
func _run_arc() -> Dictionary:
	var clock := SimClock.new()
	var lib := MemoryDefs.build()
	var holder := Memory.MemoryHolder.new()
	var rel := Relationship.new()

	_event(clock, holder, rel, lib, "greeted", 0.05)
	clock.advance(HOUR)
	_event(clock, holder, rel, lib, "complimented", 0.2)
	clock.advance(HOUR)
	_event(clock, holder, rel, lib, "complimented", 0.2)
	clock.advance(2 * HOUR)
	_event(clock, holder, rel, lib, "pushed_away", -0.3)
	holder.expire_old(clock)
	rel.decay(0)

	var mv := holder.mood_values(clock)
	var aff := rel.get_affection(PLAYER, MAREN)
	var ann := rel.get_annoyance(MAREN, PLAYER)
	var e := Mood.read(mv, aff, rel.get_lust(PLAYER, MAREN), ann)
	return {"valence": e.valence, "tension": e.tension, "attention": e.attention, "affection": aff}


func _event(clock: SimClock, holder, rel, lib: Dictionary, mem_id: String, aff_delta: float) -> void:
	holder.add_memory(clock, lib[mem_id], PLAYER)
	rel.add_affection(PLAYER, MAREN, aff_delta)
	if mem_id == "pushed_away":
		rel.add_annoyance(MAREN, PLAYER, 0.8)


func _test_integration_arc() -> void:
	# Snapshot the ExprState at three points along the arc and check it MOVES right:
	# guarded start -> warming after compliments -> stung after the slight.
	var clock := SimClock.new()
	var lib := MemoryDefs.build()
	var holder := Memory.MemoryHolder.new()
	var rel := Relationship.new()

	_event(clock, holder, rel, lib, "greeted", 0.05)
	var start := Mood.read(holder.mood_values(clock), rel.get_affection(PLAYER, MAREN), 0.0,
		rel.get_annoyance(MAREN, PLAYER))

	clock.advance(HOUR)
	_event(clock, holder, rel, lib, "complimented", 0.2)
	clock.advance(HOUR)
	_event(clock, holder, rel, lib, "complimented", 0.2)
	var warmed := Mood.read(holder.mood_values(clock), rel.get_affection(PLAYER, MAREN), 0.0,
		rel.get_annoyance(MAREN, PLAYER))

	clock.advance(HOUR)
	_event(clock, holder, rel, lib, "pushed_away", -0.3)
	var stung := Mood.read(holder.mood_values(clock), rel.get_affection(PLAYER, MAREN), 0.0,
		rel.get_annoyance(MAREN, PLAYER))

	_ok(warmed.valence > start.valence, "compliments raise valence over the greeting baseline")
	_ok(warmed.attention > start.attention, "compliments grow engaged attention")
	_ok(stung.valence < warmed.valence, "the slight drops valence from the warmed peak")
	_ok(stung.tension > warmed.tension, "the slight + annoyance raises tension")
