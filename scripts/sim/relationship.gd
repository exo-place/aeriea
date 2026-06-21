## Relationship — pairwise affection/lust + short-term annoyance, with decay.
##
## PORTED (Path A) from BDCC2 `Game/Systems/RelationshipSystem/`
##   (`RelationshipEntry.gd`, `RelationshipShortTermEntry.gd`, `RelationshipSystem.gd`).
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
##
## What is ported (the reusable MODEL):
##   - RelationshipEntry: pairwise long-term affection + lust, clamped, slow decay
##     toward 0 (BDCC2 decayEntryShouldRemove).
##   - ShortTermEntry: short-term ANNOYANCE that fades, with per-action cooldowns
##     (BDCC2 RelationshipShortTermEntry.updateCheckShouldRemove).
##   - The add/get/decay API + the asymmetric affection diminishing-returns curve
##     (BDCC2 addAffection: pushing past +-1 has reduced effect).
##
## Path-A cuts (bdcc2-mining-backlog.md #2):
##   - `GM.GB.*` balance constants (socialAnnoyanceFadeRate, socialCooldownDecayRate,
##     etc.) -> aeriea-owned CONSTS here (DATA). No global-balance god-object.
##   - `GM.main.characterRegistry.hasCharacter` validation + `RelationshipHolder` +
##     `introduced` set -> DELETED. Pairs are keyed by ORDERED plain id strings; no
##     character objects, no registry. (The "introduced/knows" set is not needed for
##     the affect read; omitted until a feature wants it.)
##   - `CharacterPawn` annoyance/cooldown overloads (addAnnoyancePawns, etc.) -> gone;
##     id-string API only.
##   - `_physics_process` frame-delta decay -> TIME-DRIVEN decay(seconds) off the
##     seeded timeline (the same determinism cut as SimClock). Same advance sequence
##     -> identical relationship state. No frame delta, no wall-clock.
##   - `Network.isServer()` gates + `Log.Print` -> DROPPED (deterministic, self-hosted).
##
## Determinism: every mutation is explicit (add_affection / add_lust / add_annoyance)
## or a TIME-DRIVEN decay(seconds); no RNG, no wall-clock. Same call sequence ->
## identical state.
class_name Relationship
extends RefCounted

# --- aeriea-owned balance DATA (was GM.GB) ------------------------------------
const AFFECTION_MAX := 3.0
const LUST_MAX := 1.0
## Long-term affection/lust decay toward 0, per second (BDCC2 used dt*0.00001).
const AFFECTION_DECAY_PER_SEC := 0.00001
const LUST_DECAY_PER_SEC := 0.00001
## Below this magnitude an entry is considered decayed to nothing.
const DECAY_EPSILON := 0.001
## Short-term annoyance fade, per second (was GM.GB.socialAnnoyanceFadeRate).
const ANNOYANCE_FADE_PER_SEC := 0.00005
## Per-action cooldown decay, per second (was GM.GB.socialCooldownDecayRate).
const COOLDOWN_DECAY_PER_SEC := 0.0001


## One pairwise long-term entry (BDCC2 RelationshipEntry).
class Entry:
	extends RefCounted
	var affection: float = 0.0
	var lust: float = 0.0

	## Decay both toward 0 by `seconds`. Returns true if fully decayed (removable).
	func decay(seconds: int) -> bool:
		affection = _move_to(affection, 0.0, seconds * Relationship.AFFECTION_DECAY_PER_SEC)
		lust = _move_to(lust, 0.0, seconds * Relationship.LUST_DECAY_PER_SEC)
		return absf(affection) < Relationship.DECAY_EPSILON and absf(lust) < Relationship.DECAY_EPSILON

	static func _move_to(v: float, target: float, by: float) -> float:
		if v < target:
			return minf(v + by, target)
		return maxf(v - by, target)


## One directional short-term entry: reactor's annoyance at target + action cooldowns
## (BDCC2 RelationshipShortTermEntry).
class ShortTerm:
	extends RefCounted
	var annoyed: float = 0.0
	var action_cooldowns: Dictionary = {}   # action id -> remaining

	## Fade annoyance + decay cooldowns by `seconds`. Returns true if removable.
	func decay(seconds: int) -> bool:
		if annoyed > 0.0:
			annoyed = maxf(0.0, annoyed - seconds * Relationship.ANNOYANCE_FADE_PER_SEC)
		if not action_cooldowns.is_empty():
			for a in action_cooldowns.keys():
				action_cooldowns[a] = float(action_cooldowns[a]) - seconds * Relationship.COOLDOWN_DECAY_PER_SEC
				if action_cooldowns[a] <= 0.0:
					action_cooldowns.erase(a)
		return annoyed <= 0.0 and action_cooldowns.is_empty()


# --- the store (was RelationshipSystem; id-keyed, no registry) -----------------

var _entries: Dictionary = {}      # "a|b" (ordered) -> Entry
var _short: Dictionary = {}        # "reactor>target" (directional) -> ShortTerm


static func _pair_key(a: String, b: String) -> String:
	# Affection/lust are symmetric -> order-independent key.
	return ("%s|%s" % [a, b]) if a <= b else ("%s|%s" % [b, a])


static func _dir_key(reactor: String, target: String) -> String:
	return "%s>%s" % [reactor, target]


func _get_or_create_entry(a: String, b: String) -> Entry:
	var k := _pair_key(a, b)
	if not _entries.has(k):
		_entries[k] = Entry.new()
	return _entries[k]


## Affection change with BDCC2's asymmetric diminishing returns: pushing further past
## +-1 has reduced effect, so relationships saturate rather than run away.
func add_affection(a: String, b: String, amount: float) -> void:
	var cur := get_affection(a, b)
	if cur > 1.0 and amount > 0.0:
		amount /= cur
	elif cur < -1.0 and amount < 0.0:
		amount /= -cur
	var e := _get_or_create_entry(a, b)
	e.affection = clampf(e.affection + amount, -AFFECTION_MAX, AFFECTION_MAX)


func add_lust(a: String, b: String, amount: float) -> void:
	var e := _get_or_create_entry(a, b)
	e.lust = clampf(e.lust + amount, 0.0, LUST_MAX)


func get_affection(a: String, b: String) -> float:
	var k := _pair_key(a, b)
	return (_entries[k] as Entry).affection if _entries.has(k) else 0.0


func get_lust(a: String, b: String) -> float:
	var k := _pair_key(a, b)
	return (_entries[k] as Entry).lust if _entries.has(k) else 0.0


# --- short-term annoyance / cooldowns -----------------------------------------

func _get_or_create_short(reactor: String, target: String) -> ShortTerm:
	var k := _dir_key(reactor, target)
	if not _short.has(k):
		_short[k] = ShortTerm.new()
	return _short[k]


func add_annoyance(reactor: String, target: String, amount: float) -> void:
	_get_or_create_short(reactor, target).annoyed += amount


func get_annoyance(reactor: String, target: String) -> float:
	var k := _dir_key(reactor, target)
	return (_short[k] as ShortTerm).annoyed if _short.has(k) else 0.0


func add_action_cooldown(reactor: String, target: String, action_id: String, amount: float = 1.0) -> void:
	if action_id == "":
		return
	var s := _get_or_create_short(reactor, target)
	s.action_cooldowns[action_id] = float(s.action_cooldowns.get(action_id, 0.0)) + amount


func get_action_cooldown(reactor: String, target: String, action_id: String) -> float:
	var k := _dir_key(reactor, target)
	if not _short.has(k):
		return 0.0
	return float((_short[k] as ShortTerm).action_cooldowns.get(action_id, 0.0))


# --- time-driven decay (was _physics_process; now timeline-driven) ------------

## Decay all long-term + short-term entries by `seconds`, removing those fully
## decayed. Call after the clock advances (e.g. on leave/return). Deterministic.
func decay(seconds: int) -> void:
	if seconds <= 0:
		return
	for k in _entries.keys():
		if (_entries[k] as Entry).decay(seconds):
			_entries.erase(k)
	for k in _short.keys():
		if (_short[k] as ShortTerm).decay(seconds):
			_short.erase(k)
