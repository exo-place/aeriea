## CharacterAutosave — autoload singleton holding the player's current character so it
## survives BOTH a launcher scene switch (the creator scene is FREED on switch) AND an app
## restart. It is the persistent store the character creator reads on `_ready` and writes on
## every committed change + on `_exit_tree`.
##
## TWO tiers, one source of truth:
##   - IN-MEMORY (cross-scene): the last saved payload lives on this autoload, which the
##     launcher does NOT free, so creator → parkour → creator restores instantly with no disk
##     round-trip and no precision loss.
##   - DISK (restart): the same payload is mirrored to user://character_autosave.json so a
##     fresh process restores it on first creator load.
##
## The on-disk payload is EXACTLY the CreatorIO "history JSON" shape
## ({ current_state, history, extremeness }), so the EXISTING read side (CreatorIO.parse_payload)
## deserializes it verbatim — no second parser. This autoload is pure wiring over creator_io.gd
## + body_state.gd + history_tree.gd; it invents no new schema.
##
## Persistence is RAW (SYNTHESIS §6): a beyond-cap value (made with extremeness raised) is
## preserved and is NOT re-clamped on restore — consistent with the inward-ratchet design. The
## global `extremeness` scalar round-trips alongside the body (one scalar per save).
extends Node

const CreatorIOScript := preload("res://scripts/body/creator_io.gd")

const SAVE_PATH := "user://character_autosave.json"

## The in-memory payload (the CreatorIO history-JSON dict), or {} when nothing is saved yet.
## Survives scene switches because the launcher never frees this autoload.
var _payload: Dictionary = {}


func _ready() -> void:
	_load_from_disk()


# ---------------------------------------------------------------------------
# Public API — the creator calls save() on commit/exit and restore() on ready.
# ---------------------------------------------------------------------------

## True iff a character has been autosaved (in memory or on disk) this run.
func has_save() -> bool:
	return not _payload.is_empty()


## Autosave the current character. `body` + `tree` + `extremeness` are serialized to the
## CreatorIO history-JSON shape, held in memory (for cross-scene), and mirrored to disk (for
## restart). Cheap enough to call on every committed change.
func save(body: BodyState, tree: HistoryTree, extremeness: float = 0.0) -> void:
	if body == null:
		return
	var json := CreatorIOScript.history_to_json(body, tree, extremeness)
	var parsed = JSON.parse_string(json)
	if typeof(parsed) == TYPE_DICTIONARY:
		_payload = parsed
	_write_disk(json)


## Restore the autosaved character. Returns the CreatorIO.parse_payload result
## ({ ok, body: BodyState, tree: HistoryTree-or-null, extremeness: float }) so the caller
## applies it through the SAME raw restore path import uses. Returns ok=false when nothing is
## saved (the creator then starts a fresh default character).
func restore() -> Dictionary:
	if _payload.is_empty():
		return {"ok": false, "body": null, "tree": null, "extremeness": 0.0}
	return CreatorIOScript.parse_payload(JSON.stringify(_payload))


## Clear the autosave (memory + disk). Used by tests; not wired to a UI affordance yet.
func clear() -> void:
	_payload = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------------------------------------------------------------------
# Disk mirror
# ---------------------------------------------------------------------------

func _write_disk(json: String) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(json)
		f.close()


func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		_payload = parsed
