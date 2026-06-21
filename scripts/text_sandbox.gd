extends Control
## Text Sandbox — the first PLAYABLE text-gameplay slice (Mode 3 in the launcher).
##
## A stateful NPC (npc_maren) authored entirely as affordance DATA in
## interaction/sandbox.kit.json is driven HEADLESSLY through InteractionInterpreter
## (the same reference semantics the 3D world uses), via a tiny ScriptedHost shim
## that supplies a per-tick ResolvedFrame with NO scene/physics — exactly the
## driver pattern in tests/interaction_golden_trace_test.gd. The player chooses a
## verb by number; the interpreter fires it; the NpcRealizer renders before/after
## as state-faithful prose into the transcript.
##
## VERB SELECTION IS DATA: each of npc_maren's command verbs guards on
## `state_enum selected == <name>`, so setting `state.selected` to one verb name
## makes exactly that verb's guard pass and the substrate's normal command-fire
## path runs it. The host sets `selected` before step() and clears it after — the
## guard layer does the dispatch, not a host bypass.
##
## IO seam unchanged: everything routes through _submit() / _append_line().
## Standalone-runnable; also instanced as a mode inside scenes/launcher.tscn.

const KIT_PATH := "res://interaction/sandbox.kit.json"
const InterpScript := preload("res://scripts/interaction/interaction_interpreter.gd")
const NpcRealizerScript := preload("res://scripts/text/npc_realizer.gd")

const NPC_ID := "npc_maren"
## One chosen verb = one interaction step. dt=1.0 makes add_fill `rate` read as a
## per-interaction DELTA (rate*dt = rate) rather than a per-frame trickle.
const STEP_DT := 1.0
## Fixed seed: the slice is deterministic; seeded variation replays bit-identically.
const RNG_SEED := 0xA371EA

const PROMPT_PREFIX := "> "

var _transcript: RichTextLabel
var _input: LineEdit

var _kit: InteractionKit
var _interp
var _host
var _rng := RandomNumberGenerator.new()
## The verb names currently offered (index -> name), recomputed each turn so the
## menu shows only verbs whose guard passes (respecting preconditions).
var _menu: Array[String] = []


# ---------------------------------------------------------------------------
# Headless host shim (the golden-trace ScriptedHost pattern). No scene/physics:
# it just hands back the frame we set for the chosen verb and tracks no carry.
# ---------------------------------------------------------------------------

class HeadlessHost:
	extends RefCounted
	var _frame: InterpScript.ResolvedFrame = null

	func set_frame(f: InterpScript.ResolvedFrame) -> void:
		_frame = f

	func host_build_frame() -> InterpScript.ResolvedFrame:
		return _frame

	func host_grab(_id: String) -> bool:
		return false

	func host_release(_mode: String, _impulse: float) -> void:
		pass

	func host_apply_impulse(_magnitude: float) -> void:
		pass

	func host_socket(_owner_id: String, _body_id: String) -> void:
		pass


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = RNG_SEED

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := Label.new()
	header.text = "Text Sandbox — talking to Maren (affordance-data NPC + deterministic realizer)"
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	root.add_child(header)

	_transcript = RichTextLabel.new()
	_transcript.bbcode_enabled = true
	_transcript.scroll_active = true
	_transcript.scroll_following = true
	_transcript.selection_enabled = true
	_transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcript.add_theme_constant_override("margin_left", 6)
	root.add_child(_transcript)

	var input_row := HBoxContainer.new()
	input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(input_row)

	var prompt := Label.new()
	prompt.text = PROMPT_PREFIX
	input_row.add_child(prompt)

	_input = LineEdit.new()
	_input.placeholder_text = "Type the number (or name) of an action and press Enter…"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.clear_button_enabled = true
	_input.text_submitted.connect(_on_text_submitted)
	input_row.add_child(_input)

	_setup_sim()

	_append_line("[i]You're standing with Maren.[/i]", Color(0.6, 0.65, 0.7))
	_append_line(_describe(), Color(0.8, 0.85, 0.9))
	_present_menu()
	_input.grab_focus()


func _setup_sim() -> void:
	_kit = InteractionKit.load_from_file(KIT_PATH)
	if not _kit.is_valid():
		_append_line("[color=#cc6666]kit load error: %s[/color]" % str(_kit.load_errors))
		return
	_host = HeadlessHost.new()
	_interp = InterpScript.new()
	_interp.setup(_kit, _host)
	_interp.add_instance(NPC_ID, NPC_ID)
	_interp.reset_state()


# ---------------------------------------------------------------------------
# Menu: offer only verbs whose guard currently passes. The guard includes the
# `selected == <name>` clause, so to test availability we temporarily set
# `selected` to the candidate name, evaluate, and restore — the host probing the
# live verb set exactly as the prompt projection would.
# ---------------------------------------------------------------------------

func _available_verbs() -> Array[String]:
	var out: Array[String] = []
	var it: InteractionKit.Interactable = _kit.interactables.get(NPC_ID)
	if it == null:
		return out
	var rec: Dictionary = _interp.state.get(NPC_ID, {})
	var saved: Variant = rec.get("selected", "none")
	var frame := _make_frame(false)  # no edge: pure guard probe
	for v: InteractionKit.Verb in it.verbs:
		if v.kind != "command":
			continue
		rec["selected"] = v.name
		if _interp._eval_guard(v.when_guard, it, NPC_ID, frame):
			out.append(v.name)
	rec["selected"] = saved
	return out


func _make_frame(interact_edge: bool) -> InterpScript.ResolvedFrame:
	var f := InterpScript.ResolvedFrame.new()
	f.focus_id = NPC_ID
	f.edges = {"interact": interact_edge}
	return f


func _present_menu() -> void:
	_menu = _available_verbs()
	if _menu.is_empty():
		_append_line("[color=#cc6666]No actions available.[/color]")
		return
	var it: InteractionKit.Interactable = _kit.interactables.get(NPC_ID)
	var lines: Array[String] = []
	for i in _menu.size():
		var prompt_text := _verb_prompt(it, _menu[i])
		lines.append("  [b]%d[/b]) %s" % [i + 1, prompt_text])
	_append_line("[color=#778899]" + "\n".join(lines) + "[/color]")


func _verb_prompt(it: InteractionKit.Interactable, verb_name: String) -> String:
	for v: InteractionKit.Verb in it.verbs:
		if v.name == verb_name and typeof(v.prompt) == TYPE_STRING and v.prompt != "":
			return str(v.prompt)
	return verb_name


# ---------------------------------------------------------------------------
# IO seam.
# ---------------------------------------------------------------------------

func _on_text_submitted(text: String) -> void:
	_submit(text)


func _submit(raw: String) -> void:
	var line := raw.strip_edges()
	_input.clear()
	_input.grab_focus()
	if line.is_empty():
		return
	var chosen := _resolve_choice(line)
	if chosen == "":
		_append_line("[color=#cc8866]Pick one of the listed actions (by number or name).[/color]")
		_present_menu()
		return
	_append_line("[b]> %s[/b]" % chosen, Color(0.85, 0.9, 0.95))
	_fire(chosen)
	_present_menu()


## Resolve a player line to a verb name: a 1-based menu index, or a verb name.
func _resolve_choice(line: String) -> String:
	if line.is_valid_int():
		var idx := line.to_int() - 1
		if idx >= 0 and idx < _menu.size():
			return _menu[idx]
		return ""
	var lower := line.to_lower()
	for name in _menu:
		if name == lower:
			return name
	return ""


# ---------------------------------------------------------------------------
# Fire a chosen verb through the interpreter and render the outcome.
# ---------------------------------------------------------------------------

func _fire(verb_name: String) -> void:
	var rec: Dictionary = _interp.state.get(NPC_ID, {})
	var before := _snapshot(rec)

	rec["selected"] = verb_name              # data-dispatch: arm exactly this verb
	_host.set_frame(_make_frame(true))       # interact edge on the focused NPC
	_interp.step(STEP_DT)
	rec["selected"] = "none"                 # disarm

	var after := _snapshot(_interp.state.get(NPC_ID, {}))
	_append_line(NpcRealizerScript.describe_outcome(before, after, verb_name, _rng), Color(0.9, 0.88, 0.82))
	_append_line(_describe(after), Color(0.78, 0.82, 0.88))


func _describe(state: Dictionary = {}) -> String:
	var s := state if not state.is_empty() else _snapshot(_interp.state.get(NPC_ID, {}))
	return NpcRealizerScript.describe_npc(s, _rng)


func _snapshot(rec: Dictionary) -> Dictionary:
	var copy := {}
	for k in rec:
		copy[k] = rec[k]
	return copy


func _append_line(bbcode: String, color: Color = Color(1, 1, 1)) -> void:
	_transcript.push_color(color)
	_transcript.append_text(bbcode)
	_transcript.pop()
	_transcript.newline()
