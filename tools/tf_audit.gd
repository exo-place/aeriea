## tf_audit — a scrollable "TF audit" sandbox for aeriea's transformation library.
##
## The point: give the user a large, varied, AUDITABLE set of concrete transformations so
## they can judge whether the model narrates a transformation well — as a PROCESS OVER
## TIME, not a static end-body. For EVERY TF in the library (tf_library.gd) this applies it
## to a single standard BASE body and shows, in one card:
##   - a clean human name and a one-line plain description of what it does;
##   - the PROCESS NARRATIVE (tf_describe.describe_transition): the ordered sequence of
##     changes — what grew in, shrank away, changed material / covering / size / shape —
##     as the primary content, read as the transformation HAPPENING;
##   - a small "ends as" form footer for context (the static end-form, one line).
## A final "Over time (staged)" section walks a few STAGED TFs stage by stage as the sim
## clock advances (describe_progression), so the card reads the change unfolding frame by
## frame. The whole set scrolls in one column, grouped by category.
##
## This is a read-only auditing surface: it drives the existing engine and never modifies
## it. Run (headless render):
##   xvfb-run -a godot4 --path . res://tools/tf_audit.tscn
##   With TF_AUDIT_SHOT=<dir> set, it pages through the whole list writing PNGs, then quits.
extends Control

const TfHolder := preload("res://scripts/body/tf/tf_holder.gd")
const TfContent := preload("res://scripts/body/tf/tf_content.gd")
const TfLibrary := preload("res://scripts/body/tf/tf_library.gd")
const TfDescribe := preload("res://scripts/body/tf/tf_describe.gd")
const TfApplier := preload("res://scripts/body/tf/tf_applier.gd")
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")

const BASE_SEED := 0xA0D17   # fixed seed so the audit is fully deterministic

var _registry: Dictionary
var _scroll: ScrollContainer
var _column: VBoxContainer


func _ready() -> void:
	_registry = TfLibrary.registry()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_populate()
	if OS.get_environment("TF_AUDIT_SHOT") != "":
		_run_self_playtest.call_deferred()


# ===================================================================== UI construction

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8)
	outer.offset_left = 16
	outer.offset_top = 14
	outer.offset_right = -16
	outer.offset_bottom = -14
	add_child(outer)

	var title := Label.new()
	title.text = "Transformation audit"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	outer.add_child(title)

	var sub := Label.new()
	sub.text = "Each card narrates the transformation as it happens — the change over time, not the end-body. Scroll to read each."
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
	outer.add_child(sub)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 12)
	_scroll.add_child(_column)


# ===================================================================== content

# The audit body: a process narrative per TF (the transformation over time), grouped by
# category, with a small "ends as" form footer for context.
func _populate() -> void:
	_column.add_child(_category_header("Base body (every card starts here)"))
	_column.add_child(_base_card())

	for entry in TfLibrary.categories():
		var cat_name: String = entry[0]
		var ids: Array = entry[1]
		_column.add_child(_category_header(cat_name))
		for tf_id in ids:
			_column.add_child(_build_card(tf_id))

	# Staged transformations: the same diff narration walked stage by stage as the sim
	# clock advances, so the card reads the change UNFOLDING over time. These demo content
	# lives in tf_content; the creep ones need a non-biped base, so each names its start.
	_column.add_child(_category_header("Over time (staged progression)"))
	for demo in STAGED_DEMOS:
		_column.add_child(_build_staged_card(demo))


func _fresh_body() -> Dictionary:
	return TfContent.biped()


# Apply one TF to a fresh base, returning the process narrative + an "ends as" footer.
func _apply_one(tf_id: String) -> Dictionary:
	var tf: Dictionary = _registry[tf_id]
	var base := _fresh_body()
	var holder := TfHolder.new(_fresh_body(), BASE_SEED, _registry)
	if bool(tf.get("staged", false)):
		holder.start_tf(tf_id)
		var step: int = int(tf.get("stage_seconds", 600))
		var stages: int = int(tf.get("max_stages", 1))
		for i in stages:
			holder.advance_time(step)
	else:
		holder.apply_instant(tf_id)
	var process: Array = TfDescribe.describe_transition(base, holder.body)
	var changed := not process.is_empty()
	return {
		"process": process,
		"ends_as": TfDescribe.form_line(holder.body),
		"changed": changed,
		"note": _precondition_note(tf) if not changed else "",
	}


# When a TF no-ops on the plain base, say so plainly so the card is still honest. Only
# cite a missing part when the gate ACTUALLY fails on the base (otherwise the gate passes
# and the no-op is because nothing visibly changes — e.g. draining milk that isn't there).
func _precondition_note(tf: Dictionary) -> String:
	var gate = tf.get("gate", null)
	if typeof(gate) == TYPE_DICTIONARY and not TfApplier.eval_predicate(gate, _fresh_body()):
		var needs := _gate_need(gate)
		if needs != "":
			return "No change here: the base body has no %s to act on." % needs
	return "No change here: this leaves the base body as it already is."


func _gate_need(gate: Dictionary) -> String:
	if gate.get("op", "") == "has_tag":
		return _word(str(gate.get("tag", "")))
	return ""


func _build_card(tf_id: String) -> Control:
	var tf: Dictionary = _registry[tf_id]
	var res := _apply_one(tf_id)
	return _card(str(tf.get("name", tf_id)), str(tf.get("blurb", "")),
		res["process"], str(res["ends_as"]), str(res.get("note", "")))


# The reference base card: no transformation, just the static form it starts from.
func _base_card() -> Control:
	var base := _fresh_body()
	return _card("Base body", "The unmodified starting body — every card transforms this.",
		["(no transformation — this is the starting point)"], TfDescribe.form_line(base), "")


# ===================================================================== staged demos
# Curated staged TFs (from tf_content) that show a transformation unfolding over time.
# Each names the base body it needs: a creep up the lower body needs a taur to creep over;
# a tail-grow needs a tail to grow. (id, base, display name, blurb).
const STAGED_DEMOS := [
	["graft_quadruped_lower_staged", "biped", "Become a taur, gradually",
		"The lower body grafts on, then grows in over several beats."],
	["set_covering_fur_upward", "taur", "Fur creeps up the body",
		"Fur advances one part per beat, lowest first."],
	["set_lower_material_chitin", "taur", "Chitin spreads up the lower body",
		"Each lower segment hardens to chitin in turn."],
	["grow_breasts", "biped", "Breasts grow over time",
		"They swell a little each beat."],
	["grow_tail_length", "biped_tail", "A tail lengthens over time",
		"The tail grows a little each beat."],
	["lactation_production", "biped", "Milk comes in over time",
		"The reservoirs fill each beat."],
	["grow_first_phallic", "biped", "A penis grows over time",
		"It lengthens and thickens each beat."],
]


# Build the base body a staged demo needs (a plain biped, or one pre-shaped via a library TF).
func _staged_base(kind: String) -> Dictionary:
	match kind:
		"taur":
			var h := TfHolder.new(_fresh_body(), BASE_SEED, _registry)
			h.apply_instant("biped_to_taur")
			return h.body
		"biped_tail":
			var h := TfHolder.new(_fresh_body(), BASE_SEED, _registry)
			h.apply_instant("add_feline_tail")
			return h.body
		_:
			return _fresh_body()


# Run a staged TF on its base, capturing a snapshot per stage, and narrate the progression.
func _run_staged(content_id: String, base_kind: String) -> Dictionary:
	var content_reg := TfContent.registry()
	var tf: Dictionary = content_reg[content_id]
	var base := _staged_base(base_kind)
	var holder := TfHolder.new(base, BASE_SEED, content_reg)
	holder.start_tf(content_id)
	var snaps: Array = [BodyGraph.dup_state(holder.body)]
	var step: int = int(tf.get("stage_seconds", 600))
	var stages: int = int(tf.get("max_stages", 1))
	for i in stages:
		holder.advance_time(step)
		snaps.append(BodyGraph.dup_state(holder.body))
	var process: Array = TfDescribe.describe_progression(snaps)
	return {
		"process": process,
		"ends_as": TfDescribe.form_line(holder.body),
		"changed": not process.is_empty(),
	}


func _build_staged_card(demo: Array) -> Control:
	var res := _run_staged(str(demo[0]), str(demo[1]))
	var lines: Array = res["process"]
	if lines.is_empty():
		lines = ["(no staged change on this base)"]
	return _card(str(demo[2]), str(demo[3]), lines, str(res["ends_as"]), "")


func _word(value) -> String:
	return str(value).replace("_", " ")


# ===================================================================== card widgets

func _category_header(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	return l


# One audit card: name (bold), blurb, the PROCESS narrative (the transformation over
# time — the primary content), and a small "ends as" form footer for context.
func _card(name_text: String, blurb: String, process: Array, ends_as: String,
		note: String) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.19)
	sb.border_color = Color(0.30, 0.34, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(vb)

	var name_l := Label.new()
	name_l.text = name_text
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", Color(0.95, 0.96, 0.85))
	vb.add_child(name_l)

	if blurb != "":
		var blurb_l := Label.new()
		blurb_l.text = blurb
		blurb_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb_l.add_theme_font_size_override("font_size", 13)
		blurb_l.add_theme_color_override("font_color", Color(0.78, 0.82, 0.72))
		vb.add_child(blurb_l)

	if note != "":
		var note_l := Label.new()
		note_l.text = note
		note_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_l.add_theme_font_size_override("font_size", 12)
		note_l.add_theme_color_override("font_color", Color(0.85, 0.72, 0.55))
		vb.add_child(note_l)

	# The process narrative: one numbered step per change, so the order reads as a sequence
	# happening over time rather than a flat list.
	var proc := VBoxContainer.new()
	proc.add_theme_constant_override("separation", 2)
	proc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(proc)
	for line in process:
		var step_l := Label.new()
		step_l.text = "  " + str(line)
		step_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step_l.add_theme_font_size_override("font_size", 13)
		step_l.add_theme_color_override("font_color", Color(0.88, 0.90, 0.82))
		step_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		proc.add_child(step_l)

	if ends_as != "":
		var foot := Label.new()
		foot.text = "Ends as: " + ends_as
		foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foot.add_theme_font_size_override("font_size", 11)
		foot.add_theme_color_override("font_color", Color(0.58, 0.64, 0.74))
		vb.add_child(foot)

	return pc


# ===================================================================== self-playtest

# Page through the whole list, writing a PNG per page, then quit. Used in TF_AUDIT_SHOT.
func _run_self_playtest() -> void:
	var out := OS.get_environment("TF_AUDIT_SHOT")
	DirAccess.make_dir_recursive_absolute(out)
	# Sanity: every changed TF yields a non-empty PROCESS narrative; print each so the
	# render log doubles as a readable transcript of the transformation narratives.
	var noops: Array = []
	for tf_id in _registry.keys():
		var res := _apply_one(tf_id)
		if not res["changed"]:
			noops.append(tf_id)
			continue
		print("[narr] %s:" % tf_id)
		for line in res["process"]:
			print("         - " + str(line))
		print("         ends as: " + str(res["ends_as"]))
	for demo in STAGED_DEMOS:
		var sres := _run_staged(str(demo[0]), str(demo[1]))
		print("[staged] %s (base %s):" % [demo[0], demo[1]])
		for line in sres["process"]:
			print("         - " + str(line))
		print("         ends as: " + str(sres["ends_as"]))
	print("[audit] %d transformations in library" % _registry.size())
	if not noops.is_empty():
		print("[audit] no-op on the plain base (precondition not met, shown with a note): "
			+ ", ".join(noops))

	# Page through the scroll region, capturing each screenful.
	await get_tree().process_frame
	await get_tree().process_frame
	var page_h := _scroll.size.y
	var total := _column.size.y
	var pages: int = int(ceil(total / page_h)) if page_h > 0 else 1
	pages = max(1, pages)
	for p in pages:
		_scroll.scroll_vertical = int(p * page_h)
		await _shot(out, "page_%02d" % p)
	print("[audit] wrote %d pages (total content %.0fpx, page %.0fpx)" % [pages, total, page_h])
	get_tree().quit()


func _shot(out: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s.png" % label))
