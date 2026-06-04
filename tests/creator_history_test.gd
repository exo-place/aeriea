## Character-creator HISTORY + EXPORT test suite. Proves the branching undo TREE,
## the four export variants' round-trips, and determinism — all headless.
##
##   - linear commit/undo/redo;
##   - BRANCH-ON-EDIT: undo then commit adds a SIBLING; the old subtree survives and
##     stays reachable via jump_to;
##   - jump_to arbitrary node restores its state;
##   - redo follows the preferred (most-recent) branch;
##   - HistoryTree to_dict/from_dict round-trip (identical structure + current + counter);
##   - PNG tEXt embed -> extract round-trip on real save_png bytes;
##   - JSON-with-history export -> import round-trip reproduces the tree;
##   - determinism: identical commit sequences yield identical ids/structure twice.
##
## Run windowed under xvfb:
##   xvfb-run -a godot4 --path . res://tests/creator_history_test.tscn --quit-after 8000
## Calls quit(0) iff every assertion passed, else quit(1).
extends Node

const HistoryTreeScript := preload("res://scripts/util/history_tree.gd")
const PngTextChunkScript := preload("res://scripts/util/png_text_chunk.gd")
const CreatorIOScript := preload("res://scripts/body/creator_io.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("\n=== aeriea creator HISTORY + EXPORT (undo-tree, 4 export variants) ===\n")
	_test_linear()
	_test_branch_on_edit()
	_test_jump_to()
	_test_redo_preferred()
	_test_tree_roundtrip()
	_test_png_chunk_roundtrip()
	_test_json_history_roundtrip()
	_test_determinism()
	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# ---------------------------------------------------------------------------

func _test_linear() -> void:
	print("--- linear commit / undo / redo ---")
	var t := HistoryTreeScript.new({"v": 0}, "root")
	_assert("fresh tree cannot undo (at root)", not t.can_undo(), "")
	_assert("fresh tree cannot redo (leaf)", not t.can_redo(), "")
	t.commit({"v": 1}, "a")
	t.commit({"v": 2}, "b")
	_assert("after 2 commits current state v=2", int(t.current_state()["v"]) == 2, str(t.current_state()))
	_assert("can_undo true with history", t.can_undo(), "")
	t.undo()
	_assert("undo -> v=1", int(t.current_state()["v"]) == 1, str(t.current_state()))
	t.undo()
	_assert("undo -> v=0 (root)", int(t.current_state()["v"]) == 0, str(t.current_state()))
	_assert("undo at root is no-op", not t.undo() and int(t.current_state()["v"]) == 0, "")
	t.redo()
	t.redo()
	_assert("redo x2 -> v=2 (follows the only path)", int(t.current_state()["v"]) == 2, str(t.current_state()))
	_assert("redo at leaf is no-op", not t.redo(), "")


func _test_branch_on_edit() -> void:
	print("--- BRANCH-ON-EDIT: undo then commit preserves the old subtree ---")
	var t := HistoryTreeScript.new({"v": 0}, "root")
	var a := t.commit({"v": "A"}, "A")
	var b := t.commit({"v": "B"}, "B")  # path: root -> A -> B, current = B
	t.undo()                            # back to A
	_assert("undone to A", t.current_id() == a, "current=%d a=%d" % [t.current_id(), a])
	var c := t.commit({"v": "C"}, "C")  # NEW sibling branch off A
	_assert("current path is A -> C", t.current_id() == c and t.parent_of(c) == a,
		"current=%d parent(c)=%d a=%d" % [t.current_id(), t.parent_of(c), a])
	# B's subtree must STILL EXIST (this is the tree, not a stack).
	_assert("B node still exists after the branching commit", t.has_node(b), "")
	_assert("A now has TWO children (B and C)", t.children_of(a).size() == 2,
		"children(A)=%s" % str(t.children_of(a)))
	# And B is reachable via jump_to.
	t.jump_to(b)
	_assert("B reachable via jump_to (state preserved)", t.current_state()["v"] == "B", str(t.current_state()))


func _test_jump_to() -> void:
	print("--- jump_to arbitrary node restores its state ---")
	var t := HistoryTreeScript.new({"v": 0}, "root")
	var ids: Array = [0]
	for i in range(1, 5):
		ids.append(t.commit({"v": i}, "n%d" % i))
	_assert("jump_to unknown id fails", not t.jump_to(999), "")
	for i in range(ids.size()):
		t.jump_to(int(ids[i]))
		_assert("jump_to node %d -> v=%d" % [ids[i], i], int(t.current_state()["v"]) == i, str(t.current_state()))


func _test_redo_preferred() -> void:
	print("--- redo follows the preferred (most-recent) branch ---")
	var t := HistoryTreeScript.new({"v": 0}, "root")
	var a := t.commit({"v": "A"}, "A")
	t.undo()                            # at root
	var b := t.commit({"v": "B"}, "B")  # B is the more-recent child of root
	t.undo()                            # at root again; preferred child should be B
	t.redo()
	_assert("redo follows the most-recently-created branch (B, not A)",
		t.current_id() == b, "current=%d a=%d b=%d" % [t.current_id(), a, b])
	# Now visit A via jump_to; that updates the preferred path. Undo to root, redo -> A.
	t.jump_to(a)
	t.undo()
	t.redo()
	_assert("redo follows the most-recently-VISITED branch after jump_to (A)",
		t.current_id() == a, "current=%d a=%d" % [t.current_id(), a])


func _test_tree_roundtrip() -> void:
	print("--- HistoryTree to_dict / from_dict round-trip ---")
	var t := HistoryTreeScript.new({"v": 0}, "root")
	var a := t.commit({"v": "A"}, "A")
	t.commit({"v": "B"}, "B")
	t.undo()
	t.commit({"v": "C"}, "C")  # branch -> A has children B and C
	t.jump_to(a)
	var d := t.to_dict()
	var back: HistoryTree = HistoryTreeScript.from_dict(d)
	_assert("round-trip preserves node count", back.node_count() == t.node_count(),
		"%d vs %d" % [back.node_count(), t.node_count()])
	_assert("round-trip preserves current id", back.current_id() == t.current_id(),
		"%d vs %d" % [back.current_id(), t.current_id()])
	_assert("round-trip preserves structure (identical to_dict)",
		JSON.stringify(back.to_dict()) == JSON.stringify(t.to_dict()), "")
	# id counter preserved: next commit gets the same id on both.
	var id_orig := t.commit({"v": "D"}, "D")
	var id_back := back.commit({"v": "D"}, "D")
	_assert("round-trip preserves id counter (next commit id matches)", id_orig == id_back,
		"orig=%d back=%d" % [id_orig, id_back])


func _test_png_chunk_roundtrip() -> void:
	print("--- PNG tEXt embed -> extract round-trip ---")
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.6, 1.0))
	var png := img.save_png_to_buffer()
	_assert("base PNG has IEND (valid)", PngTextChunkScript._find_chunk_start(png, "IEND") >= 0, "")
	var payload := '{"hello":"wörld","nested":[1,2,3]}'  # non-ASCII to exercise UTF-8
	var embedded := PngTextChunkScript.embed(png, "aeriea_history", payload)
	_assert("embed grows the byte stream", embedded.size() > png.size(),
		"%d -> %d" % [png.size(), embedded.size()])
	# Embedded PNG is still loadable as an image (the tEXt chunk is ancillary).
	var reimg := Image.new()
	var load_err := reimg.load_png_from_buffer(embedded)
	_assert("embedded PNG still decodes as a valid image", load_err == OK, "err=%d" % load_err)
	var got := PngTextChunkScript.extract(embedded, "aeriea_history")
	_assert("extract returns the exact embedded payload", got == payload, "got=%s" % got)
	_assert("extract of a missing keyword returns empty",
		PngTextChunkScript.extract(embedded, "nope") == "", "")
	# CRC sanity: a known PNG CRC value for the IEND chunk type+data (empty data) is 0xAE426082.
	_assert("crc32 matches the known PNG IEND value",
		PngTextChunkScript.crc32("IEND".to_ascii_buffer()) == 0xAE426082,
		"%08X" % PngTextChunkScript.crc32("IEND".to_ascii_buffer()))


func _test_json_history_roundtrip() -> void:
	print("--- JSON-with-history export -> import round-trip ---")
	var body := BodyState.new()
	body.age_years = 33.0
	body.masculinity = 70.0
	var t := HistoryTreeScript.new(BodyState.new().to_dict(), "initial")
	t.commit({"age_years": 30.0, "masculinity": 50.0, "muscle": 50.0, "weight": 100.0, "proportions": 0.5, "height_cm": 166.589}, "age = 30")
	t.commit(body.to_dict(), "masculinity = 70%")
	var json := CreatorIOScript.history_to_json(body, t)
	var parsed := CreatorIOScript.parse_payload(json)
	_assert("with-history payload parses ok", bool(parsed["ok"]) and parsed["tree"] != null, "")
	var body2: BodyState = parsed["body"]
	_assert("import reproduces current BodyState",
		is_equal_approx(body2.age_years, 33.0) and is_equal_approx(body2.masculinity, 70.0),
		"age=%.1f masc=%.1f" % [body2.age_years, body2.masculinity])
	var t2: HistoryTree = parsed["tree"]
	_assert("import reproduces the tree (identical to_dict)",
		JSON.stringify(t2.to_dict()) == JSON.stringify(t.to_dict()), "")
	_assert("import reproduces current pointer", t2.current_id() == t.current_id(), "")
	# Current-only JSON (variant 1) imports as a body with no tree.
	var p1 := CreatorIOScript.parse_payload(CreatorIOScript.body_to_json(body))
	_assert("current-only JSON imports body, tree null",
		bool(p1["ok"]) and p1["tree"] == null and is_equal_approx((p1["body"] as BodyState).age_years, 33.0),
		"")
	# And the full PNG-with-history file round-trips the tree back out.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var png_h := CreatorIOScript.embed_history_in_png(img.save_png_to_buffer(), json)
	var extracted := CreatorIOScript.extract_history_from_png(png_h)
	var p_png := CreatorIOScript.parse_payload(extracted)
	_assert("PNG-with-history round-trips the tree",
		p_png["tree"] != null and JSON.stringify((p_png["tree"] as HistoryTree).to_dict()) == JSON.stringify(t.to_dict()),
		"")


func _test_determinism() -> void:
	print("--- determinism: identical commit sequences -> identical ids/structure ---")
	var seq := [["A", {"v": 1}], ["B", {"v": 2}], ["C", {"v": 3}]]
	var t1 := _run_seq(seq)
	var t2 := _run_seq(seq)
	_assert("same sequence yields byte-identical to_dict twice",
		JSON.stringify(t1.to_dict()) == JSON.stringify(t2.to_dict()), "")
	# Determinism holds even with undo/branch in the sequence.
	var t3 := HistoryTreeScript.new({"v": 0}, "root")
	var t4 := HistoryTreeScript.new({"v": 0}, "root")
	for tt in [t3, t4]:
		tt.commit({"v": 1}, "A")
		tt.commit({"v": 2}, "B")
		tt.undo()
		tt.commit({"v": 3}, "C")
	_assert("branching sequence is deterministic too",
		JSON.stringify(t3.to_dict()) == JSON.stringify(t4.to_dict()), "")
	_assert("no wall-clock in ids: ids are 0..N monotonic",
		t3.has_node(0) and t3.has_node(1) and t3.has_node(2) and t3.has_node(3) and not t3.has_node(4), "")


func _run_seq(seq: Array) -> HistoryTree:
	var t := HistoryTreeScript.new({"v": 0}, "root")
	for step in seq:
		t.commit(step[1], step[0])
	return t


# ---------------------------------------------------------------------------

func _assert(name: String, cond: bool, evidence: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s  [%s]" % [name, evidence])
	else:
		_fail += 1
		print("  FAIL  %s  [%s]" % [name, evidence])
