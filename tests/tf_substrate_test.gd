## TF SUBSTRATE test — the plain struct + stateless function transformation model.
##
## Exercises the whole substrate against the seven contract cases:
##   1. Gradual transformation over N ticks.
##   2. Two parallel out-of-step transitions on one part (independent progress).
##   3. Pause + resume (condition written by an action).
##   4. Pause-the-most-recent (recency = list position) with two parallel transitions.
##   5. Cross-part dependency by field: a tail transition reading a breast's size.
##   6. Relational disambiguation on a HUMAN-TAUR with two identical torsos,
##      distinguished ONLY by structure (no id, no location field).
##   7. Replay determinism: same seed + action log ⇒ identical tree; a different
##      seed differs.
##
## Run: xvfb-run -a godot4 --path . res://tests/tf_substrate_test.tscn --quit-after 2000
extends Node

# TFPart / TFTree / TFRng / TFEngine are globally registered via class_name.

var _pass := 0
var _fail := 0
var _transforms: Dictionary = {}


func _ready() -> void:
	print("\n=== aeriea tf-substrate test ===\n")
	_transforms = _build_transforms()
	_case1_gradual()
	_case2_parallel()
	_case3_pause()
	_case4_pause_most_recent()
	_case5_cross_part_by_field()
	_case6_relational_disambiguation()
	_case7_replay_determinism()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


# ---------------------------------------------------------------------------
# The stateless transformation functions. Each reads current field values and
# writes the next. They live entirely OUTSIDE the parts (data/computation split);
# a transition record just names its `kind`.
# ---------------------------------------------------------------------------
func _build_transforms() -> Dictionary:
	return {
		"accrue": _xf_accrue,
		"accrue_pausable": _xf_accrue_pausable,
		"accrue_recent": _xf_accrue_recent,
		"track_breast": _xf_track_breast,
		"maybe_grow": _xf_maybe_grow,
	}


# Accumulate progress and interpolate a field from `from` to `to`.
func _xf_accrue(_root: TFPart, part: TFPart, tr: Dictionary, _ctx: Dictionary) -> void:
	tr["prog"] = minf(1.0, tr["prog"] + tr["rate"])
	part.fields[tr["field"]] = lerpf(tr["from"], tr["to"], tr["prog"])


# Like accrue, but DECLINES to advance while the part's `held` field is set
# (pause is a transformation reading a condition, not a substrate flag).
func _xf_accrue_pausable(_root: TFPart, part: TFPart, tr: Dictionary, _ctx: Dictionary) -> void:
	if part.fields.get("held", false):
		return
	tr["prog"] = minf(1.0, tr["prog"] + tr["rate"])
	part.fields[tr["field"]] = lerpf(tr["from"], tr["to"], tr["prog"])


# Pauses ONLY when this transition is the MOST RECENT (last in the list).
# Recency is list position; identity via is_same, not content equality.
func _xf_accrue_recent(_root: TFPart, part: TFPart, tr: Dictionary, _ctx: Dictionary) -> void:
	var is_most_recent := is_same(part.transitions().back(), tr)
	if part.fields.get("held", false) and is_most_recent:
		return
	tr["prog"] = minf(1.0, tr["prog"] + tr["rate"])


# Cross-part: read a breast's `size` by KIND-match and write our thickness.
func _xf_track_breast(root: TFPart, part: TFPart, tr: Dictionary, _ctx: Dictionary) -> void:
	var breast := TFTree.find_first(root, TFTree.field_is("kind", "breast"))
	if breast != null:
		part.fields[tr["field"]] = breast.fields.get("size", 0.0) * tr["factor"]


# Probabilistic: with probability `p`, bump a counter. The draw is keyed off
# (seed, coord, per-transition draw counter) — no clock, replay-exact.
func _xf_maybe_grow(_root: TFPart, _part: TFPart, tr: Dictionary, ctx: Dictionary) -> void:
	var d: int = tr.get("_draws", 0)
	tr["_draws"] = d + 1
	var coord := TFRng.mix2(ctx["coord"], d)
	if TFRng.chance(ctx["seed"], coord, tr["p"]):
		tr["count"] = tr.get("count", 0) + 1


# ---------------------------------------------------------------------------
# CASE 1 — gradual transformation over N ticks.
# ---------------------------------------------------------------------------
func _case1_gradual() -> void:
	var tail := TFPart.make({"kind": "tail", "size": 0.0})
	tail.transitions().append({"kind": "accrue", "field": "size", "from": 0.0, "to": 10.0, "rate": 0.2, "prog": 0.0})

	var seen: Array = []
	for i in range(6):
		seen.append(tail.fields["size"])
		TFEngine.tick(tail, _transforms)

	# Monotonic non-decreasing, strictly grows early, reaches full by tick 5.
	var monotonic := true
	for i in range(1, seen.size()):
		if seen[i] < seen[i - 1]:
			monotonic = false
	_ok(monotonic, "case1: size is non-decreasing over ticks %s" % str(seen))
	_ok(seen[0] == 0.0 and seen[1] > 0.0, "case1: grows gradually from 0 (%s)" % str(seen))
	_ok(is_equal_approx(tail.fields["size"], 10.0), "case1: reaches full size 10.0 (%f)" % tail.fields["size"])


# ---------------------------------------------------------------------------
# CASE 2 — two parallel out-of-step transitions on one part.
# ---------------------------------------------------------------------------
func _case2_parallel() -> void:
	var part := TFPart.make({"kind": "torso"})
	var a := {"kind": "accrue", "field": "a_out", "from": 0.0, "to": 1.0, "rate": 0.10, "prog": 0.0}
	var b := {"kind": "accrue", "field": "b_out", "from": 0.0, "to": 1.0, "rate": 0.25, "prog": 0.60}
	part.transitions().append(a)
	part.transitions().append(b)

	for i in range(3):
		TFEngine.tick(part, _transforms)

	# Each advanced by its OWN rate from its OWN start — no shared clock.
	_ok(is_equal_approx(a["prog"], 0.30), "case2: A progress independent (%f, want 0.30)" % a["prog"])
	_ok(is_equal_approx(b["prog"], 1.00), "case2: B progress independent+clamped (%f, want 1.00)" % b["prog"])
	_ok(a["prog"] != b["prog"], "case2: the two transitions are out of step")


# ---------------------------------------------------------------------------
# CASE 3 — pause + resume; the condition field is written by an ACTION.
# ---------------------------------------------------------------------------
func _case3_pause() -> void:
	var builder := func() -> TFPart:
		var p := TFPart.make({"kind": "horn", "held": false})
		p.transitions().append({"kind": "accrue_pausable", "field": "len", "from": 0.0, "to": 1.0, "rate": 0.25, "prog": 0.0})
		return p

	# Log: 2 ticks, action holds, 3 ticks (frozen), action releases, 4 ticks.
	var log: Array = [
		{"op": "tick"}, {"op": "tick"},
		{"op": "set_field", "field": "held", "value": true},
		{"op": "tick"}, {"op": "tick"}, {"op": "tick"},
		{"op": "set_field", "field": "held", "value": false},
		{"op": "tick"}, {"op": "tick"}, {"op": "tick"}, {"op": "tick"},
	]
	# Run manually so we can sample progress at the held boundary.
	var p: TFPart = builder.call()
	TFEngine.apply_action(p, {"op": "tick"}, _transforms, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _transforms, 0)
	var before_hold: float = p.transitions()[0]["prog"]
	TFEngine.apply_action(p, {"op": "set_field", "field": "held", "value": true}, _transforms, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _transforms, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _transforms, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _transforms, 0)
	var during_hold: float = p.transitions()[0]["prog"]
	_ok(is_equal_approx(before_hold, 0.50), "case3: progressed to 0.50 before hold (%f)" % before_hold)
	_ok(is_equal_approx(during_hold, before_hold), "case3: FROZEN while held (%f == %f)" % [during_hold, before_hold])
	TFEngine.apply_action(p, {"op": "set_field", "field": "held", "value": false}, _transforms, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _transforms, 0)
	var after_release: float = p.transitions()[0]["prog"]
	_ok(after_release > during_hold, "case3: RESUMES after release (%f > %f)" % [after_release, during_hold])


# ---------------------------------------------------------------------------
# CASE 4 — pause the MOST RECENT of two parallel transitions (recency = list pos).
# ---------------------------------------------------------------------------
func _case4_pause_most_recent() -> void:
	var part := TFPart.make({"kind": "torso", "held": false})
	# First-started (earlier in list) then most-recent (last in list).
	var older := {"kind": "accrue_recent", "field": "x", "rate": 0.10, "prog": 0.0}
	var newer := {"kind": "accrue_recent", "field": "y", "rate": 0.10, "prog": 0.0}
	part.transitions().append(older)
	part.transitions().append(newer)

	for i in range(2):
		TFEngine.tick(part, _transforms)          # both advance
	part.fields["held"] = true
	for i in range(3):
		TFEngine.tick(part, _transforms)          # only OLDER advances; NEWER frozen
	var older_held: float = older["prog"]
	var newer_held: float = newer["prog"]
	_ok(is_equal_approx(older["prog"], 0.50), "case4: older keeps advancing while held (%f, want 0.50)" % older["prog"])
	_ok(is_equal_approx(newer["prog"], 0.20), "case4: most-recent FROZEN while held (%f, want 0.20)" % newer["prog"])
	part.fields["held"] = false
	TFEngine.tick(part, _transforms)
	_ok(newer["prog"] > newer_held, "case4: most-recent resumes after release (%f > %f)" % [newer["prog"], newer_held])
	_ok(older["prog"] > older_held, "case4: older also advances after release")


# ---------------------------------------------------------------------------
# CASE 5 — cross-part dependency by field: a tail reads a breast's size (kind).
# ---------------------------------------------------------------------------
func _case5_cross_part_by_field() -> void:
	var body := TFPart.make({"kind": "torso"})
	# Breast BEFORE tail in pre-order => tail sees this-tick breast value (no lag).
	var breast := body.add_child(TFPart.make({"kind": "breast", "size": 0.0}))
	var tail := body.add_child(TFPart.make({"kind": "tail", "thickness": 0.0}))
	breast.transitions().append({"kind": "accrue", "field": "size", "from": 0.0, "to": 8.0, "rate": 0.5, "prog": 0.0})
	tail.transitions().append({"kind": "track_breast", "field": "thickness", "factor": 0.5})

	for i in range(4):
		TFEngine.tick(body, _transforms)

	# tail.thickness == 0.5 * breast.size, tracked by KIND-match (no pointer/id).
	_ok(breast.fields["size"] > 0.0, "case5: breast grew (%f)" % breast.fields["size"])
	_ok(is_equal_approx(tail.fields["thickness"], breast.fields["size"] * 0.5),
		"case5: tail tracks breast size via kind-match (%f == %f)" % [tail.fields["thickness"], breast.fields["size"] * 0.5])

	# And confirm the emergent one-tick lag when the source sorts LATER: rebuild
	# with tail BEFORE breast; tail must read last tick's (smaller) breast size.
	var body2 := TFPart.make({"kind": "torso"})
	var tail2 := body2.add_child(TFPart.make({"kind": "tail", "thickness": 0.0}))
	var breast2 := body2.add_child(TFPart.make({"kind": "breast", "size": 0.0}))
	breast2.transitions().append({"kind": "accrue", "field": "size", "from": 0.0, "to": 8.0, "rate": 0.5, "prog": 0.0})
	tail2.transitions().append({"kind": "track_breast", "field": "thickness", "factor": 0.5})
	TFEngine.tick(body2, _transforms)   # tail reads breast BEFORE breast grew this tick
	_ok(is_equal_approx(tail2.fields["thickness"], 0.0),
		"case5: one-tick lag emergent from order when source sorts later (%f == 0)" % tail2.fields["thickness"])


# ---------------------------------------------------------------------------
# CASE 6 — relational disambiguation on a human-taur with TWO identical torsos.
# No id, no location/region field: structure alone distinguishes them.
# ---------------------------------------------------------------------------
func _case6_relational_disambiguation() -> void:
	var is_torso := TFTree.field_is("kind", "torso")

	# pelvis -> torso_rear -> torso_front (spine chained upward). Both torsos are
	# byte-identical in fields (kind "torso", form "human"), each with head/arms/
	# breasts. The ONLY difference is where they sit in the attachment structure.
	var pelvis := TFPart.make({"kind": "pelvis"})
	var torso_rear := pelvis.add_child(TFPart.make({"kind": "torso", "form": "human"}))
	_add_human_parts(torso_rear)
	var tail := torso_rear.add_child(TFPart.make({"kind": "tail"}))   # a REAR appendage
	var torso_front := torso_rear.add_child(TFPart.make({"kind": "torso", "form": "human"}))
	_add_human_parts(torso_front)

	# "My torso" for the rear tail == the rear torso (nearest matching ancestor).
	var my_torso := TFTree.nearest_ancestor(tail, is_torso)
	_ok(my_torso == torso_rear, "case6: tail's nearest torso is the REAR torso")

	# "The other/front torso" via chain traversal: the topmost torso in the spine.
	var top := TFTree.topmost_in_chain(pelvis, is_torso)
	_ok(top == torso_front, "case6: topmost torso in the chain is the FRONT torso")

	# Structural discriminator with NO id and NO region field: the front torso is
	# the torso that itself has a torso ANCESTOR; the rear torso has none.
	var all_torsos := TFTree.find_all(pelvis, is_torso)
	_ok(all_torsos.size() == 2, "case6: exactly two torsos found by field match")
	var front_by_structure: TFPart = null
	var rear_by_structure: TFPart = null
	for t in all_torsos:
		if TFTree.has_ancestor(t, is_torso):
			front_by_structure = t
		else:
			rear_by_structure = t
	_ok(front_by_structure == torso_front, "case6: front torso resolved purely by structure")
	_ok(rear_by_structure == torso_rear, "case6: rear torso resolved purely by structure")

	# They are genuinely identical in fields — proving disambiguation used no id.
	_ok(torso_rear.fields == torso_front.fields, "case6: the two torsos have identical field bags")
	_ok(torso_rear != torso_front, "case6: yet they are distinct parts (structure, not id)")

	# "The nearest torso that isn't me": from a part inside the FRONT torso, the
	# nearest torso excluding the front is the rear.
	var front_head := TFTree.find_first(torso_front, TFTree.field_is("kind", "head"))
	var other := TFTree.nearest_ancestor_excluding(front_head, is_torso, torso_front)
	_ok(other == torso_rear, "case6: 'nearest torso that isn't me' from front resolves to rear")


func _add_human_parts(torso: TFPart) -> void:
	torso.add_child(TFPart.make({"kind": "head"}))
	torso.add_child(TFPart.make({"kind": "arm", "side": "left"}))
	torso.add_child(TFPart.make({"kind": "arm", "side": "right"}))
	torso.add_child(TFPart.make({"kind": "breast", "side": "left", "size": 0.0}))
	torso.add_child(TFPart.make({"kind": "breast", "side": "right", "size": 0.0}))


# ---------------------------------------------------------------------------
# CASE 7 — replay determinism: same seed + log ⇒ identical tree; different seed
# differs (a probabilistic transition makes the seed load-bearing).
# ---------------------------------------------------------------------------
func _case7_replay_determinism() -> void:
	var builder := func() -> TFPart:
		var body := TFPart.make({"kind": "torso"})
		var horn := body.add_child(TFPart.make({"kind": "horn"}))
		horn.transitions().append({"kind": "maybe_grow", "p": 0.5, "count": 0, "_draws": 0})
		var breast := body.add_child(TFPart.make({"kind": "breast"}))
		breast.transitions().append({"kind": "maybe_grow", "p": 0.5, "count": 0, "_draws": 0})
		return body

	var log: Array = []
	for i in range(24):
		log.append({"op": "tick"})

	var a := TFEngine.run_log(12345, builder, log, _transforms)
	var b := TFEngine.run_log(12345, builder, log, _transforms)
	_ok(TFPart.deep_equals(a, b), "case7: same seed + same log ⇒ identical final tree")

	var c := TFEngine.run_log(999, builder, log, _transforms)
	_ok(not TFPart.deep_equals(a, c), "case7: a DIFFERENT seed produces a different tree")

	# Sanity: the probabilistic draws actually fired (counts are within range).
	var horn_a: TFPart = a.children[0]
	var cnt: int = horn_a.transitions()[0]["count"]
	_ok(cnt > 0 and cnt <= 24, "case7: probabilistic transition drew deterministically (count=%d)" % cnt)
