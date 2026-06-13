## CreatorIO — export / import for the character creator's body + edit history.
##
## FOUR export variants (DESIGN.md "lived history" + data-over-code at every seam —
## everything serializes to a diffable, replayable artifact):
##   1. JSON, no history  — the current BodyState dict as JSON (a portable preset).
##   2. JSON, with history — { current_state, history: <HistoryTree.to_dict()> }.
##   3. PNG, no history    — a render of the body (a shareable picture).
##   4. PNG, with history  — that PNG with the history JSON embedded in a tEXt chunk,
##                           so the image FILE round-trips back into an editable tree.
##
## IMPORT mirrors all of it: a current-only JSON sets the BodyState; a with-history
## JSON (or a PNG carrying the tEXt chunk) rebuilds the whole HistoryTree.
##
## Pure data helpers (RefCounted) so the round-trip is unit-testable headlessly; the
## creator wires its viewport/render into render_png_bytes for the actual capture.
class_name CreatorIO
extends RefCounted

const PngTextChunkScript := preload("res://scripts/util/png_text_chunk.gd")
const ImageMetadataScript := preload("res://scripts/util/image_metadata.gd")
const HistoryTreeScript := preload("res://scripts/util/history_tree.gd")

## The tEXt-chunk keyword our embedded history rides under.
const HISTORY_KEYWORD := "aeriea_history"
## Where exports land (created on demand).
const EXPORT_DIR := "user://creator_exports"


# ---------------------------------------------------------------------------
# Serialization payloads (pure; the load-bearing round-trip)
# ---------------------------------------------------------------------------

## JSON text for the current BodyState only (variant 1).
static func body_to_json(body: BodyState) -> String:
	return JSON.stringify(body.to_dict(), "  ")


## JSON text for the full history + current pointer (variant 2 / the PNG payload).
## Shape: { "current_state": <BodyState dict>, "history": <HistoryTree dict> }.
static func history_to_json(body: BodyState, tree: HistoryTree) -> String:
	return JSON.stringify({
		"current_state": body.to_dict(),
		"history": tree.to_dict(),
	}, "  ")


## Parse an import payload (the text of a variant-1, variant-2, or PNG-embedded JSON)
## into { "body": BodyState, "tree": HistoryTree-or-null, "ok": bool }.
##   - current-only JSON  -> body set, tree null (caller starts a fresh tree from it).
##   - with-history JSON  -> body + rebuilt tree.
static func parse_payload(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "body": null, "tree": null}
	var d: Dictionary = parsed
	if d.has("history") and d.has("current_state"):
		var body := BodyState.from_dict(d["current_state"])
		var tree := HistoryTreeScript.from_dict(d["history"])
		return {"ok": true, "body": body, "tree": tree}
	# Treat any other dict as a bare BodyState dict (variant 1).
	return {"ok": true, "body": BodyState.from_dict(d), "tree": null}


## Extract the embedded history JSON from PNG bytes (variant-4 import). Returns ""
## if the PNG carries no aeriea_history chunk.
static func extract_history_from_png(png: PackedByteArray) -> String:
	return PngTextChunkScript.extract(png, HISTORY_KEYWORD)


## Embed the history JSON into PNG bytes (variant-4 export).
static func embed_history_in_png(png: PackedByteArray, history_json: String) -> PackedByteArray:
	return PngTextChunkScript.embed(png, HISTORY_KEYWORD, history_json)


# ---------------------------------------------------------------------------
# Per-FORMAT image helpers (PNG / JPG / WEBP). The creator offers individual export
# actions (image / image+history) and lets the user pick the format; metadata embedding
# is format-aware via ImageMetadata. supports_image_history() tells the UI HONESTLY
# whether a format can carry the history so it can disable image+history rather than
# silently drop it.
# ---------------------------------------------------------------------------

## True iff `format` can carry embedded history (so image+history is offered for it).
static func supports_image_history(format: String) -> bool:
	return ImageMetadataScript.supports_metadata(format)


## Encode `img` to `format`'s bytes (no metadata).
static func encode_image(img: Image, format: String) -> PackedByteArray:
	return ImageMetadataScript.encode(img, format)


## Embed the history JSON into already-encoded image `bytes` of `format`. Returns the
## input unchanged if the format can't carry metadata.
static func embed_history_in_image(bytes: PackedByteArray, format: String, history_json: String) -> PackedByteArray:
	return ImageMetadataScript.embed(bytes, format, HISTORY_KEYWORD, history_json)


## Extract embedded history JSON from image `bytes` of `format` (import). "" if absent.
static func extract_history_from_image(bytes: PackedByteArray, format: String) -> String:
	return ImageMetadataScript.extract(bytes, format, HISTORY_KEYWORD)


# ---------------------------------------------------------------------------
# Filesystem export (the four files). Returns a dict of variant -> absolute path.
# `png_bytes` is the already-captured viewport render (may be empty to skip PNGs).
# ---------------------------------------------------------------------------

static func ensure_export_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(EXPORT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))


## Write every applicable variant. `basename` is the stem (e.g. "body_2026"). PNG
## variants are skipped if `png_bytes` is empty. Returns { variant_key: path }.
static func export_all(body: BodyState, tree: HistoryTree, basename: String,
		png_bytes: PackedByteArray = PackedByteArray()) -> Dictionary:
	ensure_export_dir()
	var out: Dictionary = {}

	# Variant 1: JSON, no history.
	var p1 := "%s/%s.json" % [EXPORT_DIR, basename]
	_write_text(p1, body_to_json(body))
	out["json"] = ProjectSettings.globalize_path(p1)

	# Variant 2: JSON, with history.
	var hist_json := history_to_json(body, tree)
	var p2 := "%s/%s.history.json" % [EXPORT_DIR, basename]
	_write_text(p2, hist_json)
	out["json_history"] = ProjectSettings.globalize_path(p2)

	if not png_bytes.is_empty():
		# Variant 3: PNG, no history.
		var p3 := "%s/%s.png" % [EXPORT_DIR, basename]
		_write_bytes(p3, png_bytes)
		out["png"] = ProjectSettings.globalize_path(p3)

		# Variant 4: PNG, with embedded history.
		var p4 := "%s/%s.history.png" % [EXPORT_DIR, basename]
		_write_bytes(p4, embed_history_in_png(png_bytes, hist_json))
		out["png_history"] = ProjectSettings.globalize_path(p4)

	return out


# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------

static func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


static func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
