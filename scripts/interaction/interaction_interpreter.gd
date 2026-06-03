## InteractionInterpreter — the deterministic fixed-tick stepper that runs an
## InteractionKit as the reference semantics (docs/decisions/affordance-substrate.md
## §5, §7a). It holds the explicit interactable-state record (per-interactable
## field maps + socket contents), runs the once-per-tick resolved-frame tick loop
## by match-ing on the op/do tag of each Guard/Effect, and projects the prompt.
## SLICE 1 reproduces the sandbox (valve->spout->jug->pedestal->beacon + grab/drop/
## throw) exactly; the compiler (Slice 2) must match THIS, not the reverse.
##
## DETERMINISM CRUX (§5): the interactor context is resolved ONCE per tick into an
## immutable ResolvedFrame at the top of step(): focused interactable, held body,
## region overlaps, and the sampled interact/throw input edges. No guard or effect
## reads Input.* or re-raycasts mid-tick — they read this frame. Iteration order is
## the kit's declared interactable order (never Dictionary order); reaction
## propagation is a bounded, ordered, load-time-acyclic pass.
##
## PHYSICS SEAM (§5): only the verb/guard/effect/event graph is data. The carry
## spring, box stacking, throw arcs, and Area3D overlap stay in-engine. Guards read
## physics RESULTS (region membership, held identity) from the frame; effects write
## physics INTENTS (grab/release/impulse/socket) back to the host via host_* calls.
class_name InteractionInterpreter
extends RefCounted

# ---------------------------------------------------------------------------
# Immutable per-tick resolved frame (§5 step 1). The host fills this once.
# ---------------------------------------------------------------------------

class ResolvedFrame:
	extends RefCounted
	## Interactable id currently under the reticle (or "").
	var focus_id: String = ""
	## Interactable id of the carried body (or ""), and its tags for held_is.
	var held_id: String = ""
	var held_tags: Array = []
	## Sampled input edges this tick: action -> bool (pressed-edge).
	var edges: Dictionary = {}
	## Region overlaps: "<owner_id>:<region>" -> Array[overlapping interactable id].
	## Sampled once. The interpreter never queries the physics world directly.
	var region_members: Dictionary = {}
	## Player-in-region: "<owner_id>:<region>" -> bool (the player body overlaps).
	var player_in_region: Dictionary = {}

	func is_edge(action: String) -> bool:
		return bool(edges.get(action, false))
	func members(owner_id: String, region: String) -> Array:
		return region_members.get("%s:%s" % [owner_id, region], [])
	func player_reached(owner_id: String, region: String) -> bool:
		return bool(player_in_region.get("%s:%s" % [owner_id, region], false))

# ---------------------------------------------------------------------------
# Explicit mutable simulation record. Nothing hidden lives outside this + host.
# ---------------------------------------------------------------------------

var kit: InteractionKit
## The host that owns the physics world. Must implement the host_* protocol:
##   host_build_frame() -> ResolvedFrame
##   host_grab(id: String) -> bool
##   host_release(mode: String, impulse_magnitude: float) -> void
##   host_apply_impulse(magnitude: float) -> void
##   host_socket(owner_id: String, body_id: String) -> void
var host

## interactable id -> { field -> value }. The whole sim state, plus sockets.
var state: Dictionary = {}

## Event queue for the reaction propagation pass: Array of { from, event }.
var _events: Array = []

## Bounded reaction-propagation depth (load-time-acyclic guarantees termination;
## this is a defensive ceiling matching the movement kit's reenter guard).
const MAX_PROPAGATION := 16

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(p_kit: InteractionKit, p_host) -> void:
	kit = p_kit
	host = p_host
	reset_state()

## Initialise every interactable's declared state to its init value.
func reset_state() -> void:
	state = {}
	for id in kit.interactable_order:
		var it: InteractionKit.Interactable = kit.interactables[id]
		var rec := {}
		for field in it.state_order:
			var slot: InteractionKit.TypedSlot = it.state_schema[field]
			match slot.type:
				"number":
					rec[field] = float(slot.init)
				"bool":
					rec[field] = bool(slot.init)
				"socket":
					rec[field] = null  # "empty"
				_:
					rec[field] = slot.init
		state[id] = rec

## Register a runtime INSTANCE of an existing definition under a unique id. The
## instance shares the definition's verbs/tick/reactions/regions (same Interactable
## object) but gets its own fresh state record and its own slot in the stable
## iteration order. Used for the box instances (one `box` definition, many boxes).
func add_instance(instance_id: String, def_id: String) -> void:
	if not kit.interactables.has(def_id):
		push_error("InteractionInterpreter.add_instance: unknown definition '%s'" % def_id)
		return
	if instance_id == def_id or kit.interactables.has(instance_id):
		# Singleton (instance == definition) or already present; just ensure state.
		if not state.has(instance_id):
			_init_state_for(instance_id, def_id)
		return
	var it: InteractionKit.Interactable = kit.interactables[def_id]
	kit.interactables[instance_id] = it          # share the definition object
	kit.interactable_order.append(instance_id)
	_init_state_for(instance_id, def_id)

func _init_state_for(instance_id: String, def_id: String) -> void:
	var it: InteractionKit.Interactable = kit.interactables[def_id]
	var rec := {}
	for field in it.state_order:
		var slot: InteractionKit.TypedSlot = it.state_schema[field]
		match slot.type:
			"number": rec[field] = float(slot.init)
			"bool": rec[field] = bool(slot.init)
			"socket": rec[field] = null
			_: rec[field] = slot.init
	state[instance_id] = rec

# ---------------------------------------------------------------------------
# The tick (one _physics_process). §5 execution model.
# ---------------------------------------------------------------------------

func step(dt: float) -> void:
	# 1. Resolve the interactor context ONCE into an immutable frame.
	var frame: ResolvedFrame = host.host_build_frame()
	_events.clear()

	# 2. Run each interactable's tick effects (while-guarded), in DECLARED order.
	#    `self_id` is the INSTANCE id (the iteration key) — distinct from the shared
	#    definition's `it.id` for instanced interactables (box). State + region keys
	#    use self_id; verbs/refs/tags/regions come from the shared definition `it`.
	for id in kit.interactable_order:
		var it: InteractionKit.Interactable = kit.interactables[id]
		var self_id: String = str(id)
		for te: InteractionKit.TickEffect in it.tick:
			if _eval_guard(te.while_guard, it, self_id, frame):
				_run_effects(te.do_effects, it, self_id, frame, dt)

	# 3. Process the interactor's verb-fire from sampled input edges.
	_process_verb_fire(frame, dt)

	# 4. Propagate events to reactions (bounded, ordered, acyclic pass).
	_propagate_events(frame, dt)

## Decide and fire the contextual verb for an input edge this tick. Mirrors the
## interactor's precedence as DATA-ordered resolution: a place verb on the focus
## (while held) before a carry_release; a grab before a plain command. Each edge
## (interact / throw) maps to the matching kind.
func _process_verb_fire(frame: ResolvedFrame, dt: float) -> void:
	var interact_edge := frame.is_edge("interact")
	var throw_edge := frame.is_edge("throw")
	if not interact_edge and not throw_edge:
		return

	# THROW edge: a carry_release(throw) on the held body, if holding.
	if throw_edge and frame.held_id != "":
		var held_it: InteractionKit.Interactable = kit.interactables.get(frame.held_id)
		if held_it != null:
			var tv := _find_verb(held_it, frame, "carry_release", "throw")
			if tv != null:
				_run_effects(tv.do_effects, held_it, frame.held_id, frame, dt)
		return

	if not interact_edge:
		return

	# INTERACT edge precedence:
	#   1. If holding and the focus accepts a place verb -> place (compose edge).
	#   2. Else if holding -> drop (carry_release/drop on held).
	#   3. Else if focus affords a grab -> grab.
	#   4. Else if focus affords a command -> command.
	if frame.held_id != "":
		if frame.focus_id != "":
			var focus_it: InteractionKit.Interactable = kit.interactables.get(frame.focus_id)
			if focus_it != null:
				var pv := _find_verb(focus_it, frame, "place", "")
				if pv != null:
					_run_effects(pv.do_effects, focus_it, frame.focus_id, frame, dt)
					return
		var held_it: InteractionKit.Interactable = kit.interactables.get(frame.held_id)
		if held_it != null:
			var dv := _find_verb(held_it, frame, "carry_release", "drop")
			if dv != null:
				_run_effects(dv.do_effects, held_it, frame.held_id, frame, dt)
			else:
				host.host_release("drop", 0.0)
		return

	if frame.focus_id == "":
		return
	var it: InteractionKit.Interactable = kit.interactables.get(frame.focus_id)
	if it == null:
		return
	var gv := _find_verb(it, frame, "grab", "")
	if gv != null:
		_run_effects(gv.do_effects, it, frame.focus_id, frame, dt)
		return
	var cv := _find_verb(it, frame, "command", "")
	if cv != null:
		_run_effects(cv.do_effects, it, frame.focus_id, frame, dt)

## First verb of the given kind whose guard holds. `name_hint` (when non-"") also
## requires the verb name to match — used to pick drop vs throw, both carry_release.
## Self-scope guards resolve against the verb's acting instance: focus_id for
## command/grab/place, held_id for carry_release.
func _find_verb(it: InteractionKit.Interactable, frame: ResolvedFrame, kind: String, name_hint: String) -> InteractionKit.Verb:
	var self_id := frame.held_id if kind == "carry_release" else frame.focus_id
	for v: InteractionKit.Verb in it.verbs:
		if v.kind != kind:
			continue
		if name_hint != "" and v.name != name_hint:
			continue
		if _eval_guard(v.when_guard, it, self_id, frame):
			return v
	return null

# ---------------------------------------------------------------------------
# Reaction propagation (§5 step 4). Bounded, declared-order, load-acyclic.
# ---------------------------------------------------------------------------

func _propagate_events(frame: ResolvedFrame, dt: float) -> void:
	var depth := 0
	while not _events.is_empty() and depth < MAX_PROPAGATION:
		depth += 1
		var batch := _events.duplicate()
		_events.clear()
		for ev: Dictionary in batch:
			# Visit reacting interactables in DECLARED order for determinism.
			for id in kit.interactable_order:
				var it: InteractionKit.Interactable = kit.interactables[id]
				for rx: InteractionKit.Reaction in it.reactions:
					if rx.on_event != ev["event"]:
						continue
					var src_id: String = str(id)
					if rx.on_from.begins_with("ref:"):
						src_id = str(it.refs.get(rx.on_from.substr(4), ""))
					elif rx.on_from == "self":
						src_id = str(id)
					if src_id != ev["from"]:
						continue
					if rx.when_guard != null and not _eval_guard(rx.when_guard, it, str(id), frame):
						continue
					_run_effects(rx.do_effects, it, str(id), frame, dt)

# ---------------------------------------------------------------------------
# Guard evaluation (closed union, §1.4). Scopes: self / held / focus / world,
# plus ref:<name> (cross-object read) and region:<region>:<tag> (effect targets).
# ---------------------------------------------------------------------------

func _eval_guard(g: Dictionary, owner: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> bool:
	if g.is_empty():
		return true
	var op := str(g.get("op", ""))
	match op:
		"all":
			for sub: Variant in g.get("of", []):
				if not _eval_guard(sub, owner, self_id, frame):
					return false
			return true
		"any":
			for sub: Variant in g.get("of", []):
				if _eval_guard(sub, owner, self_id, frame):
					return true
			return false
		"not":
			var of: Array = g.get("of", [])
			return not _eval_guard(of[0], owner, self_id, frame) if of.size() > 0 else true
		"is_held":
			return frame.held_id != ""
		"held_is":
			return frame.held_tags.has(str(g.get("tag", "")))
		"focus_is":
			if frame.focus_id == "":
				return false
			var fit: InteractionKit.Interactable = kit.interactables.get(frame.focus_id)
			return fit != null and fit.tags.has(str(g.get("tag", "")))
		"in_region":
			var members := frame.members(self_id, str(g.get("region", "")))
			var tag := str(g.get("tag", ""))
			if tag == "":
				return not members.is_empty()
			for mid: String in members:
				var mit: InteractionKit.Interactable = kit.interactables.get(mid)
				if mit != null and mit.tags.has(tag):
					return true
			return false
		"reached_by_player":
			return frame.player_reached(self_id, str(g.get("region", "")))
		"body_is_adult":
			# LAYER-1 NSFW GATE (DESIGN.md Layer 1; body-and-locomotion-slice.md 2.2).
			# Reads the actor BODY-STATE adult predicate from the host (same shape as
			# any other world-fact guard; the host supplies the body fact, the
			# interpreter stays host-agnostic). This is the INTERSECTION predicate:
			# an NSFW/intimate verb guarding on it is structurally absent from the
			# live verb set unless the body-state is adult. The age primitive itself
			# is untouched; only the combination is gated. No body-state -> NON-adult
			# (fail-closed: the safe direction for a hard legal gate).
			if host != null and host.has_method("host_is_adult_body"):
				return bool(host.host_is_adult_body())
			return false
		"state_bool":
			var rec := _scope_record(str(g.get("scope", "self")), owner, self_id, frame)
			return bool(rec.get(str(g.get("field", "")), false)) == bool(g.get("value", true))
		"state_cmp":
			var rec2 := _scope_record(str(g.get("scope", "self")), owner, self_id, frame)
			var lhs := float(rec2.get(str(g.get("field", "")), 0.0))
			return _cmp(lhs, str(g.get("cmp", "")), _resolve_value(g.get("value"), owner, self_id, frame))
		"state_enum":
			var rec3 := _scope_record(str(g.get("scope", "self")), owner, self_id, frame)
			return str(rec3.get(str(g.get("field", "")), "")) == str(g.get("eq", ""))
		"socket_empty":
			var rec4 := _scope_record(str(g.get("scope", "self")), owner, self_id, frame)
			return rec4.get(str(g.get("field", "")), null) == null
	push_error("InteractionInterpreter: unhandled guard op '%s'" % op)
	return false

## Resolve a scope to its state record. self -> the acting INSTANCE (self_id);
## held/focus -> the frame's held/focus interactable; ref:<name> -> the declared
## ref's record (refs come from the shared definition `owner`).
func _scope_record(scope: String, owner: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> Dictionary:
	if scope == "self":
		return state.get(self_id, {})
	if scope == "held":
		return state.get(frame.held_id, {})
	if scope == "focus":
		return state.get(frame.focus_id, {})
	if scope.begins_with("ref:"):
		var tgt := str(owner.refs.get(scope.substr(4), ""))
		return state.get(tgt, {})
	return {}

func _cmp(lhs: float, op: String, rhs: float) -> bool:
	match op:
		"ge": return lhs >= rhs
		"gt": return lhs > rhs
		"le": return lhs <= rhs
		"lt": return lhs < rhs
		"eq": return is_equal_approx(lhs, rhs)
	return false

# ---------------------------------------------------------------------------
# Effect execution (closed union, §1.5). Effects transform the state record or
# emit physics intents to the host. A guarded effect carries its own `when`.
# ---------------------------------------------------------------------------

func _run_effects(effects: Array, owner: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame, dt: float) -> void:
	for e: Variant in effects:
		_run_effect(e, owner, self_id, frame, dt)

func _run_effect(e: Dictionary, owner: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame, dt: float) -> void:
	# Guarded effect: skip when its own `when` is present and false.
	if e.has("when") and typeof(e["when"]) == TYPE_DICTIONARY:
		if not _eval_guard(e["when"], owner, self_id, frame):
			return
	var op := str(e.get("do", ""))
	match op:
		"set_state":
			var rec := _scope_record(str(e.get("scope", "self")), owner, self_id, frame)
			rec[str(e.get("field", ""))] = e.get("value")
		"toggle_state":
			var rec2 := _scope_record(str(e.get("scope", "self")), owner, self_id, frame)
			var f := str(e.get("field", ""))
			rec2[f] = not bool(rec2.get(f, false))
		"add_fill":
			_eff_add_fill(e, owner, self_id, frame, dt)
		"emit":
			# Event source is the acting INSTANCE id (so reactions on a ref match it).
			_events.append({ "from": self_id, "event": str(e.get("signal", "")) })
		"arm":
			var rec3 := _scope_record(str(e.get("scope", "self")), owner, self_id, frame)
			rec3[str(e.get("field", ""))] = true
		"trigger":
			# Idempotent: set the terminal field true once.
			var rec4 := _scope_record(str(e.get("scope", "self")), owner, self_id, frame)
			rec4[str(e.get("field", ""))] = true
		"consume_into_socket":
			# Take the held body out of carry and bind it into the socket field.
			# Physics is the host's; the socket field records identity.
			var rec5 := _scope_record(str(e.get("scope", "self")), owner, self_id, frame)
			rec5[str(e.get("field", ""))] = frame.held_id
			host.host_socket(self_id, frame.held_id)
		"grab_body":
			# Intent: the host takes THIS body (the acting instance) as carried.
			host.host_grab(self_id)
		"release":
			var mode := str(e.get("mode", "drop"))
			host.host_release(mode, 0.0)
		"apply_impulse":
			# Physics kick along the look direction (throw). Magnitude is data.
			host.host_apply_impulse(_resolve_value(e.get("magnitude"), owner, self_id, frame))
		_:
			push_error("InteractionInterpreter: unhandled effect op '%s'" % op)

func _eff_add_fill(e: Dictionary, owner: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame, dt: float) -> void:
	# scope of the form "region:<region>:<tag>" fills EVERY matching overlapping
	# body deterministically (declared-member order from the frame). Mirrors the
	# spout's per-overlapping-jug fill. Clamped to the slot bounds.
	var scope := str(e.get("scope", "self"))
	var field := str(e.get("field", ""))
	var rate := _resolve_value(e.get("rate"), owner, self_id, frame)
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
	# Plain scope (self/held/focus).
	var rec := _scope_record(scope, owner, self_id, frame)
	var target_id := _scope_owner_id(scope, owner, self_id, frame)
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

func _scope_owner_id(scope: String, owner: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> String:
	if scope == "self":
		return self_id
	if scope == "held":
		return frame.held_id
	if scope == "focus":
		return frame.focus_id
	if scope.begins_with("ref:"):
		return str(owner.refs.get(scope.substr(4), ""))
	return ""

# ---------------------------------------------------------------------------
# Value resolution: number | param name | cross-scope state path ("held.fill").
# ---------------------------------------------------------------------------

func _resolve_value(v: Variant, owner: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> float:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return float(v)
		TYPE_STRING:
			var s := v as String
			if s.contains("."):
				# Cross-scope state path: "<scope>.<field>". The scope's field may be
				# a number (state) — but for params like "held.full_threshold" the
				# threshold is a PARAM (full_threshold), so fall back to the param table
				# when the scope has no such state field.
				var parts := s.split(".")
				var scope := parts[0]
				var field := parts[1]
				var rec := _scope_record(scope, owner, self_id, frame)
				if rec.has(field):
					return float(rec[field])
				# Fall back: treat the trailing token as a param name.
				return float(kit.params.get(field, 0.0))
			return float(kit.params.get(s, 0.0))
	return 0.0

# ---------------------------------------------------------------------------
# Prompt projection (§3). Pure function of the live verb set + state. Render-side;
# excluded from the sim hash. Returns the contextual prompt for the interactor.
#
# PROMPT GRAMMAR (pinned, closed):
#   prompt := String | Array[Variant]
#   Variant := { "when"?: Guard, "text": String }   (first matching variant wins)
#   text interpolation: {field} -> state field value; {pct field} -> round(field*100)
#     Fields read from the verb's prompt scope: `held.<field>` reads the held body
#     (place verbs); a bare {field} reads self (command/grab verbs).
# No inline ternary expressions — the design's `{a ? b : c}` shorthand is the
# guarded-variant array instead.
# ---------------------------------------------------------------------------

## The contextual prompt the interactor surfaces this tick, given the resolved
## frame. Mirrors the interactor's held/focus precedence (place target > drop line >
## focus verb). This is what current_prompt() returns.
func project_prompt(frame: ResolvedFrame) -> String:
	if frame.held_id != "":
		if frame.focus_id != "":
			var focus_it: InteractionKit.Interactable = kit.interactables.get(frame.focus_id)
			if focus_it != null:
				var pv := _find_verb(focus_it, frame, "place", "")
				if pv != null:
					return _render_prompt(pv, focus_it, frame.focus_id, frame)
		return "[E] Drop    [F] Throw"
	if frame.focus_id == "":
		return ""
	var it: InteractionKit.Interactable = kit.interactables.get(frame.focus_id)
	if it == null:
		return ""
	# Surface the first available verb's prompt (grab before command — declared
	# order with grab listed first in the kit).
	for v: InteractionKit.Verb in it.verbs:
		if v.kind == "carry_release":
			continue  # only relevant while held
		if _eval_guard(v.when_guard, it, frame.focus_id, frame):
			var text := _render_prompt(v, it, frame.focus_id, frame)
			if text != "":
				return text
	return ""

func _render_prompt(v: InteractionKit.Verb, it: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> String:
	var template := ""
	match typeof(v.prompt):
		TYPE_STRING:
			template = v.prompt
		TYPE_ARRAY:
			for variant: Variant in v.prompt:
				if typeof(variant) != TYPE_DICTIONARY:
					continue
				var w: Variant = variant.get("when", null)
				if w == null or (typeof(w) == TYPE_DICTIONARY and _eval_guard(w, it, self_id, frame)):
					template = str(variant.get("text", ""))
					break
	return _interpolate(template, v, it, self_id, frame)

## Interpolate {field} and {pct field} over the verb's prompt scope. For a place
## verb the natural scope is the held body (held.<field>); for grab/command it is
## self. A token "held.fill" reads the held body explicitly.
func _interpolate(template: String, v: InteractionKit.Verb, it: InteractionKit.Interactable, self_id: String, frame: ResolvedFrame) -> String:
	if not template.contains("{"):
		return template
	var out := template
	var default_scope := "held" if v.kind == "place" else "self"
	# Find {...} tokens and replace. Simple closed grammar: {field}, {pct field},
	# {held.field}, {pct held.field}.
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
		var rec := _scope_record(scope, it, self_id, frame)
		var value: Variant = rec.get(field, 0.0)
		var rendered := ""
		if as_pct:
			rendered = "%d" % int(round(float(value) * 100.0))
		else:
			rendered = str(value)
		out = out.replace(m.get_string(0), rendered)
	return out
