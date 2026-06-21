## Memory test — aeriea's per-NPC memory (ported from BDCC2 MemorySystem, behind a
## seam, time-driven off SimClock).
##
## Asserts:
##   (a) ADD/QUERY — adding a memory records it, keyed by type and other-party id.
##   (b) DECAY — a memory's mood contribution ramps DOWN linearly over the seeded
##       clock toward 0 at no_effects_after, then expires (GC) at will_expire_at.
##   (c) STACKING — repeated same-type memories add diminishing mood (stack_mult^n),
##       capped at stack_max; more compliments warm Maren MORE but with falloff.
##   (d) DETERMINISM — same clock-advance sequence + same add sequence -> identical
##       memories and identical aggregated MoodValues (no RNG, no wall-clock).
##   (e) CALLBACK SURFACE — strongest_with / most_recent rank memories for the realizer.
##
## Run: xvfb-run -a godot4 --path . res://tests/memory_test.tscn --quit-after 2000
extends Node

const SimClock := preload("res://scripts/sim/sim_clock.gd")
const Memory := preload("res://scripts/sim/memory.gd")
const MemoryDefs := preload("res://scripts/sim/memory_defs.gd")

const PLAYER := "player"
const DAY := 24 * 3600
const HOUR := 3600

var _pass := 0
var _fail := 0
var _lib := {}


func _ready() -> void:
	print("\n=== aeriea memory test ===\n")
	_lib = MemoryDefs.build()
	_test_add_query()
	_test_decay_and_expiry()
	_test_stacking()
	_test_determinism()
	_test_callback_surface()
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


func _test_add_query() -> void:
	var clock := SimClock.new()
	var h := Memory.MemoryHolder.new()
	h.add_memory(clock, _lib["complimented"], PLAYER)
	h.add_memory(clock, _lib["greeted"], PLAYER)
	_ok(h.count_of("complimented") == 1, "memory recorded by type")
	_ok(h.has_memory_with("complimented", PLAYER), "memory keyed by other-party id")
	_ok(not h.has_memory_with("complimented", "someone_else"), "not matched for a different party")
	_ok(h.memories.size() == 2, "all memories held")


func _test_decay_and_expiry() -> void:
	var clock := SimClock.new()
	var h := Memory.MemoryHolder.new()
	h.add_memory(clock, _lib["complimented"], PLAYER)  # effect window = 2 days
	var m0 := h.mood_values(clock).mood
	_ok(m0 > 0.3, "fresh compliment contributes full mood (%.3f)" % m0)
	# Advance halfway through the effect window: contribution should roughly halve.
	clock.advance(DAY)  # 1 of 2 days
	var m_half := h.mood_values(clock).mood
	_ok(m_half < m0 and m_half > 0.0, "mood contribution decays over time (%.3f < %.3f)" % [m_half, m0])
	_ok(_approx(m_half, m0 * 0.5, 0.02), "decay is ~linear to half at the window midpoint")
	# Past the effect window: no mood contribution, but still REMEMBERED (duration=3d).
	clock.advance(2 * DAY)  # now 3 days elapsed; past 2-day effect window, at duration edge
	var m_late := h.mood_values(clock).mood
	_ok(_approx(m_late, 0.0), "no mood contribution past the effect window (%.4f)" % m_late)
	# Expire: at/after will_expire_at (3 days) the memory is GC'd.
	clock.advance(HOUR)  # past 3 days
	var removed := h.expire_old(clock)
	_ok(removed == 1 and h.memories.is_empty(), "memory GC'd after its remember-duration")


func _test_stacking() -> void:
	var clock := SimClock.new()
	var one := Memory.MemoryHolder.new()
	one.add_memory(clock, _lib["complimented"], PLAYER)
	var m1 := one.mood_values(clock).mood

	var three := Memory.MemoryHolder.new()
	for i in 3:
		three.add_memory(clock, _lib["complimented"], PLAYER)
	var m3 := three.mood_values(clock).mood

	_ok(m3 > m1, "3 compliments warm more than 1 (%.3f > %.3f)" % [m3, m1])
	# Diminishing returns: 3x is LESS than 3 * single (stack_mult < 1).
	_ok(m3 < m1 * 3.0, "stacking has diminishing returns (%.3f < %.3f)" % [m3, m1 * 3.0])

	# stack_max cap: with a tiny stack_max, extra memories don't add mood.
	var capped := Memory.MemoryHolder.new()
	var d: Memory.MemoryDef = _lib["complimented"]
	var saved_max: int = d.stack_max
	d.stack_max = 2
	for i in 5:
		capped.add_memory(clock, d, PLAYER)
	var m_capped := capped.mood_values(clock).mood
	var two := Memory.MemoryHolder.new()
	for i in 2:
		two.add_memory(clock, d, PLAYER)
	var m_two := two.mood_values(clock).mood
	_ok(_approx(m_capped, m_two), "stack_max caps the number that affect mood (%.3f == %.3f)" % [m_capped, m_two])
	d.stack_max = saved_max  # restore shared def


func _test_determinism() -> void:
	# Same clock-advance + add sequence on two independent stores -> identical mood.
	var seq_adds := ["greeted", "complimented", "teased_sour", "complimented", "given_gift"]
	var seq_waits := [HOUR, 6 * HOUR, DAY, HOUR, 2 * HOUR]
	var a := _replay(seq_adds, seq_waits)
	var b := _replay(seq_adds, seq_waits)
	_ok(_approx(a["mood"], b["mood"]) and _approx(a["anger"], b["anger"])
		and a["count"] == b["count"],
		"same clock+add sequence -> identical memory state + mood (deterministic)")


func _replay(adds: Array, waits: Array) -> Dictionary:
	var clock := SimClock.new()
	var lib := MemoryDefs.build()  # fresh defs per replay (independent)
	var h := Memory.MemoryHolder.new()
	for i in adds.size():
		h.add_memory(clock, lib[adds[i]], PLAYER)
		clock.advance(waits[i])
		h.expire_old(clock)
	var mv := h.mood_values(clock)
	return {"mood": mv.mood, "anger": mv.anger, "count": h.memories.size()}


func _test_callback_surface() -> void:
	var clock := SimClock.new()
	var h := Memory.MemoryHolder.new()
	h.add_memory(clock, _lib["greeted"], PLAYER)
	clock.advance(HOUR)
	h.add_memory(clock, _lib["pushed_away"], PLAYER)  # higher priority
	var ranked := h.strongest_with(clock.full_time(), PLAYER, 3)
	_ok(ranked.size() == 2, "strongest_with returns memories about the party")
	_ok(ranked[0].def.id == "pushed_away", "higher-priority memory ranks first")
	var recent := h.most_recent(PLAYER)
	_ok(recent != null and recent.def.id == "pushed_away", "most_recent is the latest add")
	# Store: per-id holders, time-driven GC across all.
	var store := Memory.MemoryStore.new()
	store.holder("npc_maren").add_memory(clock, _lib["greeted"], PLAYER)
	_ok(store.holder("npc_maren").count_of("greeted") == 1, "MemoryStore keys holders by npc id")
