## TfApplier — aeriea's single deterministic TF interpreter (TF system §5).
##
## ONE function interprets ANY TF record against ANY body. No per-TF code, no
## class-per-transformation. A TF is a data record (§4.1); ops are a small closed
## vocabulary (§4.2) over the three axes (FORM/MATERIAL/COVERING) + properties + tags.
## Every op region-targets node(s) by id / tag / structural subtree (§3.7), never a
## global slot. Coherence is UNENFORCED here (§3.8) — the optional validator lives in
## tf_validator.gd and is NEVER called from this file.
##
## Determinism (§5.1): every {"roll":...} resolves through a DetRng seeded by a pure
## function of (world_seed, action_id, stage_index, op_index). No randf(), no
## wall-clock. Iteration that feeds a draw is total-ordered (BodyGraph does the
## sorting). NO float in the RNG/selection path: rolls draw integer hundredths and the
## prop deltas accumulate as integer hundredths-of-a-unit, converted to float only for
## the final stored prop value.
##
## Reversibility (§5.4): apply_stage returns an effects list — one {effect, before,
## after, ...} record per op that changed something — that undo walks backward.
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const DetRng := preload("res://scripts/util/det_rng.gd")


# ===========================================================================
# Predicate evaluation (§4.1). A predicate is a small data tree, no closures.
#   {"op":"has_tag","tag":"tail"[, "under":id]}
#   {"op":"material_is","node":id,"v":"flesh"}
#   {"op":"eq"/"ne"/"lt"/"gt","path":"#id.material" or "#id.covering" or
#                              "#id.props.length_cm","v":...}
#   {"op":"and"/"or","of":[ ... ]}   {"op":"not","of": <pred>}
# `#id.<field>` selects a segment by id then a field (material/covering or props.X).
# ===========================================================================
static func eval_predicate(pred, body: Dictionary) -> bool:
	if pred == null or typeof(pred) != TYPE_DICTIONARY:
		return true   # absent gate == always-true
	var root: Dictionary = body["root"]
	match pred.get("op", ""):
		"has_tag":
			var scope := BodyGraph.all_segments(root)
			if pred.has("under"):
				var node = BodyGraph.find_by_id(root, pred["under"])
				scope = BodyGraph.subtree_segments(node) if node != null else []
			for seg in scope:
				if pred["tag"] in seg.get("tags", []):
					return true
			return false
		"material_is":
			var seg = BodyGraph.find_by_id(root, pred["node"])
			return seg != null and seg.get("material", "") == pred["v"]
		"eq":
			return _read_path(root, pred["path"]) == pred["v"]
		"ne":
			return _read_path(root, pred["path"]) != pred["v"]
		"lt":
			var lv = _read_path(root, pred["path"])
			return lv != null and float(lv) < float(pred["v"])
		"gt":
			var gv = _read_path(root, pred["path"])
			return gv != null and float(gv) > float(pred["v"])
		"and":
			for p in pred.get("of", []):
				if not eval_predicate(p, body):
					return false
			return true
		"or":
			for p in pred.get("of", []):
				if eval_predicate(p, body):
					return true
			return false
		"not":
			return not eval_predicate(pred.get("of"), body)
		_:
			return true


## Read a `#id.field` or `#id.props.key` path; returns the value or null if absent.
static func _read_path(root: Dictionary, path: String):
	if not path.begins_with("#"):
		return null
	var rest := path.substr(1)
	var parts := rest.split(".")
	var seg = BodyGraph.find_by_id(root, parts[0])
	if seg == null:
		return null
	if parts.size() == 2:
		return seg.get(parts[1])
	if parts.size() == 3 and parts[1] == "props":
		return seg.get("props", {}).get(parts[2])
	return null


# ===========================================================================
# Apply one stage of a TF (§5.2). Pure function of (body, tf, stage_index, seeds).
# Mutates `body` in place and returns the effects list for the undo log.
# `world_seed`/`action_id` pin the RNG coordinate (§5.1).
# ===========================================================================
static func apply_stage(
		body: Dictionary, tf: Dictionary, stage_index: int,
		world_seed: int, action_id: int) -> Array:
	var effects: Array = []
	if not eval_predicate(tf.get("gate"), body):
		return effects   # gate failed — no-op, signals "done" to the holder
	var root: Dictionary = body["root"]
	var ops: Array = tf.get("ops", [])
	# `one_op_per_stage`: fire only the FIRST op that actually changes something this
	# stage (a creeping-boundary TF advances one segment per clock step — §4.3c).
	# Default false: all matching ops fire in the stage (e.g. a subtree-fan set).
	var one_per_stage: bool = bool(tf.get("one_op_per_stage", false))
	for op_index in ops.size():
		var op: Dictionary = ops[op_index]
		if op.has("when") and not eval_predicate(op["when"], body):
			continue
		var rng := DetRng.new(DetRng.seed_for(world_seed, action_id, stage_index, op_index))
		var eff = _apply_op(root, op, rng)
		if eff != null:
			effects.append(eff)
			if one_per_stage:
				break
	return effects


static func _apply_op(root: Dictionary, op: Dictionary, rng: DetRng):
	match op.get("effect", ""):
		"graft_subtree":
			var ok := BodyGraph.graft(root, op["target_node"], op["at"], op["subtree"])
			if not ok:
				return null
			return {"effect": "graft_subtree", "parent_id": op["target_node"],
					"node_id": op["subtree"]["id"]}
		"remove_subtree":
			var loc = BodyGraph.find_parent(root, op["target_node"])
			if loc == null:
				return null
			var parent_id: String = loc["parent"]["id"]
			var edge = BodyGraph.remove(root, op["target_node"])
			if edge == null:
				return null
			# Store the removed edge so undo can re-graft it EXACTLY (§5.4).
			return {"effect": "remove_subtree", "parent_id": parent_id,
					"node_id": op["target_node"], "removed_edge": edge}
		"reparent":
			var loc = BodyGraph.find_parent(root, op["target_node"])
			if loc == null:
				return null
			var old_parent: String = loc["parent"]["id"]
			var old_at: String = loc["at"]
			var ok := BodyGraph.reparent(root, op["target_node"], op["new_parent"], op["at"])
			if not ok:
				return null
			return {"effect": "reparent", "node_id": op["target_node"],
					"old_parent": old_parent, "old_at": old_at,
					"new_parent": op["new_parent"], "new_at": op["at"]}
		"set_material":
			return _fan_set(root, op, "material", rng)
		"set_covering":
			return _fan_set(root, op, "covering", rng)
		"prop_delta":
			return _apply_prop_delta(root, op, rng)
		"tag_add":
			return _apply_tag(root, op, true)
		"tag_remove":
			return _apply_tag(root, op, false)
		_:
			return null


# set_material / set_covering may target one node or fan across a subtree (§4.2).
# Captures per-node before/after so undo restores each exactly.
static func _fan_set(root: Dictionary, op: Dictionary, field: String, _rng: DetRng):
	var targets := BodyGraph.resolve_targets(root, op)
	var changes: Array = []
	for seg in targets:
		var before_mat: String = seg["material"]
		var before_cov = seg["covering"]
		if field == "material":
			seg["material"] = op["value"]
			# Setting a non-flesh material nulls the covering (§3.2).
			if not BodyGraph.material_takes_covering(op["value"]):
				seg["covering"] = null
		else:  # covering — only meaningful for flesh-type
			if BodyGraph.material_takes_covering(seg["material"]):
				seg["covering"] = op["value"]
			else:
				continue
		if seg["material"] != before_mat or seg["covering"] != before_cov:
			changes.append({"id": seg["id"], "before_material": before_mat,
							"before_covering": before_cov,
							"after_material": seg["material"], "after_covering": seg["covering"]})
	if changes.is_empty():
		return null
	return {"effect": "set_axis", "field": field, "changes": changes}


# prop_delta: seeded integer roll (hundredths) added to a scalar, then clamped.
# NO float in the draw: amount.roll draws integer hundredths in [lo*100, hi*100].
static func _apply_prop_delta(root: Dictionary, op: Dictionary, rng: DetRng):
	var seg = BodyGraph.find_by_id(root, op["target_node"])
	if seg == null:
		return null
	var prop: String = op["prop"]
	var before: float = float(seg.get("props", {}).get(prop, 0.0))
	var amount: Dictionary = op["amount"]
	var delta_hundredths: int = 0
	if amount.get("roll", "") == "uniform":
		var lo_h := int(round(float(amount["lo"]) * 100.0))
		var hi_h := int(round(float(amount["hi"]) * 100.0))
		delta_hundredths = rng.range_inclusive(lo_h, hi_h)
	else:
		delta_hundredths = int(round(float(amount.get("v", 0.0)) * 100.0))
	var before_h := int(round(before * 100.0))
	var after_h := before_h + delta_hundredths
	if op.has("clamp"):
		var lo_c := int(round(float(op["clamp"][0]) * 100.0))
		var hi_c := int(round(float(op["clamp"][1]) * 100.0))
		after_h = clampi(after_h, lo_c, hi_c)
	var after: float = float(after_h) / 100.0
	if after == before:
		return null
	if not seg.has("props"):
		seg["props"] = {}
	seg["props"][prop] = after
	return {"effect": "prop_delta", "id": seg["id"], "prop": prop,
			"before": before, "after": after}


static func _apply_tag(root: Dictionary, op: Dictionary, add: bool):
	var targets := BodyGraph.resolve_targets(root, op)
	var changes: Array = []
	for seg in targets:
		var tags: Array = seg.get("tags", [])
		var has: bool = op["value"] in tags
		if add and not has:
			tags.append(op["value"])
			changes.append(seg["id"])
		elif not add and has:
			tags.erase(op["value"])
			changes.append(seg["id"])
		seg["tags"] = tags
	if changes.is_empty():
		return null
	return {"effect": "tag", "add": add, "value": op["value"], "ids": changes}


# ===========================================================================
# Undo (§5.4) — walk an effects list BACKWARD, reverting each op exactly.
# ===========================================================================
static func undo_effects(body: Dictionary, effects: Array) -> void:
	var root: Dictionary = body["root"]
	for i in range(effects.size() - 1, -1, -1):
		_undo_one(root, effects[i])


static func _undo_one(root: Dictionary, eff: Dictionary) -> void:
	match eff["effect"]:
		"graft_subtree":
			BodyGraph.remove(root, eff["node_id"])
		"remove_subtree":
			# Re-graft the exact removed edge back onto its parent.
			BodyGraph.graft_edge(root, eff["parent_id"], eff["removed_edge"])
		"reparent":
			BodyGraph.reparent(root, eff["node_id"], eff["old_parent"], eff["old_at"])
		"set_axis":
			for ch in eff["changes"]:
				var seg = BodyGraph.find_by_id(root, ch["id"])
				if seg != null:
					seg["material"] = ch["before_material"]
					seg["covering"] = ch["before_covering"]
		"prop_delta":
			var seg = BodyGraph.find_by_id(root, eff["id"])
			if seg != null:
				seg["props"][eff["prop"]] = eff["before"]
		"tag":
			for id in eff["ids"]:
				var seg = BodyGraph.find_by_id(root, id)
				if seg != null:
					var tags: Array = seg.get("tags", [])
					if eff["add"]:
						tags.erase(eff["value"])     # undo an add == remove
					elif not (eff["value"] in tags):
						tags.append(eff["value"])    # undo a remove == add back
					seg["tags"] = tags
