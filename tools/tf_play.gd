## tf_play — interactive in-editor playground for aeriea's TF (transformation) system.
##
## A clean Control-based debug surface that DRIVES the already-built TF engine
## (TfHolder + TfContent + TfDescribe) and shows the body change LIVE. Nothing here
## modifies the engine — this is purely a UI/driver on top.
##
## Layout:
##   - LEFT: live body view(s) — prose description (prominent) + a structure view of
##     the graph (each segment: tags / material / covering / extent / parent). A SECOND
##     body view appears alongside after a split-off.
##   - RIGHT: action panel — seed + reset, one button per TF record, advance-time +
##     active-staged-TF progress, undo / make-permanent, save / load, split / merge.
##   - BOTTOM: a scrolling action log.
##
## Run (headless render): xvfb-run -a godot4 --path . res://tools/tf_play.tscn
##   With TF_PLAY_SHOT=<dir> set, the scene also auto-drives a scripted sequence and
##   writes after-action PNGs, then quits (self-playtest mode).
extends Control

const TfHolder := preload("res://scripts/body/tf/tf_holder.gd")
const TfContent := preload("res://scripts/body/tf/tf_content.gd")
const TfDescribe := preload("res://scripts/body/tf/tf_describe.gd")
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const TfMeasure := preload("res://scripts/body/tf/tf_measure.gd")

var _registry: Dictionary
var _holder                       # TfHolder (primary body)
var _detached: Dictionary = {}    # split-off body state, or {} if none
var _save_slot: Dictionary = {}   # in-memory save (a to_dict())
var _seed: int = 0xA32115
var _std: Dictionary = TfMeasure.default_standard()   # current measurement standard

# --- node refs (built in _ready) ---
var _seed_edit: LineEdit
var _prose_label: RichTextLabel
var _struct_label: RichTextLabel
var _detached_panel: PanelContainer
var _detached_prose: RichTextLabel
var _detached_struct: RichTextLabel
var _active_label: RichTextLabel
var _clock_label: Label
var _sex_label: RichTextLabel
var _log: RichTextLabel
var _merge_btn: Button
var _split_buttons: VBoxContainer
var _std_btn: Button

var _log_lines: Array = []


func _ready() -> void:
	_registry = TfContent.registry()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_reset()
	if OS.get_environment("TF_PLAY_SHOT") != "":
		_run_self_playtest.call_deferred()


# ================================================================= UI construction

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 6)
	# margin
	outer.offset_left = 10
	outer.offset_top = 10
	outer.offset_right = -10
	outer.offset_bottom = -10
	add_child(outer)

	var title := Label.new()
	title.text = "TF Playground"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	outer.add_child(title)

	# Main split: bodies (left) | actions (right)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	outer.add_child(split)

	# ---- LEFT: body view(s) ----
	var bodies := HBoxContainer.new()
	bodies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bodies.size_flags_stretch_ratio = 2.4
	bodies.add_theme_constant_override("separation", 8)
	split.add_child(bodies)

	var primary := _make_body_panel("Primary body")
	bodies.add_child(primary["outer"])
	_prose_label = primary["prose"]
	_struct_label = primary["struct"]

	var dpair := _make_body_panel("Detached body")
	_detached_panel = dpair["outer"]
	_detached_prose = dpair["prose"]
	_detached_struct = dpair["struct"]
	_detached_panel.visible = false
	bodies.add_child(_detached_panel)

	# ---- RIGHT: action panel ----
	var actions_scroll := ScrollContainer.new()
	actions_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_scroll.size_flags_stretch_ratio = 1.0
	actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(actions_scroll)
	var actions_box := _panel_box("Actions")
	actions_box["outer"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_scroll.add_child(actions_box["outer"])
	var actions: VBoxContainer = actions_box["body"]

	_clock_label = Label.new()
	_clock_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	actions.add_child(_clock_label)

	_sex_label = RichTextLabel.new()
	_sex_label.bbcode_enabled = true
	_sex_label.fit_content = true
	_sex_label.scroll_active = false
	_sex_label.custom_minimum_size = Vector2(0, 24)
	actions.add_child(_sex_label)

	# measurement standard switch — re-renders the SAME body under a different standard.
	actions.add_child(_section("Measurement"))
	_std_btn = _button(_std_btn_label(), _on_switch_standard)
	actions.add_child(_std_btn)

	# seed + reset
	actions.add_child(_section("Determinism"))
	var seed_row := HBoxContainer.new()
	var seed_lbl := Label.new()
	seed_lbl.text = "Seed:"
	seed_row.add_child(seed_lbl)
	_seed_edit = LineEdit.new()
	_seed_edit.text = "0x%X" % _seed
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_edit)
	actions.add_child(seed_row)
	actions.add_child(_button("Reset body", _on_reset))

	# transformations
	actions.add_child(_section("Transformations"))
	for tf_id in _registry.keys():
		var tf: Dictionary = _registry[tf_id]
		var staged: bool = bool(tf.get("staged", false))
		var label: String = "%s%s" % [tf["name"], "  [staged]" if staged else "  [instant]"]
		actions.add_child(_button(label, _on_tf.bind(tf_id)))

	# time
	actions.add_child(_section("Time"))
	actions.add_child(_button("Advance to next stage", _on_advance))
	_active_label = RichTextLabel.new()
	_active_label.bbcode_enabled = true
	_active_label.fit_content = true
	_active_label.custom_minimum_size = Vector2(0, 40)
	_active_label.scroll_active = false
	actions.add_child(_active_label)

	# history
	actions.add_child(_section("History"))
	actions.add_child(_button("Undo last", _on_undo))
	actions.add_child(_button("Make permanent", _on_make_permanent))

	# persistence
	actions.add_child(_section("Persistence"))
	actions.add_child(_button("Save", _on_save))
	actions.add_child(_button("Load", _on_load))

	# body ops
	actions.add_child(_section("Body parts"))
	_split_buttons = VBoxContainer.new()
	actions.add_child(_split_buttons)
	_merge_btn = _button("Merge detached body back", _on_merge)
	_merge_btn.disabled = true
	actions.add_child(_merge_btn)

	# ---- BOTTOM: action log ----
	var log_box := _panel_box("Log")
	log_box["outer"].custom_minimum_size = Vector2(0, 160)
	outer.add_child(log_box["outer"])
	var log_panel: VBoxContainer = log_box["body"]
	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.custom_minimum_size = Vector2(0, 120)
	log_panel.add_child(log_scroll)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 120)
	log_scroll.add_child(_log)


func _make_body_panel(heading: String) -> Dictionary:
	var box := _panel_box(heading)
	var outer: PanelContainer = box["outer"]
	var panel: VBoxContainer = box["body"]
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	panel.add_child(_section("Description"))
	var prose := RichTextLabel.new()
	prose.bbcode_enabled = true
	prose.fit_content = true
	prose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prose.custom_minimum_size = Vector2(0, 120)
	prose.add_theme_color_override("default_color", Color(0.95, 0.95, 0.8))
	panel.add_child(prose)

	panel.add_child(_section("Structure"))
	var struct_scroll := ScrollContainer.new()
	struct_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	struct_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(struct_scroll)
	var struct := RichTextLabel.new()
	struct.bbcode_enabled = true
	struct.fit_content = true
	struct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	struct.custom_minimum_size = Vector2(0, 200)
	struct_scroll.add_child(struct)

	return {"outer": outer, "prose": prose, "struct": struct}


# A bordered panel with a heading. Returns {"outer": PanelContainer (add this to the
# tree), "body": VBoxContainer (add content here)}.
func _panel_box(heading: String) -> Dictionary:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.19)
	sb.border_color = Color(0.30, 0.34, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(vb)
	var hdr := Label.new()
	hdr.text = heading
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.55, 0.70, 0.95))
	vb.add_child(hdr)
	return {"outer": pc, "body": vb}


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	return b


# ================================================================= action handlers

func _on_reset() -> void:
	_reset()


func _reset() -> void:
	_seed = _parse_seed(_seed_edit.text if _seed_edit else "0xA32115")
	_holder = TfHolder.new(TfContent.biped(), _seed, _registry)
	_detached = {}
	if _detached_panel:
		_detached_panel.visible = false
	if _merge_btn:
		_merge_btn.disabled = true
	_log_lines.clear()
	_logline("Reset to starting body (seed 0x%X)" % _seed)
	_refresh()


func _on_tf(tf_id: String) -> void:
	var tf: Dictionary = _registry[tf_id]
	if bool(tf.get("staged", false)):
		_holder.start_tf(tf_id)
		_logline("Started: [color=#9cf]%s[/color] (%d stages, %ds each). Advance time to progress."
			% [tf["name"], int(tf.get("max_stages", 1)), int(tf.get("stage_seconds", 0))])
	else:
		var before := _describe(_holder.body)
		var effects: Array = _holder.apply_instant(tf_id)
		if effects.is_empty():
			_logline("[color=#fa6]%s[/color]: nothing changed" % tf["name"])
		else:
			_logline("Applied [color=#9cf]%s[/color] (%d change(s))" % [tf["name"], effects.size()])
	_refresh()


# Primary time button: advance EXACTLY to the soonest pending staged-TF stage, so each
# press lands one meaningful step. With no staged TF in flight, time does NOT advance —
# advancing the clock with nothing pending is a no-op, so don't pretend otherwise.
func _on_advance() -> void:
	var step := _next_event_step()
	if step < 0:
		_logline("[color=#888]No transformation in progress — nothing to advance[/color]")
		_refresh()
		return
	_advance_by(step)


# Seconds from now to the soonest pending staged-TF stage due time, or -1 if none pending.
func _next_event_step() -> int:
	var now: int = _holder.clock.full_time()
	var soonest := -1
	for atf in _holder.active:
		var due: int = int(atf["due_full_time"])
		if soonest < 0 or due < soonest:
			soonest = due
	if soonest < 0:
		return -1
	# Always move forward at least 1s even if a stage is already overdue (shouldn't happen,
	# but keeps the press meaningful and the clock monotonic).
	return max(1, soonest - now)


func _advance_by(seconds: int) -> void:
	var pre := {}
	for atf in _holder.active:
		pre[atf["tf_id"]] = atf["next_stage"]
	_holder.advance_time(seconds)
	var notes: Array = []
	# report stage advances by comparing (active may have dropped completed ones)
	var seen := {}
	for atf in _holder.active:
		seen[atf["tf_id"]] = true
		var tf: Dictionary = _registry[atf["tf_id"]]
		notes.append("%s -> stage %d/%d" % [tf["name"], atf["next_stage"], int(tf.get("max_stages", 1))])
	for tf_id in pre.keys():
		if not seen.has(tf_id):
			notes.append("%s -> COMPLETE" % _registry[tf_id]["name"])
	# also surface a measured outcome (tail length) if present
	var tail = BodyGraph.find_by_id(_holder.body["root"], "tail")
	var measure := ""
	if tail != null and tail["props"].has("length_cm"):
		measure = "  tail=%.1fcm" % float(tail["props"]["length_cm"])
	_logline("advance +%ds  (day %d, t=%d)%s%s" % [
		seconds, _holder.clock.day, _holder.clock.time_of_day, measure,
		("  | " + ", ".join(notes)) if not notes.is_empty() else ""])
	_refresh()


func _on_undo() -> void:
	if _holder.undo_last():
		_logline("[color=#fc9]Undid the last change[/color]")
	else:
		_logline("[color=#888]Nothing to undo[/color]")
	_refresh()


func _on_make_permanent() -> void:
	_holder.make_permanent()
	_logline("[color=#9f9]Made current body permanent[/color]")
	_refresh()


func _on_save() -> void:
	# round-trip through JSON exactly like a real save, so we prove identity.
	_save_slot = JSON.parse_string(JSON.stringify(_holder.to_dict()))
	_logline("[color=#9cf]Saved[/color] (%d bytes)" % JSON.stringify(_save_slot).length())
	_refresh()


func _on_load() -> void:
	if _save_slot.is_empty():
		_logline("[color=#888]No save to load yet[/color]")
		return
	var before := _describe(_holder.body)
	_holder = TfHolder.from_dict(_save_slot, _registry)
	var after := _describe(_holder.body)
	# detached state is not part of the holder save; clear it on load for clarity.
	_detached = {}
	_detached_panel.visible = false
	_merge_btn.disabled = true
	_logline("[color=#9cf]Loaded[/color] (body %s the saved one)"
		% ("matches" if after == _describe_dict(_save_slot["body"]) else "differs from"))
	_refresh()


func _on_split(node_id: String) -> void:
	var det: Dictionary = _holder.split_off(node_id)
	if det.is_empty():
		_logline("[color=#fa6]Cannot split '%s'[/color]" % node_id)
		return
	_detached = det
	_detached_panel.visible = true
	_merge_btn.disabled = false
	_logline("[color=#fc9]Split off[/color] [b]%s[/b] as a new body" % node_id)
	_refresh()


func _on_merge() -> void:
	if _detached.is_empty():
		return
	var root_id: String = _detached["root"]["id"]
	var ok: bool = _holder.merge_in(_detached, "torso_upper", "graft_point")
	if ok:
		_logline("[color=#9f9]Merged[/color] the detached body (%s) back" % root_id)
		_detached = {}
		_detached_panel.visible = false
		_merge_btn.disabled = true
	else:
		_logline("[color=#fa6]Merge failed[/color]")
	_refresh()


# ================================================================= refresh / render

func _refresh() -> void:
	# clock
	_clock_label.text = "Day %d, time %d    seed 0x%X" % [
		_holder.clock.day, _holder.clock.time_of_day, _seed]

	# primary body
	_prose_label.text = _describe(_holder.body)
	_struct_label.text = _structure_bb(_holder.body)

	# derived sex readout (recomputed live — never stored, §6).
	_sex_label.text = "[color=#f9c]Sex (derived):[/color] " + TfDescribe.sex_sentence(_holder.body)

	# detached body
	if not _detached.is_empty():
		_detached_prose.text = _describe(_detached)
		_detached_struct.text = _structure_bb(_detached)

	# active staged TFs
	if _holder.active.is_empty():
		_active_label.text = "[color=#888]No transformations in progress[/color]"
	else:
		var rows: Array = []
		for atf in _holder.active:
			var tf: Dictionary = _registry[atf["tf_id"]]
			var maxs: int = int(tf.get("max_stages", 1))
			var cur: int = atf["next_stage"]
			var due_in: int = atf["due_full_time"] - _holder.clock.full_time()
			rows.append("[color=#cf9]%s[/color]: stage %d/%d, next in %ds"
				% [tf["name"], cur, maxs, max(0, due_in)])
		_active_label.text = "\n".join(rows)

	# rebuild split buttons for current node ids
	_rebuild_split_buttons()


func _rebuild_split_buttons() -> void:
	for c in _split_buttons.get_children():
		c.queue_free()
	var hdr := _section("Split off a part:")
	_split_buttons.add_child(hdr)
	# offer a handful of splittable (non-root) nodes that actually exist now.
	var candidates := ["leg_l", "butt", "barrel", "tail", "leg_fl", "arm_r", "head"]
	var root: Dictionary = _holder.body["root"]
	var row: HBoxContainer = null
	var n := 0
	for cid in candidates:
		if BodyGraph.find_by_id(root, cid) == null:
			continue
		if cid == root["id"]:
			continue
		if n % 2 == 0:
			row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_split_buttons.add_child(row)
		var b := Button.new()
		b.text = cid
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_split.bind(cid))
		b.disabled = not _detached.is_empty()   # one detached body at a time
		row.add_child(b)
		n += 1
	if n == 0:
		_split_buttons.add_child(_section("  (no parts to split)"))


# Structure view: indented tree, each segment showing material / covering / extent /
# tags / parent attachment, as BBCode.
func _structure_bb(body: Dictionary) -> String:
	var lines: Array = []
	_struct_walk(body["root"], "root", 0, lines)
	return "\n".join(lines)


func _struct_walk(seg: Dictionary, at: String, depth: int, lines: Array) -> void:
	var indent := "    ".repeat(depth)
	var mat: String = seg.get("material", "?")
	var cov = seg.get("covering")
	var cov_s: String = "[color=#888]—[/color]" if cov == null else str(cov)
	var props: Dictionary = seg.get("props", {})
	var ext := ""
	if props.has("length_cm"):
		ext = " %.0fcm" % float(props["length_cm"])
	var tags: Array = seg.get("tags", [])
	var tag_s := ""
	if not tags.is_empty():
		tag_s = " [color=#7a9]{%s}[/color]" % ",".join(tags)
	# Fluid reservoirs (§5.1): type amount/capacity, total-ordered by type.
	var fluid_s := ""
	var fluids: Array = seg.get("fluids", [])
	if not fluids.is_empty():
		var ordered := fluids.duplicate()
		ordered.sort_custom(func(a, b): return str(a.get("type", "")) < str(b.get("type", "")))
		var fbits: Array = []
		for f in ordered:
			fbits.append("%s %d/%d" % [str(f.get("type", "")), int(f.get("amount", 0)), int(f.get("capacity", 0))])
		fluid_s = " [color=#6cf]«%s»[/color]" % ", ".join(fbits)
	lines.append("%s[color=#9cf]%s[/color][color=#666]@%s[/color]  [color=#fc9]%s[/color]/%s%s%s%s" % [
		indent, seg["id"], at, mat, cov_s, ext, tag_s, fluid_s])
	var kids: Array = seg.get("children", []).duplicate()
	kids.sort_custom(func(a, b): return str(a["node"]["id"]) < str(b["node"]["id"]))
	for edge in kids:
		_struct_walk(edge["node"], edge["at"], depth + 1, lines)


func _describe(body: Dictionary) -> String:
	return TfDescribe.describe(body, _std)


func _describe_dict(body_dict: Dictionary) -> String:
	return TfDescribe.describe(body_dict, _std)


func _std_btn_label() -> String:
	return "Standard: %s" % _std["name"]


# Switch the measurement standard. The body is UNCHANGED — only the describe layer's
# rendering parameter flips, so the same body re-renders (e.g. "13DD" <-> "32G").
func _on_switch_standard() -> void:
	_std = TfMeasure.next_standard(_std)
	_std_btn.text = _std_btn_label()
	_logline("measurement standard -> %s" % _std["name"])
	_refresh()


func _logline(s: String) -> void:
	_log_lines.append("[color=#666]%02d:[/color] %s" % [_log_lines.size(), s])
	# keep last ~200
	if _log_lines.size() > 200:
		_log_lines = _log_lines.slice(_log_lines.size() - 200)
	if _log:
		_log.text = "\n".join(_log_lines)
		# autoscroll to bottom
		await get_tree().process_frame
		var sc := _log.get_parent()
		if sc is ScrollContainer:
			(sc as ScrollContainer).scroll_vertical = int(_log.get_content_height())


func _parse_seed(s: String) -> int:
	s = s.strip_edges()
	if s.begins_with("0x") or s.begins_with("0X"):
		return s.hex_to_int()
	if s.is_valid_int():
		return s.to_int()
	return s.hash()


# ================================================================= self-playtest

# Scripted drive used in TF_PLAY_SHOT mode: exercises every action, writes PNGs.
func _run_self_playtest() -> void:
	var out := OS.get_environment("TF_PLAY_SHOT")
	DirAccess.make_dir_recursive_absolute(out)
	var errors: Array = []

	await _shot(out, "00_start")

	# FIX 4 — STAGED graft (biped -> taur, gradual). Each advance-to-next-stage press
	# should land exactly one stage. Stage 0 lands the form (barrel appears).
	_on_tf("graft_quadruped_lower_staged")
	if BodyGraph.find_by_id(_holder.body["root"], "barrel") != null:
		errors.append("staged graft fired before clock advanced")
	_on_advance()   # -> stage 0 due: form lands
	if BodyGraph.find_by_id(_holder.body["root"], "barrel") == null:
		errors.append("staged graft: barrel never grafted after first stage")
	else:
		print("[pt] staged graft stage0: barrel present, len=%.1f" % float(BodyGraph.find_by_id(_holder.body["root"], "barrel")["props"]["length_cm"]))
	await _shot(out, "01_taur")
	# advance the remaining grow stages, one press = one stage
	var prev_stage := _active_stage("graft_quadruped_lower_staged")
	_on_advance()
	var now_stage := _active_stage("graft_quadruped_lower_staged")
	if now_stage != -1 and now_stage != prev_stage + 1:
		errors.append("advance-to-next-stage did not advance exactly one stage (%d -> %d)" % [prev_stage, now_stage])
	for i in 4:
		_on_advance()
	print("[pt] after staged graft prose:\n" + _describe(_holder.body))

	# staged fur creep — start + step (one stage per press)
	_on_tf("set_covering_fur_upward")
	_on_advance()
	await _shot(out, "02_furcreep_mid")
	print("[pt] mid-staged active:")
	for atf in _holder.active:
		print("   %s stage %d/%d" % [atf["tf_id"], atf["next_stage"], int(_registry[atf["tf_id"]].get("max_stages", 1))])
	for i in 4:
		_on_advance()

	# tail graft + grow (seeded staged)
	_on_tf("graft_tail")
	_on_tf("grow_tail_length")
	for i in 6:
		_on_advance()
	var tail = BodyGraph.find_by_id(_holder.body["root"], "tail")
	print("[pt] grown tail length = %.2f" % float(tail["props"]["length_cm"]))

	# save -> load identity
	_on_save()
	var pre_load := _describe(_holder.body)
	_on_load()
	if _describe(_holder.body) != pre_load:
		errors.append("save/load diverged")

	# FIX 2 — chitin staged: must convert ONE segment per stage, not all at once.
	_on_tf("set_lower_material_chitin")
	var chitin_counts: Array = []
	for i in 5:
		_on_advance()
		chitin_counts.append(_count_material("chitin"))
	print("[pt] chitin per-stage counts: %s" % str(chitin_counts))
	# Each stage should harden exactly one more lower segment (strictly increasing by 1).
	var progressive := true
	for i in chitin_counts.size():
		if chitin_counts[i] != i + 1:
			progressive = false
	if not progressive:
		errors.append("chitin did not progress one segment per stage: %s" % str(chitin_counts))
	await _shot(out, "03_chitin")

	# undo
	_on_undo()

	# split + merge
	_on_split("leg_fl")
	await _shot(out, "04_split")
	if _detached.is_empty():
		errors.append("split produced no detached body")
	_on_merge()
	await _shot(out, "05_merge")

	# === COMPOUND PARTS / GENITALIA / FLUIDS drive ===
	# Fresh body so the genital/breast/fluid state is the starting reservoir set.
	_reset()
	print("[pt] start sex: " + TfDescribe.sex_readout(_holder.body))
	await _shot(out, "06_genitalia_start")
	# add a member -> derived phallic count rises.
	_on_tf("add_phallic_genital")
	print("[pt] after add member sex: " + TfDescribe.sex_readout(_holder.body))
	if TfDescribe.derive_sex(_holder.body)["counts"]["phallic"] != 2:
		errors.append("add_phallic_genital did not raise phallic count to 2")
	# grow the 1st phallic (staged, seeded).
	var g1_before := float(BodyGraph.find_by_id(_holder.body["root"], "genital_1")["props"]["length_cm"])
	_on_tf("grow_first_phallic")
	for i in 4:
		_on_advance()
	var g1_after := float(BodyGraph.find_by_id(_holder.body["root"], "genital_1")["props"]["length_cm"])
	print("[pt] grew genital_1 length %.1f -> %.1f" % [g1_before, g1_after])
	if g1_after <= g1_before:
		errors.append("grow_first_phallic did not grow the member")
	# set lactating -> milk fills (instant kick) + staged production refills.
	var milk_before := int(BodyGraph.find_by_id(_holder.body["root"], "breast_l")["fluids"][0]["amount"])
	_on_tf("set_lactating")
	var milk_kick := int(BodyGraph.find_by_id(_holder.body["root"], "breast_l")["fluids"][0]["amount"])
	print("[pt] milk after set_lactating: %d -> %d" % [milk_before, milk_kick])
	if milk_kick <= milk_before:
		errors.append("set_lactating did not fill milk")
	_on_tf("lactation_production")
	for i in 4:
		_on_advance()
	var milk_prod := int(BodyGraph.find_by_id(_holder.body["root"], "breast_l")["fluids"][0]["amount"])
	print("[pt] milk after staged production: %d (cap %d)" % [milk_prod, int(BodyGraph.find_by_id(_holder.body["root"], "breast_l")["fluids"][0]["capacity"])])
	await _shot(out, "07_lactating")
	# feminize -> derived sex flips (parts only, no gender field).
	print("[pt] PRE-feminize sex: " + TfDescribe.sex_readout(_holder.body))
	_on_tf("feminize")
	print("[pt] POST-feminize sex: " + TfDescribe.sex_readout(_holder.body))
	var fem := TfDescribe.derive_sex(_holder.body)
	if fem["has_phallic"] or not fem["has_vaginal"]:
		errors.append("feminize did not flip derived sex (phallic removed, vaginal added)")
	print("[pt] post-feminize prose:\n" + _describe(_holder.body))
	await _shot(out, "08_feminized")
	# fluid save/load round-trip.
	_on_save()
	var milk_pre_load := int(BodyGraph.find_by_id(_holder.body["root"], "breast_l")["fluids"][0]["amount"])
	_on_load()
	var milk_post_load := int(BodyGraph.find_by_id(_holder.body["root"], "breast_l")["fluids"][0]["amount"])
	print("[pt] fluid round-trip: milk %d -> %d (%s)" % [milk_pre_load, milk_post_load, "OK" if milk_pre_load == milk_post_load else "DIVERGED"])
	if milk_pre_load != milk_post_load:
		errors.append("fluid amount diverged across save/load")

	# === SIZE + MEASUREMENT-STANDARD drive ===
	_reset()
	var bl = BodyGraph.find_by_id(_holder.body["root"], "breast_l")
	print("[pt] start breast volume=%d band_mm=%d" % [int(bl["props"]["volume_ml"]), int(bl["props"]["band_mm"])])
	# The same body under both standards (default METRIC) — show it re-renders.
	_std = TfMeasure.METRIC
	var metric_desc := _describe(_holder.body)
	_std = TfMeasure.IMPERIAL
	var imperial_desc := _describe(_holder.body)
	_std = TfMeasure.default_standard()
	if metric_desc == imperial_desc:
		errors.append("measurement standard switch did not change the rendering")
	print("[pt] metric breast line: " + _measurement_line(metric_desc))
	print("[pt] imperial breast line: " + _measurement_line(imperial_desc))
	await _shot(out, "09_size_metric")
	# Worked example: set a breast to (1200 ml, 810 mm ribcage) and read both standards.
	bl["props"]["volume_ml"] = 1200
	bl["props"]["band_mm"] = 810
	var met_cup := TfMeasure.cup_label(1200, 810, TfMeasure.METRIC)
	var imp_cup := TfMeasure.cup_label(1200, 810, TfMeasure.IMPERIAL)
	print("[pt] (1200,810mm) -> imperial=%s  metric=%s" % [imp_cup, met_cup])
	if imp_cup != "32DD" or met_cup != "81G":
		errors.append("worked example wrong: imperial=%s metric=%s (want 32DD / 81G)" % [imp_cup, met_cup])
	# switch the live standard and re-shoot so the PNG shows the imperial rendering.
	_on_switch_standard()
	await _shot(out, "10_size_imperial")
	_std = TfMeasure.default_standard()
	# Drive grow/shrink: cup must change with volume; widen band must lower the cup.
	_reset()
	var cup0 := TfMeasure.cup_label(_breast_vol("breast_l"), _breast_band("breast_l"), _std)
	_on_tf("grow_breasts")
	for i in 4:
		_on_advance()
	var cup_grown := TfMeasure.cup_label(_breast_vol("breast_l"), _breast_band("breast_l"), _std)
	print("[pt] grow_breasts: cup %s -> %s (vol now %d)" % [cup0, cup_grown, _breast_vol("breast_l")])
	if _breast_vol("breast_l") <= 650:
		errors.append("grow_breasts did not raise volume")
	# band-dependence at fixed volume: widen band -> smaller cup letter index.
	var diff_before := TfMeasure.diff_mm(_breast_vol("breast_l"), _breast_band("breast_l"))
	_on_tf("widen_band")
	var diff_after := TfMeasure.diff_mm(_breast_vol("breast_l"), _breast_band("breast_l"))
	print("[pt] widen_band: diff_mm %d -> %d (band %d)" % [diff_before, diff_after, _breast_band("breast_l")])
	if diff_after >= diff_before:
		errors.append("widen_band did not lower the cup difference at fixed volume")
	await _shot(out, "11_size_grown")
	# size props round-trip save/load as INTEGERS.
	_on_save()
	_on_load()
	var rv = BodyGraph.find_by_id(_holder.body["root"], "breast_l")["props"]["volume_ml"]
	var rb = BodyGraph.find_by_id(_holder.body["root"], "breast_l")["props"]["band_mm"]
	print("[pt] size round-trip: volume type=%s band type=%s" % [typeof(rv), typeof(rb)])
	if typeof(rv) != TYPE_INT or typeof(rb) != TYPE_INT:
		errors.append("size props did not round-trip as integers")

	# determinism check (independent of the live holder)
	var det_ok := _determinism_check()
	print("[pt] determinism (same seed identical, diff seed differs): %s" % det_ok)
	if not det_ok:
		errors.append("determinism check failed")

	if errors.is_empty():
		print("[pt] SELF-PLAYTEST OK — all actions driven, no logical errors")
	else:
		print("[pt] SELF-PLAYTEST ISSUES: " + ", ".join(errors))
	get_tree().quit()


func _breast_vol(id: String) -> int:
	return int(BodyGraph.find_by_id(_holder.body["root"], id)["props"]["volume_ml"])


func _breast_band(id: String) -> int:
	return int(BodyGraph.find_by_id(_holder.body["root"], id)["props"]["band_mm"])


# Pull the breast_l line out of a rendered description (for the self-playtest log).
func _measurement_line(desc: String) -> String:
	for line in desc.split("\n"):
		if "(breast_l)" in line:
			return line.strip_edges()
	return "(breast_l line not found)"


# next_stage of the named active staged TF, or -1 if it's no longer active.
func _active_stage(tf_id: String) -> int:
	for atf in _holder.active:
		if atf["tf_id"] == tf_id:
			return int(atf["next_stage"])
	return -1


# count of segments whose material == `mat`.
func _count_material(mat: String) -> int:
	var n := 0
	for seg in BodyGraph.all_segments(_holder.body["root"]):
		if seg.get("material", "") == mat:
			n += 1
	return n


func _determinism_check() -> bool:
	var a := _scripted_outcome(0xA32115)
	var b := _scripted_outcome(0xA32115)
	var c := _scripted_outcome(0xBEEF)
	return a == b and a != c


func _scripted_outcome(seed_value: int) -> String:
	var h = TfHolder.new(TfContent.biped(), seed_value, _registry)
	h.apply_instant("graft_quadruped_lower")
	h.apply_instant("graft_tail")
	h.start_tf("grow_tail_length")
	h.advance_time(900 * 6)
	# include the exact seeded tail length: the prose only shows size BANDS, so two
	# different seeds can describe identically while their rolled lengths differ.
	var tail = BodyGraph.find_by_id(h.body["root"], "tail")
	var len_cm := float(tail["props"]["length_cm"]) if tail != null else -1.0
	return TfDescribe.describe(h.body) + "\n||tail_len=%.4f" % len_cm


func _shot(out: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join("%s.png" % label)
	img.save_png(path)
	print("[pt] wrote " + path)
