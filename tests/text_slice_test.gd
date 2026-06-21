## Text-slice test — the first playable text-gameplay slice
## (npc_maren affordance data + NpcRealizer + headless interpreter drive).
##
## Asserts:
##   (a) describe_npc is a STABLE PURE FUNCTION of state (same state -> same string,
##       across repeated calls and fresh instances);
##   (b) a FIXED verb sequence fired through the interpreter (the same headless
##       ScriptedHost / data-dispatch path the text sandbox uses) produces a STABLE,
##       NON-VACUOUS transcript (the relationship actually moves; replay is identical);
##   (c) FAITHFULNESS sanity — a high-mood/high-rapport state never renders hostile
##       phrasing, and a low-mood state never renders warm/lit-up phrasing.
##
## Run (windowed under xvfb per the substrate spec):
##   nix develop --command bash -lc \
##     'xvfb-run -a godot4 --path . res://tests/text_slice_test.tscn --quit-after 2000'
## Exits 0 iff all pass; else 1.
extends Node

const KIT_PATH := "res://interaction/sandbox.kit.json"
const InterpScript := preload("res://scripts/interaction/interaction_interpreter.gd")
const NpcRealizerScript := preload("res://scripts/text/npc_realizer.gd")

const NPC_ID := "npc_maren"
const STEP_DT := 1.0

var _pass := 0
var _fail := 0


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
	print("\n=== aeriea text-slice test ===\n")
	_test_describe_pure()
	_test_fixed_sequence_stable()
	_test_faithfulness_bands()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# ---------------------------------------------------------------------------
# (a) describe_npc is a stable pure function of state.
# ---------------------------------------------------------------------------

func _test_describe_pure() -> void:
	var states := [
		{"mood": 0.9, "rapport": 0.85, "last_social_act": "complimented", "times_complimented": 5.0},
		{"mood": 0.5, "rapport": 0.3, "last_social_act": "none", "times_complimented": 0.0},
		{"mood": 0.15, "rapport": 0.1, "last_social_act": "pushed_away", "times_complimented": 0.0},
		{"mood": 0.7, "rapport": 0.6, "last_social_act": "teased", "times_complimented": 3.0},
	]
	for s: Dictionary in states:
		var a := NpcRealizerScript.describe_npc(s)
		var b := NpcRealizerScript.describe_npc(s)
		var c := NpcRealizerScript.describe_npc(s.duplicate())
		_assert("describe_npc pure (repeat) for %s" % _key(s), a == b, a)
		_assert("describe_npc pure (fresh dict) for %s" % _key(s), a == c, a)
		_assert("describe_npc non-empty for %s" % _key(s), a.strip_edges() != "", a)

	# Distinct combinations must read DIFFERENTLY (not a constant / mad-libs).
	var distinct := {}
	for s: Dictionary in states:
		distinct[NpcRealizerScript.describe_npc(s)] = true
	_assert("describe_npc varies with state (not constant)", distinct.size() == states.size(),
		"%d distinct of %d states" % [distinct.size(), states.size()])


# ---------------------------------------------------------------------------
# (b) Fixed verb sequence -> stable, non-vacuous transcript via the interpreter.
# ---------------------------------------------------------------------------

func _run_sequence(verbs: Array) -> Dictionary:
	var kit := InteractionKit.load_from_file(KIT_PATH)
	if not kit.is_valid():
		push_error("text-slice: invalid kit: %s" % str(kit.load_errors))
	var host := HeadlessHost.new()
	var interp = InterpScript.new()
	interp.setup(kit, host)
	interp.add_instance(NPC_ID, NPC_ID)
	interp.reset_state()

	var lines: Array[String] = []
	for verb: String in verbs:
		var rec: Dictionary = interp.state[NPC_ID]
		var before := rec.duplicate()
		rec["selected"] = verb
		var f := InterpScript.ResolvedFrame.new()
		f.focus_id = NPC_ID
		f.edges = {"interact": true}
		host.set_frame(f)
		interp.step(STEP_DT)
		rec["selected"] = "none"
		var after: Dictionary = interp.state[NPC_ID].duplicate()
		lines.append(NpcRealizerScript.describe_outcome(before, after, verb))
		lines.append(NpcRealizerScript.describe_npc(after))
	return {"transcript": "\n".join(lines), "final": (interp.state[NPC_ID] as Dictionary).duplicate()}


func _test_fixed_sequence_stable() -> void:
	# greet warms her past the compliment gate; compliment x2 builds rapport past
	# the tease gate; tease (now allowed) and offer_gift exercise the branches.
	var seq := ["greet", "compliment", "compliment", "compliment", "tease", "offer_gift"]
	var a := _run_sequence(seq)
	var b := _run_sequence(seq)
	_assert("fixed sequence transcript is stable (replay identical)",
		a["transcript"] == b["transcript"], "len=%d" % a["transcript"].length())

	# Non-vacuous: the relationship actually moved from its init (mood .5, rapport .3).
	var final: Dictionary = a["final"]
	_assert("sequence is non-vacuous: mood rose above init",
		float(final.get("mood", 0.0)) > 0.5, "mood=%s" % str(final.get("mood")))
	_assert("sequence is non-vacuous: rapport rose above init",
		float(final.get("rapport", 0.0)) > 0.3, "rapport=%s" % str(final.get("rapport")))
	_assert("sequence remembers compliments",
		int(round(float(final.get("times_complimented", 0.0)))) == 3,
		"times_complimented=%s" % str(final.get("times_complimented")))

	# A specific verb reads DIFFERENTLY as state changes: compliment at low vs high
	# rapport must not produce identical outcome prose (state-driven, not canned).
	var low := _outcome_of_first_compliment_fresh()
	var high := _outcome_of_compliment_after_buildup()
	_assert("same verb (compliment) reads differently as relationship grows",
		low != high, "low=[%s] high=[%s]" % [low, high])


func _outcome_of_first_compliment_fresh() -> String:
	var r := _run_sequence(["greet", "compliment"])
	# Re-derive just the first compliment outcome deterministically.
	var kit := InteractionKit.load_from_file(KIT_PATH)
	var host := HeadlessHost.new()
	var interp = InterpScript.new()
	interp.setup(kit, host)
	interp.add_instance(NPC_ID, NPC_ID)
	interp.reset_state()
	_step(interp, host, "greet")
	return _step(interp, host, "compliment")


func _outcome_of_compliment_after_buildup() -> String:
	var kit := InteractionKit.load_from_file(KIT_PATH)
	var host := HeadlessHost.new()
	var interp = InterpScript.new()
	interp.setup(kit, host)
	interp.add_instance(NPC_ID, NPC_ID)
	interp.reset_state()
	for v in ["greet", "compliment", "compliment", "offer_gift", "offer_gift"]:
		_step(interp, host, v)
	return _step(interp, host, "compliment")


## Fire one verb, return the rendered outcome string.
func _step(interp, host, verb: String) -> String:
	var rec: Dictionary = interp.state[NPC_ID]
	var before := rec.duplicate()
	rec["selected"] = verb
	var f := InterpScript.ResolvedFrame.new()
	f.focus_id = NPC_ID
	f.edges = {"interact": true}
	host.set_frame(f)
	interp.step(STEP_DT)
	rec["selected"] = "none"
	return NpcRealizerScript.describe_outcome(before, rec.duplicate(), verb)


# ---------------------------------------------------------------------------
# (c) Faithfulness sanity — phrasing bands never contradict the state.
# ---------------------------------------------------------------------------

const HOSTILE := ["upset", "wary", "closed off", "stiffen", "flinch", "stings", "hurt", "put off", "draining"]
const WARM := ["lit up", "warmth", "melts", "trusts", "old friend", "pleased", "make her day"]

func _test_faithfulness_bands() -> void:
	var happy := {"mood": 0.95, "rapport": 0.9, "last_social_act": "complimented", "times_complimented": 6.0}
	var happy_text := NpcRealizerScript.describe_npc(happy).to_lower()
	var hostile_hit := ""
	for w: String in HOSTILE:
		if happy_text.contains(w):
			hostile_hit = w
	_assert("high mood/rapport never reads hostile", hostile_hit == "",
		"text=[%s] hit=[%s]" % [happy_text, hostile_hit])

	var sour := {"mood": 0.1, "rapport": 0.1, "last_social_act": "pushed_away", "times_complimented": 0.0}
	var sour_text := NpcRealizerScript.describe_npc(sour).to_lower()
	var warm_hit := ""
	for w: String in WARM:
		if sour_text.contains(w):
			warm_hit = w
	_assert("low mood/rapport never reads warm", warm_hit == "",
		"text=[%s] hit=[%s]" % [sour_text, warm_hit])

	# A cooling outcome (push_away) from a warm state must read as a setback, and a
	# warming outcome (offer_gift) must never read as cooling.
	var warm_before := {"mood": 0.8, "rapport": 0.7}
	var pushed := {"mood": 0.65, "rapport": 0.58}
	var push_text := NpcRealizerScript.describe_outcome(warm_before, pushed, "push_away").to_lower()
	var push_ok := push_text.contains("flinch") or push_text.contains("sting") or push_text.contains("stiffen") or push_text.contains("tighten")
	_assert("a real mood drop reads as a setback", push_ok, push_text)

	var gift_after := {"mood": 0.95, "rapport": 0.85}
	var gift_text := NpcRealizerScript.describe_outcome(warm_before, gift_after, "offer_gift").to_lower()
	var gift_bad := gift_text.contains("flinch") or gift_text.contains("sting") or gift_text.contains("stiffen")
	_assert("a warming outcome never reads hostile", not gift_bad, gift_text)


# ---------------------------------------------------------------------------

func _key(s: Dictionary) -> String:
	return "m=%s r=%s" % [str(s.get("mood")), str(s.get("rapport"))]


func _assert(test_name: String, condition: bool, evidence: String) -> void:
	if condition:
		_pass += 1
		print("  PASS  %s  [%s]" % [test_name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [test_name, evidence])
