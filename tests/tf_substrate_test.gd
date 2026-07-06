## TF SUBSTRATE test — transformations as MARINADA EXPRESSIONS over the plain-struct
## part tree, evaluated by the GDScript marinada core evaluator (tf_marinada.gd).
##
## Every transformation is now authored DATA (an entry in the authored marinada
## module lib:tf-core, resolved by TFLibrary.build) — proving transformations are
## content, not engine code. The engine calls each definition and writes back its
## pure result record. The suite covers:
##   0. Evaluator conformance on marinada snippets taken from the spec.
##   1. Gradual transformation over N ticks.
##   2. Two parallel out-of-step transitions on one part (independent progress).
##   3. Pause + resume (condition written by an action).
##   4. Pause-the-most-recent (recency = list position) with two parallel transitions.
##   5. Cross-part dependency by field: a tail transition reading a breast's size.
##   6. Relational disambiguation on a HUMAN-TAUR with two identical torsos,
##      distinguished ONLY by structure — the queries authored as marinada exprs.
##   7. Replay determinism: same seed + action log => identical tree; different seed
##      differs.
##
## Run: xvfb-run -a godot4 --path . res://tests/tf_substrate_test.tscn --quit-after 2000
extends Node

# TFPart / TFTree / TFRng / TFEngine / TFMarinada / TFLibrary are globally
# registered via class_name.

var _pass := 0
var _fail := 0
var _lib: Dictionary = {}


func _ready() -> void:
	print("\n=== aeriea tf-substrate test ===\n")
	# The transformation library, resolved once from the authored marinada module.
	_lib = TFLibrary.build()
	_case0_evaluator()
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
# CASE 0 — the evaluator itself, on marinada snippets from the spec.
# ---------------------------------------------------------------------------
func _case0_evaluator() -> void:
	# Arithmetic / nesting (spec: ["+", a, b]).
	_ok(TFMarinada.eval_top(["+", 1, 2]) == 3, "case0: [+ 1 2] == 3")
	_ok(TFMarinada.eval_top(["*", ["+", 1, 2], 4]) == 12, "case0: nested arithmetic == 12")

	# let binds names in scope of the body (spec: let).
	_ok(TFMarinada.eval_top(["let", [["x", 5], ["y", 3]], ["+", "x", "y"]]) == 8,
		"case0: let binding == 8")

	# A bare string in arg position is a string literal when unbound.
	_ok(TFMarinada.eval_top(["str-concat", "hello ", "world"]) == "hello world",
		"case0: unbound bare strings are literals")

	# get / get-in over records (spec: data access).
	var rec := {"a": {"b": 7}}
	_ok(TFMarinada.eval_with(["get-in", "r", ["array", "a", "b"]], {"r": rec}) == 7,
		"case0: get-in nested == 7")
	# set returns a NEW record; the original is untouched (immutability).
	var rec2: Dictionary = TFMarinada.eval_with(["set", "r", "a", 99], {"r": {"a": 1}})
	_ok(rec2["a"] == 99, "case0: set returns updated record")

	# match on a DU constructor (spec: Shape / Circle area).
	var area: Variant = TFMarinada.eval_top(
		["match", ["Circle", 2.0],
			[["Circle", "r"], ["*", 3.0, ["*", "r", "r"]]],
			[["Rect", "w", "h"], ["*", "w", "h"]]])
	_ok(is_equal_approx(area, 12.0), "case0: match Circle area == 12.0 (%s)" % str(area))

	# letrec + fn + call: recursive factorial (spec: letrec for recursion).
	var fact: Variant = TFMarinada.eval_top(
		["letrec", [["fact", ["fn", ["n"],
			["if", ["==", "n", 0], 1, ["*", "n", ["call", "fact", ["-", "n", 1]]]]]]],
			["call", "fact", 5]])
	_ok(fact == 120, "case0: letrec factorial 5 == 120 (%s)" % str(fact))


# ---------------------------------------------------------------------------
# CASE 1 — gradual transformation over N ticks.
# ---------------------------------------------------------------------------
func _case1_gradual() -> void:
	var tail := TFPart.make({"kind": "tail", "size": 0.0})
	tail.transitions().append({"kind": "accrue", "field": "size", "from": 0.0, "to": 10.0, "rate": 0.2, "prog": 0.0})

	var seen: Array = []
	for i in range(6):
		seen.append(tail.fields["size"])
		TFEngine.tick(tail, _lib)

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
	part.transitions().append({"kind": "accrue", "field": "a_out", "from": 0.0, "to": 1.0, "rate": 0.10, "prog": 0.0})
	part.transitions().append({"kind": "accrue", "field": "b_out", "from": 0.0, "to": 1.0, "rate": 0.25, "prog": 0.60})

	for i in range(3):
		TFEngine.tick(part, _lib)

	# Each advanced by its OWN rate from its OWN start — the engine writes back the
	# pure result, so we read current state from the live transition list.
	var a_prog: float = part.transitions()[0]["prog"]
	var b_prog: float = part.transitions()[1]["prog"]
	_ok(is_equal_approx(a_prog, 0.30), "case2: A progress independent (%f, want 0.30)" % a_prog)
	_ok(is_equal_approx(b_prog, 1.00), "case2: B progress independent+clamped (%f, want 1.00)" % b_prog)
	_ok(a_prog != b_prog, "case2: the two transitions are out of step")


# ---------------------------------------------------------------------------
# CASE 3 — pause + resume; the condition field is written by an ACTION.
# ---------------------------------------------------------------------------
func _case3_pause() -> void:
	var builder := func() -> TFPart:
		var p := TFPart.make({"kind": "horn", "held": false})
		p.transitions().append({"kind": "accrue_pausable", "field": "len", "from": 0.0, "to": 1.0, "rate": 0.25, "prog": 0.0})
		return p

	var p: TFPart = builder.call()
	TFEngine.apply_action(p, {"op": "tick"}, _lib, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _lib, 0)
	var before_hold: float = p.transitions()[0]["prog"]
	TFEngine.apply_action(p, {"op": "set_field", "field": "held", "value": true}, _lib, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _lib, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _lib, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _lib, 0)
	var during_hold: float = p.transitions()[0]["prog"]
	_ok(is_equal_approx(before_hold, 0.50), "case3: progressed to 0.50 before hold (%f)" % before_hold)
	_ok(is_equal_approx(during_hold, before_hold), "case3: FROZEN while held (%f == %f)" % [during_hold, before_hold])
	TFEngine.apply_action(p, {"op": "set_field", "field": "held", "value": false}, _lib, 0)
	TFEngine.apply_action(p, {"op": "tick"}, _lib, 0)
	var after_release: float = p.transitions()[0]["prog"]
	_ok(after_release > during_hold, "case3: RESUMES after release (%f > %f)" % [after_release, during_hold])


# ---------------------------------------------------------------------------
# CASE 4 — pause the MOST RECENT of two parallel transitions (recency = list pos).
# ---------------------------------------------------------------------------
func _case4_pause_most_recent() -> void:
	var part := TFPart.make({"kind": "torso", "held": false})
	# First-started (earlier in list) then most-recent (last in list).
	part.transitions().append({"kind": "accrue_recent", "field": "x", "rate": 0.10, "prog": 0.0})
	part.transitions().append({"kind": "accrue_recent", "field": "y", "rate": 0.10, "prog": 0.0})

	for i in range(2):
		TFEngine.tick(part, _lib)                # both advance
	part.fields["held"] = true
	for i in range(3):
		TFEngine.tick(part, _lib)                # only OLDER advances; NEWER frozen
	var older_held: float = part.transitions()[0]["prog"]
	var newer_held: float = part.transitions()[1]["prog"]
	_ok(is_equal_approx(older_held, 0.50), "case4: older keeps advancing while held (%f, want 0.50)" % older_held)
	_ok(is_equal_approx(newer_held, 0.20), "case4: most-recent FROZEN while held (%f, want 0.20)" % newer_held)
	part.fields["held"] = false
	TFEngine.tick(part, _lib)
	_ok(part.transitions()[1]["prog"] > newer_held, "case4: most-recent resumes after release (%f > %f)" % [part.transitions()[1]["prog"], newer_held])
	_ok(part.transitions()[0]["prog"] > older_held, "case4: older also advances after release")


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
		TFEngine.tick(body, _lib)

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
	TFEngine.tick(body2, _lib)   # tail reads breast BEFORE breast grew this tick
	_ok(is_equal_approx(tail2.fields["thickness"], 0.0),
		"case5: one-tick lag emergent from order when source sorts later (%f == 0)" % tail2.fields["thickness"])


# ---------------------------------------------------------------------------
# CASE 6 — relational disambiguation on a human-taur with TWO identical torsos.
# No id, no location/region field: structure alone distinguishes them. The queries
# are authored as MARINADA EXPRESSIONS over the tree-navigation host ops.
# ---------------------------------------------------------------------------
func _case6_relational_disambiguation() -> void:
	# pelvis -> torso_rear -> torso_front (spine chained upward). Both torsos are
	# byte-identical in fields, each with head/arms/breasts. The ONLY difference is
	# where they sit in the attachment structure.
	var pelvis := TFPart.make({"kind": "pelvis"})
	var torso_rear := pelvis.add_child(TFPart.make({"kind": "torso", "form": "human"}))
	_add_human_parts(torso_rear)
	var tail := torso_rear.add_child(TFPart.make({"kind": "tail"}))   # a REAR appendage
	var torso_front := torso_rear.add_child(TFPart.make({"kind": "torso", "form": "human"}))
	_add_human_parts(torso_front)

	# A marinada predicate: a part whose kind == "torso".
	var is_torso := ["fn", ["p"], ["==", ["part-field", "p", "kind"], "torso"]]
	var binds := {"pelvis": pelvis, "tail": tail}

	# "My torso" for the rear tail == the rear torso (nearest matching ancestor).
	var my_torso: Variant = TFMarinada.eval_with(["nearest-ancestor", "tail", is_torso], binds)
	_ok(my_torso == torso_rear, "case6: tail's nearest torso is the REAR torso")

	# "The other/front torso" via chain traversal: the topmost torso in the spine.
	var top: Variant = TFMarinada.eval_with(["topmost-in-chain", "pelvis", is_torso], binds)
	_ok(top == torso_front, "case6: topmost torso in the chain is the FRONT torso")

	# Exactly two torsos found by field match.
	var all_torsos: Array = TFMarinada.eval_with(["find-all", "pelvis", is_torso], binds)
	_ok(all_torsos.size() == 2, "case6: exactly two torsos found by field match")

	# Structural discriminator with NO id and NO region field: the front torso is the
	# torso that itself HAS a torso ancestor; the rear torso has none. Asked in marinada.
	var front_by_structure: TFPart = null
	var rear_by_structure: TFPart = null
	for t in all_torsos:
		var has_anc: bool = TFMarinada.eval_with(["has-ancestor", "t", is_torso], {"t": t})
		if has_anc:
			front_by_structure = t
		else:
			rear_by_structure = t
	_ok(front_by_structure == torso_front, "case6: front torso resolved purely by structure")
	_ok(rear_by_structure == torso_rear, "case6: rear torso resolved purely by structure")

	# They are genuinely identical in fields — proving disambiguation used no id.
	_ok(torso_rear.fields == torso_front.fields, "case6: the two torsos have identical field bags")
	_ok(torso_rear != torso_front, "case6: yet they are distinct parts (structure, not id)")

	# "The nearest torso that isn't me": from a part inside the FRONT torso, the
	# nearest torso excluding the front is the rear — authored in marinada.
	var front_head := TFTree.find_first(torso_front, TFTree.field_is("kind", "head"))
	var other: Variant = TFMarinada.eval_with(
		["nearest-ancestor-excluding", "head", is_torso, "front"],
		{"head": front_head, "front": torso_front})
	_ok(other == torso_rear, "case6: 'nearest torso that isn't me' from front resolves to rear")


func _add_human_parts(torso: TFPart) -> void:
	torso.add_child(TFPart.make({"kind": "head"}))
	torso.add_child(TFPart.make({"kind": "arm", "side": "left"}))
	torso.add_child(TFPart.make({"kind": "arm", "side": "right"}))
	torso.add_child(TFPart.make({"kind": "breast", "side": "left", "size": 0.0}))
	torso.add_child(TFPart.make({"kind": "breast", "side": "right", "size": 0.0}))


# ---------------------------------------------------------------------------
# CASE 7 — replay determinism: same seed + log => identical tree; different seed
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

	var a := TFEngine.run_log(12345, builder, log, _lib)
	var b := TFEngine.run_log(12345, builder, log, _lib)
	_ok(TFPart.deep_equals(a, b), "case7: same seed + same log => identical final tree")

	var c := TFEngine.run_log(999, builder, log, _lib)
	_ok(not TFPart.deep_equals(a, c), "case7: a DIFFERENT seed produces a different tree")

	# Sanity: the probabilistic draws actually fired (counts are within range).
	var horn_a: TFPart = a.children[0]
	var cnt: int = horn_a.transitions()[0]["count"]
	_ok(cnt > 0 and cnt <= 24, "case7: probabilistic transition drew deterministically (count=%d)" % cnt)
