## BodyCaps — the cap-model foundation (SYNTHESIS.md §3).
##
## Implements the FINALIZED cap model: raw modifier values + ONE global `extremeness`
## scalar + a DERIVED per-control allowed interval `cap(control, extremeness) -> [a, b]`
## (neutral-agnostic) + the single `apply_capped` choke (ONE per-pole-ratcheted clamp).
##
## This is the PURE, headless core the character creator wires its live write paths
## through (sculpt apply, region sliders, headline-axis fields, numeric entry, randomize).
## It carries NO scene/UI state, so it is exhaustively unit-testable.
##
## The cap function is TOTAL over every registry-reachable control (the DEFAULT CAP RULE,
## §3.1): an AUTHORED interval if one exists in the caps asset (the ~56 curated controls +
## the 6 headline axes), else a DERIVED symmetric interval from the modifier's registry
## range × a global default fraction, anchored at the modifier's neutral. So every live
## write path is genuinely capped, not just the curated set.
##
## CAP ASSET (`assets/body/caps.v<N>.json`): a versioned JSON table (§3.7) of authored
## modifier intervals + headline-axis bands + the single derived-fraction constant. The
## numeric values are PROVISIONAL and USER-TASTE-GATED (pending §8 #1b sweep + sign-off).
##
## THE CLAMP — ONE formula, every axis type (§3.2, the verified CORE FORMULA):
##   hi  = max(b, cur)     # cur raises the ceiling ONLY if already beyond b
##   lo  = min(a, cur)     # cur lowers the floor   ONLY if already beyond a
##   new = clamp(req, lo, hi)
## Outward-past-[a,b] hard-clamps; inward is free; each pole ratchets independently (no
## cross-pole sign-flip re-admission); beyond-cap stored values PERSIST (never re-snapped).
##
## HELD-INTERVAL / GESTURE LIFECYCLE (§3.2, the choke-capture invariant): the FIRST time
## `apply_capped(control, …)` is called within an active gesture, the choke LAZILY captures
## that control's held value `cur_start` (the live `cur` BEFORE the first write) and clamps
## every subsequent write in the gesture against the HELD interval, so a transient mid-gesture
## dip cannot collapse a ratchet. The held map is CLEARED at gesture end (and on a
## state-replacing op that ABORTS the gesture — the gesture-lifecycle-interruption invariant).
class_name BodyCaps
extends RefCounted

const ModifierRegistry := preload("res://scripts/body/modifier_registry.gd")

const DEFAULT_ASSET_PATH := "res://assets/body/caps.v1.json"

## Global extremeness scalar (0..1). 0 = conservative default intervals; 1 = each
## interval widened to the control's hard range. Lives on this creator-settings layer,
## NOT in BodyState.modifiers (§3.1) — it governs the INPUT clamp, not a body morph.
var extremeness: float = 0.0

## Authored modifier intervals: full_name -> {"a": float, "b": float} (the ~56 curated).
var _authored_modifiers: Dictionary = {}
## Authored headline-axis bands: field -> {a,b,hard_min,hard_max,neutral}.
var _headline: Dictionary = {}
## The single global fraction of the hard range for DERIVED (uncurated) intervals.
var _derived_fraction: float = 0.5
## The caps-asset version (recorded in saves for replay determinism, §3.7).
var version: int = 1

## Cached registry view (full_name -> entry), so cap() can read derived ranges/kinds.
var _by_full_name: Dictionary = {}

## The gesture's HELD-interval map: control -> cur_start (captured at first touch).
## Lives across an active gesture; cleared at gesture end / abort. The presence of a key
## marks "a gesture is active and this control has been touched within it."
var _drag_start_value: Dictionary = {}
## True while a continuous gesture is active (slider drag or sculpt drag). A one-write edit
## brackets a single apply_capped call (start_gesture + end_gesture around it), so its
## first-touch capture and gesture-end recompute coincide — capture is then a no-op.
var _gesture_active: bool = false


func _init(asset_path: String = DEFAULT_ASSET_PATH, registry: Dictionary = {}) -> void:
	_load_asset(asset_path)
	var reg := registry if not registry.is_empty() else BodyState.registry()
	_by_full_name = reg.get("by_full_name", {})


func _load_asset(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("BodyCaps: cannot open caps asset %s" % path)
		return
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("BodyCaps: caps asset %s did not parse to a dict" % path)
		return
	version = int(data.get("version", 1))
	_derived_fraction = float(data.get("derived_fraction", 0.5))
	_authored_modifiers = data.get("modifiers", {})
	_headline = data.get("headline", {})


## Is `control` a headline-axis field (vs a modifier full_name)?
func is_headline(control: String) -> bool:
	return _headline.has(control)


## The control's NEUTRAL / default value (the value an absent control reads as, §3.1).
## Headline fields use their authored neutral; modifiers use their registry default
## (0 for the bidirectional/unipolar detail modifiers).
func neutral_of(control: String) -> float:
	if _headline.has(control):
		return float(_headline[control]["neutral"])
	if _by_full_name.has(control):
		return float(_by_full_name[control]["default"])
	return 0.0


## The control's HARD range [hard_min, hard_max] in its own units (§3.1).
func hard_range_of(control: String) -> Array:
	if _headline.has(control):
		var h: Dictionary = _headline[control]
		return [float(h["hard_min"]), float(h["hard_max"])]
	if _by_full_name.has(control):
		var r: Array = _by_full_name[control]["range"]
		return [float(r[0]), float(r[1])]
	# Unknown control: a conservative symmetric unit interval (should not occur for any
	# registry-reachable control or headline field).
	return [-1.0, 1.0]


## The control's DEFAULT interval [a, b] at extremeness 0 — AUTHORED if present, else
## DERIVED by the §3.1 DEFAULT CAP RULE: symmetric about the neutral at `_derived_fraction`
## of the hard range (unipolar floor pinned to a=0), clamped to the hard range. TOTAL.
func default_interval(control: String) -> Array:
	if _headline.has(control):
		var h: Dictionary = _headline[control]
		return [float(h["a"]), float(h["b"])]
	if _authored_modifiers.has(control):
		var m: Dictionary = _authored_modifiers[control]
		return [float(m["a"]), float(m["b"])]
	# DERIVED: from the modifier's registry range × the global default fraction.
	var hr := hard_range_of(control)
	var hmin := float(hr[0])
	var hmax := float(hr[1])
	var span := hmax - hmin
	var neutral := neutral_of(control)
	var a := clampf(neutral - _derived_fraction * span, hmin, hmax)
	var b := clampf(neutral + _derived_fraction * span, hmin, hmax)
	# Unipolar floor pinned to the neutral (= 0): a [min>0, b] floor is FORBIDDEN (§3.1).
	if hmin >= 0.0:
		a = hmin
	return [a, b]


## cap(control, extremeness) -> [a, b]: the live allowed interval. At e=0 the default
## interval; as e->1 each endpoint lerps toward the HARD limit (§3.1/§3.2 widening).
func cap(control: String, e: float = -1.0) -> Array:
	if e < 0.0:
		e = extremeness
	var di := default_interval(control)
	var hr := hard_range_of(control)
	var a := lerpf(float(di[0]), float(hr[0]), clampf(e, 0.0, 1.0))
	var b := lerpf(float(di[1]), float(hr[1]), clampf(e, 0.0, 1.0))
	return [a, b]


# ---------------------------------------------------------------------------
# Gesture lifecycle (§3.2). A gesture brackets a continuous edit (slider drag / sculpt
# drag) or, degenerately, a single one-write edit. The held-interval map lives across it.
# ---------------------------------------------------------------------------

## Begin an active edit gesture. The held-interval map starts empty; each control captures
## its cur_start lazily on first touch through the choke.
func start_gesture() -> void:
	_gesture_active = true
	_drag_start_value.clear()


## End the active gesture: clear the held-interval map so no entry leaks into the next
## gesture (§3.2 — the ratchet collapses inward, once per gesture, on the committed value;
## the post-gesture recompute reads the settled stored value via cap()).
func end_gesture() -> void:
	_gesture_active = false
	_drag_start_value.clear()


## ABORT the active gesture (the gesture-lifecycle-interruption invariant, §3.2): a
## state-replacing op (raw restore/undo/redo/reset/jump, archetype/import load, or an
## extremeness change) MUST call this BEFORE applying, so the held map (whose cur_start
## references the op invalidates) is cleared and no zombie gesture survives. Equivalent to
## end_gesture, named for intent at the call sites.
func abort_gesture() -> void:
	end_gesture()


func gesture_active() -> bool:
	return _gesture_active


## True iff `control` has a captured held interval in the active gesture.
func has_held(control: String) -> bool:
	return _drag_start_value.has(control)


## The control's HELD interval [lo, hi] for the active gesture, computed from its captured
## cur_start (§3.2 step 3). Used to set widget bounds mid-gesture. Requires has_held.
func held_interval(control: String) -> Array:
	var cur_start := float(_drag_start_value[control])
	var ci := cap(control)
	return [minf(float(ci[0]), cur_start), maxf(float(ci[1]), cur_start)]


# ---------------------------------------------------------------------------
# The choke (§3.2). apply_capped is the ONE site every LIVE write routes through.
# ---------------------------------------------------------------------------

## apply_capped(control, req, cur) -> stored. The per-pole-ratcheted clamp. `cur` is the
## control's CURRENT stored value (the caller passes the live stored value, or the control's
## neutral if absent — §3.2 M9-2). On the FIRST touch within an active gesture, captures
## `cur` as the held cur_start; subsequent touches clamp against the HELD interval so a
## transient dip cannot collapse the ratchet. Outside a gesture, clamps against `cur` live.
func apply_capped(control: String, req: float, cur: float) -> float:
	# Choke-capture invariant: lazily capture cur_start on first touch in the gesture.
	if _gesture_active and not _drag_start_value.has(control):
		_drag_start_value[control] = cur
	# The ratchet input: the HELD cur_start during a gesture (after first touch), else live.
	var ratchet_cur := cur
	if _drag_start_value.has(control):
		ratchet_cur = float(_drag_start_value[control])
	var ci := cap(control)
	var a := float(ci[0])
	var b := float(ci[1])
	var hi := maxf(b, ratchet_cur)
	var lo := minf(a, ratchet_cur)
	return clampf(req, lo, hi)


# ---------------------------------------------------------------------------
# Build-time gate (§3.1 / §8 #11). Asserts neutral ∈ [a,b] for EVERY control (authored
# + derived). Archetype-containment is a stub that passes when no archetypes exist yet.
# ---------------------------------------------------------------------------

## Validate the build-time invariant `neutral ∈ default_interval` for every control:
## the authored headline + modifier intervals NUMERICALLY, and every registry-reachable
## modifier's DERIVED interval (which satisfies it by construction). Returns a list of
## violation strings; empty == the gate passes. (§8 #11b.)
func validate_neutral_in_interval() -> PackedStringArray:
	var errs := PackedStringArray()
	# Headline axes.
	for field in _headline:
		var n := neutral_of(field)
		var di := default_interval(field)
		if n < float(di[0]) - 1e-6 or n > float(di[1]) + 1e-6:
			errs.append("headline %s: neutral %f not in [%f, %f]" % [field, n, di[0], di[1]])
	# Every registry-reachable modifier (authored + derived). Macro modifiers are not
	# sculpt-reachable (excluded by build_accel), but checking them is harmless.
	for fn in _by_full_name:
		var n := neutral_of(fn)
		var di := default_interval(fn)
		if n < float(di[0]) - 1e-6 or n > float(di[1]) + 1e-6:
			errs.append("modifier %s: neutral %f not in [%f, %f]" % [fn, n, di[0], di[1]])
	return errs


## Validate first-party ARCHETYPE containment: every archetype value lies within its
## control's default interval `cap(control, 0)` (§8 #11a). STUB that passes when no
## archetypes exist yet (the roster is not built in Phase 1). `archetypes` is a list of
## BodyState-shaped dicts; pass [] for the stub. Returns violation strings (empty == pass).
func validate_archetype_containment(archetypes: Array = []) -> PackedStringArray:
	var errs := PackedStringArray()
	for arch in archetypes:
		if typeof(arch) != TYPE_DICTIONARY:
			continue
		# Headline fields.
		for field in _headline:
			if arch.has(field):
				var v := float(arch[field])
				var di := default_interval(field)
				if v < float(di[0]) - 1e-6 or v > float(di[1]) + 1e-6:
					errs.append("archetype headline %s=%f not in [%f, %f]" % [field, v, di[0], di[1]])
		# Modifier values.
		var mods: Dictionary = arch.get("modifiers", {})
		for fn in mods:
			var v := float(mods[fn])
			var di := default_interval(fn)
			if v < float(di[0]) - 1e-6 or v > float(di[1]) + 1e-6:
				errs.append("archetype modifier %s=%f not in [%f, %f]" % [fn, v, di[0], di[1]])
	return errs
