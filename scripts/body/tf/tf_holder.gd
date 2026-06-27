## TfHolder — aeriea's per-character stateful TF manager (TF system §5.3, §5.4).
##
## The ONLY stateful piece. Holds: the body graph, a SimClock (deterministic on-action
## time, §5.3), the active staged TFs, and the undo log. Everything else is pure
## functions over data (BodyGraph / TfApplier).
##
## Staged progression (§5.3): start_tf() records an ActiveTF; on each logged action
## that advances time, advance_time(seconds) advances the clock and, while a staged
## TF's stage is due, runs TfApplier.apply_stage, appends its effects to the undo log,
## and steps the stage — stopping at max_stages or when the gate fails.
##
## Reversibility (§5.4): the undo log is the list of stage effect-batches; undo_last()
## reverts the most recent batch; make_permanent() clears the log (new baseline).
##
## Save/load (§7): to_dict/from_dict serialize body + clock + active TFs + undo log so
## a save round-trips identically (the dict IS the truth).
extends RefCounted

const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const TfApplier := preload("res://scripts/body/tf/tf_applier.gd")
const SimClock := preload("res://scripts/sim/sim_clock.gd")

var body: Dictionary           # { "root": Segment, "scalars": {...} }
var clock: SimClock
var world_seed: int
var active: Array              # [ ActiveTF ] — staged TFs in flight
var undo_log: Array            # [ { "tf_id", "stage_index", "action_id", "effects":[...] } ]
var _next_action_id: int       # monotonic per-character action counter (RNG coordinate)

# TF records are looked up by id from this registry (set by the owner).
var registry: Dictionary


func _init(start_body: Dictionary, seed_value: int = 0, tf_registry: Dictionary = {}) -> void:
	body = BodyGraph.dup_state(start_body)
	clock = SimClock.new()
	world_seed = seed_value
	active = []
	undo_log = []
	_next_action_id = 0
	registry = tf_registry


# --- instant + staged TF entry --------------------------------------------------

## Apply an instant (non-staged) TF immediately. Returns its effects (also logged).
func apply_instant(tf_id: String) -> Array:
	var tf: Dictionary = registry[tf_id]
	var aid := _next_action_id
	_next_action_id += 1
	var effects := TfApplier.apply_stage(body, tf, 0, world_seed, aid)
	if not effects.is_empty():
		undo_log.append({"tf_id": tf_id, "stage_index": 0, "action_id": aid, "effects": effects})
	return effects


## Begin a staged TF. Its first stage comes due after `stage_seconds` of in-game time.
func start_tf(tf_id: String) -> void:
	var tf: Dictionary = registry[tf_id]
	var stage_seconds: int = int(tf.get("stage_seconds", 0))
	active.append({
		"tf_id": tf_id,
		"action_id": _next_action_id,
		"next_stage": 0,
		"due_full_time": clock.full_time() + stage_seconds,
	})
	_next_action_id += 1


# --- staged progression on sim_clock (§5.3) -------------------------------------

## A logged action that consumes `seconds` of in-game time. Advances the clock then
## fires every staged TF stage that is now due. Deterministic: clock + RNG are both
## pinned to the action-log timeline, so replay reproduces the exact unfolding.
func advance_time(seconds: int) -> void:
	clock.advance(seconds)
	var still_active: Array = []
	for atf in active:
		_drain_due(atf)
		var tf: Dictionary = registry[atf["tf_id"]]
		var maxed: bool = atf["next_stage"] >= int(tf.get("max_stages", 1))
		var gate_ok: bool = TfApplier.eval_predicate(tf.get("gate"), body)
		if not maxed and gate_ok:
			still_active.append(atf)
	active = still_active


# Run every stage of this TF that is due at the current clock time.
func _drain_due(atf: Dictionary) -> void:
	var tf: Dictionary = registry[atf["tf_id"]]
	var max_stages: int = int(tf.get("max_stages", 1))
	var stage_seconds: int = int(tf.get("stage_seconds", 0))
	while atf["next_stage"] < max_stages and clock.full_time() >= atf["due_full_time"]:
		if not TfApplier.eval_predicate(tf.get("gate"), body):
			break   # gate failed mid-progression — stop
		var stage_index: int = atf["next_stage"]
		var effects := TfApplier.apply_stage(body, tf, stage_index, world_seed, atf["action_id"])
		if not effects.is_empty():
			undo_log.append({"tf_id": atf["tf_id"], "stage_index": stage_index,
							"action_id": atf["action_id"], "effects": effects})
		atf["next_stage"] += 1
		atf["due_full_time"] += stage_seconds


## True if any staged TF is still in flight.
func has_active() -> bool:
	return not active.is_empty()


# --- reversibility (§5.4) -------------------------------------------------------

## Undo the most recent logged stage batch (re-grafts removed subtrees, restores
## materials/coverings/props/tags exactly). Returns true if anything was undone.
func undo_last() -> bool:
	if undo_log.is_empty():
		return false
	var batch: Dictionary = undo_log.pop_back()
	TfApplier.undo_effects(body, batch["effects"])
	return true


## Clear the undo log: the current graph becomes the new baseline (§5.4).
func make_permanent() -> void:
	undo_log.clear()


# --- split / merge (§4.2) — graft/remove generalized across body boundaries -----

## SPLIT: detach the subtree rooted at `node_id` and return it AS ITS OWN body state
## (a new {"root", "scalars"}). The detachment is logged for undo. World-entity
## identity of the split-off body is the AUTHOR's call (§4.2) — we just return it.
func split_off(node_id: String) -> Dictionary:
	var loc = BodyGraph.find_parent(body["root"], node_id)
	if loc == null:
		return {}
	var parent_id: String = loc["parent"]["id"]
	var edge = BodyGraph.remove(body["root"], node_id)
	if edge == null:
		return {}
	undo_log.append({"tf_id": "<split>", "stage_index": 0, "action_id": _next_action_id,
		"effects": [{"effect": "remove_subtree", "parent_id": parent_id,
					"node_id": node_id, "removed_edge": edge}]})
	_next_action_id += 1
	return {"root": edge["node"], "scalars": {}}


## MERGE: graft ANOTHER body's whole graph onto this one at (target_id, at). Logged.
func merge_in(other_body: Dictionary, target_id: String, at: String) -> bool:
	var subtree: Dictionary = other_body["root"]
	var ok := BodyGraph.graft(body["root"], target_id, at, subtree)
	if not ok:
		return false
	undo_log.append({"tf_id": "<merge>", "stage_index": 0, "action_id": _next_action_id,
		"effects": [{"effect": "graft_subtree", "parent_id": target_id,
					"node_id": subtree["id"]}]})
	_next_action_id += 1
	return true


# --- save / load (§7) -----------------------------------------------------------

## Serialize body + clock + active TFs + undo log. The dict IS the truth.
func to_dict() -> Dictionary:
	return {
		"body": body.duplicate(true),
		"clock": clock.to_dict(),
		"world_seed": world_seed,
		"active": active.duplicate(true),
		"undo_log": undo_log.duplicate(true),
		"next_action_id": _next_action_id,
	}


## Reconstruct a holder from a saved dict (registry must be supplied — TF records are
## shared static data, not per-character save state).
static func from_dict(d: Dictionary, tf_registry: Dictionary) -> RefCounted:
	var h := new(d["body"], int(d.get("world_seed", 0)), tf_registry)
	# Fluids are integer-only (§5.1); JSON reloads every number as a float, so re-cast
	# fluid amount/capacity back to int for a byte-identical, drift-free round-trip.
	if h.body.has("root"):
		BodyGraph.recast_fluid_ints(h.body["root"])
	h.clock = SimClock.from_dict(d.get("clock", {}))
	h.active = d.get("active", []).duplicate(true)
	h.undo_log = d.get("undo_log", []).duplicate(true)
	h._next_action_id = int(d.get("next_action_id", 0))
	# JSON erases the int/float distinction (every number reloads as a float). Re-cast
	# the integer bookkeeping fields so a reloaded holder's to_dict() is type-stable and
	# matches the pre-save dict exactly (the dict IS the truth — §3.4).
	for atf in h.active:
		atf["action_id"] = int(atf.get("action_id", 0))
		atf["next_stage"] = int(atf.get("next_stage", 0))
		atf["due_full_time"] = int(atf.get("due_full_time", 0))
	for batch in h.undo_log:
		batch["action_id"] = int(batch.get("action_id", 0))
		batch["stage_index"] = int(batch.get("stage_index", 0))
		# Undo records may carry detached subtrees (remove_subtree's removed_edge) or
		# captured fluids[] (fluids_set before/after) — recast their fluid ints too so
		# the reloaded undo log is byte-identical and undo restores exact integers.
		for eff in batch.get("effects", []):
			if eff.get("effect", "") == "remove_subtree" and eff.has("removed_edge"):
				BodyGraph.recast_fluid_ints(eff["removed_edge"]["node"])
			elif eff.get("effect", "") == "remove_subtree_fan":
				for r in eff.get("removed", []):
					BodyGraph.recast_fluid_ints(r["removed_edge"]["node"])
			elif eff.get("effect", "") == "fluids_set":
				for ch in eff.get("changes", []):
					for snap in [ch.get("before", []), ch.get("after", [])]:
						for f in snap:
							if f.has("amount"):
								f["amount"] = int(round(float(f["amount"])))
							if f.has("capacity"):
								f["capacity"] = int(round(float(f["capacity"])))
	return h
