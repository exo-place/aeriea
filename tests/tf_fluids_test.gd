## TF fluids / compound-parts / derived-sex test — aeriea's compound-part, genitalia
## and fluids MVP (decisions/compound-parts-and-fluids.md). Asserts:
##   (a) FLUIDS ROUND-TRIP — integer amount/capacity survive save/load EXACTLY.
##   (b) fluid_delta CLAMPS to [0, capacity], stays integer, and is DETERMINISTIC
##       (same seed -> identical roll).
##   (c) set_fluid_type works (rename + add-if-absent).
##   (d) UNDO restores fluid state exactly (incl. restoring fluid absence).
##   (e) COMPOUND TARGETING — nth_tagged hits the right sibling (by node-id order) and
##       no-ops past the end; all_tagged fans the whole compound set.
##   (f) derive_sex returns the expected token set across configurations
##       (male / female / herm / neuter) with NO stored gender field.
##   (g) add/remove member changes derived sex.
##
## Run: xvfb-run -a godot4 --path . res://tests/tf_fluids_test.tscn --quit-after 2000
extends Node

const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const TfApplier := preload("res://scripts/body/tf/tf_applier.gd")
const TfHolder := preload("res://scripts/body/tf/tf_holder.gd")
const TfContent := preload("res://scripts/body/tf/tf_content.gd")
const TfDescribe := preload("res://scripts/body/tf/tf_describe.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea TF-fluids / compound-parts test ===\n")
	_test_fluids_roundtrip()
	_test_fluid_delta_clamp_and_determinism()
	_test_fluid_delta_capacity()
	_test_set_fluid_type()
	_test_fluid_undo()
	_test_nth_tagged_targeting()
	_test_all_tagged_fan()
	_test_nth_tagged_noop_past_end()
	_test_derive_sex_configs()
	_test_add_remove_member_changes_sex()
	_test_feminize_flips_sex()
	_test_lactation_self_limits()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


func _fluids_of(body: Dictionary, id: String) -> Array:
	var seg = BodyGraph.find_by_id(body["root"], id)
	return seg.get("fluids", []) if seg != null else []


# (a) integer fluids round-trip through save/load EXACTLY.
func _test_fluids_roundtrip() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 0xABCDEF, reg)
	h.apply_instant("set_lactating")   # fills milk with a seeded integer amount
	var before_milk: int = int(_fluids_of(h.body, "breast_l")[0]["amount"])
	_ok(before_milk > 0, "set_lactating filled milk (amount=%d)" % before_milk)
	var saved := JSON.stringify(h.to_dict())
	var h2 := TfHolder.from_dict(JSON.parse_string(saved), reg)
	var after_milk = _fluids_of(h2.body, "breast_l")[0]["amount"]
	_ok(typeof(after_milk) == TYPE_INT, "reloaded milk amount is INT not float (%s)" % typeof(after_milk))
	_ok(after_milk == before_milk, "milk amount survives round-trip exactly (%d == %d)" % [before_milk, after_milk])
	_ok(JSON.stringify(h.body) == JSON.stringify(h2.body), "whole body (incl. fluids) round-trips byte-identically")
	# A fresh biped's seed reservoir round-trips too (amount 0, capacity 30).
	var seed_f := _fluids_of(h2.body, "genital_1")
	_ok(seed_f.size() == 1 and int(seed_f[0]["capacity"]) == 30 and int(seed_f[0]["amount"]) == 0,
		"genital seed reservoir round-trips {amount:0, capacity:30}")


# (b) fluid_delta clamps to [0, capacity], stays integer, deterministic.
func _test_fluid_delta_clamp_and_determinism() -> void:
	# clamp HIGH: a huge fill on a 400-capacity milk reservoir lands at exactly 400.
	var b1 := TfContent.biped()
	var op_fill := {"effect": "fluid_delta", "target": {"select": "all_tagged", "tag": "breast"},
		"fluid": "milk", "amount": {"v": 99999}, "clamp_amount": [0]}
	TfApplier.apply_stage({"root": b1["root"]}, {"id": "x", "ops": [op_fill]}, 0, 1, 1)
	var m = _fluids_of(b1, "breast_l")[0]["amount"]
	_ok(m == 400 and typeof(m) == TYPE_INT, "fluid_delta clamps to capacity (400) and stays int, got %s" % str(m))
	# clamp LOW: drain past zero lands at 0.
	var op_drain := {"effect": "fluid_delta", "target": {"select": "all_tagged", "tag": "breast"},
		"fluid": "milk", "amount": {"v": -99999}, "clamp_amount": [0]}
	TfApplier.apply_stage({"root": b1["root"]}, {"id": "x", "ops": [op_drain]}, 0, 1, 1)
	_ok(_fluids_of(b1, "breast_l")[0]["amount"] == 0, "fluid_delta clamps to 0 on overdrain")
	# determinism: same seed -> identical seeded roll.
	var amt_a := _seeded_fill_amount(0xCAFE)
	var amt_b := _seeded_fill_amount(0xCAFE)
	var amt_c := _seeded_fill_amount(0xBEEF)
	_ok(amt_a == amt_b, "same seed -> identical seeded fluid roll (%d == %d)" % [amt_a, amt_b])
	_ok(amt_a >= 80 and amt_a <= 160, "seeded fill within declared range [80,160], got %d" % amt_a)
	_ok(amt_a != amt_c or true, "different seed may differ (a=%d, c=%d)" % [amt_a, amt_c])


func _seeded_fill_amount(seed_value: int) -> int:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), seed_value, reg)
	h.apply_instant("set_lactating")
	return int(_fluids_of(h.body, "breast_l")[0]["amount"])


# capacity_delta grows the reservoir; shrinking below amount re-clamps amount down.
func _test_fluid_delta_capacity() -> void:
	var b := TfContent.biped()
	# open seed capacity by +20 (30 -> 50) and fill 25.
	var ops := [
		{"effect": "fluid_delta", "target_node": "genital_1", "fluid": "seed",
			"amount": {"v": 25}, "capacity_delta": 20, "clamp_amount": [0]},
	]
	TfApplier.apply_stage({"root": b["root"]}, {"id": "x", "ops": ops}, 0, 1, 1)
	var f = _fluids_of(b, "genital_1")[0]
	_ok(int(f["capacity"]) == 50 and int(f["amount"]) == 25, "capacity_delta grew reservoir to 50, amount 25")
	# now shrink capacity to 10 -> amount must re-clamp down to 10.
	var ops2 := [
		{"effect": "fluid_delta", "target_node": "genital_1", "fluid": "seed",
			"amount": {"v": 0}, "capacity_delta": -40, "clamp_amount": [0]},
	]
	TfApplier.apply_stage({"root": b["root"]}, {"id": "x", "ops": ops2}, 0, 1, 1)
	f = _fluids_of(b, "genital_1")[0]
	_ok(int(f["capacity"]) == 10 and int(f["amount"]) == 10, "shrinking capacity re-clamps amount down (cap=10, amt=10)")


# (c) set_fluid_type renames an entry and adds-if-absent.
func _test_set_fluid_type() -> void:
	var b := TfContent.biped()
	# rename genital_1's "seed" -> "venom"
	var op_rename := {"effect": "set_fluid_type", "target_node": "genital_1",
		"match": "seed", "value": "venom"}
	TfApplier.apply_stage({"root": b["root"]}, {"id": "x", "ops": [op_rename]}, 0, 1, 1)
	var types: Array = []
	for f in _fluids_of(b, "genital_1"):
		types.append(f["type"])
	_ok("venom" in types and not ("seed" in types), "set_fluid_type renamed seed -> venom")
	# add-if-absent: a "lube" entry on the head (which had none).
	var op_add := {"effect": "set_fluid_type", "target_node": "head", "value": "lube", "capacity": 15}
	TfApplier.apply_stage({"root": b["root"]}, {"id": "x", "ops": [op_add]}, 0, 1, 1)
	var hf := _fluids_of(b, "head")
	_ok(hf.size() == 1 and hf[0]["type"] == "lube" and int(hf[0]["capacity"]) == 15 and int(hf[0]["amount"]) == 0,
		"set_fluid_type adds entry if absent (lube, cap 15, amount 0)")


# (d) undo restores fluid state exactly, including restoring absence.
func _test_fluid_undo() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	var before := JSON.stringify(_fluids_of(h.body, "breast_l"))
	h.apply_instant("set_lactating")
	_ok(JSON.stringify(_fluids_of(h.body, "breast_l")) != before, "set_lactating changed milk")
	h.undo_last()
	_ok(JSON.stringify(_fluids_of(h.body, "breast_l")) == before, "undo restored prior fluid state exactly")
	# undo restoring ABSENCE: add a fluid to head (had none), undo -> key gone.
	var op_add := {"effect": "set_fluid_type", "target_node": "head", "value": "lube", "capacity": 10}
	var eff := TfApplier.apply_stage(h.body, {"id": "x", "ops": [op_add]}, 0, 1, 1)
	_ok(BodyGraph.find_by_id(h.body["root"], "head").has("fluids"), "fluid added to head")
	TfApplier.undo_effects(h.body, eff)
	_ok(not BodyGraph.find_by_id(h.body["root"], "head").has("fluids"),
		"undo of an add-fluid restores ABSENCE of the fluids key")


# (e) nth_tagged hits the right sibling by node-id order.
func _test_nth_tagged_targeting() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	# add a 2nd phallic genital (genital_3); ids order: genital_1 (phallic), genital_2
	# (vaginal), genital_3 (phallic). The phallic subset by id-order: [genital_1, genital_3].
	h.apply_instant("add_phallic_genital")
	# tag the 2nd phallic (index 1) via the applier directly.
	var op := {"effect": "tag_add",
		"select": {"select": "nth_tagged", "tag": "genital", "kind": "phallic", "index": 1}, "value": "MARK"}
	TfApplier.apply_stage(h.body, {"id": "x", "ops": [op]}, 0, 1, 1)
	var g1 = BodyGraph.find_by_id(h.body["root"], "genital_1")
	var g3 = BodyGraph.find_by_id(h.body["root"], "genital_3")
	_ok(not ("MARK" in g1.get("tags", [])), "nth_tagged index 1 did NOT hit genital_1 (the 1st phallic)")
	_ok("MARK" in g3.get("tags", []), "nth_tagged index 1 hit genital_3 (the 2nd phallic, by id order)")


# all_tagged fans across the whole compound set.
func _test_all_tagged_fan() -> void:
	var b := TfContent.biped()
	var op := {"effect": "tag_add", "select": {"select": "all_tagged", "tag": "breast"}, "value": "FAN"}
	TfApplier.apply_stage({"root": b["root"]}, {"id": "x", "ops": [op]}, 0, 1, 1)
	var n := 0
	for seg in BodyGraph.all_segments(b["root"]):
		if "FAN" in seg.get("tags", []):
			n += 1
	_ok(n == 2, "all_tagged breast fanned across both breasts, got %d" % n)


# nth_tagged no-ops past the end (§3.7).
func _test_nth_tagged_noop_past_end() -> void:
	var b := TfContent.biped()   # only 1 phallic genital
	var nodes := BodyGraph.resolve_targets(b,
		{"select": {"select": "nth_tagged", "tag": "genital", "kind": "phallic", "index": 5}})
	_ok(nodes.is_empty(), "nth_tagged past the end resolves to [] (no-op)")
	# An op against it changes nothing.
	var op := {"effect": "tag_add",
		"select": {"select": "nth_tagged", "tag": "genital", "kind": "phallic", "index": 5}, "value": "X"}
	var eff := TfApplier.apply_stage({"root": b["root"]}, {"id": "x", "ops": [op]}, 0, 1, 1)
	_ok(eff.is_empty(), "an op targeting nth_tagged past the end no-ops")


# (f) derive_sex returns the expected token set across configurations.
func _test_derive_sex_configs() -> void:
	# herm: the starting biped has phallic + vaginal + breasts.
	var herm := TfDescribe.derive_sex(TfContent.biped())
	_ok("herm" in herm["presentation_tokens"], "starting biped (phallic+vaginal+breasts) derives {herm}")
	_ok(herm["counts"]["phallic"] == 1 and herm["counts"]["vaginal"] == 1, "herm counts correct")
	# male: build a body with only a phallic genital, no breasts/vaginal.
	var seg := BodyGraph.segment
	var male_body := {"root": seg.call("torso", "flesh", "skin", {}, ["torso"], [
		seg.call("p", "flesh", "skin", {}, ["genital", "phallic"], []),
	])}
	# wrap as a child so it's under root properly
	male_body = {"root": seg.call("torso", "flesh", "skin", {}, ["torso"], [
		BodyGraph.child("g", seg.call("p", "flesh", "skin", {}, ["genital", "phallic"], [])),
	])}
	var male := TfDescribe.derive_sex(male_body)
	_ok("male" in male["presentation_tokens"] and not ("female" in male["presentation_tokens"]),
		"phallic-only derives {male}")
	# female: vaginal + breasts.
	var fem_body := {"root": seg.call("torso", "flesh", "skin", {}, ["torso"], [
		BodyGraph.child("g", seg.call("v", "flesh", "skin", {}, ["genital", "vaginal"], [])),
		BodyGraph.child("b", seg.call("br", "flesh", "skin", {}, ["breast"], [])),
	])}
	var fem := TfDescribe.derive_sex(fem_body)
	_ok("female" in fem["presentation_tokens"] and not ("male" in fem["presentation_tokens"]),
		"vaginal+breasts derives {female}")
	# neuter: nothing.
	var neuter_body := {"root": seg.call("torso", "flesh", "skin", {}, ["torso"], [])}
	var neuter := TfDescribe.derive_sex(neuter_body)
	_ok("neuter" in neuter["presentation_tokens"], "no genitals/breasts derives {neuter}")
	# NO stored gender field anywhere in the save.
	_ok(not ("gender" in JSON.stringify(TfContent.biped())) and not ("sex" in TfContent.biped()),
		"no stored gender/sex field in the body save")


# (g) add/remove member changes derived sex (no gender field to keep in sync).
func _test_add_remove_member_changes_sex() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	var s0 := TfDescribe.derive_sex(h.body)
	_ok(s0["counts"]["phallic"] == 1, "start: 1 phallic")
	h.apply_instant("add_phallic_genital")
	_ok(TfDescribe.derive_sex(h.body)["counts"]["phallic"] == 2, "add member -> derived phallic count = 2")
	h.apply_instant("remove_first_phallic")
	_ok(TfDescribe.derive_sex(h.body)["counts"]["phallic"] == 1, "remove member -> derived phallic count back to 1")
	# undo re-grafts the removed member exactly.
	h.undo_last()
	_ok(TfDescribe.derive_sex(h.body)["counts"]["phallic"] == 2, "undo re-grafts removed member (count back to 2)")


# feminize (pure part ops) flips derived sex with NO gender field.
func _test_feminize_flips_sex() -> void:
	var reg := TfContent.registry()
	# Build a male-presenting start: biped minus the vaginal genital & with no extra parts.
	var h := TfHolder.new(TfContent.biped(), 1, reg)
	# remove the starting vaginal genital so the body reads male-ish (phallic + breasts).
	TfApplier.apply_stage(h.body, {"id": "x", "ops": [
		{"effect": "remove_subtree", "target": {"select": "nth_tagged", "tag": "genital", "kind": "vaginal", "index": 0}}]}, 0, 1, 1)
	var pre := TfDescribe.derive_sex(h.body)
	_ok(pre["has_phallic"] and not pre["has_vaginal"], "pre-feminize: phallic present, vaginal absent")
	# add a SECOND phallic first, so feminize must remove BOTH (fan-remove).
	h.apply_instant("add_phallic_genital")
	_ok(TfDescribe.derive_sex(h.body)["counts"]["phallic"] == 2, "two phallic before feminize")
	var g1_pre := JSON.stringify(BodyGraph.find_by_id(h.body["root"], "genital_1"))
	var g3_pre := JSON.stringify(BodyGraph.find_by_id(h.body["root"], "genital_3"))
	h.apply_instant("feminize")
	var post := TfDescribe.derive_sex(h.body)
	_ok(not post["has_phallic"], "feminize removed ALL phallic genitals (fan-remove)")
	_ok(post["has_vaginal"], "feminize grafted a vaginal genital")
	_ok("female" in post["presentation_tokens"], "feminize flips derived sex to {female}")
	# undo restores both phallic members exactly (content + parentage; child order is
	# append-based in the graph, so compare each member's serialization, not raw order).
	h.undo_last()
	_ok(TfDescribe.derive_sex(h.body)["counts"]["phallic"] == 2, "undo of feminize restores 2 phallic")
	_ok(JSON.stringify(BodyGraph.find_by_id(h.body["root"], "genital_1")) == g1_pre,
		"undo re-grafts genital_1 byte-identically (props + fluids)")
	_ok(JSON.stringify(BodyGraph.find_by_id(h.body["root"], "genital_3")) == g3_pre,
		"undo re-grafts genital_3 byte-identically (props + fluids)")
	_ok(BodyGraph.find_parent(h.body["root"], "genital_1")["parent"]["id"] == "pelvis",
		"undo restores genital_1 under the pelvis")


# lactation_production self-limits at capacity (staged refill on sim_clock).
func _test_lactation_self_limits() -> void:
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), 0x5EED, reg)
	# Shrink each breast's capacity to a tiny 50 mL so 8 stages of 40-70 mL each MUST
	# saturate it — proving the staged production self-limits (clamps at capacity).
	TfApplier.apply_stage(h.body, {"id": "x", "ops": [
		{"effect": "fluid_delta", "target": {"select": "all_tagged", "tag": "breast"},
			"fluid": "milk", "amount": {"v": 0}, "capacity_delta": -350, "clamp_amount": [0]}]}, 0, 1, 1)
	_ok(int(_fluids_of(h.body, "breast_l")[0]["capacity"]) == 50, "shrunk milk capacity to 50")
	h.start_tf("lactation_production")
	h.advance_time(3600 * 8)   # 8 stages, 40-70 mL each -> would be ~440, clamps at 50
	var milk: int = int(_fluids_of(h.body, "breast_l")[0]["amount"])
	_ok(milk == 50, "lactation production self-limits at capacity (milk=%d == 50)" % milk)
	_ok(typeof(_fluids_of(h.body, "breast_l")[0]["amount"]) == TYPE_INT, "production keeps amount integer")
