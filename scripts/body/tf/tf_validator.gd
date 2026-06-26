## TfValidator — OPT-IN, unopinionated coherence checker (TF system §3.8).
##
## This is NEVER called by the applier or the holder. It is a tool you point at a body
## ON DEMAND to get a report of unusual structure; it carries no authority, blocks no
## TF, and the body is under no obligation to pass it. Most content never runs it.
##
## Returns an Array of issue dicts: { "kind": String, "node": id, "detail": String }.
## An empty array means "nothing flagged" — NOT "valid" (there is no privileged valid
## form, §3.8). The checks below are deliberately mild examples, not a schema.
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")


static func validate(body: Dictionary) -> Array:
	var issues: Array = []
	var root: Dictionary = body["root"]
	var seen_ids := {}
	for seg in BodyGraph.all_segments(root):
		# Duplicate id (would break id-targeting).
		if seen_ids.has(seg["id"]):
			issues.append({"kind": "duplicate_id", "node": seg["id"],
						"detail": "two segments share this id"})
		seen_ids[seg["id"]] = true
		# Flesh with a null covering (unusual but legal — flag, don't block).
		if BodyGraph.material_takes_covering(seg.get("material", "")) and seg.get("covering") == null:
			issues.append({"kind": "flesh_uncovered", "node": seg["id"],
						"detail": "flesh-type material with no covering"})
		# Non-flesh material carrying a covering (covering is meaningless here).
		if not BodyGraph.material_takes_covering(seg.get("material", "")) and seg.get("covering") != null:
			issues.append({"kind": "spurious_covering", "node": seg["id"],
						"detail": "non-flesh material carries a covering"})
	# A MULTI-LEGGED lower body (4+ legs) with no spine to support it (the §3.8
	# example). A normal biped pelvis (2 legs, no spine) is unremarkable and NOT
	# flagged — the heuristic targets a grafted quadruped lower that lost its spine.
	var leg_count := 0
	var has_spine := false
	for seg in BodyGraph.all_segments(root):
		if "leg" in seg.get("tags", []):
			leg_count += 1
		if "spine" in seg.get("tags", []):
			has_spine = true
	if leg_count >= 4 and not has_spine:
		issues.append({"kind": "unsupported_lower", "node": "",
					"detail": "a 4+-legged lower body has no supporting spine"})
	issues.sort_custom(func(a, b): return str(a) < str(b))
	return issues
