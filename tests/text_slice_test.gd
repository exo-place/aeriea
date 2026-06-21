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
	_test_show_dont_tell()
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
# (c) Faithfulness sanity — behavioural tells never contradict the state.
# A high-mood/high-rapport read must never show CLOSED/GUARDED/COLD body language,
# and a low-mood/low-rapport read must never show OPEN/EASY/UNGUARDED body language.
# (Behavioural vocabulary, not named feelings — see the show-don't-tell test below.)
# ---------------------------------------------------------------------------

# Cold/guarded BEHAVIOURS that must never appear on a warm, close read.
const COLD_TELLS := [
	"out of reach", "squared", "arms are folded", "back foot", "sidelong",
	"thin line", "won't meet", "goes still", "flattening", "looks down at her hands",
	"middle distance", "room between you", "drawn back", "arm's length",
]
# Open/easy BEHAVIOURS that must never appear on a sour, distant read.
const OPEN_TELLS := [
	"eyes bright", "holding yours", "leans in", "loosens", "grin", "shoulders loose",
	"breaking before she can", "closing the last of the gap", "ducks her head, but",
	"leans into your side",
]

func _test_faithfulness_bands() -> void:
	var happy := {"mood": 0.95, "rapport": 0.9, "last_social_act": "complimented", "times_complimented": 6.0}
	var happy_text := NpcRealizerScript.describe_npc(happy).to_lower()
	var cold_hit := ""
	for w: String in COLD_TELLS:
		if happy_text.contains(w):
			cold_hit = w
	_assert("high mood/rapport never shows cold/guarded body language", cold_hit == "",
		"text=[%s] hit=[%s]" % [happy_text, cold_hit])

	var sour := {"mood": 0.1, "rapport": 0.1, "last_social_act": "pushed_away", "times_complimented": 0.0}
	var sour_text := NpcRealizerScript.describe_npc(sour).to_lower()
	var open_hit := ""
	for w: String in OPEN_TELLS:
		if sour_text.contains(w):
			open_hit = w
	_assert("low mood/rapport never shows open/easy body language", open_hit == "",
		"text=[%s] hit=[%s]" % [sour_text, open_hit])

	# A cooling outcome (push_away) from a warm state must read as a physical setback
	# (rocking back / going still / face shutting), and a warming outcome (offer_gift)
	# must never read as a flinch.
	var warm_before := {"mood": 0.8, "rapport": 0.7}
	var pushed := {"mood": 0.65, "rapport": 0.58}
	var push_text := NpcRealizerScript.describe_outcome(warm_before, pushed, "push_away").to_lower()
	var push_ok := push_text.contains("rocks back") or push_text.contains("goes still") \
		or push_text.contains("squares") or push_text.contains("stalls") or push_text.contains("goes out of her face")
	_assert("a real mood drop reads as a physical setback", push_ok, push_text)

	var gift_after := {"mood": 0.95, "rapport": 0.85}
	var gift_text := NpcRealizerScript.describe_outcome(warm_before, gift_after, "offer_gift").to_lower()
	var gift_bad := gift_text.contains("rocks back") or gift_text.contains("goes still") \
		or gift_text.contains("squares") or gift_text.contains("goes out of her face")
	_assert("a warming outcome never reads as a setback", not gift_bad, gift_text)


# ---------------------------------------------------------------------------
# (d) SHOW, DON'T TELL — the realizer must render state through observable
# behaviour and never NAME the feeling/meter or print field names/numbers.
# ---------------------------------------------------------------------------

# Abstractions that LABEL the interior state or the meters directly. The realizer
# removed all of these in favour of behaviour; their reappearance is a regression
# toward telling. Word-boundary matched so we don't false-positive on substrings
# (e.g. "content" inside "contentment" is still telling, but "warm" must not flag
# inside an honest phrase — see the curated list / boundary check below).
const BANNED_ABSTRACTIONS := [
	"mood", "rapport", "trust", "trusts", "content", "happy", "guard down",
	"warms to it", "her feelings", "relationship", "affection", "fond",
	"pleased", "upset", "comfortable", "at ease",
]
# State field names that must never leak into prose.
const FIELD_NAMES := ["last_social_act", "times_complimented", "selected"]

func _contains_word(haystack: String, word: String) -> bool:
	# Multi-word phrases: plain substring is fine. Single words: require boundaries
	# so "warm" doesn't trip on "warmth" of a cooling line etc. — but every entry
	# in BANNED_ABSTRACTIONS that is a single token is itself a banned token, so a
	# boundaried match is exactly what we want.
	if word.contains(" "):
		return haystack.contains(word)
	var idx := haystack.find(word)
	while idx != -1:
		var before_ok := idx == 0 or not _is_word_char(haystack[idx - 1])
		var after_i := idx + word.length()
		var after_ok := after_i >= haystack.length() or not _is_word_char(haystack[after_i])
		if before_ok and after_ok:
			return true
		idx = haystack.find(word, idx + 1)
	return false

func _is_word_char(c: String) -> bool:
	return c.length() == 1 and (c.to_lower() != c.to_upper() or c >= "0" and c <= "9")

func _scan_banned(text: String) -> String:
	var lower := text.to_lower()
	for w: String in BANNED_ABSTRACTIONS:
		if _contains_word(lower, w):
			return w
	for f: String in FIELD_NAMES:
		if lower.contains(f):
			return f
	# No bare numbers (a leaked meter value like "0.7" or "rapport 70").
	for i in text.length():
		if text[i] >= "0" and text[i] <= "9":
			return "digit:" + text[i]
	return ""

func _test_show_dont_tell() -> void:
	# A spread of states covering every band and combination, plus the live sequence.
	var states := [
		{"mood": 0.95, "rapport": 0.9, "last_social_act": "complimented", "times_complimented": 6.0},
		{"mood": 0.5, "rapport": 0.3, "last_social_act": "none", "times_complimented": 0.0},
		{"mood": 0.15, "rapport": 0.1, "last_social_act": "pushed_away", "times_complimented": 0.0},
		{"mood": 0.7, "rapport": 0.6, "last_social_act": "teased", "times_complimented": 3.0},
		{"mood": 0.4, "rapport": 0.5, "last_social_act": "greeted", "times_complimented": 2.0},
		{"mood": 0.85, "rapport": 0.5, "last_social_act": "given_gift", "times_complimented": 4.0},
		{"mood": 0.25, "rapport": 0.75, "last_social_act": "pushed_away", "times_complimented": 5.0},
	]
	for s: Dictionary in states:
		var t := NpcRealizerScript.describe_npc(s)
		var hit := _scan_banned(t)
		_assert("describe_npc SHOWS (no named feeling/field/number) for %s" % _key(s),
			hit == "", "hit=[%s] text=[%s]" % [hit, t])

	# describe_outcome across the verb set, at low and high rapport, also clean.
	var verbs := ["greet", "compliment", "tease", "push_away", "offer_gift"]
	var before_lo := {"mood": 0.5, "rapport": 0.25, "times_complimented": 0.0}
	var after_lo := {"mood": 0.62, "rapport": 0.35, "times_complimented": 1.0}
	var before_hi := {"mood": 0.8, "rapport": 0.72, "times_complimented": 3.0}
	var after_hi := {"mood": 0.92, "rapport": 0.82, "times_complimented": 4.0}
	var after_cool := {"mood": 0.62, "rapport": 0.6, "times_complimented": 3.0}
	for v: String in verbs:
		for pair in [[before_lo, after_lo], [before_hi, after_hi], [before_hi, after_cool]]:
			var ot := NpcRealizerScript.describe_outcome(pair[0], pair[1], v)
			var hit := _scan_banned(ot)
			_assert("describe_outcome SHOWS (no named feeling/field/number) verb=%s" % v,
				hit == "", "hit=[%s] text=[%s]" % [hit, ot])


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
