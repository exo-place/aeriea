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


# Resolve the single node-id an id-style op targets. Supports both the literal
# `target_node` key and the ordinal `target` selector (§3.2) which resolves to a
# specific node by node-id order. Returns "" if nothing resolves (op no-ops).
static func _target_id(root: Dictionary, op: Dictionary) -> String:
	if op.has("target_node"):
		return str(op["target_node"])
	if op.has("target"):
		var nodes := BodyGraph.resolve_targets(root, {"select": op["target"]})
		if not nodes.is_empty():
			return str(nodes[0]["id"])
	return ""


# Resolve a graft's PARENT mount id: a literal `target_node` (stable upper-body mount),
# or `parent_tag` resolving to the first node carrying that region tag (id order). "" if
# nothing resolves (the graft no-ops — §3.7).
static func _graft_parent_id(root: Dictionary, op: Dictionary) -> String:
	if op.has("target_node"):
		return str(op["target_node"])
	if op.has("parent_tag"):
		var nodes := BodyGraph.resolve_targets(root, {"tag": op["parent_tag"]})
		if not nodes.is_empty():
			return str(nodes[0]["id"])
	return ""


# Resolve a reparent's NEW parent id: a literal `new_parent` id, or `new_parent_tag`
# resolving to the first node carrying that tag (id order). "" if nothing resolves.
static func _reparent_parent_id(root: Dictionary, op: Dictionary) -> String:
	if op.has("new_parent"):
		return str(op["new_parent"])
	if op.has("new_parent_tag"):
		var nodes := BodyGraph.resolve_targets(root, {"tag": op["new_parent_tag"]})
		if not nodes.is_empty():
			return str(nodes[0]["id"])
	return ""


static func _apply_op(root: Dictionary, op: Dictionary, rng: DetRng):
	match op.get("effect", ""):
		"graft_subtree":
			# The graft names a PARENT mount. By a stable mount id (`target_node`) for the
			# fixed upper-body mounts (torso_upper / head / arm_l …), OR by a region TAG
			# (`parent_tag`) so a graft onto "the groin/lower body" generalizes without a
			# global node id — resolving to the first tagged node in id order (§3.7).
			var gp := _graft_parent_id(root, op)
			if gp == "":
				return null
			var ok := BodyGraph.graft(root, gp, op["at"], op["subtree"])
			if not ok:
				return null
			return {"effect": "graft_subtree", "parent_id": gp,
					"node_id": op["subtree"]["id"]}
		"remove_subtree":
			# An `all_tagged` select fans the removal across every matching member,
			# capturing each removed edge for undo (re-grafted in reverse on undo).
			if op.has("target") and typeof(op["target"]) == TYPE_DICTIONARY \
					and op["target"].get("select", "") == "all_tagged":
				var matched := BodyGraph.resolve_targets(root, {"select": op["target"]})
				var removed: Array = []
				for seg in matched:
					var l = BodyGraph.find_parent(root, seg["id"])
					if l == null:
						continue
					var pid: String = l["parent"]["id"]
					var e = BodyGraph.remove(root, seg["id"])
					if e != null:
						removed.append({"parent_id": pid, "node_id": seg["id"], "removed_edge": e})
				if removed.is_empty():
					return null
				return {"effect": "remove_subtree_fan", "removed": removed}
			var tid := _target_id(root, op)
			if tid == "":
				return null
			var loc = BodyGraph.find_parent(root, tid)
			if loc == null:
				return null
			var parent_id: String = loc["parent"]["id"]
			var edge = BodyGraph.remove(root, tid)
			if edge == null:
				return null
			# Store the removed edge so undo can re-graft it EXACTLY (§5.4).
			return {"effect": "remove_subtree", "parent_id": parent_id,
					"node_id": tid, "removed_edge": edge}
		"reparent":
			# Resolve the new parent: a literal `new_parent` id, or `new_parent_tag`
			# resolving to the first node carrying that tag (id order). "" ⇒ no-op.
			var np := _reparent_parent_id(root, op)
			if np == "":
				return null
			# Fan form: an `all_tagged` select moves every matching member onto the new
			# parent (genitals/butt onto a freshly-grafted barrel). Idempotent — a member
			# already docked under `np` is skipped, so a re-run produces no spurious move.
			if op.has("target") and typeof(op["target"]) == TYPE_DICTIONARY \
					and op["target"].get("select", "") == "all_tagged":
				var matched := BodyGraph.resolve_targets(root, {"select": op["target"]})
				var moves: Array = []
				for seg in matched:
					var l = BodyGraph.find_parent(root, seg["id"])
					if l == null or l["parent"]["id"] == np:
						continue
					var op_id: String = l["parent"]["id"]
					var op_at: String = l["at"]
					var op_idx: int = int(l["index"])   # original sibling index (exact undo)
					if BodyGraph.reparent(root, seg["id"], np, op["at"]):
						moves.append({"node_id": seg["id"], "old_parent": op_id,
							"old_at": op_at, "old_index": op_idx,
							"new_parent": np, "new_at": op["at"]})
				if moves.is_empty():
					return null
				return {"effect": "reparent_fan", "moves": moves}
			var loc = BodyGraph.find_parent(root, op["target_node"])
			if loc == null:
				return null
			var old_parent: String = loc["parent"]["id"]
			var old_at: String = loc["at"]
			var ok := BodyGraph.reparent(root, op["target_node"], np, op["at"])
			if not ok:
				return null
			return {"effect": "reparent", "node_id": op["target_node"],
					"old_parent": old_parent, "old_at": old_at,
					"new_parent": np, "new_at": op["at"]}
		"set_material":
			return _fan_set(root, op, "material", rng)
		"set_covering":
			return _fan_set(root, op, "covering", rng)
		"prop_delta":
			return _apply_prop_delta(root, op, rng)
		"prop_scale":
			return _apply_prop_scale(root, op)
		"tag_add":
			return _apply_tag(root, op, true)
		"tag_remove":
			return _apply_tag(root, op, false)
		"set_fluid_type":
			return _apply_set_fluid_type(root, op)
		"fluid_delta":
			return _apply_fluid_delta(root, op, rng)
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
# An `all_tagged` select FANS the same delta across every matching member (each member
# draws from the one stage RNG in node-id order, so the fan is deterministic and
# replay-safe). Captures per-node before/after so undo restores each exactly.
static func _apply_prop_delta(root: Dictionary, op: Dictionary, rng: DetRng):
	# Fan path: a compound `all_tagged` select touches every matching member.
	if op.has("target") and typeof(op["target"]) == TYPE_DICTIONARY \
			and op["target"].get("select", "") == "all_tagged":
		var targets := BodyGraph.resolve_targets(root, {"select": op["target"]})
		var changes: Array = []
		for seg in targets:
			var ch = _prop_delta_one(seg, op, rng)
			if ch != null:
				changes.append(ch)
		if changes.is_empty():
			return null
		return {"effect": "prop_delta_fan", "prop": op["prop"], "changes": changes}
	# Single-node path (target_node or an ordinal nth_tagged resolving to one).
	var tid := _target_id(root, op)
	if tid == "":
		return null
	var seg = BodyGraph.find_by_id(root, tid)
	if seg == null:
		return null
	var ch = _prop_delta_one(seg, op, rng)
	if ch == null:
		return null
	return {"effect": "prop_delta", "id": ch["id"], "prop": ch["prop"],
			"before": ch["before"], "after": ch["after"]}


# prop_scale: MULTIPLY a scalar prop by an integer fixed-point factor num/den (optionally
# CUBED), then clamp. This is how the whole-body scale TFs (shrink_to_fae / grow_to_giant)
# scale the FIGURE measurements proportionally — waist/hip/band by the linear factor, breast
# (and butt) volume by the CUBE of the factor (volume scales as length^3) — so a fae/giant
# keeps the base body's PROPORTIONS and reads the SAME figure shape. No RNG (a deterministic
# multiply, not a roll). Integer-only in the path; INT_PROPS stay int. Fans across every
# resolved target that actually CARRIES the prop (others no-op). Emits the prop_delta_fan
# result shape so the existing undo path restores each before-value exactly.
static func _apply_prop_scale(root: Dictionary, op: Dictionary):
	var targets := _scale_targets(root, op)
	var prop: String = op["prop"]
	var n: int = int(op.get("num", 1))
	var d: int = int(op.get("den", 1))
	if op.get("cube", false):
		n = n * n * n
		d = d * d * d
	if d == 0:
		return null
	var changes: Array = []
	for seg in targets:
		if not seg.get("props", {}).has(prop):
			continue
		var before: float = float(seg["props"][prop])
		var before_h := int(round(before * 100.0))
		var after_h := before_h * n / d
		if op.has("clamp"):
			var lo_c := int(round(float(op["clamp"][0]) * 100.0))
			var hi_c := int(round(float(op["clamp"][1]) * 100.0))
			after_h = clampi(after_h, lo_c, hi_c)
		var after: float = float(after_h) / 100.0
		if after == before:
			continue
		if prop in BodyGraph.INT_PROPS:
			seg["props"][prop] = int(round(after))
		else:
			seg["props"][prop] = after
		changes.append({"id": seg["id"], "prop": prop, "before": before, "after": after})
	if changes.is_empty():
		return null
	return {"effect": "prop_delta_fan", "prop": prop, "changes": changes}


# Resolve the fan-set a prop_scale targets. Accepts a `target` select dict (the §3.2
# {select:"all_tagged",tag:...} sugar, mirroring prop_delta's fan), a direct `target_node`,
# or the legacy tag/subtree keys.
static func _scale_targets(root: Dictionary, op: Dictionary) -> Array:
	if op.has("target") and typeof(op["target"]) == TYPE_DICTIONARY \
			and str(op["target"].get("select", "")) != "":
		return BodyGraph.resolve_targets(root, {"select": op["target"]})
	return BodyGraph.resolve_targets(root, op)


# Apply one prop_delta to one segment; returns {id, prop, before, after} or null (no-op).
static func _prop_delta_one(seg: Dictionary, op: Dictionary, rng: DetRng):
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
	# Canonical integer size props stay INT (no float drift, byte-identical round-trip).
	if prop in BodyGraph.INT_PROPS:
		seg["props"][prop] = int(round(after))
	else:
		seg["props"][prop] = after
	return {"id": seg["id"], "prop": prop, "before": before, "after": after}


# set_fluid_type (§5.2): set/rename a fluid's `type` on the target(s). On a node with
# no matching entry it ADDS one (amount:0, given/zero capacity) — the add/no-op
# symmetry of the FORM ops. `match` selects the entry to retype (old type name); when
# absent the op adds a fresh entry of `value` type. Captures the full prior fluids[]
# per node so undo restores it exactly. Fans across resolved targets.
# Resolve the fan-set of nodes a fluid op targets. Accepts the `target` selector
# (§3.2 {select:...}) OR the legacy direct keys (target_node / tag / select / subtree_*).
static func _fluid_targets(root: Dictionary, op: Dictionary) -> Array:
	if op.has("target"):
		var t = op["target"]
		if typeof(t) == TYPE_DICTIONARY and t.has("select"):
			return BodyGraph.resolve_targets(root, {"select": t})
		return BodyGraph.resolve_targets(root, {"target_node": t})
	return BodyGraph.resolve_targets(root, op)


static func _apply_set_fluid_type(root: Dictionary, op: Dictionary):
	var targets := _fluid_targets(root, op)
	var new_type: String = str(op["value"])
	var match_type = op.get("match", null)   # old type to rename, or null = add-if-absent
	var capacity: int = int(op.get("capacity", 0))
	var changes: Array = []
	for seg in targets:
		var before: Array = (seg.get("fluids", []) as Array).duplicate(true)
		var fluids: Array = seg.get("fluids", [])
		var found := false
		for f in fluids:
			if match_type != null and f.get("type", "") == match_type:
				f["type"] = new_type
				found = true
				break
			elif match_type == null and f.get("type", "") == new_type:
				found = true   # entry already present — no add needed
				break
		if not found:
			fluids.append({"type": new_type, "amount": 0, "capacity": capacity})
		seg["fluids"] = fluids
		var after: Array = fluids.duplicate(true)
		if JSON.stringify(before) != JSON.stringify(after):
			changes.append({"id": seg["id"], "before": before, "after": after})
	if changes.is_empty():
		return null
	return {"effect": "fluids_set", "changes": changes}


# fluid_delta (§5.2): add to a fluid's amount and/or capacity on the target(s), seeded
# + clamped to integers (mirrors prop_delta — no float in the path). `amount` is a
# {"roll":"uniform_int","lo":..,"hi":..} seeded integer draw or {"v":int} literal.
# new amount clamps to [0, capacity]; capacity_delta grows/shrinks the reservoir
# (clamped >= 0), and a shrunk capacity re-clamps amount down. If the target lacks the
# named fluid entry it is ADDED (amount:0, capacity from capacity_delta) first, so a
# capacity-opening delta can begin a reservoir. Captures prior fluids[] for undo.
static func _apply_fluid_delta(root: Dictionary, op: Dictionary, rng: DetRng):
	var targets := _fluid_targets(root, op)
	var ftype: String = str(op["fluid"])
	var changes: Array = []
	for seg in targets:
		var before: Array = (seg.get("fluids", []) as Array).duplicate(true)
		var fluids: Array = seg.get("fluids", [])
		var entry = null
		for f in fluids:
			if f.get("type", "") == ftype:
				entry = f
				break
		if entry == null:
			entry = {"type": ftype, "amount": 0, "capacity": 0}
			fluids.append(entry)
		# capacity first (so the amount clamp sees the new ceiling).
		var cap: int = int(entry.get("capacity", 0))
		cap = maxi(0, cap + int(op.get("capacity_delta", 0)))
		entry["capacity"] = cap
		# amount delta — seeded integer roll or literal.
		var amount = op.get("amount", {"v": 0})
		var delta: int = 0
		if typeof(amount) == TYPE_DICTIONARY and amount.get("roll", "") == "uniform_int":
			delta = rng.range_inclusive(int(amount["lo"]), int(amount["hi"]))
		elif typeof(amount) == TYPE_DICTIONARY:
			delta = int(amount.get("v", 0))
		else:
			delta = int(amount)
		var amt: int = int(entry.get("amount", 0)) + delta
		# clamp to [0, capacity] (null hi ⇒ this entry's capacity — §5.2).
		var lo := 0
		if op.has("clamp_amount"):
			lo = int(op["clamp_amount"][0])
		amt = clampi(amt, lo, cap)
		entry["amount"] = amt
		seg["fluids"] = fluids
		var after: Array = fluids.duplicate(true)
		if JSON.stringify(before) != JSON.stringify(after):
			changes.append({"id": seg["id"], "before": before, "after": after})
	if changes.is_empty():
		return null
	return {"effect": "fluids_set", "changes": changes}


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
# Restore a prop value with the right numeric type (canonical int props stay int).
static func _restore_prop(prop: String, value):
	if prop in BodyGraph.INT_PROPS:
		return int(round(float(value)))
	return value


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
		"remove_subtree_fan":
			# Re-graft every removed member in reverse order (exact restoration).
			for i in range(eff["removed"].size() - 1, -1, -1):
				var r: Dictionary = eff["removed"][i]
				BodyGraph.graft_edge(root, r["parent_id"], r["removed_edge"])
		"reparent":
			BodyGraph.reparent(root, eff["node_id"], eff["old_parent"], eff["old_at"])
		"reparent_fan":
			# Reverse each move in reverse order, docking the node back at its EXACT prior
			# parent AND sibling index so the graph restores byte-identically (§5.4).
			for i in range(eff["moves"].size() - 1, -1, -1):
				var m: Dictionary = eff["moves"][i]
				var edge = BodyGraph.remove(root, m["node_id"])
				if edge != null:
					edge["at"] = m["old_at"]
					BodyGraph.graft_edge_at(root, m["old_parent"], edge, int(m["old_index"]))
		"set_axis":
			for ch in eff["changes"]:
				var seg = BodyGraph.find_by_id(root, ch["id"])
				if seg != null:
					seg["material"] = ch["before_material"]
					seg["covering"] = ch["before_covering"]
		"prop_delta":
			var seg = BodyGraph.find_by_id(root, eff["id"])
			if seg != null:
				seg["props"][eff["prop"]] = _restore_prop(eff["prop"], eff["before"])
		"prop_delta_fan":
			for ch in eff["changes"]:
				var fseg = BodyGraph.find_by_id(root, ch["id"])
				if fseg != null:
					fseg["props"][ch["prop"]] = _restore_prop(ch["prop"], ch["before"])
		"fluids_set":
			# Restore each touched node's prior fluids[] exactly (§5.4).
			for ch in eff["changes"]:
				var seg = BodyGraph.find_by_id(root, ch["id"])
				if seg != null:
					var before: Array = (ch["before"] as Array).duplicate(true)
					if before.is_empty():
						seg.erase("fluids")   # was absent before — restore absence
					else:
						seg["fluids"] = before
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
