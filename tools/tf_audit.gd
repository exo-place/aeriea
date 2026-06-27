## tf_audit — a scrollable "TF audit" sandbox for aeriea's transformation library.
##
## The point: give the user a large, varied, AUDITABLE set of concrete transformations so
## they can judge whether the model produces good bodies. For EVERY TF in the library
## (tf_library.gd) this applies it to a single standard BASE body and shows, in one card:
##   - a clean human name and a one-line plain description of what it does;
##   - the resulting body DESCRIPTION (tf_describe), so you read the actual outcome;
##   - the sequence of OPS it ran, in plain language, so you can audit what it did.
## The whole set scrolls in one column, grouped by category. Every TF is applied from the
## SAME fresh base body, so the cards are directly comparable.
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
	sub.text = "Every transformation applied to the same base body. Scroll to read each one."
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

# The base body description, shown once at the top as the reference point.
func _populate() -> void:
	# Reference: the base body itself, so every "after" reads against a visible "before".
	var base := _fresh_body()
	_column.add_child(_category_header("Base body (every card starts here)"))
	_column.add_child(_card("Base body", "The unmodified starting body.",
		TfDescribe.describe(base), ["(no transformation applied)"], ""))

	for entry in TfLibrary.categories():
		var cat_name: String = entry[0]
		var ids: Array = entry[1]
		_column.add_child(_category_header(cat_name))
		for tf_id in ids:
			_column.add_child(_build_card(tf_id))


func _fresh_body() -> Dictionary:
	return TfContent.biped()


# Apply one TF to a fresh base, returning {desc, ops_lines, changed}.
func _apply_one(tf_id: String) -> Dictionary:
	var tf: Dictionary = _registry[tf_id]
	var holder := TfHolder.new(_fresh_body(), BASE_SEED, _registry)
	var effect_count := 0
	if bool(tf.get("staged", false)):
		holder.start_tf(tf_id)
		var step: int = int(tf.get("stage_seconds", 600))
		var stages: int = int(tf.get("max_stages", 1))
		for i in stages:
			holder.advance_time(step)
		effect_count = -1   # staged: count is per-stage, not meaningful as one number
	else:
		var effects: Array = holder.apply_instant(tf_id)
		effect_count = effects.size()
	# A staged TF reports per-stage; treat "changed" by comparing to the fresh base.
	var changed := effect_count != 0
	if effect_count == -1:
		changed = TfDescribe.describe(holder.body) != TfDescribe.describe(_fresh_body())
	return {
		"desc": TfDescribe.describe(holder.body),
		"ops_lines": _ops_to_lines(tf),
		"changed": changed,
		"note": _precondition_note(tf) if not changed else "",
	}


# When a TF no-ops on the plain base (its gate needs a part the base lacks, or it is
# idempotent here), say so plainly so the card is still honest and auditable.
func _precondition_note(tf: Dictionary) -> String:
	var gate = tf.get("gate", null)
	if typeof(gate) == TYPE_DICTIONARY:
		var needs := _gate_need(gate)
		if needs != "":
			return "No change here: the base body has no %s to act on." % needs
	return "No change here: the base body already matches this result."


func _gate_need(gate: Dictionary) -> String:
	if gate.get("op", "") == "has_tag":
		return _word(str(gate.get("tag", "")))
	return ""


func _build_card(tf_id: String) -> Control:
	var tf: Dictionary = _registry[tf_id]
	var res := _apply_one(tf_id)
	return _card(str(tf.get("name", tf_id)), str(tf.get("blurb", "")),
		res["desc"], res["ops_lines"], str(res.get("note", "")))


# Render a TF's ops as plain-language audit lines. Each op becomes one readable sentence
# describing what it targets and does — no raw JSON, no engine keys in the player text.
func _ops_to_lines(tf: Dictionary) -> Array:
	var lines: Array = []
	if bool(tf.get("staged", false)):
		lines.append("Runs in %d stages over time." % int(tf.get("max_stages", 1)))
	for op in tf.get("ops", []):
		lines.append(_op_line(op))
	return lines


func _op_line(op: Dictionary) -> String:
	var tgt := _target_phrase(op)
	match str(op.get("effect", "")):
		"graft_subtree":
			var sub: Dictionary = op.get("subtree", {})
			return "Add %s." % _part_phrase(sub)
		"remove_subtree":
			return "Remove %s." % tgt
		"reparent":
			return "Move %s to a new attachment." % tgt
		"set_material":
			return "Change %s material to %s." % [tgt, _word(op.get("value", ""))]
		"set_covering":
			return "Change %s surface to %s." % [tgt, _word(op.get("value", ""))]
		"prop_delta":
			return "%s %s of %s." % [_delta_verb(op), _prop_word(op.get("prop", "")), tgt]
		"tag_add":
			return "Mark %s as %s." % [tgt, _word(op.get("value", ""))]
		"tag_remove":
			return "Unmark %s as %s." % [tgt, _word(op.get("value", ""))]
		"fluid_delta":
			return _fluid_line(op, tgt)
		"set_fluid_type":
			return "Set the %s fluid on %s." % [_word(op.get("value", "")), tgt]
		_:
			return "Adjust %s." % tgt


func _fluid_line(op: Dictionary, tgt: String) -> String:
	var fluid := _word(op.get("fluid", ""))
	var amount = op.get("amount", {})
	var v := 0
	if typeof(amount) == TYPE_DICTIONARY:
		v = int(amount.get("v", 0))
	var cap_d := int(op.get("capacity_delta", 0))
	if cap_d > 0 and v >= 0:
		return "Open %s capacity in %s and begin filling it." % [fluid, tgt]
	if v < 0:
		return "Drain %s from %s." % [fluid, tgt]
	return "Add %s to %s." % [fluid, tgt]


func _delta_verb(op: Dictionary) -> String:
	var amount = op.get("amount", {})
	var v := 0.0
	if typeof(amount) == TYPE_DICTIONARY:
		if amount.has("v"):
			v = float(amount["v"])
		elif amount.has("lo") and amount.has("hi"):
			v = (float(amount["lo"]) + float(amount["hi"])) / 2.0
	return "Increase the" if v >= 0 else "Decrease the"


# A human phrase for what an op targets (a role/region tag, an ordinal, or a named node).
func _target_phrase(op: Dictionary) -> String:
	if op.has("target_node"):
		return _node_phrase(str(op["target_node"]))
	if op.has("subtree_under"):
		return "everything from %s down" % _node_phrase(str(op["subtree_under"]))
	if op.has("subtree_tag"):
		return "the %s region" % _word(str(op["subtree_tag"]))
	if op.has("tag"):
		return "every %s" % _word(str(op["tag"]))
	if op.has("target") and typeof(op["target"]) == TYPE_DICTIONARY:
		var sel: Dictionary = op["target"]
		var kind = sel.get("kind", null)
		var noun := _kind_noun(str(kind)) if kind != null else _word(str(sel.get("tag", "part")))
		if sel.get("select", "") == "nth_tagged":
			return "the first %s" % noun
		return "every %s" % noun
	return "the targeted part"


# Natural plural-friendly noun for a genital kind tag, for the ops audit.
func _kind_noun(kind: String) -> String:
	match kind:
		"phallic": return "penis"
		"vaginal": return "vagina"
		_:
			return _word(kind)


# A readable, articled noun for a named node id (the stable base-body mounts/parts), so
# it reads naturally after "of" / "Remove" etc. ("the butt", "the left leg").
func _node_phrase(id: String) -> String:
	match id:
		"torso_upper": return "the torso"
		"pelvis": return "the lower body"
		"barrel": return "the barrel"
		"head": return "the head"
		"butt": return "the butt"
		"leg_l": return "the left leg"
		"leg_r": return "the right leg"
		"arm_l": return "the left arm"
		"arm_r": return "the right arm"
		"breast_l": return "the left breast"
		"breast_r": return "the right breast"
		_:
			return "the " + _word(id)


# A readable phrase naming the part a graft adds (role tag + the part's surface).
func _part_phrase(sub: Dictionary) -> String:
	var tags: Array = sub.get("tags", [])
	var noun := "a part"
	if "pelvis" in tags:
		return "a two-legged lower body"
	for role in ["wing", "horn", "ear", "tail", "arm", "leg", "claw", "hoof", "udder",
			"teat", "nipple", "breast", "serpentine", "barrel"]:
		if role in tags:
			noun = _role_noun(role)
			break
	if "genital" in tags:
		if "phallic" in tags:
			noun = "a penis"
		elif "vaginal" in tags:
			noun = "a vagina"
		else:
			noun = "a genital"
	return noun


func _role_noun(role: String) -> String:
	match role:
		"wing": return "a wing"
		"horn": return "a horn"
		"ear": return "an ear"
		"tail": return "a tail"
		"arm": return "an arm"
		"leg": return "a leg"
		"claw": return "claws"
		"hoof": return "a hoof"
		"udder": return "an udder"
		"teat": return "a teat"
		"nipple": return "a nipple"
		"breast": return "a breast"
		"barrel": return "a four-legged barrel"
		"serpentine": return "a serpentine lower body"
		_:
			return "a " + role


func _prop_word(prop: String) -> String:
	match prop:
		"volume_ml": return "volume"
		"length_cm": return "length"
		"girth_cm": return "girth"
		"depth_cm": return "depth"
		"band_cm": return "rib band"
		"width_cm": return "width"
		_:
			return prop.replace("_", " ")


func _word(value) -> String:
	return str(value).replace("_", " ")


# ===================================================================== card widgets

func _category_header(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	return l


# One audit card: name (bold), blurb, the resulting description, and the ops it ran.
func _card(name_text: String, blurb: String, desc: String, ops_lines: Array,
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

	# Two columns: the resulting body description (left) and the ops audit (right).
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	vb.add_child(cols)

	cols.add_child(_labelled_block("Result", desc, Color(0.70, 0.86, 0.95),
		Color(0.86, 0.88, 0.78), 2.0))
	cols.add_child(_labelled_block("What it did", "\n".join(ops_lines),
		Color(0.70, 0.86, 0.95), Color(0.74, 0.80, 0.86), 1.4))

	return pc


func _labelled_block(heading: String, body: String, head_col: Color, body_col: Color,
		ratio: float) -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_stretch_ratio = ratio
	vb.add_theme_constant_override("separation", 2)
	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 12)
	h.add_theme_color_override("font_color", head_col)
	vb.add_child(h)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", body_col)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(b)
	return vb


# ===================================================================== self-playtest

# Page through the whole list, writing a PNG per page, then quit. Used in TF_AUDIT_SHOT.
func _run_self_playtest() -> void:
	var out := OS.get_environment("TF_AUDIT_SHOT")
	DirAccess.make_dir_recursive_absolute(out)
	# Sanity: every TF applies and yields a non-empty description.
	var errors: Array = []
	var noops: Array = []
	for tf_id in _registry.keys():
		var res := _apply_one(tf_id)
		if str(res["desc"]).strip_edges() == "":
			errors.append("%s produced an empty description" % tf_id)
		if not res["changed"]:
			noops.append(tf_id)
	print("[audit] %d transformations in library" % _registry.size())
	if not noops.is_empty():
		print("[audit] no-op on the plain base (precondition not met, shown with a note): "
			+ ", ".join(noops))
	if errors.is_empty():
		print("[audit] all transformations apply and describe non-empty on the base")
	else:
		print("[audit] ISSUES: " + ", ".join(errors))

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
