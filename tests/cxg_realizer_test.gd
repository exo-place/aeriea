## CxG realizer test — the §8 first-experiment runtime invariants.
##
## Asserts the three disciplines + the bet's gate, NOT prose quality (quality is
## judged by READING, in tools/cxg_playtest — a mechanical test cannot see it):
##   (1) DETERMINISM — same (seed, voice) -> byte-identical output, across repeated
##       calls and a sweep of seeds.
##   (2) GATE — the lexeme-level provenance gate: a poisoned construction that
##       asserts an UNCOMMITTED proposition is UNREACHABLE over a large seed sweep;
##       and the LICENSED-FALSITY frame both (a) CAN emit its lie when the
##       speech-fact is licensed and (b) CANNOT when it is not.
##   (3) VOICE PARAMETERIZATION — the same seed under two contrasting voices yields
##       different output (taste is a moving distribution, not one locked voice).
##   (4) TOTAL ORDERING — output is invariant to constructicon insertion order
##       (a shuffled index gives the same bytes), proving no Dict/Array iteration
##       order leaks into selection.
##
## Run: xvfb-run -a godot4 --path . res://tests/cxg_realizer_test.tscn --quit-after 2000
extends Node

const Cxg := preload("res://scripts/text/cxg_realizer.gd")

var _pass := 0
var _fail := 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok   - %s" % label)
	else:
		_fail += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var commit := Cxg.scene_commitments(true)

	# (1) DETERMINISM — repeated calls identical, across several (seed, voice).
	for pair in [[101, "literary_guarded"], [202, "slangy_wry"], [404, "plain_flat"], [7, "gruff_guard"]]:
		var seed: int = pair[0]
		var vn: String = pair[1]
		var a: Array = Cxg.realize_beat(seed, vn, commit)
		var b: Array = Cxg.realize_beat(seed, vn, commit)
		_ok(a[0] == b[0], "determinism: seed=%d voice=%s byte-identical on repeat" % [seed, vn])

	# determinism across a sweep (no nondeterministic drift over many seeds)
	var sweep_ok := true
	for s in range(0, 500):
		var r1: Array = Cxg.realize_beat(s, "literary_guarded", commit)
		var r2: Array = Cxg.realize_beat(s, "literary_guarded", commit)
		if r1[0] != r2[0]:
			sweep_ok = false
			break
	_ok(sweep_ok, "determinism: 500-seed sweep all byte-identical on repeat")

	# (2) GATE — poisoned construction (asserts uncommitted scene.threshold_crossing)
	# is UNREACHABLE over a large sweep across all voices.
	var threshold_seen := false
	for vn in Cxg._voices().keys():
		for s in range(0, 1200):
			var r: Array = Cxg.realize_beat(s, vn, commit)
			if "C.threshold_BAD" in r[1]:
				threshold_seen = true
				break
		if threshold_seen:
			break
	_ok(not threshold_seen, "gate: unlicensed false assertion (C.threshold_BAD) NEVER emitted")

	# Sanity: the poisoned construction WOULD be reachable if its asserted prop were
	# committed — proving the gate (not absence-from-inventory) is what blocks it.
	var poisoned_commit := Cxg.scene_commitments(true)
	poisoned_commit.commit("scene.threshold_crossing")
	var threshold_now := false
	for s in range(0, 4000):
		var r: Array = Cxg.realize_beat(s, "gruff_guard", poisoned_commit)
		if "C.threshold_BAD" in r[1]:
			threshold_now = true
			break
	_ok(threshold_now, "gate: C.threshold_BAD BECOMES reachable once its prop is committed (gate is the cause)")

	# (2b) LICENSED-FALSITY — the lie CAN emit when licensed.
	var lie_when_licensed := false
	for s in range(0, 4000):
		var r: Array = Cxg.realize_beat(s, "slangy_wry", commit)
		if "S.lie_indifferent" in r[1]:
			lie_when_licensed = true
			break
	_ok(lie_when_licensed, "gate: licensed lie (S.lie_indifferent) CAN be emitted when speech-fact licensed")

	# ...and CANNOT when not licensed.
	var no_lie_commit := Cxg.scene_commitments(false)
	var lie_when_unlicensed := false
	for vn in Cxg._voices().keys():
		for s in range(0, 1200):
			var r: Array = Cxg.realize_beat(s, vn, no_lie_commit)
			if "S.lie_indifferent" in r[1]:
				lie_when_unlicensed = true
				break
		if lie_when_unlicensed:
			break
	_ok(not lie_when_unlicensed, "gate: licensed lie BLOCKED when speech-fact not licensed")

	# the false proposition the lie asserts (speech.claims_indifferent) must NEVER
	# surface through NARRATION (only the SPEECH cxn may carry it). No narration cxn
	# asserts it, so this is structural — assert no narration path can.
	_ok(not commit.narratable("speech.claims_indifferent"), "gate: lie's content is NOT narratable (narration cannot assert it)")

	# (3) VOICE PARAMETERIZATION — same seed, two contrasting voices, differing output.
	var diff_count := 0
	for s in range(0, 50):
		var lit: Array = Cxg.realize_beat(s, "literary_guarded", commit)
		var sla: Array = Cxg.realize_beat(s, "slangy_wry", commit)
		if lit[0] != sla[0]:
			diff_count += 1
	_ok(diff_count >= 40, "voice: literary vs slangy differ on >=40/50 seeds (got %d)" % diff_count)

	# (4) TOTAL ORDERING — output invariant to insertion order. Re-realize with a
	# reversed-then-reindexed constructicon: same bytes (no iteration-order leak).
	# We exercise this by checking that build_index produces stable output under a
	# manual re-sort of every per-sem list into reverse-id order before realizing.
	var order_stable := true
	for s in range(0, 200):
		var normal: Array = Cxg.realize_beat(s, "literary_guarded", commit)
		var shuffled: String = _realize_with_reversed_index(s, "literary_guarded", commit)
		if normal[0] != shuffled:
			order_stable = false
			break
	_ok(order_stable, "total-order: output invariant to per-sem list order (no Dict/Array order leak)")

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


## Realize with every per-sem candidate list REVERSED before selection. Because the
## realizer total-orders candidates by id before any draw, reversing the stored list
## must not change the output — this is the cross-platform iteration-order guard.
func _realize_with_reversed_index(seed: int, voice_name: String, commit) -> String:
	var by_sem: Dictionary = Cxg.build_index()
	for sem in by_sem.keys():
		(by_sem[sem] as Array).reverse()
	var rng := Cxg.Rng.new(seed)
	var voice: Dictionary = Cxg._voices().get(voice_name, Cxg._voices()["plain_flat"])
	var r: Array = Cxg.realize("BEAT_NOTICE", rng, voice, commit, by_sem)
	return r[0]
