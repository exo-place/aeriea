## GENERATED from res://interaction/sandbox.kit.json — do not edit by hand.
## Regenerate with:
##   nix develop --command bash -lc 'xvfb-run -a godot4 --path . res://tools/regen_compiled_interaction.tscn --quit-after 120'
##
## This is the COMPILED projection of the interaction kit (see
## docs/decisions/affordance-substrate.md §7b and scripts/interaction/interaction_compiler.gd).
## It is a faithful lowering of InteractionInterpreter's reference semantics to
## direct branching code: tick effects, verb selection and reaction propagation
## are inlined if/elif chains in declared order, guards are inline boolean
## expressions, effects are straight-line kernel calls. The golden-trace harness
## asserts interpreter == compiled.
class_name CompiledSandboxInteraction
extends RefCounted

# Mirrors InteractionInterpreter's public surface so the same host (InteractionWorld)
# can drive either path and the same tests exercise both. The resolved frame is the
# interpreter's ResolvedFrame verbatim (same shape; render-side prompt excluded from hash).
const ResolvedFrame := preload("res://scripts/interaction/interaction_interpreter.gd").ResolvedFrame
var kit: InteractionKit
var host
var state: Dictionary = {}
var _events: Array = []
const MAX_PROPAGATION := 16

# --- Params lowered to consts (referenced by name in the kit) ---
const P_fill_rate := 1.5
const P_full_threshold := 0.95
const P_throw_impulse := 8.0

func setup(p_kit: InteractionKit, p_host) -> void:
	kit = p_kit
	host = p_host
	reset_state()

func reset_state() -> void:
	state = {}
	for id in kit.interactable_order:
		_init_state_for(id, _def_id_of(id))

var _def_of: Dictionary = {}

func _def_id_of(instance_id: String) -> String:
	return str(_def_of.get(instance_id, instance_id))

func add_instance(instance_id: String, def_id: String) -> void:
	if not kit.interactables.has(def_id):
		push_error("compiled: unknown definition '%s'" % def_id)
		return
	if instance_id == def_id or kit.interactables.has(instance_id):
		if not state.has(instance_id):
			_def_of[instance_id] = def_id
			_init_state_for(instance_id, def_id)
		return
	kit.interactables[instance_id] = kit.interactables[def_id]
	kit.interactable_order.append(instance_id)
	_def_of[instance_id] = def_id
	_init_state_for(instance_id, def_id)

func _init_state_for(instance_id: String, def_id: String) -> void:
	var rec := {}
	if def_id == "box":
		pass
	elif def_id == "valve":
		rec["flowing"] = false
	elif def_id == "spout":
		pass
	elif def_id == "jug":
		rec["fill"] = 0.0
	elif def_id == "pedestal":
		rec["active"] = false
		rec["socketed"] = null
	elif def_id == "beacon":
		rec["armed"] = false
		rec["triggered"] = false
	state[instance_id] = rec

func step(dt: float) -> void:
	var frame: ResolvedFrame = host.host_build_frame()
	_frame = frame
	_events.clear()
	_run_tick(frame, dt)
	_process_verb_fire(frame, dt)
	_propagate_events(frame, dt)

func _run_tick(frame: ResolvedFrame, dt: float) -> void:
	for _self in kit.interactable_order:
		var _def := _def_id_of(_self)
		if _def == "spout":
			var _owner: InteractionKit.Interactable = kit.interactables["spout"]
			if (_g_state_bool("spout", _self, "ref:valve", "flowing", true) and _g_in_region(frame, _self, "stream", "jug")):
				_e_add_fill("spout", _self, "region:stream:jug", "fill", frame, P_fill_rate, dt)
		elif _def == "beacon":
			var _owner: InteractionKit.Interactable = kit.interactables["beacon"]
			if (_g_state_bool("beacon", _self, "self", "armed", true) and frame.player_reached(_self, "reach")):
				_e_set_true("beacon", _self, "self", "triggered", frame)

func _process_verb_fire(frame: ResolvedFrame, dt: float) -> void:
	var interact_edge := frame.is_edge("interact")
	var throw_edge := frame.is_edge("throw")
	if not interact_edge and not throw_edge:
		return
	# THROW edge: a carry_release(throw) on the held body, if holding.
	if throw_edge and frame.held_id != "":
		if kit.interactables.has(frame.held_id):
			_fire_verb(frame.held_id, frame.held_id, frame, dt, "carry_release", "throw")
		return
	if not interact_edge:
		return
	# INTERACT edge precedence: place(focus) > drop(held) > grab(focus) > command(focus).
	if frame.held_id != "":
		if frame.focus_id != "" and kit.interactables.has(frame.focus_id):
			if _fire_verb(frame.focus_id, frame.focus_id, frame, dt, "place", ""):
				return
		if kit.interactables.has(frame.held_id):
			if not _fire_verb(frame.held_id, frame.held_id, frame, dt, "carry_release", "drop"):
				host.host_release("drop", 0.0)
		else:
			host.host_release("drop", 0.0)
		return
	if frame.focus_id == "" or not kit.interactables.has(frame.focus_id):
		return
	if _fire_verb(frame.focus_id, frame.focus_id, frame, dt, "grab", ""):
		return
	_fire_verb(frame.focus_id, frame.focus_id, frame, dt, "command", "")

func _fire_verb(def_id_inst: String, self_id: String, frame: ResolvedFrame, dt: float, kind: String, name_hint: String) -> bool:
	var _def := _def_id_of(def_id_inst)
	var _self := self_id
	if _def == "box":
		var _owner: InteractionKit.Interactable = kit.interactables["box"]
		if kind == "grab" and (name_hint == "" or name_hint == "grab") and ((not (frame.held_id != ""))):
			host.host_grab(_self)
			return true
		if kind == "carry_release" and (name_hint == "" or name_hint == "drop") and ((frame.held_id != "")):
			host.host_release("drop", 0.0)
			return true
		if kind == "carry_release" and (name_hint == "" or name_hint == "throw") and ((frame.held_id != "")):
			host.host_release("throw", 0.0)
			host.host_apply_impulse(P_throw_impulse)
			return true
	elif _def == "valve":
		var _owner: InteractionKit.Interactable = kit.interactables["valve"]
		if kind == "command" and (name_hint == "" or name_hint == "toggle") and (true):
			_e_toggle_state("valve", _self, "self", "flowing", frame)
			_events.append({ "from": _self, "event": "flow_changed" })
			return true
	elif _def == "jug":
		var _owner: InteractionKit.Interactable = kit.interactables["jug"]
		if kind == "grab" and (name_hint == "" or name_hint == "grab") and ((not (frame.held_id != ""))):
			host.host_grab(_self)
			return true
		if kind == "carry_release" and (name_hint == "" or name_hint == "drop") and ((frame.held_id != "")):
			host.host_release("drop", 0.0)
			return true
		if kind == "carry_release" and (name_hint == "" or name_hint == "throw") and ((frame.held_id != "")):
			host.host_release("throw", 0.0)
			host.host_apply_impulse(P_throw_impulse)
			return true
	elif _def == "pedestal":
		var _owner: InteractionKit.Interactable = kit.interactables["pedestal"]
		if kind == "place" and (name_hint == "" or name_hint == "place") and ((_g_socket_empty("pedestal", _self, "self", "socketed") and (frame.held_id != "") and frame.held_tags.has("jug"))):
			_e_consume_into_socket("pedestal", _self, "self", "socketed", frame)
			if _g_state_cmp("pedestal", _self, "held", "fill", "ge", P_full_threshold):
				_e_set_state("pedestal", _self, "self", "active", frame, true)
			if _g_state_bool("pedestal", _self, "self", "active", true):
				_events.append({ "from": _self, "event": "activated" })
			return true
	return false

func _propagate_events(frame: ResolvedFrame, dt: float) -> void:
	var depth := 0
	while not _events.is_empty() and depth < MAX_PROPAGATION:
		depth += 1
		var batch := _events.duplicate()
		_events.clear()
		for ev: Dictionary in batch:
			for _self in kit.interactable_order:
				_react(_self, ev, frame, dt)

func _react(self_id: String, ev: Dictionary, frame: ResolvedFrame, dt: float) -> void:
	var _def := _def_id_of(self_id)
	var _self := self_id
	if _def == "beacon":
		var _owner: InteractionKit.Interactable = kit.interactables["beacon"]
		if ev["event"] == "activated" and ev["from"] == str(_owner.refs.get("pedestal", "")):
			_e_set_true("beacon", _self, "self", "armed", frame)


func _g_focus_is(frame: ResolvedFrame, tag: String) -> bool:
	if frame.focus_id == "":
		return false
	var fit: InteractionKit.Interactable = kit.interactables.get(frame.focus_id)
	return fit != null and fit.tags.has(tag)

func _g_in_region(frame: ResolvedFrame, self_id: String, region: String, tag: String) -> bool:
	var members := frame.members(self_id, region)
	if tag == "":
		return not members.is_empty()
	for mid: String in members:
		var mit: InteractionKit.Interactable = kit.interactables.get(mid)
		if mit != null and mit.tags.has(tag):
			return true
	return false

func _g_state_bool(def_id: String, self_id: String, scope: String, field: String, value: bool) -> bool:
	var rec := _scope_record(def_id, scope, self_id, _frame)
	return bool(rec.get(field, false)) == value

func _g_state_cmp(def_id: String, self_id: String, scope: String, field: String, cmp: String, rhs: float) -> bool:
	var rec := _scope_record(def_id, scope, self_id, _frame)
	var lhs := float(rec.get(field, 0.0))
	return _cmp(lhs, cmp, rhs)

func _g_state_enum(def_id: String, self_id: String, scope: String, field: String, eq: String) -> bool:
	var rec := _scope_record(def_id, scope, self_id, _frame)
	return str(rec.get(field, "")) == eq

func _g_socket_empty(def_id: String, self_id: String, scope: String, field: String) -> bool:
	var rec := _scope_record(def_id, scope, self_id, _frame)
	return rec.get(field, null) == null

func _cmp(lhs: float, op: String, rhs: float) -> bool:
	match op:
		"ge": return lhs >= rhs
		"gt": return lhs > rhs
		"le": return lhs <= rhs
		"lt": return lhs < rhs
		"eq": return is_equal_approx(lhs, rhs)
	return false

## Resolve a scope to its state record. self -> the acting INSTANCE id; held/focus
## -> the frame's held/focus; ref:<name> -> the def's declared ref record.
func _scope_record(def_id: String, scope: String, self_id: String, frame: ResolvedFrame) -> Dictionary:
	if scope == "self":
		return state.get(self_id, {})
	if scope == "held":
		return state.get(frame.held_id, {})
	if scope == "focus":
		return state.get(frame.focus_id, {})
	if scope.begins_with("ref:"):
		var owner: InteractionKit.Interactable = kit.interactables.get(def_id)
		var tgt := str(owner.refs.get(scope.substr(4), "")) if owner != null else ""
		return state.get(tgt, {})
	return {}


## The current resolved frame, set at the top of each kernel-using pass. Used only
## by guard kernels invoked from inline boolean expressions (they cannot thread the
## frame argument). step() sets it once per tick; identical to the interpreter's
## per-tick frame, so guard evaluation is bit-identical.
var _frame: ResolvedFrame = null

func _e_set_state(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame, value) -> void:
	var rec := _scope_record(def_id, scope, self_id, frame)
	rec[field] = value

func _e_set_true(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame) -> void:
	var rec := _scope_record(def_id, scope, self_id, frame)
	rec[field] = true

func _e_toggle_state(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame) -> void:
	var rec := _scope_record(def_id, scope, self_id, frame)
	rec[field] = not bool(rec.get(field, false))

func _e_consume_into_socket(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame) -> void:
	var rec := _scope_record(def_id, scope, self_id, frame)
	rec[field] = frame.held_id
	host.host_socket(self_id, frame.held_id)

func _e_add_fill(def_id: String, self_id: String, scope: String, field: String, frame: ResolvedFrame, rate: float, dt: float) -> void:
	if scope.begins_with("region:"):
		var parts := scope.split(":")
		var region := parts[1] if parts.size() > 1 else ""
		var tag := parts[2] if parts.size() > 2 else ""
		for mid: String in frame.members(self_id, region):
			var mit: InteractionKit.Interactable = kit.interactables.get(mid)
			if mit == null:
				continue
			if tag != "" and not mit.tags.has(tag):
				continue
			_apply_fill(mid, field, rate * dt)
		return
	var rec := _scope_record(def_id, scope, self_id, frame)
	var target_id := _scope_owner_id(def_id, scope, self_id, frame)
	if target_id != "":
		_apply_fill(target_id, field, rate * dt)
	elif rec.has(field):
		rec[field] = float(rec[field]) + rate * dt

func _apply_fill(id: String, field: String, amount: float) -> void:
	var rec: Dictionary = state.get(id, {})
	if not rec.has(field):
		return
	var slot := _slot_for(id, field)
	var v := float(rec[field]) + amount
	if slot != null and slot.has_bounds:
		v = clampf(v, slot.lo, slot.hi)
	rec[field] = v

func _slot_for(id: String, field: String) -> InteractionKit.TypedSlot:
	var it: InteractionKit.Interactable = kit.interactables.get(id)
	if it == null:
		return null
	return it.state_schema.get(field)

func _scope_owner_id(def_id: String, scope: String, self_id: String, frame: ResolvedFrame) -> String:
	if scope == "self":
		return self_id
	if scope == "held":
		return frame.held_id
	if scope == "focus":
		return frame.focus_id
	if scope.begins_with("ref:"):
		var owner: InteractionKit.Interactable = kit.interactables.get(def_id)
		return str(owner.refs.get(scope.substr(4), "")) if owner != null else ""
	return ""


## Resolve a cross-scope state path "<scope>.<field>" against the live record, with
## a param-table fallback (e.g. "held.full_threshold" is the full_threshold PARAM).
## Self-scope context for the path's <scope> uses the frame's held/focus; "ref:"
## paths are not used as guard VALUES in the slice, so the def is the current frame
## focus def when needed — but in practice slice values are held.<param>.
func _resolve_value_path(s: String, frame: ResolvedFrame) -> float:
	if not s.contains("."):
		return float(kit.params.get(s, 0.0))
	var parts := s.split(".")
	var scope := parts[0]
	var field := parts[1]
	var rec := _scope_record_for_value(scope, frame)
	if rec.has(field):
		return float(rec[field])
	return float(kit.params.get(field, 0.0))

## A reduced scope_record for value paths: scope is self/held/focus (no def-ref
## needed — value paths in the slice read held.<x>). self maps to focus (the acting
## target) for value context; the interpreter resolves the same way via its owner.
func _scope_record_for_value(scope: String, frame: ResolvedFrame) -> Dictionary:
	if scope == "held":
		return state.get(frame.held_id, {})
	if scope == "focus":
		return state.get(frame.focus_id, {})
	return {}


## Project the contextual prompt this tick (render-side; not part of equivalence).
## Mirrors InteractionInterpreter.project_prompt: place(focus) > drop line > first
## available focus verb. Verb availability uses the same inlined guard kernels.
func project_prompt(frame: ResolvedFrame) -> String:
	_frame = frame
	if frame.held_id != "":
		if frame.focus_id != "" and kit.interactables.has(frame.focus_id):
			var fdef := _def_id_of(frame.focus_id)
			var fit: InteractionKit.Interactable = kit.interactables[frame.focus_id]
			for v: InteractionKit.Verb in fit.verbs:
				if v.kind == "place" and _eval_guard_dyn(v.when_guard, fdef, frame.focus_id, frame):
					return _render_prompt(v, fit, frame.focus_id, frame)
		return "[E] Drop    [F] Throw"
	if frame.focus_id == "" or not kit.interactables.has(frame.focus_id):
		return ""
	var def := _def_id_of(frame.focus_id)
	var it: InteractionKit.Interactable = kit.interactables[frame.focus_id]
	for v: InteractionKit.Verb in it.verbs:
		if v.kind == "carry_release":
			continue
		if _eval_guard_dyn(v.when_guard, def, frame.focus_id, frame):
			var text := _render_prompt(v, it, frame.focus_id, frame)
			if text != "":
				return text
	return ""

## A small dynamic guard evaluator used ONLY by the render-side prompt projection
## (not the sim hash path). Mirrors InteractionInterpreter._eval_guard. The hot tick
## path uses the inlined guard EXPRESSIONS; prompts are recomputed off the sim loop.
func _eval_guard_dyn(g: Dictionary, def_id: String, self_id: String, frame: ResolvedFrame) -> bool:
	if g.is_empty():
		return true
	var op := str(g.get("op", ""))
	match op:
		"all":
			for sub: Variant in g.get("of", []):
				if not _eval_guard_dyn(sub, def_id, self_id, frame):
					return false
			return true
		"any":
			for sub: Variant in g.get("of", []):
				if _eval_guard_dyn(sub, def_id, self_id, frame):
					return true
			return false
		"not":
			var of: Array = g.get("of", [])
			return not _eval_guard_dyn(of[0], def_id, self_id, frame) if of.size() > 0 else true
		"is_held":
			return frame.held_id != ""
		"held_is":
			return frame.held_tags.has(str(g.get("tag", "")))
		"focus_is":
			return _g_focus_is(frame, str(g.get("tag", "")))
		"in_region":
			return _g_in_region(frame, self_id, str(g.get("region", "")), str(g.get("tag", "")))
		"reached_by_player":
			return frame.player_reached(self_id, str(g.get("region", "")))
		"state_bool":
			var rec := _scope_record(def_id, str(g.get("scope", "self")), self_id, frame)
			return bool(rec.get(str(g.get("field", "")), false)) == bool(g.get("value", true))
		"state_cmp":
			var rec2 := _scope_record(def_id, str(g.get("scope", "self")), self_id, frame)
			return _cmp(float(rec2.get(str(g.get("field", "")), 0.0)), str(g.get("cmp", "")), _resolve_value_dyn(g.get("value"), def_id, self_id, frame))
		"state_enum":
			var rec3 := _scope_record(def_id, str(g.get("scope", "self")), self_id, frame)
			return str(rec3.get(str(g.get("field", "")), "")) == str(g.get("eq", ""))
		"socket_empty":
			var rec4 := _scope_record(def_id, str(g.get("scope", "self")), self_id, frame)
			return rec4.get(str(g.get("field", "")), null) == null
	return false

func _resolve_value_dyn(v: Variant, def_id: String, self_id: String, frame: ResolvedFrame) -> float:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return float(v)
		TYPE_STRING:
			var s := v as String
			if s.contains("."):
				var parts := s.split(".")
				var rec := _scope_record(def_id, parts[0], self_id, frame)
				if rec.has(parts[1]):
					return float(rec[parts[1]])
				return float(kit.params.get(parts[1], 0.0))
			return float(kit.params.get(s, 0.0))
	return 0.0

func _render_prompt(v: InteractionKit.Verb, it: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> String:
	var def := _def_id_of(self_id)
	var template := ""
	match typeof(v.prompt):
		TYPE_STRING:
			template = v.prompt
		TYPE_ARRAY:
			for variant: Variant in v.prompt:
				if typeof(variant) != TYPE_DICTIONARY:
					continue
				var w: Variant = variant.get("when", null)
				if w == null or (typeof(w) == TYPE_DICTIONARY and _eval_guard_dyn(w, def, self_id, frame)):
					template = str(variant.get("text", ""))
					break
	return _interpolate(template, v, it, self_id, frame)

func _interpolate(template: String, v: InteractionKit.Verb, it: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> String:
	if not template.contains("{"):
		return template
	var out := template
	var def := _def_id_of(self_id)
	var default_scope := "held" if v.kind == "place" else "self"
	var rx := RegEx.new()
	rx.compile("\\{([^}]*)\\}")
	for m in rx.search_all(template):
		var inner := m.get_string(1).strip_edges()
		var as_pct := false
		if inner.begins_with("pct "):
			as_pct = true
			inner = inner.substr(4).strip_edges()
		var scope := default_scope
		var field := inner
		if inner.contains("."):
			var parts := inner.split(".")
			scope = parts[0]
			field = parts[1]
		var rec := _scope_record(def, scope, self_id, frame)
		var value: Variant = rec.get(field, 0.0)
		var rendered := ""
		if as_pct:
			rendered = "%d" % int(round(float(value) * 100.0))
		else:
			rendered = str(value)
		out = out.replace(m.get_string(0), rendered)
	return out

