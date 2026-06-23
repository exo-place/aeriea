## Cap-model foundation test — the BodyCaps core (SYNTHESIS.md §3): the per-control
## allowed interval `cap()`, the apply_capped per-pole-ratcheted choke, the held-interval
## gesture lifecycle, and the build-time `neutral ∈ [a,b]` gate.
##
## These behaviors are OBJECTIVELY testable (the §8 (a) measurable class — the agent may
## verify; the per-control plausibility AABB sweep / visual taste is USER-gated and NOT here).
##
## Asserts (gate #1a OBJECTIVE clauses, mapped to the spec):
##   - B8-1: outward beyond [a,b] HARD-clamps (masculinity window 20/80; bidir ±0.5).
##   - inward toward the interior is FREE.
##   - B8-3: per-pole ratchet — a high-ratcheted cur does NOT re-admit the low pole.
##   - beyond-cap value PERSISTS (extremeness raised then lowered → not retroactively snapped).
##   - iv: a transient mid-gesture dip does NOT collapse a ratchet (held-interval invariant).
##   - vi: a state-replacing op mid-gesture ABORTS the gesture; fresh capture against new state.
##   - B8-2: restore/load BYPASSES the cap (raw, no re-clamp) — beyond-cap survives.
##   - v: an UNCURATED sculpt-reachable modifier clamps to its DERIVED interval, not hard range.
##   - #11b: neutral ∈ [a,b] holds for EVERY control (authored + derived).
##   - extremeness widens the interval toward the hard range.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/body_caps_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const BodyCaps := preload("res://scripts/body/body_caps.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea CAP-MODEL FOUNDATION — extremeness, per-pole ratcheted caps, the choke ===\n")
	_test_default_intervals()
	_test_outward_hard_clamp()
	_test_inward_free()
	_test_per_pole_ratchet()
	_test_beyond_cap_persists()
	_test_extremeness_widens()
	_test_derived_uncurated()
	_test_held_interval_transient_dip()
	_test_gesture_abort()
	_test_one_write_no_held_leak()
	_test_neutral_in_interval_gate()
	_test_archetype_containment_stub()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % msg)


func _approx(a: float, b: float, eps: float = 1e-4) -> bool:
	return absf(a - b) <= eps


func _new_caps() -> BodyCaps:
	return BodyCaps.new()


# A curated bidirectional modifier with authored interval [-0.5, 0.5].
const BIDIR := "breast/breast-dist-decr|incr"
# A curated unipolar modifier with authored interval [0, 0.5].
const UNIPOLAR := "head/head-oval"


func _test_default_intervals() -> void:
	var c := _new_caps()
	# Headline masculinity authored window [20, 80] around neutral 50.
	var mi := c.cap("masculinity", 0.0)
	_ok(_approx(mi[0], 20.0) and _approx(mi[1], 80.0), "masculinity default [20,80], got %s" % str(mi))
	# Curated bidirectional default [-0.5, 0.5].
	var bi := c.cap(BIDIR, 0.0)
	_ok(_approx(bi[0], -0.5) and _approx(bi[1], 0.5), "bidir default [-0.5,0.5], got %s" % str(bi))
	# Curated unipolar floor pinned to 0.
	var ui := c.cap(UNIPOLAR, 0.0)
	_ok(_approx(ui[0], 0.0) and _approx(ui[1], 0.5), "unipolar default [0,0.5], got %s" % str(ui))


func _test_outward_hard_clamp() -> void:
	var c := _new_caps()
	# B8-1: masculinity window — req=100 → 80, req=0 → 20 (cur at neutral 50, inside).
	_ok(_approx(c.apply_capped("masculinity", 100.0, 50.0), 80.0), "masculinity req=100 → 80")
	_ok(_approx(c.apply_capped("masculinity", 0.0, 50.0), 20.0), "masculinity req=0 → 20")
	# Bidirectional ±0.5: req=-1.0 → -0.5 (NOT -1.0); req=+1.0 → +0.5.
	_ok(_approx(c.apply_capped(BIDIR, -1.0, 0.0), -0.5), "bidir req=-1 → -0.5")
	_ok(_approx(c.apply_capped(BIDIR, 1.0, 0.0), 0.5), "bidir req=+1 → +0.5")


func _test_inward_free() -> void:
	var c := _new_caps()
	# Any request inside [a,b] applies unchanged, from either side.
	_ok(_approx(c.apply_capped(BIDIR, 0.3, 0.0), 0.3), "inward 0.3 free")
	_ok(_approx(c.apply_capped(BIDIR, -0.2, 0.5), -0.2), "inward -0.2 from cur=0.5 free")
	_ok(_approx(c.apply_capped("masculinity", 55.0, 50.0), 55.0), "masculinity inward 55 free")


func _test_per_pole_ratchet() -> void:
	var c := _new_caps()
	# B8-3: cur=+0.9 (ratcheted high; b=0.5). hi=0.9, lo=min(-0.5,0.9)=-0.5.
	# req=-0.9 must land at the FLOOR -0.5, NOT -0.9 (no cross-pole sign-flip re-admission).
	_ok(_approx(c.apply_capped(BIDIR, -0.9, 0.9), -0.5), "ratcheted-high cur=0.9, req=-0.9 → -0.5 (floor)")
	# Back up toward the ratcheted reach is still admitted (clamped to hi=0.9).
	_ok(_approx(c.apply_capped(BIDIR, 1.5, 0.9), 0.9), "ratcheted-high cur=0.9, req=1.5 → 0.9 (held high)")
	# Symmetric: cur=-0.9 (ratcheted low). req=+0.9 → +0.5 (ceiling), not +0.9.
	_ok(_approx(c.apply_capped(BIDIR, 0.9, -0.9), 0.5), "ratcheted-low cur=-0.9, req=+0.9 → +0.5 (ceiling)")


func _test_beyond_cap_persists() -> void:
	# Raise extremeness, push a value beyond the default cap, lower extremeness: the value is
	# NOT retroactively snapped (apply_capped with cur beyond [a,b] holds it; ci uses live e).
	var c := _new_caps()
	c.extremeness = 1.0
	var v := c.apply_capped(BIDIR, 1.0, 0.0)   # at e=1, [a,b] widens to hard [-1,1]
	_ok(_approx(v, 1.0), "at e=1, req=1 reaches 1.0, got %f" % v)
	# Lower extremeness back to 0; the STORED value v=1.0 is the new cur. A no-op write
	# (req=cur) returns it unchanged — no retroactive snap to the [-0.5,0.5] default.
	c.extremeness = 0.0
	_ok(_approx(c.apply_capped(BIDIR, 1.0, 1.0), 1.0), "beyond-cap cur=1.0 at e=0 persists (no snap)")
	# Reducing it inward is free; once inside, it is re-bounded going forward.
	_ok(_approx(c.apply_capped(BIDIR, 0.4, 1.0), 0.4), "beyond-cap reduces inward freely")
	_ok(_approx(c.apply_capped(BIDIR, 0.8, 0.4), 0.5), "after settling at 0.4, req=0.8 → 0.5 (re-bounded)")


func _test_extremeness_widens() -> void:
	var c := _new_caps()
	var d := c.cap(BIDIR, 0.0)
	var w := c.cap(BIDIR, 1.0)
	_ok(_approx(d[0], -0.5) and _approx(d[1], 0.5), "e=0 default [-0.5,0.5]")
	_ok(_approx(w[0], -1.0) and _approx(w[1], 1.0), "e=1 widens to hard [-1,1], got %s" % str(w))
	# Half extremeness lerps halfway.
	var h := c.cap(BIDIR, 0.5)
	_ok(_approx(h[1], 0.75), "e=0.5 ceiling lerps to 0.75, got %f" % h[1])


func _test_derived_uncurated() -> void:
	# v: an UNCURATED sculpt-reachable modifier (no authored interval) clamps to its DERIVED
	# interval (neutral 0 ± fraction·R, R=hard span=2, fraction=0.25 → [-0.5,0.5]), NOT the
	# hard range. Pick a bidirectional modifier NOT in the curated set.
	var c := _new_caps()
	var uncurated := "head/head-angle-in|out"   # bidirectional, not a region-slider spec
	var iv := c.cap(uncurated, 0.0)
	_ok(_approx(iv[0], -0.5) and _approx(iv[1], 0.5),
		"uncurated derived [-0.5,0.5] (neutral 0 ± 0.25·2), got %s" % str(iv))
	# req=1.0 clamps to the DERIVED 0.5, not the hard 1.0.
	_ok(_approx(c.apply_capped(uncurated, 1.0, 0.0), 0.5), "uncurated req=1 → derived 0.5 (not hard 1.0)")


func _test_held_interval_transient_dip() -> void:
	# iv: pre-ratcheted cur=0.9 on a default-[-0.5,0.5] control (held interval [-0.5,0.9]).
	# Within a single gesture drive 0.9 → 0.6 → 0.85, then end. The value MUST reach 0.85
	# mid-gesture (held cur_start=0.9 not collapsed by the transient dip to 0.6).
	var c := _new_caps()
	c.start_gesture()
	# First touch captures cur_start=0.9 (the live stored before the first write).
	var a := c.apply_capped(BIDIR, 0.6, 0.9)
	_ok(_approx(a, 0.6), "gesture: dip to 0.6 applies, got %f" % a)
	_ok(c.has_held(BIDIR), "gesture: held interval captured on first touch")
	# Now the stored value is 0.6; WITHOUT the held interval the live cur would be 0.6 giving
	# hi=max(0.5,0.6)=0.6, trapping the gesture. With the held cur_start=0.9, hi=0.9.
	var b := c.apply_capped(BIDIR, 0.85, 0.6)
	_ok(_approx(b, 0.85), "gesture: back up to 0.85 admitted (held cur_start=0.9 not collapsed), got %f" % b)
	# Widget bounds use the held interval too.
	var hb := c.held_interval(BIDIR)
	_ok(_approx(hb[0], -0.5) and _approx(hb[1], 0.9), "held bounds [-0.5,0.9], got %s" % str(hb))
	# On gesture end the held map clears; subsequent clamp reads the settled cur live.
	c.end_gesture()
	_ok(not c.has_held(BIDIR), "gesture end clears held map")
	# Settled at 0.6 → req=0.85 now clamps to max(0.5,0.6)=0.6 (the ratchet collapsed inward).
	_ok(_approx(c.apply_capped(BIDIR, 0.85, 0.6), 0.6), "post-gesture settled 0.6 re-bounds req=0.85 → 0.6")


func _test_gesture_abort() -> void:
	# vi: begin a gesture, capture cur_start=0.9; a state-replacing op aborts the gesture
	# (clears the held map). A fresh gesture then captures against the NEW state (0.0), so
	# the stale 0.9 ratchet does NOT survive.
	var c := _new_caps()
	c.start_gesture()
	c.apply_capped(BIDIR, 0.7, 0.9)   # captures held cur_start=0.9
	_ok(c.has_held(BIDIR), "pre-abort: held captured")
	c.abort_gesture()                  # the state-replacing op aborts
	_ok(not c.has_held(BIDIR) and not c.gesture_active(), "abort clears held map + ends gesture")
	# Fresh gesture against the restored un-ratcheted state cur=0.0.
	c.start_gesture()
	# req=0.9 against cur_start=0.0 → clamped to the default ceiling 0.5 (the stale 0.9 ratchet
	# is gone), proving the fresh capture reads the new state.
	_ok(_approx(c.apply_capped(BIDIR, 0.9, 0.0), 0.5), "post-abort fresh gesture caps req=0.9 → 0.5 (no stale ratchet)")
	c.end_gesture()


func _test_one_write_no_held_leak() -> void:
	# A degenerate one-write edit (start+single apply+end) captures and clears within the one
	# call-bracket; cur_start == cur, so holding is a no-op (the choke clamps against live cur).
	var c := _new_caps()
	c.start_gesture()
	var v := c.apply_capped(BIDIR, 1.0, 0.0)
	c.end_gesture()
	_ok(_approx(v, 0.5), "one-write outward clamp → 0.5")
	_ok(not c.has_held(BIDIR), "one-write leaves no held entry after end")


func _test_neutral_in_interval_gate() -> void:
	# #11b: neutral ∈ [a,b] for EVERY control (authored headline + modifiers, and every
	# registry-reachable derived modifier). Empty error list == the build gate passes.
	var c := _new_caps()
	var errs := c.validate_neutral_in_interval()
	_ok(errs.is_empty(), "neutral∈[a,b] gate passes for all controls; violations: %s" % str(errs))


func _test_archetype_containment_stub() -> void:
	# #11a stub: with no archetypes, the containment gate passes. A within-interval archetype
	# also passes; a beyond-interval one fails (proving the check is real, not a no-op).
	var c := _new_caps()
	_ok(c.validate_archetype_containment([]).is_empty(), "archetype gate stub passes with []")
	var good := {"masculinity": 60.0, "modifiers": {BIDIR: 0.3}}
	_ok(c.validate_archetype_containment([good]).is_empty(), "within-interval archetype passes")
	var bad := {"masculinity": 95.0}   # outside [20,80]
	_ok(not c.validate_archetype_containment([bad]).is_empty(), "beyond-interval archetype fails (gate is real)")
