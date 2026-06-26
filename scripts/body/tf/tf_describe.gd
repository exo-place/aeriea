## TfDescribe — state-derived body description by graph traversal (TF system §6).
##
## Prose is RE-DERIVED on every read by walking the graph; never stored. For each
## segment it reads the visible surface (covering for flesh; the material itself for
## chitin/slime, which ARE the surface — §6), the convention tags (for the noun), and
## scalar props (for size bands). Transition zones (§6) are described at attachment
## points where parent/child surfaces differ. The commitment gate (§6) is structural:
## a feature is mentioned ONLY if a segment actually carries it — no phantom parts.
##
## Aliases (§3.6) are OPTIONAL shorthand bound to tag-set configurations, with a
## STRUCTURAL FALLBACK when none match (always available). Deep prose quality is OUT
## of scope (§6) — this is a plain descriptor traversal, setting-neutral, no lore.
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")

# Optional aliases: a tag-set -> short label. Surfaced when a body's tags are a
# superset of an alias's required tags. Open, conventional, unenforced (§3.6).
const ALIASES := [
	{"label": "taur", "require": ["upper_body", "lower_body", "spine"]},
]


## Top-level: a structural one-line summary, then a per-segment description, then any
## transition zones. Pure function of the body dict.
static func describe(body: Dictionary) -> String:
	var root: Dictionary = body["root"]
	var lines: Array = []
	lines.append("Form: " + _form_summary(root))
	for seg in BodyGraph.all_segments(root):
		lines.append("  - " + _describe_segment(seg))
	var zones := _transition_zones(root)
	for z in zones:
		lines.append("  ~ " + z)
	return "\n".join(lines)


# --- form summary: alias if one matches, else structural (§3.6 fallback) ---------

static func _form_summary(root: Dictionary) -> String:
	var all_tags := {}
	for seg in BodyGraph.all_segments(root):
		for t in seg.get("tags", []):
			all_tags[t] = true
	# Try aliases (total-ordered by label for determinism).
	var matched: Array = []
	for alias in ALIASES:
		var ok := true
		for req in alias["require"]:
			if not all_tags.has(req):
				ok = false
				break
		if ok:
			matched.append(alias["label"])
	matched.sort()
	# Always available: a structural fallback describing the leg/limb count.
	var structural := _structural_form(root)
	if matched.is_empty():
		return structural
	return "%s (%s)" % [", ".join(matched), structural]


static func _structural_form(root: Dictionary) -> String:
	var legs := 0
	var arms := 0
	var has_tail := false
	for seg in BodyGraph.all_segments(root):
		var tags: Array = seg.get("tags", [])
		if "leg" in tags:
			legs += 1
		if "arm" in tags:
			arms += 1
		if "tail" in tags:
			has_tail = true
	var bits: Array = []
	bits.append("%d-limbed upper body" % arms if arms != 1 else "1-armed upper body")
	bits.append("%d-legged lower body" % legs)
	if has_tail:
		bits.append("tailed")
	return ", ".join(bits)


# --- per-segment phrase ---------------------------------------------------------

static func _describe_segment(seg: Dictionary) -> String:
	var noun := _noun_for_tags(seg.get("tags", []))
	var surface := _surface_word(seg)
	var size := _size_band(seg)
	var bits: Array = []
	if size != "":
		bits.append(size)
	if surface != "":
		bits.append(surface)
	bits.append(noun)
	return " ".join(bits) + " (" + seg["id"] + ")"


# The visible surface: covering for flesh-type; the material itself otherwise (§6).
static func _surface_word(seg: Dictionary) -> String:
	var material: String = seg.get("material", "")
	if BodyGraph.material_takes_covering(material):
		var cov = seg.get("covering")
		if cov == null:
			return material  # flesh with no covering yet: name the material
		return "%s-covered" % cov
	return material  # chitin / slime — the material is the surface


static func _noun_for_tags(tags: Array) -> String:
	# Prefer the most specific conventional tag; structural fallback if none.
	for pref in ["head", "tail", "arm", "leg", "hand", "spine", "torso"]:
		if pref in tags:
			return pref
	return "segment"


static func _size_band(seg: Dictionary) -> String:
	var props: Dictionary = seg.get("props", {})
	if props.has("length_cm"):
		var l: float = float(props["length_cm"])
		if l <= 0:
			return ""
		if l < 20:
			return "short"
		if l < 70:
			return ""   # ordinary — no adjective
		if l < 100:
			return "long"
		return "very long"
	return ""


# --- transition zones (§6): parent/child surface mismatch at an attachment --------

static func _transition_zones(root: Dictionary) -> Array:
	var out: Array = []
	_walk_zones(root, out)
	return out


static func _walk_zones(seg: Dictionary, out: Array) -> void:
	var parent_surface := _surface_word(seg)
	var kids: Array = seg.get("children", [])
	var ordered := kids.duplicate()
	ordered.sort_custom(func(a, b): return str(a["node"]["id"]) < str(b["node"]["id"]))
	for edge in ordered:
		var  child_seg: Dictionary = edge["node"]
		var child_surface := _surface_word(child_seg)
		if child_surface != parent_surface and parent_surface != "" and child_surface != "":
			out.append("at the %s, %s gives way to %s" % [edge["at"], parent_surface, child_surface])
		_walk_zones(child_seg, out)
