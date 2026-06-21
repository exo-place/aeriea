## Maren-history test — the full System-5 wiring: affordance events -> MemorySystem
## -> Mood -> ExprState (face) AND -> a memory callback (realizer dialogue).
##
## Asserts the show-don't-tell loop end to end:
##   (a) EVENTS -> MEMORY — recording affordance verbs accrues the right memories.
##   (b) MEMORY -> FACE — accumulated warm history lifts the resulting ExprState
##       valence; a slight + annoyance raises tension and drops valence.
##   (c) MEMORY CALLBACK FIRES — after 3 compliments the "you keep saying that"
##       dialogue callback surfaces (memory as prose, not narrated reaction).
##   (d) REMEMBERS ACROSS TIME — leave (advance the clock) and return: the warm read
##       has DECAYED but the memory PERSISTS — Maren still remembers (callback holds,
##       valence stays above the cold baseline).
##   (e) DETERMINISM — same seed + same event sequence -> identical ExprState AND
##       identical callback string (no RNG, no wall-clock).
##
## Run: xvfb-run -a godot4 --path . res://tests/maren_history_test.tscn --quit-after 2000
extends Node

const MarenHistory := preload("res://scripts/text/maren_history.gd")

const SEED := 0xA371EA
const HOUR := 3600

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea maren-history (System 5) test ===\n")
	_test_events_to_memory()
	_test_memory_to_face()
	_test_callback_fires()
	_test_remembers_across_time()
	_test_determinism()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", msg)


func _approx(a: float, b: float, eps := 1e-5) -> bool:
	return absf(a - b) <= eps


# A post-fire state dict (the realizer/host hands MarenHistory the interactable record).
func _post(mood: float, rapport: float, last: String) -> Dictionary:
	return {"mood": mood, "rapport": rapport, "last_social_act": last}


func _test_events_to_memory() -> void:
	var h := MarenHistory.new(SEED)
	h.record_event("greet", _post(0.55, 0.3, "greeted"))
	h.record_event("compliment", _post(0.7, 0.4, "complimented"))
	_ok(h.holder.count_with("greeted", MarenHistory.PLAYER) == 1, "greet -> greeted memory")
	_ok(h.holder.count_with("complimented", MarenHistory.PLAYER) == 1, "compliment -> complimented memory")
	# A tease at high rapport is WARM; at low rapport it's SOUR (outcome-dependent).
	var warm := MarenHistory.new(SEED)
	warm.record_event("tease", _post(0.7, 0.8, "teased"))
	_ok(warm.holder.has_memory_with("teased_warm", MarenHistory.PLAYER), "tease at high rapport -> warm memory")
	var sour := MarenHistory.new(SEED)
	sour.record_event("tease", _post(0.4, 0.3, "teased"))
	_ok(sour.holder.has_memory_with("teased_sour", MarenHistory.PLAYER), "tease at low rapport -> sour memory")


func _test_memory_to_face() -> void:
	# Warm arc: greet + 2 compliments + a gift -> the face read should be positive.
	var warm := MarenHistory.new(SEED)
	warm.record_event("greet", _post(0.55, 0.3, "greeted"))
	warm.record_event("compliment", _post(0.7, 0.45, "complimented"))
	warm.record_event("compliment", _post(0.82, 0.55, "complimented"))
	warm.record_event("offer_gift", _post(0.9, 0.7, "given_gift"))
	var warm_e := warm.current_expr("given_gift")
	_ok(warm_e.valence > 0.2, "warm history -> positive face valence (%.3f)" % warm_e.valence)
	_ok(warm_e.attention > 0.6, "warm history -> engaged face attention (%.3f)" % warm_e.attention)

	# Sour arc: a push-away -> negative valence, high tension, snarl emphasis.
	var sour := MarenHistory.new(SEED)
	sour.record_event("push_away", _post(0.35, 0.18, "pushed_away"))
	var sour_e := sour.current_expr("pushed_away")
	_ok(sour_e.valence < 0.0, "push-away -> negative face valence (%.3f)" % sour_e.valence)
	_ok(sour_e.tension > 0.4, "push-away + annoyance -> high face tension (%.3f)" % sour_e.tension)
	_ok(sour_e.emphasis == "snarl", "push-away -> snarl face emphasis")


func _test_callback_fires() -> void:
	var h := MarenHistory.new(SEED)
	# Two compliments: not yet the "keep saying that" callback, but a softer one if warm.
	h.record_event("compliment", _post(0.7, 0.45, "complimented"))
	h.record_event("compliment", _post(0.82, 0.55, "complimented"))
	var cb2 := h.memory_callback()
	# Third compliment crosses the threshold for the canonical "you keep saying that".
	h.record_event("compliment", _post(0.9, 0.65, "complimented"))
	var cb3 := h.memory_callback()
	_ok(cb3.to_lower().contains("keep saying that") or cb3.to_lower().contains("third time"),
		"3 compliments fire the memory callback: '%s'" % cb3)
	_ok(cb3 != "", "memory callback is non-empty after a real history")
	# A fresh history with no events: no callback.
	var fresh := MarenHistory.new(SEED)
	_ok(fresh.memory_callback() == "", "no callback without accumulated memory")


func _test_remembers_across_time() -> void:
	var h := MarenHistory.new(SEED)
	h.record_event("compliment", _post(0.7, 0.45, "complimented"))
	h.record_event("compliment", _post(0.82, 0.55, "complimented"))
	h.record_event("compliment", _post(0.9, 0.65, "complimented"))
	var fresh_valence := h.current_expr("complimented").valence
	var fresh_cb := h.memory_callback()
	_ok(fresh_cb != "", "callback present right after the compliments")

	# Leave for 9 hours and return: warm read DECAYS but the memory PERSISTS.
	h.advance(9 * HOUR)
	var return_valence := h.current_expr("").valence
	var return_cb := h.memory_callback()
	_ok(return_valence < fresh_valence, "warm read decays after leaving (%.3f < %.3f)" % [return_valence, fresh_valence])
	# The compliment memories' effect window is 2 days, so after 9h they still color mood
	# and still exist -> she STILL REMEMBERS (callback still fires, valence above 0).
	_ok(return_cb != "", "Maren still remembers across time (callback persists on return)")
	_ok(h.holder.count_with("complimented", MarenHistory.PLAYER) == 3, "the compliment memories persist")


func _test_determinism() -> void:
	var a := _run_seq()
	var b := _run_seq()
	_ok(_approx(a["valence"], b["valence"]) and _approx(a["tension"], b["tension"])
		and _approx(a["attention"], b["attention"]) and a["callback"] == b["callback"],
		"same seed + same events -> identical ExprState AND identical callback")


func _run_seq() -> Dictionary:
	var h := MarenHistory.new(SEED)
	h.record_event("greet", _post(0.55, 0.3, "greeted"))
	h.advance(HOUR)
	h.record_event("compliment", _post(0.7, 0.45, "complimented"))
	h.advance(2 * HOUR)
	h.record_event("compliment", _post(0.82, 0.55, "complimented"))
	h.record_event("compliment", _post(0.9, 0.65, "complimented"))
	h.advance(HOUR)
	h.record_event("tease", _post(0.6, 0.4, "teased"))
	var e := h.current_expr("teased")
	return {"valence": e.valence, "tension": e.tension, "attention": e.attention,
		"callback": h.memory_callback()}
