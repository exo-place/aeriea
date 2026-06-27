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
	# Derived sex/presentation — a pure read over the configuration, never stored (§6).
	lines.append("  = sex (derived): " + sex_readout(body))
	return "\n".join(lines)


# --- derived sex / sexual presentation (§6) -------------------------------------
# Sex is a CONFIGURATION, not a stored field: a pure read over which genital/breast
# segments and tags are present. No gender enum, no stored field — a TF that grafts or
# removes a part changes this output for free. Returns booleans, counts, and an OPEN
# combinatorial token set (a body can satisfy several tokens at once, or none).
static func derive_sex(body: Dictionary) -> Dictionary:
	var root: Dictionary = body["root"]
	var phallic := 0
	var vaginal := 0
	var breasts := 0
	for seg in BodyGraph.all_segments(root):
		var tags: Array = seg.get("tags", [])
		if "genital" in tags:
			if "phallic" in tags:
				phallic += 1
			if "vaginal" in tags:
				vaginal += 1
		if "breast" in tags:
			breasts += 1
	var has_p := phallic > 0
	var has_v := vaginal > 0
	var has_b := breasts > 0
	# Open, combinatorial token mapping (content-owned, not engine-baked — §6.1).
	var tokens: Array = []
	if has_p and has_v:
		tokens.append("herm")
		tokens.append("intersex")
	elif has_p and not has_v:
		tokens.append("male")
		if has_b:
			tokens.append("busty")
	elif has_v and not has_p:
		tokens.append("female")
		if not has_b:
			tokens.append("flat")
	else:   # neither phallic nor vaginal
		if has_b:
			tokens.append("femme_neuter")
		else:
			tokens.append("neuter")
			tokens.append("agender")
	return {
		"has_phallic": has_p, "has_vaginal": has_v, "has_breasts": has_b,
		"counts": {"phallic": phallic, "vaginal": vaginal, "breast": breasts},
		"presentation_tokens": tokens,
	}


## A one-line human-readable form of derive_sex for the harness/description.
static func sex_readout(body: Dictionary) -> String:
	var s := derive_sex(body)
	var c: Dictionary = s["counts"]
	return "{%s}  (phallic=%d, vaginal=%d, breast=%d)" % [
		", ".join(s["presentation_tokens"]), c["phallic"], c["vaginal"], c["breast"]]


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
	var line: String = " ".join(bits) + " (" + seg["id"] + ")"
	# Fluid state, gated by the commitment gate (§5.3): a fluid is described ONLY if
	# the segment actually carries that entry — no phantom milk. Plain (type, band).
	var fluids: Array = seg.get("fluids", [])
	if not fluids.is_empty():
		var ordered := fluids.duplicate()
		ordered.sort_custom(func(a, b): return str(a.get("type", "")) < str(b.get("type", "")))
		var fbits: Array = []
		for f in ordered:
			fbits.append("%s %s" % [_fluid_band(int(f.get("amount", 0)), int(f.get("capacity", 0))), str(f.get("type", ""))])
		line += " [" + ", ".join(fbits) + "]"
	return line


# Fullness band for a fluid reservoir (§5.3). Sensible MVP defaults, kept simple:
# empty / low / partial / full / leaking (amount can exceed capacity only transiently;
# clamping keeps it at capacity, so "full" is the ceiling).
static func _fluid_band(amount: int, capacity: int) -> String:
	if capacity <= 0:
		return "no"     # no reservoir opened
	if amount <= 0:
		return "empty"
	var pct := float(amount) / float(capacity)
	if pct < 0.25:
		return "low"
	if pct < 0.75:
		return "partial"
	if pct < 1.0:
		return "full"
	return "brimming"


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
	# Genitalia: noun from the kind tag, clinical and setting-neutral (§4.1). The
	# `genital` tag marks membership; a kind tag (phallic/vaginal/…) gives the noun.
	if "genital" in tags:
		for kind in ["phallic", "vaginal", "cloacal", "ovipositor", "tentacular"]:
			if kind in tags:
				return "%s genital" % kind
		return "genital"
	if "breast" in tags:
		return "breast"
	# Prefer the most specific conventional tag; structural fallback if none.
	for pref in ["head", "tail", "arm", "leg", "hand", "spine", "pelvis", "torso"]:
		if pref in tags:
			return pref
	return "segment"


static func _size_band(seg: Dictionary) -> String:
	var props: Dictionary = seg.get("props", {})
	var tags: Array = seg.get("tags", [])
	# Genital size bands (§4.3) — clinical, MVP defaults, simple. Phallic reads off
	# length_cm; vaginal off depth_cm; breasts off volume_ml.
	if "genital" in tags:
		if "phallic" in tags and props.has("length_cm"):
			var pl := float(props["length_cm"])
			if pl <= 0: return ""
			if pl < 10: return "small"
			if pl < 18: return ""
			if pl < 28: return "large"
			return "huge"
		if "vaginal" in tags and props.has("depth_cm"):
			var d := float(props["depth_cm"])
			if d < 8: return "shallow"
			if d < 16: return ""
			return "deep"
		return ""
	if "breast" in tags and props.has("volume_ml"):
		var v := float(props["volume_ml"])
		if v < 200: return "small"
		if v < 700: return ""
		if v < 1200: return "large"
		return "huge"
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
