## FaceOverrideProfile — hard overrides for specific FaceValue channels.
##
## PORTED (Path A) from BDCC2 `Util/FaceAnimatorOverrideProfile.gd`.
##   BDCC2 is MIT, Copyright (c) 2025 Rahi (github: alexofp). See NOTICE.md.
## Path-A cut: BDCC2's loadData() used the `SAVE` autoload; replaced with a plain
## dict read (no BDCC2 autoload dependency).
##
## When a channel is overridden the rig clamps it to the given value AFTER the
## gesture stack resolves (used for e.g. a forced expression). Pure data.
class_name FaceOverrideProfile
extends RefCounted

var fields: Dictionary = {}   # face_value:int -> true
var values: Dictionary = {}   # face_value:int -> float | Vector2


func is_overridden(face_value: int) -> bool:
	return fields.has(face_value)


func get_override(face_value: int, default = 0.0):
	if not values.has(face_value) or not fields.has(face_value):
		return default
	return values[face_value]


func add_override(face_value: int) -> void:
	fields[face_value] = true


func set_value(face_value: int, val) -> void:
	values[face_value] = val


func remove_override(face_value: int) -> void:
	fields.erase(face_value)
	values.erase(face_value)


func clear() -> void:
	fields.clear()
	values.clear()
