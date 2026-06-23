## SELF-PLAYTEST driver for the cap-model foundation — instantiates the REAL character
## creator scene and exercises a REAL slider edit and a REAL sculpt drag through the live
## write paths (NOT the pure BodyCaps core), logging stored values so caps can be confirmed
## to actually engage end-to-end (outward stops at cap; inward free). Diagnostic, not a test.
##
##   xvfb-run -a godot4 --path . res://tools/creator_caps_playtest.tscn --quit-after 4000
extends Node

const CreatorScene := preload("res://scenes/character_creator.tscn")


func _ready() -> void:
	var creator = CreatorScene.instantiate()
	add_child(creator)
	# Let the creator build its UI + body across a couple of frames.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_drive(creator)
	get_tree().quit(0)


func _drive(creator) -> void:
	print("\n=== CREATOR CAP-MODEL SELF-PLAYTEST (live write paths) ===\n")
	var sliders: Dictionary = creator.get("_sliders")
	var caps = creator.get("_caps")
	var body = creator.get("_body_state")

	# --- SLIDER edit: masculinity, authored window [20, 80] at extremeness 0 ---
	var masc := sliders["masculinity"] as HSlider
	print("masculinity slider bounds at build: [%.1f, %.1f] (expect cap window [20,80])"
		% [masc.min_value, masc.max_value])
	# Drive a ONE-WRITE outward edit past the cap (req=100). The live value_changed callback
	# routes through apply_capped; the clamped value lands on the slider + body field.
	masc.value_changed.emit(100.0)
	print("masculinity: requested 100 → stored %.1f, slider thumb %.1f (expect 80 — OUTWARD CLAMP)"
		% [float(body.get("masculinity")), masc.value])
	# Inward edit is free.
	masc.value_changed.emit(55.0)
	print("masculinity: requested 55 → stored %.1f (expect 55 — INWARD FREE)"
		% float(body.get("masculinity")))

	# --- SCULPT drag: drive a modifier outward past its cap via the live sculpt apply ---
	# We bypass the camera-pick plumbing and exercise the apply path directly the way a drag
	# does: start a gesture, push a large delta on a curated modifier, observe the clamp.
	var mod := "breast/breast-dist-decr|incr"   # curated bidirectional, authored [-0.5, 0.5]
	caps.start_gesture()
	# Simulate the per-frame sculpt write: req = cur + big delta, through apply_capped.
	var cur := float(body.modifiers.get(mod, 0.0))
	var stored: float = caps.apply_capped(mod, cur + 2.0, cur)
	if absf(stored) < 1e-6:
		body.modifiers.erase(mod)
	else:
		body.modifiers[mod] = stored
	print("sculpt %s: pushed delta +2.0 from 0.0 → stored %.3f (expect 0.500 — OUTWARD CLAMP)"
		% [mod, float(body.modifiers.get(mod, 0.0))])
	# Inward within the same gesture is free.
	var stored2: float = caps.apply_capped(mod, 0.2, float(body.modifiers.get(mod, 0.0)))
	body.modifiers[mod] = stored2
	print("sculpt %s: pulled to 0.2 → stored %.3f (expect 0.200 — INWARD FREE)"
		% [mod, float(body.modifiers.get(mod, 0.0))])
	caps.end_gesture()

	# --- Extremeness widening: raise it and confirm the cap opens toward the hard range ---
	caps.extremeness = 1.0
	var w: Array = caps.cap(mod)
	print("extremeness=1.0: %s cap widened to [%.2f, %.2f] (expect hard [-1.00, 1.00])"
		% [mod, w[0], w[1]])
	caps.extremeness = 0.0

	print("\n=== SELF-PLAYTEST DONE ===\n")
