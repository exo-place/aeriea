## A part in a body tree — a PLAIN STRUCT and nothing more.
##
## A part is: a bag of named fields (each holding a plain value — number / string
## / bool / list / dict), an ordered list of children, and a parent link. That is
## the entire state model. A field holds a VALUE; you read it directly
## (`part.fields["kind"]`). There is no value|expr union, no cell, no accessor, no
## discriminator, no id. A body is the root part plus its subtree.
##
## Behaviour is NOT here. Parts carry no transformation code. A transformation is
## a separate, stateless plain function (see tf_engine.gd) that reads the tree and
## writes new field values into parts. Data and computation are separate.
##
## A part's ACTIVE TRANSITIONS live in an ordinary field — `fields["transitions"]`,
## a plain Array of plain dicts. Appending one starts it; list POSITION is recency
## (the last element is "most recent"). Each entry carries its own accumulated
## progress, so parallel entries advance independently and out of step. The list is
## just data like any other field.
class_name TFPart
extends RefCounted

var parent: TFPart = null           ## parent link (null at the root)
var children: Array = []            ## ordered Array[TFPart]
var fields: Dictionary = {}         ## plain field name -> plain value


## Make a part with an initial field bag. `f` is copied shallowly into fields.
static func make(f: Dictionary = {}) -> TFPart:
	var p := TFPart.new()
	for k in f:
		p.fields[k] = f[k]
	return p


## Attach `c` as the last child of this part. Attachment is the SINGLE source of
## truth for where a part is — location is structural, never a field.
func add_child(c: TFPart) -> TFPart:
	c.parent = self
	children.append(c)
	return c


## Detach this part from its parent (structural remove). Identity (its fields)
## is untouched — what a part IS travels with it wherever it is re-attached.
func detach() -> void:
	if parent != null:
		parent.children.erase(self)
		parent = null


## The list of active transitions on this part (a plain Array field). Created
## lazily so a bare part needs no ceremony. Appending to the returned Array starts
## a transition; its position in the Array is its recency.
func transitions() -> Array:
	if not fields.has("transitions"):
		fields["transitions"] = []
	return fields["transitions"]


## Deep structural + field copy of this subtree (parent of the copy is null).
## Used for replay comparison and for capturing a tree without aliasing.
func clone() -> TFPart:
	var c := TFPart.new()
	c.fields = _deep_copy_value(fields)
	for ch in children:
		c.add_child(ch.clone())
	return c


## Deep equality of two subtrees: same field bags (deep) and same ordered
## children (deep). Parent links are implied by structure, not compared directly.
static func deep_equals(a: TFPart, b: TFPart) -> bool:
	if a == null or b == null:
		return a == b
	if not _values_equal(a.fields, b.fields):
		return false
	if a.children.size() != b.children.size():
		return false
	for i in range(a.children.size()):
		if not deep_equals(a.children[i], b.children[i]):
			return false
	return true


## A stable, human-readable dump of a subtree (fields + children), for diffing
## in tests. Deterministic key order so two equal trees stringify identically.
func to_debug() -> Dictionary:
	var kids: Array = []
	for ch in children:
		kids.append(ch.to_debug())
	return {"fields": _sorted(fields), "children": kids}


static func _sorted(d: Dictionary) -> Dictionary:
	var keys := d.keys()
	keys.sort()
	var out := {}
	for k in keys:
		out[k] = d[k]
	return out


static func _deep_copy_value(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _deep_copy_value(v[k])
		return out
	if v is Array:
		var out := []
		for e in v:
			out.append(_deep_copy_value(e))
		return out
	return v


static func _values_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k):
				return false
			if not _values_equal(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _values_equal(a[i], b[i]):
				return false
		return true
	# Numbers: compare with type tolerance (int/float) but exact value.
	return a == b
