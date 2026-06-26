## tf_playtest — headless text harness for aeriea's TF system (self-playtest surface).
##
## Starts the biped, applies a sequence of TFs, prints the body description after each
## step (including a STAGED TF mid-progress), then a save -> load -> re-describe to show
## identity, then a SPLIT showing two independent bodies, then a MERGE, then an UNDO.
## Finally verifies DETERMINISM (same world_seed -> byte-identical run twice).
##
## Run: xvfb-run -a godot4 --path . res://tools/tf_playtest.tscn --quit-after 400
extends Node

const TfHolder := preload("res://scripts/body/tf/tf_holder.gd")
const TfContent := preload("res://scripts/body/tf/tf_content.gd")
const TfDescribe := preload("res://scripts/body/tf/tf_describe.gd")
const TfValidator := preload("res://scripts/body/tf/tf_validator.gd")
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")


func _ready() -> void:
	var out := _run_sequence(0xA32115)
	print(out)
	print("\n========== DETERMINISM CHECK ==========")
	var a := _run_sequence(0xA32115)
	var b := _run_sequence(0xA32115)
	print("run A == run B (same world_seed): ", a == b)
	var c := _run_sequence(0xBEEF)
	print("run C (different seed) == run A:  ", c == a, "  (expected false — seed drives rolls)")
	get_tree().quit()


func _run_sequence(world_seed: int) -> String:
	var L: Array = []
	var reg := TfContent.registry()
	var h := TfHolder.new(TfContent.biped(), world_seed, reg)

	L.append("===== aeriea TF system playtest (seed=0x%X) =====" % world_seed)
	L.append("\n[0] starting biped:")
	L.append(TfDescribe.describe(h.body))

	# (a) instant FORM graft: biped -> taur.
	h.apply_instant("graft_quadruped_lower")
	L.append("\n[1] after graft_quadruped_lower (instant FORM, biped -> taur):")
	L.append(TfDescribe.describe(h.body))

	# (c) staged COVERING: skin -> fur creeping up the lower body. Show MID-PROGRESS.
	# (Done before chitin so the lower body is still flesh.) leg_bl already fur from
	# the quadruped graft, so the upward creep hits leg_br / barrel / torso.
	h.start_tf("set_covering_fur_upward")
	h.advance_time(900)   # stage 0
	L.append("\n[2] set_covering_fur_upward MID-PROGRESS (1 clock step, day=%d t=%d):" % [h.clock.day, h.clock.time_of_day])
	L.append(TfDescribe.describe(h.body))
	h.advance_time(900)   # stage 1
	L.append("\n[3] set_covering_fur_upward MID-PROGRESS (2 clock steps):")
	L.append(TfDescribe.describe(h.body))
	h.advance_time(900 * 5)   # drain the rest
	L.append("\n[4] set_covering_fur_upward COMPLETE (drained):")
	L.append(TfDescribe.describe(h.body))

	# (d) graft a tail then grow it (staged + seeded PROPERTY delta).
	h.apply_instant("graft_tail")
	h.start_tf("grow_tail_length")
	h.advance_time(900 * 6)
	var tail = BodyGraph.find_by_id(h.body["root"], "tail")
	L.append("\n[5] graft_tail + grow_tail_length (seeded): tail length_cm = %.2f" % float(tail["props"]["length_cm"]))
	L.append(TfDescribe.describe(h.body))

	# Save -> load -> re-describe (identity).
	var saved := h.to_dict()
	var json := JSON.stringify(saved)
	var reloaded = JSON.parse_string(json)
	var h2: TfHolder = TfHolder.from_dict(reloaded, reg)
	var before_desc := TfDescribe.describe(h.body)
	var after_desc := TfDescribe.describe(h2.body)
	L.append("\n[6] SAVE -> LOAD -> re-describe identity: %s" % ("IDENTICAL" if before_desc == after_desc else "DIVERGED"))
	L.append("    (json length = %d bytes)" % json.length())

	# SPLIT: detach a leg as its own body.
	var detached := h2.split_off("leg_fl")
	L.append("\n[7] SPLIT off 'leg_fl' as its own body:")
	L.append("  -- remaining body:")
	L.append(TfDescribe.describe(h2.body))
	L.append("  -- detached body (independent):")
	L.append(TfDescribe.describe(detached))
	L.append("  bodies are independent dicts: %s" % (not _shares_node(h2.body["root"], detached["root"])))

	# MERGE: graft the detached leg back at a different spot (the arm).
	h2.merge_in(detached, "arm_r", "graft_point")
	L.append("\n[8] MERGE detached body back onto arm_r:")
	L.append(TfDescribe.describe(h2.body))

	# (b) staged MATERIAL -> chitin, fans over lower_body. Then VALIDATE (opt-in).
	h2.start_tf("set_lower_material_chitin")
	h2.advance_time(1200 * 4)
	L.append("\n[9] set_lower_material_chitin (staged MATERIAL fan over lower_body):")
	L.append(TfDescribe.describe(h2.body))

	# UNDO the chitin batch (reversibility).
	h2.undo_last()
	L.append("\n[10] UNDO last batch (chitin reverted):")
	L.append(TfDescribe.describe(h2.body))

	# Opt-in validator (NOT called by the applier).
	var issues := TfValidator.validate(h2.body)
	L.append("\n[11] opt-in validator report (%d issues):" % issues.size())
	for iss in issues:
		L.append("    - %s @%s: %s" % [iss["kind"], iss["node"], iss["detail"]])

	return "\n".join(L)


# Structural check that two graphs share no live segment dict (true independence).
# Dicts are passed by reference in GDScript, so we tag every node in `b` and check
# whether the tag bleeds into `a` (it must not, for independent bodies).
func _shares_node(a: Dictionary, b: Dictionary) -> bool:
	for seg in BodyGraph.all_segments(b):
		seg["__mark__"] = true
	var shared := false
	for seg in BodyGraph.all_segments(a):
		if seg.has("__mark__"):
			shared = true
	for seg in BodyGraph.all_segments(b):
		seg.erase("__mark__")
	for seg in BodyGraph.all_segments(a):
		seg.erase("__mark__")
	return shared
