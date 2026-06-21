## Memory — per-NPC memory of events: decay, priority, mood-effect, stacking.
##
## PORTED (Path A) from BDCC2 `Game/Systems/MemorySystem/` (`MemoryBase.gd`,
## `MemoryEntry.gd`, `MemoryHolder.gd`).
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
##
## What is ported (the reusable MODEL):
##   - MemoryDef (from MemoryBase): a memory TYPE's def — id, duration,
##     duration_effects, stack_mult, stack_max, priority, and a mood-EFFECT MoodValues.
##   - MemoryEntry (from MemoryEntry): one remembered event — its def, happened_at,
##     will_expire_at, no_effects_after, and the other party's id.
##   - MemoryHolder (from MemoryHolder): one NPC's memory — add, GC-on-expiry, and
##     the decay-weighted + stack-weighted mood aggregation (calculateMoodValues).
##
## Path-A cuts (per bdcc2-mining-backlog.md #1):
##   - `GM.main.timeManager` -> aeriea's SimClock, INJECTED into every time call
##     (add_memory(clock,...), expire_old(clock), mood_values(clock)). The holder
##     never reaches for a global clock; the caller (timeline) hands it in. Time is
##     deterministic (SimClock.full_time off the seeded timeline).
##   - `GlobalRegistry.getMemory(id)` -> an aeriea-owned DEF TABLE (MemoryDefs.lib,
##     data). No global registry hub.
##   - `charRef:WeakRef` / `getChar()`/`getCharacter()`/`getPawn()` back-pointers ->
##     DELETED. A holder is keyed by NPC id externally (MemoryStore); memories key the
##     OTHER party by plain id string (other_id), never a character object.
##   - `ReactionSystem` / `getAskDayReactions` / `RNG.grabWeightedPairs` -> DROPPED
##     (that is the realizer's job in aeriea; surfaced as a plain priority-ranked
##     callback list via recent()/strongest_with(), no embedded line engine).
##   - `Log.Print` / `Bins` networking -> DROPPED (deterministic, self-hosted; no RPC).
##
## Determinism: every time-dependent value derives from the injected SimClock's
## full_time(), which advances only off the seeded timeline. Same clock sequence +
## same add_memory sequence -> identical memories and identical aggregated mood. No
## RNG, no wall-clock.

class_name Memory
extends RefCounted

const SimClock := preload("res://scripts/sim/sim_clock.gd")


## A memory TYPE's definition (BDCC2 MemoryBase). Pure data.
class MemoryDef:
	extends RefCounted
	var id: String = ""
	## How long the event is REMEMBERED at all (seconds). After this it is GC'd.
	var duration: int = MemoryDef.DAY
	## How long it AFFECTS mood (seconds). < 0 means "same as duration". The mood
	## contribution ramps DOWN linearly to 0 across this window (decay).
	var duration_effects: int = -1
	## Each additional same-type memory beyond the first contributes stack_mult^n of
	## its mood effect (diminishing returns on repetition).
	var stack_mult: float = 0.8
	## At most this many same-type memories contribute to mood (all are still
	## remembered; only stack_max affect mood).
	var stack_max: int = 99
	## Ranking weight for surfacing as a callback (recent()/strongest_with()).
	var priority: float = 1.0
	## The mood EFFECT this memory contributes while in its effect window (null = none).
	var mood: MoodValues = null

	const MINUTE := 60
	const HOUR := 3600
	const DAY := 24 * 3600

	func _init(p_id: String = "") -> void:
		id = p_id

	## Effect window end relative to happen-time (seconds): duration_effects or,
	## if unset (<0), the full remember-duration.
	func effects_window() -> int:
		return duration_effects if duration_effects >= 0 else duration


## One remembered event instance (BDCC2 MemoryEntry).
class MemoryEntry:
	extends RefCounted
	var def: MemoryDef = null
	var happened_at: int = 0       # absolute seconds (SimClock.full_time at add)
	var will_expire_at: int = 0    # absolute seconds; GC'd once full_time >= this
	var no_effects_after: int = 0  # absolute seconds; no mood contribution past this
	var other_id: String = ""      # the other party (plain id string), "" if none

	## 0..1 ramp from add-time to effect-window end (BDCC2 getProgress).
	func progress(now: int) -> float:
		var total := no_effects_after - happened_at
		if total <= 0:
			return 1.0
		return clampf(remap(float(now - happened_at), 0.0, float(total), 0.0, 1.0), 0.0, 1.0)

	## Ranking weight for surfacing as a callback. BDCC2's calculateFinalPriority was
	## progress*priority (progress ramps 0->1 as the memory AGES, so OLDER memories
	## ranked HIGHER — sensible for its "ask about your day" recap, wrong for aeriea's
	## "react to what just happened" callbacks). aeriea DELIBERATELY DIVERGES: rank by
	## priority * FRESHNESS (1-progress), so a recent strong event (pushed_away just
	## now) outranks a faint stale one. (Path-A: we own the projection; the realizer's
	## need defines the ranking, not BDCC2's.) freshness() exposes the raw factor.
	func final_priority(now: int) -> float:
		return freshness(now) * def.priority

	## 1 at add-time, ramping to 0 at the effect-window end (inverse of progress).
	func freshness(now: int) -> float:
		return 1.0 - progress(now)

	func elapsed_seconds(now: int) -> int:
		return now - happened_at

	func elapsed_days(now: int) -> int:
		return SimClock.day_at(now) - SimClock.day_at(happened_at)


## One NPC's memory store + decay-weighted mood aggregation (BDCC2 MemoryHolder).
## Keyed by NPC id externally; holds no back-pointer to any character object.
class MemoryHolder:
	extends RefCounted
	var memories: Array = []           # MemoryEntry, oldest first
	var by_type: Dictionary = {}       # def id -> Array[MemoryEntry]
	## The last aggregated mood (recomputed by mood_values()). Cached for cheap reads.
	var mood_values_cache: MoodValues = MoodValues.new()

	## Remember an event NOW (clock.full_time()). other_id keys the other party.
	func add_memory(clock: SimClock, def: MemoryDef, other_id: String = "") -> MemoryEntry:
		if def == null:
			return null
		var now := clock.full_time()
		var e := MemoryEntry.new()
		e.def = def
		e.happened_at = now
		e.will_expire_at = now + def.duration
		e.no_effects_after = now + def.effects_window()
		e.other_id = other_id
		memories.append(e)
		if not by_type.has(def.id):
			by_type[def.id] = [e]
		else:
			by_type[def.id].append(e)
		return e

	## GC expired memories (full_time >= will_expire_at). Time-driven: call after the
	## clock advances. Returns how many were removed.
	func expire_old(clock: SimClock) -> int:
		var now := clock.full_time()
		var removed := 0
		var kept: Array = []
		for e in memories:
			if now >= e.will_expire_at:
				if by_type.has(e.def.id):
					by_type[e.def.id].erase(e)
					if (by_type[e.def.id] as Array).is_empty():
						by_type.erase(e.def.id)
				removed += 1
			else:
				kept.append(e)
		memories = kept
		return removed

	## Aggregate the live mood effect across all in-window memories, decay-weighted
	## (progress ramps the contribution to 0) and stack-weighted (stack_mult^n, capped
	## at stack_max per type). PORTED from BDCC2 calculateMoodValues. Pure function of
	## (memories, clock); updates and returns mood_values_cache.
	func mood_values(clock: SimClock) -> MoodValues:
		var now := clock.full_time()
		var out := MoodValues.new()
		var type_mult: Dictionary = {}   # def -> running stack multiplier
		var type_count: Dictionary = {}  # def -> contributing count
		# Newest first (BDCC2 iterates in reverse so recent stacks count first).
		for i in memories.size():
			var e: MemoryEntry = memories[memories.size() - 1 - i]
			var def := e.def
			if def.mood == null or now > e.no_effects_after:
				continue
			var count: int = type_count.get(def, 0)
			if count >= def.stack_max:
				continue
			# Linear decay: full at add, 0 at no_effects_after.
			var total := e.no_effects_after - e.happened_at
			var fresh := 1.0
			if total > 0:
				fresh = 1.0 - clampf(remap(float(now - e.happened_at), 0.0, float(total), 0.0, 1.0), 0.0, 1.0)
			var mult := fresh
			if not type_mult.has(def):
				type_mult[def] = 1.0
				type_count[def] = 1
			else:
				type_mult[def] = float(type_mult[def]) * def.stack_mult
				mult *= float(type_mult[def])
				type_count[def] = count + 1
			out.combine_with(def.mood, mult)
		mood_values_cache = out
		return out

	# --- query / callback surface (replaces BDCC2's ReactionSystem coupling) ------

	func count_of(def_id: String) -> int:
		return (by_type.get(def_id, []) as Array).size()

	func count_with(def_id: String, other_id: String) -> int:
		var n := 0
		for e in by_type.get(def_id, []):
			if e.other_id == other_id:
				n += 1
		return n

	func has_memory(def_id: String) -> bool:
		return by_type.has(def_id)

	func has_memory_with(def_id: String, other_id: String) -> bool:
		return count_with(def_id, other_id) > 0

	## Memories about `other_id`, ranked by final_priority (highest first). The
	## realizer reads this to surface a callback line. now = clock.full_time().
	func strongest_with(now: int, other_id: String, max_n: int = 3) -> Array:
		var ranked: Array = []
		for e in memories:
			if e.other_id != other_id:
				continue
			ranked.append(e)
		ranked.sort_custom(func(a, b): return a.final_priority(now) > b.final_priority(now))
		if ranked.size() > max_n:
			ranked.resize(max_n)
		return ranked

	## The most recent memory of any type (or about other_id if given), or null.
	func most_recent(other_id: String = "") -> MemoryEntry:
		for i in memories.size():
			var e: MemoryEntry = memories[memories.size() - 1 - i]
			if other_id == "" or e.other_id == other_id:
				return e
		return null


## A small per-id store of holders (replaces BDCC2's characterRegistry-keyed holders
## dict). aeriea-owned; keys NPCs by plain id string, no character objects.
class MemoryStore:
	extends RefCounted
	var holders: Dictionary = {}   # npc id -> MemoryHolder

	func holder(npc_id: String) -> MemoryHolder:
		if not holders.has(npc_id):
			holders[npc_id] = MemoryHolder.new()
		return holders[npc_id]

	## GC every holder against the clock (time-driven). Call after advancing time.
	func expire_all(clock: SimClock) -> void:
		for id in holders:
			(holders[id] as MemoryHolder).expire_old(clock)
