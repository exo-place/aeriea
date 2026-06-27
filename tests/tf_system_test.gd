## TF system test — aeriea's deterministic transformation system (decisions/
## transformation-system.md). Asserts the MVP-slice invariants (§7):
##   (a) DETERMINISM — same world_seed + action log -> byte-identical body graph.
##   (b) STAGED PROGRESSION — a staged TF advances one stage per due sim_clock step.
##   (c) REGION-TARGETING — an op hits only tagged/structural nodes; a convention-
##       targeting op NO-OPS on a body lacking the tag (§3.7).
##   (d) REVERSIBILITY — undo restores the exact prior graph, incl. re-grafting a
##       removed subtree (§5.4).
##   (e) SAVE/LOAD — body + holder round-trip through JSON identically (§7).
##   (f) SPLIT — produces two independent bodies (§4.2).
##   (g) GRAFT/MERGE — attaches correctly across body boundaries (§4.2).
##   (h) COMMITMENT GATE — description mentions no phantom parts (§6).
##   (i) VALIDATOR — opt-in, runs without ever being invoked by the applier (§3.8).
##
## Run: xvfb-run -a godot4 --path . res://tests/tf_system_test.tscn --quit-after 2000
extends Node

const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const TfApplier := preload("res://scripts/body/tf/tf_applier.gd")
const TfHolder := preload("res://scripts/body/tf/tf_holder.gd")
const TfContent := preload("res://scripts/body/tf/tf_content.gd")
const TfDescribe := preload("res://scripts/body/tf/tf_describe.gd")
const TfValidator := preload("res://scripts/body/tf/tf_validator.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea TF-system test ===\n")
	_test_determinism()
	_test_staged_progression()
	_test_region_targeting_tag()
	_test_region_targeting_structural()
	_test_convention_noop()
	_test_reversibility()
	_test_reversibility_regraft()
	_test_save_load_roundtrip()
	_test_split_independence()
	_test_graft_merge()
	_test_commitment_gate()
	_test_validator_opt_in()
	_test_material_nulls_covering()
	_test_chitin_progressive()
	_test_staged_graft()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


# Run a fixed scripted sequence and return the final body dict + tail length.
func _scripted_run(seed_value: int) -> Dictionary:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), seed_value, reg)
	h.apply_instant("graft_quadruped_lower")
	h.start_tf("set_covering_fur_upward")
	h.advance_time(900 * 5)
	h.apply_instant("graft_tail")
	h.start_tf("grow_tail_length")
	h.advance_time(900 * 6)
	return h.body


func _test_determinism() -> void:
	var a := _scripted_run(0xA32115)
	var b := _scripted_run(0xA32115)
	_ok(JSON.stringify(a) == JSON.stringify(b),
		"same world_seed + action log -> byte-identical body graph")
	var c := _scripted_run(0xBEEF)
	# The only seeded roll is the tail growth, so c diverges in tail length only.
	_ok(JSON.stringify(c) != JSON.stringify(a),
		"different world_seed -> divergent graph (seed drives the roll)")
	# And a/b agree on the deterministic (non-rolled) structure regardless.
	_ok(BodyGraph.find_by_id(a["root"], "barrel") != null,
		"deterministic graft landed (barrel present)")


func _test_staged_progression() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	h.apply_instant("graft_quadruped_lower")
	h.start_tf("set_covering_fur_upward")
	# Before any time, nothing converted.
	var leg_bl0 = BodyGraph.find_by_id(h.body["root"], "leg_bl")
	_ok(leg_bl0["covering"] == "skin", "staged TF: no conversion before clock advances")
	h.advance_time(900)   # one stage due
	_ok(BodyGraph.find_by_id(h.body["root"], "leg_bl")["covering"] == "fur",
		"staged TF: stage 1 converts the lowest segment")
	_ok(BodyGraph.find_by_id(h.body["root"], "leg_br")["covering"] == "skin",
		"staged TF: exactly ONE segment per stage (leg_br still skin)")
	h.advance_time(900)   # second stage
	_ok(BodyGraph.find_by_id(h.body["root"], "leg_br")["covering"] == "fur",
		"staged TF: stage 2 advances the boundary one further")
	# A single big advance drains the remaining stages.
	h.advance_time(900 * 4)
	_ok(BodyGraph.find_by_id(h.body["root"], "barrel")["covering"] == "fur",
		"staged TF: a multi-stage advance drains remaining stages")
	_ok(not h.has_active(), "staged TF: deactivates at max_stages")


func _test_region_targeting_tag() -> void:
	# A tag-targeting op hits ONLY tagged nodes. Build a body, tag-add to lower_body.
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	h.apply_instant("graft_quadruped_lower")
	# Manually drive a tag op via the applier over the lower_body subtree.
	var tf := {"id": "x", "ops": [{"effect": "tag_add", "subtree_tag": "lower_body", "value": "MARK"}]}
	TfApplier.apply_stage(h.body, tf, 0, 1, 99)
	var marked := 0
	var unmarked_upper := true
	for seg in BodyGraph.all_segments(h.body["root"]):
		if "MARK" in seg.get("tags", []):
			marked += 1
		if seg["id"] in ["torso_upper", "head", "arm_l", "arm_r"] and "MARK" in seg.get("tags", []):
			unmarked_upper = false
	_ok(marked == 5, "tag-target hit only the lower_body subtree (5 nodes: barrel+4 legs), got %d" % marked)
	_ok(unmarked_upper, "tag-target left the upper body untouched")


func _test_region_targeting_structural() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	h.apply_instant("graft_quadruped_lower")
	var tf := {"id": "x", "ops": [{"effect": "tag_add", "subtree_under": "barrel", "value": "S"}]}
	TfApplier.apply_stage(h.body, tf, 0, 1, 7)
	var n := 0
	for seg in BodyGraph.all_segments(h.body["root"]):
		if "S" in seg.get("tags", []):
			n += 1
	_ok(n == 5, "structural subtree_under hit barrel + its 4 legs (5), got %d" % n)


func _test_convention_noop() -> void:
	# A convention-targeting op on a body lacking the tag NO-OPS (§3.7).
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)   # biped: no quadruped lower tags
	var tf := {"id": "x", "ops": [{"effect": "set_covering", "tag": "wing", "value": "feathers"}]}
	var eff := TfApplier.apply_stage(h.body, tf, 0, 1, 1)
	_ok(eff.is_empty(), "convention-targeting op no-ops on a body lacking the tag (§3.7)")


func _test_reversibility() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	var before := JSON.stringify(h.body)
	h.apply_instant("graft_quadruped_lower")   # removes pelvis subtree + grafts barrel
	var after := JSON.stringify(h.body)
	_ok(before != after, "graft changed the graph")
	h.undo_last()
	_ok(JSON.stringify(h.body) == before, "undo restored the EXACT prior graph (incl. re-grafted pelvis)")


func _test_reversibility_regraft() -> void:
	# A remove_subtree undo must re-graft the removed subtree byte-identically.
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	var pelvis_before := JSON.stringify(BodyGraph.find_by_id(h.body["root"], "pelvis"))
	var tf := {"id": "x", "ops": [{"effect": "remove_subtree", "target_node": "pelvis"}]}
	var eff := TfApplier.apply_stage(h.body, tf, 0, 1, 1)
	_ok(BodyGraph.find_by_id(h.body["root"], "pelvis") == null, "remove dropped the pelvis subtree")
	TfApplier.undo_effects(h.body, eff)
	var pelvis_after := JSON.stringify(BodyGraph.find_by_id(h.body["root"], "pelvis"))
	_ok(pelvis_after == pelvis_before, "undo re-grafted the removed subtree byte-identically")


func _test_save_load_roundtrip() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 0xA32115, reg)
	h.apply_instant("graft_quadruped_lower")
	h.start_tf("grow_tail_length")  # leaves an active staged TF + an undo log entry path
	h.apply_instant("graft_tail")
	h.advance_time(900 * 3)
	var saved := JSON.stringify(h.to_dict())
	var reloaded = JSON.parse_string(saved)
	var h2: TfHolder = TfHolder.from_dict(reloaded, reg)
	_ok(JSON.stringify(h.body) == JSON.stringify(h2.body), "save/load: body round-trips identically")
	_ok(JSON.stringify(h.to_dict()) == JSON.stringify(h2.to_dict()),
		"save/load: full holder (clock+active+undo_log) round-trips identically")
	# And the reloaded holder continues deterministically.
	h.advance_time(900 * 3)
	h2.advance_time(900 * 3)
	_ok(JSON.stringify(h.body) == JSON.stringify(h2.body),
		"save/load: reloaded holder continues the timeline deterministically")


func _test_split_independence() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	h.apply_instant("graft_quadruped_lower")
	var detached := h.split_off("leg_fl")
	_ok(BodyGraph.find_by_id(h.body["root"], "leg_fl") == null, "split removed leg_fl from the source")
	_ok(BodyGraph.find_by_id(detached["root"], "leg_fl") != null, "split returned leg_fl as its own body")
	# Mutating the detached body must NOT affect the source (true independence).
	detached["root"]["material"] = "stone"
	_ok(BodyGraph.find_by_id(h.body["root"], "barrel")["material"] == "flesh",
		"split bodies are independent (mutating one does not touch the other)")


func _test_graft_merge() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	# graft: the quadruped-lower op attaches the barrel at the hip.
	h.apply_instant("graft_quadruped_lower")
	var loc = BodyGraph.find_parent(h.body["root"], "barrel")
	_ok(loc != null and loc["parent"]["id"] == "torso_upper" and loc["at"] == "hip",
		"graft attached barrel at (torso_upper, hip)")
	# merge: graft another body's graph onto this one.
	var other := {"root": BodyGraph.segment("extra_arm", "flesh", "skin", {}, ["arm"], []), "scalars": {}}
	var ok := h.merge_in(other, "torso_upper", "shoulder_x")
	_ok(ok and BodyGraph.find_by_id(h.body["root"], "extra_arm") != null,
		"merge grafted another body's graph onto this one")


func _test_commitment_gate() -> void:
	# Description mentions a feature ONLY if a segment carries it (§6) — no phantom parts.
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	var desc_biped := TfDescribe.describe(h.body)
	_ok(not ("tail" in desc_biped), "biped description has no phantom tail")
	_ok(not ("taur" in desc_biped), "biped description is not labelled a taur")
	h.apply_instant("graft_quadruped_lower")
	h.apply_instant("graft_tail")
	var desc_taur := TfDescribe.describe(h.body)
	_ok("tail" in desc_taur, "after graft_tail the tail IS described (committed)")
	_ok("taur" in desc_taur, "after the quadruped graft the form reads as a taur")


func _test_validator_opt_in() -> void:
	# The validator is never called by the applier; calling it explicitly works and a
	# clean body yields no issues, while a deliberately-odd body flags.
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	var issues_clean := TfValidator.validate(h.body)
	_ok(issues_clean.is_empty(), "validator: clean biped flags nothing (got %d)" % issues_clean.size())
	# Make flesh with a null covering -> should be flagged (flesh_uncovered).
	BodyGraph.find_by_id(h.body["root"], "head")["covering"] = null
	var issues := TfValidator.validate(h.body)
	var flagged := false
	for iss in issues:
		if iss["kind"] == "flesh_uncovered" and iss["node"] == "head":
			flagged = true
	_ok(flagged, "validator: flags flesh-with-null-covering when run on demand")
	# Crucially: applying a TF never calls the validator — a structurally 'odd' body
	# still transforms. (We just assert the applier produced effects with no gate from
	# the validator.)
	var tf := {"id": "x", "ops": [{"effect": "tag_add", "target_node": "head", "value": "Z"}]}
	var eff := TfApplier.apply_stage(h.body, tf, 0, 1, 1)
	_ok(not eff.is_empty(), "applier transforms an 'odd' body without ever consulting the validator")


# The lower-body chitin TF must PROGRESS one segment per stage (not convert everything
# in stage 0). Regression guard for the staged-fan bug.
func _test_chitin_progressive() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	h.apply_instant("graft_quadruped_lower")
	h.start_tf("set_lower_material_chitin")
	var counts: Array = []
	for i in 5:
		h.advance_time(1200)   # one stage per advance
		var n := 0
		for seg in BodyGraph.all_segments(h.body["root"]):
			if seg.get("material", "") == "chitin":
				n += 1
		counts.append(n)
	_ok(counts == [1, 2, 3, 4, 5],
		"chitin hardens ONE lower segment per stage (progressive), got %s" % str(counts))
	_ok(not h.has_active(), "chitin staged TF deactivates after all 5 segments converted")


# Form edits (graft/remove) are stageable: a staged graft lands its form change on the
# due stage, not instantly, and progresses on the clock (§4.2).
func _test_staged_graft() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	h.start_tf("graft_quadruped_lower_staged")
	_ok(BodyGraph.find_by_id(h.body["root"], "barrel") == null,
		"staged graft: nothing grafted before the clock advances")
	h.advance_time(1200)   # stage 0 due — the form edit lands
	_ok(BodyGraph.find_by_id(h.body["root"], "barrel") != null,
		"staged graft: form edit lands on the first due stage (barrel grafted)")
	_ok(BodyGraph.find_by_id(h.body["root"], "pelvis") == null,
		"staged graft: the biped pelvis was removed as part of the staged form edit")
	var len0: float = float(BodyGraph.find_by_id(h.body["root"], "barrel")["props"]["length_cm"])
	h.advance_time(1200 * 4)   # remaining grow stages
	var len1: float = float(BodyGraph.find_by_id(h.body["root"], "barrel")["props"]["length_cm"])
	_ok(len1 > len0, "staged graft: grafted lower body grows over subsequent stages (%.1f -> %.1f)" % [len0, len1])


func _test_material_nulls_covering() -> void:
	# Setting a non-flesh material nulls the covering (§3.2); undo restores it.
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	var tf := {"id": "x", "ops": [{"effect": "set_material", "target_node": "head", "value": "chitin"}]}
	var eff := TfApplier.apply_stage(h.body, tf, 0, 1, 1)
	var head = BodyGraph.find_by_id(h.body["root"], "head")
	_ok(head["material"] == "chitin" and head["covering"] == null,
		"set_material to chitin nulls the covering (§3.2)")
	TfApplier.undo_effects(h.body, eff)
	head = BodyGraph.find_by_id(h.body["root"], "head")
	_ok(head["material"] == "flesh" and head["covering"] == "skin",
		"undo restores both material and covering")
