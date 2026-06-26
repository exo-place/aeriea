## CxG realizer self-playtest harness. Run headless to READ actual output.
##   xvfb-run -a godot4 --path . res://tools/cxg_playtest.tscn --quit-after 200
## Prints ~10-12 realizations across both voices (incl. an ungrammatical voice-B
## dialogue line), an A/B vs the "emit one top construction" baseline, the
## determinism check, and the gate checks. Not a test suite — a reading harness.
extends Node

const Cxg := preload("res://scripts/text/cxg_realizer.gd")

func _ready() -> void:
	var commit := Cxg.scene_commitments(true)

	print("# COMMITTED SCENE:")
	print("#   Maren notices the player has returned after a long absence;")
	print("#   guarded but glad; it is raining. (She LIES in dialogue: claims indifference.)\n")

	# ~12 realizations, varied seed AND voice. Two contrasting anchor voices lead.
	var runs := [
		[101, "literary_guarded"], [137, "literary_guarded"], [211, "literary_guarded"],
		[167, "intimate_soft"],    [929, "literary_guarded"],
		[202, "slangy_wry"],       [233, "slangy_wry"],        [307, "slangy_wry"],
		[409, "slangy_wry"],       [501, "gruff_guard"],
		[613, "plain_flat"],       [719, "intimate_soft"],
	]
	print("=== FULL COMPOSITION + COHESION ===")
	for i in runs.size():
		var seed: int = runs[i][0]
		var vn: String = runs[i][1]
		var r := Cxg.realize_beat(seed, vn, commit)
		print("--- %2d  (seed=%d, voice=%s) ---" % [i + 1, seed, vn])
		print(r[0])
		print("    cxns: " + " > ".join(r[1]))
	print("")

	# Honest A/B: same content, "just emit the single top construction" baseline.
	print("=== A/B BASELINE: emit one top construction (no seeded variety/cohesion comp) ===")
	for vn in ["literary_guarded", "slangy_wry"]:
		var b := Cxg.realize_baseline_top(vn, commit)
		print("--- baseline (voice=%s) ---" % vn)
		print(b[0])
		print("    cxns: " + " > ".join(b[1]))
	print("")

	# Determinism: same seed+voice twice -> byte-identical.
	var a1 := Cxg.realize_beat(101, "literary_guarded", commit)
	var a2 := Cxg.realize_beat(101, "literary_guarded", commit)
	print("DETERMINISM seed=101 literary_guarded identical: %s" % str(a1[0] == a2[0]))
	var b1 := Cxg.realize_beat(202, "slangy_wry", commit)
	var b2 := Cxg.realize_beat(202, "slangy_wry", commit)
	print("DETERMINISM seed=202 slangy_wry identical: %s" % str(b1[0] == b2[0]))

	# Voice parameterization changes output (same seed, different voice).
	var v1 := Cxg.realize_beat(404, "literary_guarded", commit)
	var v2 := Cxg.realize_beat(404, "slangy_wry", commit)
	print("VOICE param same seed=404 differs: %s" % str(v1[0] != v2[0]))
	print("   literary: %s" % v1[0])
	print("   slangy:   %s" % v2[0])

	# GATE — unlicensed false assertion is unreachable. Sweep many seeds; the
	# poisoned C.threshold_BAD (asserts scene.threshold_crossing, uncommitted) must
	# NEVER appear in any used-id list.
	var threshold_seen := false
	for s in range(0, 4000):
		var r := Cxg.realize_beat(s, "gruff_guard", commit)
		if "C.threshold_BAD" in r[1]:
			threshold_seen = true
			break
	print("GATE poisoned C.threshold_BAD never emitted over 4000 seeds: %s" % str(not threshold_seen))

	# GATE — licensed lie CAN appear when licensed, CANNOT when not licensed.
	var lie_seen_when_licensed := false
	for s in range(0, 4000):
		var r := Cxg.realize_beat(s, "slangy_wry", commit)
		if "S.lie_indifferent" in r[1]:
			lie_seen_when_licensed = true
			break
	var no_lie := Cxg.scene_commitments(false)  # lie NOT licensed
	var lie_seen_when_unlicensed := false
	for s in range(0, 4000):
		var r := Cxg.realize_beat(s, "slangy_wry", no_lie)
		if "S.lie_indifferent" in r[1]:
			lie_seen_when_unlicensed = true
			break
	print("GATE licensed lie S.lie_indifferent reachable WHEN licensed: %s" % str(lie_seen_when_licensed))
	print("GATE licensed lie S.lie_indifferent BLOCKED when NOT licensed: %s" % str(not lie_seen_when_unlicensed))

	get_tree().quit(0)
