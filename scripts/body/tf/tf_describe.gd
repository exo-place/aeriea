## TfDescribe — state-derived body description by graph traversal (TF system §6).
##
## Prose is RE-DERIVED on every read by walking the graph; never stored. For each
## segment it reads the visible surface (covering for flesh; the material itself for
## chitin/slime, which ARE the surface — §6), the convention tags (for the noun), and
## scalar props (for size bands). Transition zones (§6) are described at attachment
## points where parent/child surfaces differ. The commitment gate (§6) is structural:
## a feature is mentioned ONLY if a segment actually carries it — no phantom parts.
##
## `describe()` is the DEFAULT, user-facing surface: clean, plain English prose with NO
## node ids, NO bracketed/angle engine state, NO debug sex counts, NO duplicated seam
## lines. It is plain and functional (not the deferred rich-prose realizer) — symmetric
## parts collapse ("two bare-skinned arms"), sizes read in words ("a C cup", "about
## 15 cm"), fluids read as states ("lactating"), and derived sex reads as a sentence.
##
## `debug_dump()` is the SEPARATE verbose readout (raw ids, props, fluid bands, counts)
## kept for tests/diagnostics — never shown to the player.
##
## Aliases (§3.6) are OPTIONAL shorthand bound to tag-set configurations, with a
## STRUCTURAL FALLBACK when none match (always available). Deep prose quality is OUT
## of scope (§6) — this is a plain descriptor traversal, setting-neutral, no lore.
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")
const TfMeasure := preload("res://scripts/body/tf/tf_measure.gd")

# Optional form aliases: a structural predicate -> short label. Open, conventional,
# unenforced (§3.6). They key off a SECOND body-core lower segment — a node tagged both
# `body_core` AND `lower_body` (a horizontal barrel or a serpentine lower carrying the
# weight, distinct from the upright torso). A plain biped has NO lower-body part at all —
# its legs hang off the torso, and the torso is `body_core`/`upper_body` only (never
# `lower_body`) — so these never false-match a biped. No special `spine` tag: a barrel and
# a torso are both body-core.
#   - a serpentine (legless) lower  -> "naga"
#   - any other body-core lower      -> "taur"
static func _form_alias(root: Dictionary):
	for seg in BodyGraph.all_segments(root):
		var tags: Array = seg.get("tags", [])
		if "body_core" in tags and "lower_body" in tags:
			return "naga" if "serpentine" in tags else "taur"
	return null


## DEFAULT user-facing description: plain English prose, no engine artifacts. A form
## line, then the notable parts (symmetric parts collapsed, sizes/fluids in words), then
## any transition zones (de-duplicated), then a one-sentence read of the derived sex.
## Pure function of the body dict + the measurement standard (a describe-layer parameter,
## NOT stored on the body — the SAME body re-renders "a C cup" under METRIC vs IMPERIAL
## once a size differs). Omit `std` to use the default standard.
static func describe(body: Dictionary, std: Dictionary = {}) -> String:
	if std.is_empty():
		std = TfMeasure.default_standard()
	var root: Dictionary = body["root"]
	var lines: Array = []
	lines.append(_form_summary(root))
	# A single body-coat line for a non-default covering/material (fur/scales/chitin/…)
	# so the surface reads once instead of being inventoried per segment.
	var coat := _body_coat_line(root)
	if coat != "":
		lines.append("  " + coat + ".")
	# The figure line: a derived BWH read (shape/build/descriptors + the triple), woven as
	# clean prose. Sits right under the form/coat lines, before the notable-part bullets.
	var figure := _figure_line(root, std)
	if figure != "":
		lines.append("  " + figure)
	for phrase in _part_phrases(root, std):
		lines.append("  " + phrase + ".")
	# Transition zones, de-duplicated (symmetric parts share one seam description).
	var seen_zones := {}
	for z in _transition_zones(root):
		if not seen_zones.has(z):
			seen_zones[z] = true
			lines.append("  " + _capitalize(z) + ".")
	lines.append("  " + sex_sentence(body))
	return "\n".join(lines)


## SEPARATE verbose readout for tests/diagnostics — raw ids, props, fluid bands, derived
## sex counts. Never shown to the player. (The old debug-shaped describe() output.)
static func debug_dump(body: Dictionary, std: Dictionary = {}) -> String:
	if std.is_empty():
		std = TfMeasure.default_standard()
	var root: Dictionary = body["root"]
	var lines: Array = []
	lines.append("Form: " + _form_summary_raw(root))
	for seg in BodyGraph.all_segments(root):
		lines.append("  - " + _debug_segment(seg, std))
	for z in _transition_zones(root):
		lines.append("  ~ " + z)
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


## A one-line DEBUG form of derive_sex (counts + token set) for diagnostics/tests.
## NOT player-facing — `sex_sentence` is the prose version.
static func sex_readout(body: Dictionary) -> String:
	var s := derive_sex(body)
	var c: Dictionary = s["counts"]
	return "{%s}  (phallic=%d, vaginal=%d, breast=%d)" % [
		", ".join(s["presentation_tokens"]), c["phallic"], c["vaginal"], c["breast"]]


## Plain-prose read of the derived sex, e.g. "She reads as a herm." / "He reads as a
## man." / "They read as neuter." No counts, no token sets — a single sentence.
static func sex_sentence(body: Dictionary) -> String:
	var s := derive_sex(body)
	var has_p: bool = s["has_phallic"]
	var has_v: bool = s["has_vaginal"]
	var has_b: bool = s["has_breasts"]
	if has_p and has_v:
		return "She reads as a herm."
	if has_p and not has_v:
		if has_b:
			return "He reads as a busty man."
		return "He reads as a man."
	if has_v and not has_p:
		if has_b:
			return "She reads as a woman."
		return "She reads as a flat-chested woman."
	# Neither phallic nor vaginal.
	if has_b:
		return "She reads as a soft, sexless figure."
	return "They read as sexless."


# --- form summary: alias if one matches, else structural (§3.6 fallback) ---------

# Player-facing form line, e.g. "She has the build of a taur: a two-armed torso over a
# four-legged lower body, with a tail." Plain, no parenthetical engine label.
static func _form_summary(root: Dictionary) -> String:
	var alias = _form_alias(root)
	var structural := _structural_clause(root)
	if alias == null:
		return _capitalize(structural) + "."
	return "She has the build of a %s: %s." % [alias, structural]


# The structural form as a readable clause: upper limbs (arms/wings), lower body, tail.
static func _structural_clause(root: Dictionary) -> String:
	var legs := 0
	var arms := 0
	var wings := 0
	var has_tail := false
	for seg in BodyGraph.all_segments(root):
		var tags: Array = seg.get("tags", [])
		if "leg" in tags:
			legs += 1
		if "arm" in tags:
			arms += 1
		if "wing" in tags:
			wings += 1
		if "tail" in tags:
			has_tail = true
	var clause := "%s torso over %s" % [_upper_clause(arms, wings), _lower_clause(legs)]
	if has_tail:
		clause += ", with a tail"
	return clause


# The upper-limb half of the form clause, articled, reading what is ACTUALLY there. A
# harpy's wings ARE its forelimbs, so a winged-but-armless torso reads "winged", never
# "armless"; a six-limbed dragon (arms AND wings) reads as both; "armless" is reserved for
# a torso with no upper limbs at all.
static func _upper_clause(arms: int, wings: int) -> String:
	if wings > 0 and arms > 0:
		return "a winged, %s-armed" % _num_word(arms)
	if wings > 0:
		return "a winged"
	if arms > 0:
		return "a %s-armed" % _num_word(arms)
	return "an armless"


# The lower-body half of the form clause, reading from the leg count.
static func _lower_clause(legs: int) -> String:
	if legs <= 0:
		return "a legless lower body"
	return "a %s-legged lower body" % _num_word(legs)


# Small integers as words; falls back to the digit for large counts.
static func _num_word(n: int) -> String:
	var words := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight"]
	if n >= 0 and n < words.size():
		return words[n]
	return str(n)


# Raw structural form (ids/counts) for debug_dump only.
static func _form_summary_raw(root: Dictionary) -> String:
	var alias = _form_alias(root)
	var structural := _structural_form_raw(root)
	if alias == null:
		return structural
	return "%s (%s)" % [alias, structural]


static func _structural_form_raw(root: Dictionary) -> String:
	var legs := 0
	var arms := 0
	var wings := 0
	var has_tail := false
	for seg in BodyGraph.all_segments(root):
		var tags: Array = seg.get("tags", [])
		if "leg" in tags:
			legs += 1
		if "arm" in tags:
			arms += 1
		if "wing" in tags:
			wings += 1
		if "tail" in tags:
			has_tail = true
	var bits: Array = []
	bits.append("%d-armed upper body" % arms)
	if wings > 0:
		bits.append("%d-winged" % wings)
	bits.append("%d-legged lower body" % legs)
	if has_tail:
		bits.append("tailed")
	return ", ".join(bits)


# --- per-segment player prose ---------------------------------------------------

# Collapse the NOTABLE segments into player phrases: identical descriptions for symmetric
# parts merge into a count ("two large breasts"), preserving first-seen order. Baseline
# gross-anatomy parts (a plain torso/head/arms/legs/trunk) are NOT listed — the form line
# already conveys them; only distinctive features and sizes are bulleted (a description,
# not a parts inventory).
static func _part_phrases(root: Dictionary, std: Dictionary) -> Array:
	var order: Array = []        # phrase (singular) in first-seen order
	var counts := {}
	var pluralizers := {}        # singular -> plural form, captured once
	for seg in BodyGraph.all_segments(root):
		if not _is_notable(seg, std):
			continue
		var p := _segment_phrase(seg, std)
		if p["text"] == "":
			continue
		var key: String = p["text"]
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
			pluralizers[key] = p["plural"]
		counts[key] += 1
	var out: Array = []
	for key in order:
		var n: int = counts[key]
		if n == 1:
			out.append("- " + _capitalize(_article(key) + " " + key))
		else:
			out.append("- %s %s" % [_num_word(n).capitalize(), pluralizers[key]])
	return out


# Baseline gross-anatomy nouns that the form line already conveys — never bulleted on
# their own (a plain one of these is implied by "a two-armed torso over a two-legged
# lower body"). A distinctive SIZE or a NOTABLE role still promotes the segment.
const _BASELINE_NOUNS := ["torso", "head", "arm", "leg", "hand", "barrel",
	"serpentine lower body"]

# Roles that are always notable features worth a bullet (regardless of size/surface).
const _FEATURE_NOUNS := ["breast", "penis", "vagina", "vulva", "cloaca", "tentacle",
	"ovipositor", "genitals", "butt", "tail", "wing", "horn", "ear", "claw", "hoof",
	"udder", "teat", "nipple"]


# Is this segment worth a bullet? A feature part always is; a baseline structural part
# (torso/head/arms/legs/trunk) only when it carries a distinctive size band (long legs,
# a short fae torso). Plain baseline parts are implied by the form line and stay silent.
static func _is_notable(seg: Dictionary, _std: Dictionary) -> bool:
	var noun := _noun_for_tags(seg.get("tags", []))
	if noun in _FEATURE_NOUNS:
		return true
	# Hands and feet are implied by their limb (arm/leg count in the form line) — never
	# bulleted on their own.
	if noun == "hand" or noun == "foot":
		return false
	if noun in _BASELINE_NOUNS:
		return _size_band(seg) != ""
	# An unrecognized/other segment: bullet it (better seen than silently dropped).
	return true


# A single line for the body's overall non-default coat (covering or material), read off
# the body-core trunk so a uniformly-furred/scaled/chitin body says it ONCE rather than
# repeating the surface on every segment. Empty for an ordinary bare-skinned body.
static func _body_coat_line(root: Dictionary) -> String:
	var trunk = _trunk_segment(root)
	if trunk == null:
		return ""
	var material: String = trunk.get("material", "")
	if not BodyGraph.material_takes_covering(material):
		# The material IS the surface (chitin/slime/…): "A body of living slime."
		return "A body of %s" % _humanize(material)
	var cov = trunk.get("covering")
	if cov == null or cov == "skin":
		return ""
	# Flesh with a non-skin covering: "Covered in fur." / "Covered in red fur."
	return "Covered in %s" % _humanize(str(cov))


# The body-core trunk that carries the body's overall surface — the upright torso (the
# upper_body core). Returns null if none found.
static func _trunk_segment(root: Dictionary):
	for seg in BodyGraph.all_segments(root):
		var tags: Array = seg.get("tags", [])
		if "body_core" in tags and "upper_body" in tags:
			return seg
	return null


# --- figure (BWH) line ----------------------------------------------------------
# The figure is a MEASUREMENT, never a part: waist_mm/hip_mm (millimeters) are stored on the
# body-core carrier (the `groin_mount` segment — the torso for a biped, the barrel/serpent
# lower for a taur/naga), the bust is derived from the ribcage band + total breast volume. NONE of
# this ever becomes a "hips"/"pelvis" bullet — it reads as one prose sentence about the
# overall figure, with the descriptive bands owned by the active standard (configurable).

# The segment that carries the lower-body measurements: the `groin_mount` segment (the
# part the legs/genitals hang off — a biped's torso, a taur's barrel, a naga's serpent).
# Falls back to the upright trunk, then null.
static func _figure_carrier(root: Dictionary):
	# Prefer a dedicated lower-body carrier (a taur barrel / naga serpent) when one exists —
	# it owns the lower figure once the body has a distinct lower body. A plain biped has no
	# such part, so it falls back to its torso (the groin_mount it carries directly).
	var fallback = null
	for seg in BodyGraph.all_segments(root):
		var tags: Array = seg.get("tags", [])
		if "groin_mount" not in tags:
			continue
		if "lower_body" in tags:
			return seg
		if fallback == null:
			fallback = seg
	if fallback != null:
		return fallback
	return _trunk_segment(root)


# The plain-prose figure sentence (or "" when the carrier has no waist/hip to read). Reads
# like "An hourglass figure, wide-hipped — 90-62-90." — a shape/build clause, optional
# targeted descriptors, then the measurement triple in the standard's unit.
static func _figure_line(root: Dictionary, std: Dictionary) -> String:
	var carrier = _figure_carrier(root)
	if carrier == null:
		return ""
	var props: Dictionary = carrier.get("props", {})
	if not (props.has("waist_mm") and props.has("hip_mm")):
		return ""
	var waist := int(round(float(props["waist_mm"])))
	var hip := int(round(float(props["hip_mm"])))
	var band := _ribcage_band(root)
	var bust := TfMeasure.bust_mm(band, _total_breast_volume(root))
	var shape := TfMeasure.figure_shape(bust, waist, hip, std)
	var build := TfMeasure.figure_build(waist, hip, std)
	var descriptors := TfMeasure.figure_descriptors(bust, waist, hip, std)
	# Head clause: the shape noun-phrase leads, qualified by the build word (slim/thick)
	# when it adds something the shape doesn't already imply.
	var sentence := _figure_head(shape, build)
	if not descriptors.is_empty():
		sentence += ", " + _join_and(descriptors)
	sentence += " — " + TfMeasure.figure_triple(bust, waist, hip, std) + "."
	return sentence


# The leading clause naming shape (+ build qualifier), articled and capitalized:
# "An hourglass figure", "A slim, straight figure", "A thick, pear-shaped figure".
static func _figure_head(shape: String, build: String) -> String:
	var noun := _shape_noun(shape)
	if build != "" and build != "curvy":
		return _capitalize(_figure_article(build) + " " + build + ", " + noun)
	return _capitalize(_figure_article(noun_first_word(noun)) + " " + noun)


# Article for a figure-clause leading word — like `_article`, but "hourglass" takes a
# vowel sound ("an hourglass") despite its leading consonant letter.
static func _figure_article(word: String) -> String:
	if word == "hourglass":
		return "an"
	return _article(word)


# The shape rendered as a figure noun-phrase ("hourglass figure", "pear-shaped figure").
static func _shape_noun(shape: String) -> String:
	match shape:
		"hourglass": return "hourglass figure"
		"pear": return "pear-shaped figure"
		"top-heavy": return "top-heavy figure"
		"apple": return "apple-shaped figure"
		"straight": return "straight figure"
		_:
			return "figure"


# First word of a phrase (for picking the article by its leading sound).
static func noun_first_word(phrase: String) -> String:
	var sp := phrase.find(" ")
	return phrase if sp < 0 else phrase.substr(0, sp)


# The ribcage band for the bust derivation: the band_mm shared by the breasts (the rib
# band the cup already reads off — a realistic ribcage circumference in mm, ~810 for an
# average adult). Falls back to ~810 mm when no breast carries one.
static func _ribcage_band(root: Dictionary) -> int:
	for seg in BodyGraph.all_segments(root):
		if "breast" in seg.get("tags", []):
			var p: Dictionary = seg.get("props", {})
			if p.has("band_mm"):
				return int(round(float(p["band_mm"])))
	return 810


# Total breast volume across every breast segment (the bust derivation's volume term).
static func _total_breast_volume(root: Dictionary) -> int:
	var total := 0
	for seg in BodyGraph.all_segments(root):
		if "breast" in seg.get("tags", []):
			var p: Dictionary = seg.get("props", {})
			if p.has("volume_ml"):
				total += int(round(float(p["volume_ml"])))
	return total


# One segment's player phrase: { text (singular, no article), plural }. Size and fluids
# read in words; node ids and brackets never appear.
static func _segment_phrase(seg: Dictionary, std: Dictionary) -> Dictionary:
	var noun := _noun_for_tags(seg.get("tags", []))
	var surface := _surface_word(seg)
	var size := _size_band(seg)
	var bits: Array = []
	if size != "":
		bits.append(size)
	if surface != "":
		bits.append(surface)
	bits.append(noun)
	var core: String = " ".join(bits)
	# Trailing prose for measurement (cup / length) and fluid state, where meaningful.
	var trail: Array = []
	var meas := _measurement_prose(seg, std)
	if meas != "":
		trail.append(meas)
	var fl := _fluid_prose(seg)
	if fl != "":
		trail.append(fl)
	var text := core
	var plural := _pluralize_noun(core, noun)
	if not trail.is_empty():
		var suffix := ", " + _join_and(trail)
		text += suffix
		plural += suffix
	return {"text": text, "plural": plural}


# Pluralize the core phrase by pluralizing its noun (the last word), leaving adjectives.
static func _pluralize_noun(core: String, noun: String) -> String:
	var plural_noun := _plural(noun)
	# Replace only the trailing noun occurrence.
	if core.ends_with(noun):
		return core.substr(0, core.length() - noun.length()) + plural_noun
	return core


# Simple English pluralizer for the part nouns in use (open, conventional).
static func _plural(noun: String) -> String:
	match noun:
		"penis": return "penises"
		"vagina": return "vaginas"
		"vulva": return "vulvas"
		"cloaca": return "cloacas"
		"tentacle": return "tentacles"
		"ovipositor": return "ovipositors"
		"hoof": return "hooves"
		"foot": return "feet"
	if noun.ends_with("s") or noun.ends_with("x") or noun.ends_with("ch") or noun.ends_with("sh"):
		return noun + "es"
	if noun.ends_with("y") and noun.length() > 1:
		return noun.substr(0, noun.length() - 1) + "ies"
	return noun + "s"


# Indefinite article for a phrase ("a"/"an") by its leading sound (vowel heuristic).
static func _article(phrase: String) -> String:
	var first := phrase.substr(0, 1).to_lower()
	return "an" if first in ["a", "e", "i", "o", "u"] else "a"


# --- measurement & fluids as prose ----------------------------------------------

# The measurement phrase for a segment, in plain words under the standard. Breasts read
# as a cup ("a C cup"); a phallic genital as a length ("about 15 cm"); the butt as a
# soft fullness word. Empty for segments with no meaningful measured size.
static func _measurement_prose(seg: Dictionary, std: Dictionary) -> String:
	var props: Dictionary = seg.get("props", {})
	var tags: Array = seg.get("tags", [])
	if "breast" in tags and props.has("volume_ml") and props.has("band_mm"):
		var letter := TfMeasure.cup_letter(
			int(round(float(props["volume_ml"]))), int(round(float(props["band_mm"]))), std)
		return "%s %s cup" % [_letter_article(letter), letter]
	if "genital" in tags and "phallic" in tags and props.has("length_cm"):
		var l := float(props["length_cm"])
		if l <= 0:
			return ""
		return "about " + _space_unit(TfMeasure.length_phrase(l, std))
	return ""


# Article for a spoken cup letter: letters whose NAME starts with a vowel sound take
# "an" (A, E, F, H, I, L, M, N, O, R, S, X), the rest take "a". The first character is
# enough for the multi-letter cup labels in use (AA, DD, DDD all start with vowel-name).
static func _letter_article(letter: String) -> String:
	if letter == "":
		return "a"
	var c := letter.substr(0, 1).to_upper()
	return "an" if c in ["A", "E", "F", "H", "I", "L", "M", "N", "O", "R", "S", "X"] else "a"


# Insert a space between a number and its unit in a measure phrase ("15cm" -> "15 cm").
static func _space_unit(phrase: String) -> String:
	var out := ""
	for i in phrase.length():
		var ch := phrase[i]
		if i > 0 and ch >= "a" and ch <= "z" and phrase[i - 1] >= "0" and phrase[i - 1] <= "9":
			out += " "
		out += ch
	return out


# A fluid reservoir read as a player-facing STATE, not a band token. Only fluids worth
# mentioning surface: lactation always reads (it's a visible body state); other fluids
# read only when they are actually present/notable, so an empty seed/nectar stays silent.
static func _fluid_prose(seg: Dictionary) -> String:
	var fluids: Array = seg.get("fluids", [])
	if fluids.is_empty():
		return ""
	var ordered := fluids.duplicate()
	ordered.sort_custom(func(a, b): return str(a.get("type", "")) < str(b.get("type", "")))
	var bits: Array = []
	for f in ordered:
		var ftype := str(f.get("type", ""))
		var amount := int(f.get("amount", 0))
		var capacity := int(f.get("capacity", 0))
		var phrase := _fluid_state_phrase(ftype, amount, capacity)
		if phrase != "":
			bits.append(phrase)
	if bits.is_empty():
		return ""
	return _join_and(bits)


# Map a fluid reservoir to a state phrase. Milk reads as lactation status (always, since
# the presence of a milk reservoir is a body trait); seed/nectar read only when non-empty.
static func _fluid_state_phrase(ftype: String, amount: int, capacity: int) -> String:
	var pct := 0.0
	if capacity > 0:
		pct = float(amount) / float(capacity)
	match ftype:
		"milk":
			if capacity <= 0 or amount <= 0:
				return "not lactating"
			if pct >= 1.0:
				return "swollen and heavy with milk"
			if pct >= 0.5:
				return "full of milk"
			if pct >= 0.25:
				return "lactating"
			return "lightly lactating"
		"seed":
			if amount <= 0:
				return ""
			if pct >= 0.75:
				return "heavy with seed"
			return "carrying seed"
		"nectar":
			if amount <= 0:
				return ""
			if pct >= 0.75:
				return "slick and wet"
			return "wet"
		_:
			if amount <= 0:
				return ""
			return "carrying " + ftype


# Join a list of clauses with commas and a final "and".
static func _join_and(parts: Array) -> String:
	if parts.size() == 0:
		return ""
	if parts.size() == 1:
		return str(parts[0])
	if parts.size() == 2:
		return "%s and %s" % [parts[0], parts[1]]
	var head: Array = parts.slice(0, parts.size() - 1)
	return "%s, and %s" % [", ".join(head), parts[parts.size() - 1]]


static func _capitalize(s: String) -> String:
	if s == "":
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)


# --- debug segment phrase (verbose, for debug_dump only) -------------------------

static func _debug_segment(seg: Dictionary, std: Dictionary) -> String:
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
	var meas := _measurement_debug(seg, std)
	if meas != "":
		line += " " + meas
	var fluids: Array = seg.get("fluids", [])
	if not fluids.is_empty():
		var ordered := fluids.duplicate()
		ordered.sort_custom(func(a, b): return str(a.get("type", "")) < str(b.get("type", "")))
		var fbits: Array = []
		for f in ordered:
			fbits.append("%s %s" % [_fluid_band(int(f.get("amount", 0)), int(f.get("capacity", 0))), str(f.get("type", ""))])
		line += " [" + ", ".join(fbits) + "]"
	return line


# The raw measurement phrase (cup label + volume / length), angle-bracketed, for debug.
static func _measurement_debug(seg: Dictionary, std: Dictionary) -> String:
	var props: Dictionary = seg.get("props", {})
	var tags: Array = seg.get("tags", [])
	if "breast" in tags and props.has("volume_ml") and props.has("band_mm"):
		return "<%s>" % TfMeasure.breast_phrase(
			int(round(float(props["volume_ml"]))), int(round(float(props["band_mm"]))), std)
	if "butt" in tags and props.has("volume_ml"):
		return "<%s>" % TfMeasure.butt_phrase(int(round(float(props["volume_ml"]))), std)
	if "genital" in tags and "phallic" in tags and props.has("length_cm"):
		return "<%s>" % TfMeasure.length_phrase(float(props["length_cm"]), std)
	return ""


# Fullness band for a fluid reservoir (§5.3) — debug token only.
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


# Humanize an open material/covering value for prose: underscores become spaces and a
# few compound values get a natural word order (e.g. "fur_red" -> "red fur"). Open and
# conventional — unknown values just lose their underscores.
static func _humanize(value: String) -> String:
	match value:
		"fur_red": return "red fur"
		"skin_deep": return "deep-toned skin"
		_:
			return value.replace("_", " ")


# The natural adjective for a covering, for prose ("fur" -> "furred"). Falls back to
# "<covering>-covered" for coverings with no special adjective.
static func _covering_adjective(cov: String) -> String:
	match cov:
		"fur": return "furred"
		"fur_red": return "red-furred"
		"scales": return "scaled"
		"feathers": return "feathered"
		"skin": return "bare-skinned"
		"skin_deep": return "deep-toned"
		_:
			return "%s-covered" % _humanize(cov)


# The visible surface: covering for flesh-type; the material itself otherwise (§6).
static func _surface_word(seg: Dictionary) -> String:
	var material: String = seg.get("material", "")
	if BodyGraph.material_takes_covering(material):
		var cov = seg.get("covering")
		if cov == null:
			return _humanize(material)  # flesh with no covering yet: name the material
		return _covering_adjective(cov)
	return _humanize(material)  # chitin / slime — the material is the surface


static func _noun_for_tags(tags: Array) -> String:
	# Genitalia: a NATURAL part noun from the kind tag (§4.1). The `genital` tag marks
	# membership; a kind tag (phallic/vaginal/…) gives the everyday noun the player reads
	# ("penis"/"vagina", never "phallic genital"). Open, content-owned mapping.
	if "genital" in tags:
		var nouns := {
			"phallic": "penis", "vaginal": "vagina", "cloacal": "cloaca",
			"ovipositor": "ovipositor", "tentacular": "tentacle",
		}
		for kind in ["phallic", "vaginal", "cloacal", "ovipositor", "tentacular"]:
			if kind in tags:
				return nouns[kind]
		return "genitals"
	if "breast" in tags:
		return "breast"
	if "butt" in tags:
		return "butt"
	# Prefer the most specific conventional tag; structural fallback if none.
	for pref in ["head", "tail", "ear", "horn", "wing", "hoof", "claw", "udder",
			"nipple", "teat", "arm", "leg", "hand", "torso"]:
		if pref in tags:
			return pref
	# A body-core trunk with no more-specific noun. A serpentine lower (naga) reads as a
	# serpentine lower body; a horizontal barrel (taur) reads as a barrel; an upright
	# trunk reads as a torso.
	if "body_core" in tags:
		if "serpentine" in tags:
			return "serpentine lower body"
		if "lower_body" in tags:
			return "barrel"
		return "torso"
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
	# Baseline structural limbs/trunk (leg/arm/torso) carry an ORDINARY natural length —
	# the starting biped's legs (~85 cm), arms (~62 cm) and torso (~55 cm) read with NO
	# adjective so they stay silent in a plain description. Only a distinctively short
	# (fae) or long (taller/giant) limb gets a band, so the size morphs stay visible.
	if ("leg" in tags or "arm" in tags or "torso" in tags) and props.has("length_cm"):
		var ll := float(props["length_cm"])
		if ll <= 0:
			return ""
		if ll < 25:
			return "short"
		if ll < 100:
			return ""   # ordinary natural length — no adjective
		if ll < 150:
			return "long"
		return "very long"
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
			# Name the CHILD part (not the raw attachment id) so the zone reads naturally.
			var where := _noun_for_tags(child_seg.get("tags", []))
			out.append("where the %s meets the body, %s gives way to %s"
				% [where, parent_surface, child_surface])
		_walk_zones(child_seg, out)


# ================================================================================
# TRANSITION / PROCESS describer (TF system §6) — narrate a TF AS IT HAPPENS.
#
# Where describe() reads the STATIC end-body, this reads the CHANGE between two body
# states and narrates it in a process voice: what GREW IN, what SHRANK AWAY, what
# changed material / covering / size / shape, in a sensible order. The end-body is a
# noun; a transformation is a verb, and this is the verb layer.
#
# `describe_transition(before, after)` diffs two states by segment id:
#   - ids present in AFTER but not BEFORE -> a part grew in / pushed out;
#   - ids in BEFORE but not AFTER         -> a part shrank away / vanished;
#   - ids in both                         -> compare material / covering / size / tags.
# The diff is emitted in passes (gestalt scale, gestalt plan, vanish, appear, material,
# covering, reshape, size, fluids) so the sentences land in a natural narrative order,
# and a gestalt pass can CONSUME the segment ids it already narrated (the four legs of a
# new barrel are part of "she settles onto four legs", not four separate bullets).
#
# `describe_progression(snapshots)` walks an ORDERED list of body states (captured stage
# by stage as a staged TF advances on the sim clock) and narrates each step's change in
# turn — literally the transformation unfolding over time, frame by frame.
#
# Plain and functional per the user-facing-text rule: no node ids, no raw deltas, no
# dev-ese. The deep literary realizer is still deferred — this describes the actual
# change clearly and in order, no faked purple prose.
# ================================================================================

## Ordered process narrative for a single TF: the sequence of changes from `before` to
## `after`, each a plain sentence in a happening voice. Empty when nothing changed.
static func describe_transition(before: Dictionary, after: Dictionary, std: Dictionary = {}) -> Array:
	if std.is_empty():
		std = TfMeasure.default_standard()
	var b_map := _seg_map(before["root"])
	var a_map := _seg_map(after["root"])
	var parent_after := _parent_map(after["root"])
	var consumed := {}
	var out: Array = []
	_emit_whole_scale(b_map, a_map, consumed, out)
	_emit_plan_morph(b_map, a_map, consumed, out)
	_emit_vanished(b_map, a_map, consumed, out)
	_emit_appeared(b_map, a_map, parent_after, consumed, out)
	_emit_material(b_map, a_map, consumed, out)
	_emit_covering(b_map, a_map, consumed, out)
	_emit_reshape(b_map, a_map, consumed, out)
	_emit_size(b_map, a_map, consumed, out, std)
	_emit_fluids(b_map, a_map, consumed, out)
	return out


## Walk an ordered list of body snapshots (state before, then after each stage) and
## narrate each step's change in order — the transformation unfolding frame by frame.
## Consecutive identical snapshots contribute nothing (a stage that no-ops is silent).
static func describe_progression(snapshots: Array, std: Dictionary = {}) -> Array:
	if std.is_empty():
		std = TfMeasure.default_standard()
	var lines: Array = []
	for i in range(1, snapshots.size()):
		for s in describe_transition(snapshots[i - 1], snapshots[i], std):
			lines.append(s)
	return lines


# A short one-line "ends as" form summary (the build sentence), for an audit footer.
static func form_line(body: Dictionary) -> String:
	return _form_summary(body["root"])


# --- diff scaffolding -----------------------------------------------------------

static func _seg_map(root: Dictionary) -> Dictionary:
	var m := {}
	for seg in BodyGraph.all_segments(root):
		m[seg["id"]] = seg
	return m


# child id -> parent id, for the AFTER graph (so an appeared child of an appeared parent
# is recognized as part of that parent's graft, not a separate "grows in" line).
static func _parent_map(root: Dictionary) -> Dictionary:
	var m := {}
	for seg in BodyGraph.all_segments(root):
		for edge in seg.get("children", []):
			m[edge["node"]["id"]] = seg["id"]
	return m


# Left/right/fore/hind qualifier read off a stable id suffix, so a creeping change can
# name "her left hind leg" / "her right foreleg" instead of repeating a bare noun.
static func _side_word(id: String) -> String:
	if id.ends_with("_bl"): return "left hind"
	if id.ends_with("_br"): return "right hind"
	if id.ends_with("_fl"): return "left fore"
	if id.ends_with("_fr"): return "right fore"
	if id.ends_with("_ll"): return "lower left"
	if id.ends_with("_rr"): return "lower right"
	if id.ends_with("_l"): return "left"
	if id.ends_with("_r"): return "right"
	return ""


# A possessive part label for one segment: a side qualifier (when the id carries one) +
# the natural noun. "left hind leg", "right wing", "barrel", "torso".
static func _part_label(seg: Dictionary) -> String:
	var noun := _noun_for_tags(seg.get("tags", []))
	var side := _side_word(str(seg.get("id", "")))
	if side == "":
		return noun
	var label := side + " " + noun
	return label.replace("fore leg", "foreleg")


# --- pass 1: whole-body scale (fae / giant / taller) ----------------------------
# A scale TF moves MANY limb lengths at once; narrate it as one gestalt, not a dozen
# "her legs lengthen" lines, and CONSUME the limb/figure props it covers.
static func _emit_whole_scale(b_map: Dictionary, a_map: Dictionary, consumed: Dictionary, out: Array) -> void:
	var kinds := {}
	var grew := false
	var shrank := false
	var limb_ids: Array = []
	for id in a_map:
		if not b_map.has(id):
			continue
		var tags: Array = a_map[id].get("tags", [])
		var kind := ""
		if "leg" in tags: kind = "leg"
		elif "arm" in tags: kind = "arm"
		elif "torso" in tags: kind = "torso"
		if kind == "":
			continue
		var bl := float(b_map[id].get("props", {}).get("length_cm", 0.0))
		var al := float(a_map[id].get("props", {}).get("length_cm", 0.0))
		if al == bl or bl == 0.0:
			continue
		kinds[kind] = true
		limb_ids.append(id)
		if al > bl: grew = true
		else: shrank = true
	if kinds.size() < 2 or (grew and shrank):
		return
	# Proportional figure scaling (waist/hip/band/volume moved too) marks a true whole-body
	# resize (fae/giant) rather than a plain height change (legs+torso only).
	var fig_scaled := false
	var fig_ids: Array = []
	for id in a_map:
		if not b_map.has(id):
			continue
		var tags: Array = a_map[id].get("tags", [])
		if not ("breast" in tags or "groin_mount" in tags or "butt" in tags):
			continue
		var bp: Dictionary = b_map[id].get("props", {})
		var ap: Dictionary = a_map[id].get("props", {})
		for p in ["waist_mm", "hip_mm", "band_mm", "volume_ml"]:
			if bp.has(p) and ap.has(p) and float(bp[p]) != float(ap[p]):
				fig_scaled = true
				if id not in fig_ids:
					fig_ids.append(id)
	if fig_scaled:
		if shrank:
			out.append("Her whole body shrinks down, dwindling to a tiny, delicate fae stature.")
		else:
			out.append("Her whole body swells outward, growing to a towering giant's frame.")
		for id in limb_ids: consumed[id] = true
		for id in fig_ids: consumed[id] = true
	else:
		# Plain height change (legs + torso lengthen/shorten, figure untouched).
		if grew:
			out.append("She grows taller, her legs and torso lengthening.")
		else:
			out.append("She shrinks shorter, her legs and torso drawing in.")
		for id in limb_ids: consumed[id] = true


# --- pass 2: whole-body plan morph (a lower-body core appears / vanishes) --------
static func _emit_plan_morph(b_map: Dictionary, a_map: Dictionary, consumed: Dictionary, out: Array) -> void:
	# A new body-core LOWER segment (a barrel / serpent) = the body re-planning around a
	# new lower body. Fold the new legs and the lost biped legs into one gestalt sentence.
	for id in a_map:
		if b_map.has(id) or id in consumed:
			continue
		var tags: Array = a_map[id].get("tags", [])
		if not ("body_core" in tags and "lower_body" in tags):
			continue
		if "serpentine" in tags:
			out.append("Her legs fuse and flow together, drawing out into one long, sinuous serpentine tail.")
		else:
			out.append("Her legs give way as a heavy four-legged barrel grows out beneath her torso, and she settles onto all fours.")
		consumed[id] = true
		# Consume every appeared leg (the new barrel's legs) and every vanished leg.
		for nid in a_map:
			if not b_map.has(nid) and "leg" in a_map[nid].get("tags", []):
				consumed[nid] = true
		for oid in b_map:
			if not a_map.has(oid) and "leg" in b_map[oid].get("tags", []):
				consumed[oid] = true
		return


# --- pass 3: vanished parts -----------------------------------------------------
static func _emit_vanished(b_map: Dictionary, a_map: Dictionary, consumed: Dictionary, out: Array) -> void:
	var counts := {}
	var seen: Array = []
	for id in b_map:
		if a_map.has(id) or id in consumed:
			continue
		# Only top-level losses: if this id's old parent also vanished, it left with the
		# parent (a removed udder's teats are part of "her udder is gone").
		var noun := _noun_for_tags(b_map[id].get("tags", []))
		if not counts.has(noun):
			counts[noun] = 0
			seen.append(noun)
		counts[noun] += 1
	for noun in seen:
		var line := _vanish_phrase(noun, counts[noun])
		if line != "":
			out.append(line)


static func _vanish_phrase(noun: String, count: int) -> String:
	match noun:
		"penis":
			return ("Her penis softens, shrinks, and is gone." if count == 1
				else "Her penises soften, shrink, and are gone.")
		"vagina":
			return "Her sex closes over and smooths away."
		"breast":
			return ("A breast flattens away to nothing." if count == 1
				else "Her breasts flatten away to nothing.")
		"wing":
			return "Her wings shrink and fall away."
		"arm":
			return "Her arms wither and pull away."
		"leg":
			return "Her legs give way beneath her."
		"tail":
			return "Her tail shrinks back and is gone."
		"horn":
			return "Her horns recede into her brow."
		"udder":
			return "Her udder shrinks back into her belly."
		_:
			return "Her %s draws back and is gone." % noun


# --- pass 4: appeared parts -----------------------------------------------------
static func _emit_appeared(b_map: Dictionary, a_map: Dictionary, parent_after: Dictionary,
		consumed: Dictionary, out: Array) -> void:
	# Group the TOP-LEVEL new parts (parent already existed) by noun, in graph order, so a
	# symmetric pair reads as "a pair of wings", and a child of a new graft is not re-listed.
	var counts := {}
	var sample := {}
	var order: Array = []
	for id in a_map:
		if b_map.has(id) or id in consumed:
			continue
		var par = parent_after.get(id, "")
		# A child whose parent ALSO just appeared belongs to that parent's graft phrase.
		if par != "" and not b_map.has(par) and par not in consumed:
			continue
		var noun := _noun_for_tags(a_map[id].get("tags", []))
		if not counts.has(noun):
			counts[noun] = 0
			order.append(noun)
			sample[noun] = a_map[id]
		counts[noun] += 1
	for noun in order:
		out.append(_appear_phrase(sample[noun], counts[noun]))


static func _appear_phrase(seg: Dictionary, count: int) -> String:
	var noun := _noun_for_tags(seg.get("tags", []))
	var surface := _surface_word(seg)
	var size := _size_band(seg)
	match noun:
		"tail":
			var s := (surface + " ") if surface != "" and surface != "bare-skinned" else ""
			return "A long %stail grows in and settles at the base of her spine." % s
		"wing":
			var ws := (surface + " ") if surface != "" and surface != "bare-skinned" else ""
			if count >= 2:
				return "A pair of broad %swings unfurl from her back." % ws
			return "A single %swing unfurls from her back." % ws
		"horn":
			var hs := (size + " ") if size != "" else ""
			if count >= 2:
				return "A pair of %shorns push up from her brow." % hs
			return "A %shorn pushes up from her brow." % hs
		"ear":
			var es := (surface + " ") if surface != "" and surface != "bare-skinned" else ""
			if count >= 2:
				return "A pair of %sears prick up atop her head." % es
			return "A %sear pricks up atop her head." % es
		"arm":
			if count >= 2:
				return "A second pair of arms push out below the first."
			return "Another arm pushes out from her side."
		"leg":
			if count >= 2:
				return "A pair of new, clawed legs take shape and she rises onto them."
			return "A new leg pushes out beneath her."
		"claw":
			return "Her fingertips harden and curl into sharp claws."
		"hoof":
			return "Her feet harden over into solid hooves."
		"breast":
			if count >= 2:
				return "A second pair of breasts swell into being below the first."
			return "Another breast swells into being on her chest."
		"nipple":
			return "A second nipple rises on each breast."
		"teat":
			return "A row of small teats forms along her lower belly."
		"udder":
			return "A heavy, teated udder swells in beneath her belly."
		"penis":
			var ps := (size + " ") if size != "" else ""
			return "A %spenis grows in at her groin." % ps
		"vagina":
			return "A new sex opens between her legs."
		_:
			if count >= 2:
				return "%s %s grow in." % [_num_word(count).capitalize(), _plural(noun)]
			return "%s grows in." % _capitalize(_article(noun) + " " + noun)


# --- pass 5: material changes ---------------------------------------------------
static func _emit_material(b_map: Dictionary, a_map: Dictionary, consumed: Dictionary, out: Array) -> void:
	# Group common segments whose MATERIAL changed by (from -> to). A change that sweeps the
	# trunk (or many segments) reads once as body-wide; a local one names the part(s).
	var groups := {}       # "from>to" -> [seg...]
	var bodywide := {}     # "from>to" -> bool (touches the trunk)
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		var bm := str(b_map[id].get("material", ""))
		var am := str(a_map[id].get("material", ""))
		if bm == am:
			continue
		var key := bm + ">" + am
		if not groups.has(key):
			groups[key] = []
			bodywide[key] = false
		groups[key].append(a_map[id])
		var tags: Array = a_map[id].get("tags", [])
		if "body_core" in tags and "upper_body" in tags:
			bodywide[key] = true
	for key in groups:
		var segs: Array = groups[key]
		var parts := str(key).split(">")
		var verb := _material_verb(parts[0], parts[1])
		if bodywide[key] or segs.size() >= 3:
			out.append("Her body %s across her whole frame." % verb)
		else:
			for seg in segs:
				out.append("Her %s %s." % [_part_label(seg), verb])


static func _material_verb(from_m: String, to_m: String) -> String:
	match to_m:
		"chitin": return "hardens into a chitin shell"
		"slime": return "softens into translucent slime"
		"keratin": return "hardens to keratin"
		"flesh": return "softens back to bare flesh"
		_:
			return "turns to %s" % _humanize(to_m)


# --- pass 6: covering changes ---------------------------------------------------
static func _emit_covering(b_map: Dictionary, a_map: Dictionary, consumed: Dictionary, out: Array) -> void:
	var groups := {}
	var bodywide := {}
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		# A material change already narrated this segment's surface (chitin/slime null the
		# covering) — don't also report a covering change on it.
		if str(b_map[id].get("material", "")) != str(a_map[id].get("material", "")):
			continue
		var bc = b_map[id].get("covering")
		var ac = a_map[id].get("covering")
		if bc == ac or ac == null:
			continue
		var key := str(bc) + ">" + str(ac)
		if not groups.has(key):
			groups[key] = []
			bodywide[key] = false
		groups[key].append(a_map[id])
		var tags: Array = a_map[id].get("tags", [])
		if "body_core" in tags and "upper_body" in tags:
			bodywide[key] = true
	for key in groups:
		var segs: Array = groups[key]
		var parts := str(key).split(">")
		if bodywide[key] or segs.size() >= 3:
			out.append(_covering_bodywide(parts[0], parts[1]))
		else:
			for seg in segs:
				out.append(_covering_local(parts[1], seg))


static func _covering_bodywide(from_c: String, to_c: String) -> String:
	match to_c:
		"fur": return "Fur sweeps across her body in a soft coat."
		"fur_red": return "A coat of russet-red fur sweeps across her body."
		"scales": return "Scales sheet over her skin from head to foot."
		"feathers": return "Feathers sprout and spread across her body."
		"skin":
			return "Her %s recedes, leaving bare skin behind." % _humanize(from_c)
		_:
			return "Her surface turns to %s across her body." % _humanize(to_c)


static func _covering_local(to_c: String, seg: Dictionary) -> String:
	var part := _part_label(seg)
	# A trunk/barrel reads as the fur "spreading up over"; a limb reads as it "creeping over".
	var tags: Array = seg.get("tags", [])
	var spread := ("body_core" in tags or "torso" in tags)
	match to_c:
		"fur":
			return ("Fur spreads up over her %s." % part) if spread else ("Fur creeps over her %s." % part)
		"fur_red":
			return "Her %s fur deepens to a russet red." % part
		"scales":
			return ("Scales spread over her %s." % part) if spread else ("Scales creep over her %s." % part)
		"feathers":
			return "Feathers spread over her %s." % part
		"skin":
			return "Her %s sheds back to bare skin." % part
		_:
			return "Her %s turns to %s." % [part, _humanize(to_c)]


# --- pass 7: reshape (notable tag changes on a kept segment) ---------------------
static func _emit_reshape(b_map: Dictionary, a_map: Dictionary, consumed: Dictionary, out: Array) -> void:
	# Arms become wings IN PLACE — a harpy's wings ARE its forelimbs, so the kept arm
	# segments are retagged to wings rather than removed-and-replaced. Narrate the limb
	# reshaping, surfaced by what the new wing is covered in (feathers / slime / …), and
	# consume the segments so no other pass double-reports them.
	var wing_sample = null
	var wing_count := 0
	var digitigrade := false
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		var before_tags: Array = b_map[id].get("tags", [])
		var after_tags: Array = a_map[id].get("tags", [])
		if "arm" in before_tags and "arm" not in after_tags and "wing" in after_tags:
			wing_sample = a_map[id]
			wing_count += 1
			consumed[id] = true
		if "digitigrade" in after_tags and "digitigrade" not in before_tags:
			digitigrade = true
	if wing_sample != null:
		var surface := _surface_word(wing_sample)
		var ws := (surface + " ") if surface != "" and surface != "bare-skinned" else ""
		if wing_count >= 2:
			out.append("Her arms broaden and reshape into a pair of %swings." % ws)
		else:
			out.append("Her arm broadens and reshapes into a single %swing." % ws)
	if digitigrade:
		out.append("Her legs reshape, the joints reversing into a digitigrade stance up on the balls of her feet.")


# --- pass 8: size changes -------------------------------------------------------
static func _emit_size(b_map: Dictionary, a_map: Dictionary, consumed: Dictionary, out: Array, std: Dictionary) -> void:
	# Breasts: collapse the pair, read the cup band-aware, narrate the swell/subside.
	var bsample = null
	var asample = null
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		if "breast" not in a_map[id].get("tags", []):
			continue
		var bv := float(b_map[id].get("props", {}).get("volume_ml", 0.0))
		var av := float(a_map[id].get("props", {}).get("volume_ml", 0.0))
		if bv != av and bsample == null:
			bsample = b_map[id]
			asample = a_map[id]
	if bsample != null:
		out.append(_breast_size_line(bsample, asample, std))

	# Figure carrier (waist / hips). Combine when both move (the hourglass pinch).
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		if "groin_mount" not in a_map[id].get("tags", []):
			continue
		var bp: Dictionary = b_map[id].get("props", {})
		var ap: Dictionary = a_map[id].get("props", {})
		var dw := float(ap.get("waist_mm", 0.0)) - float(bp.get("waist_mm", 0.0))
		var dh := float(ap.get("hip_mm", 0.0)) - float(bp.get("hip_mm", 0.0))
		if dw < 0 and dh > 0:
			out.append("Her waist draws in as her hips flare wider — an hourglass deepening.")
		elif dw > 0 and dh > 0:
			out.append("Her waist and hips both thicken, filling out her lower frame.")
		elif dw < 0:
			out.append("Her waist cinches in, slimming her midriff.")
		elif dw > 0:
			out.append("Her waist thickens into a straighter line.")
		elif dh > 0:
			out.append("Her hips widen and flare outward.")
		elif dh < 0:
			out.append("Her hips draw in narrower.")

	# Barrel (a taur lower) filling out over staged growth.
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		var tags: Array = a_map[id].get("tags", [])
		if not ("body_core" in tags and "lower_body" in tags and "serpentine" not in tags):
			continue
		var bl := float(b_map[id].get("props", {}).get("length_cm", 0.0))
		var al := float(a_map[id].get("props", {}).get("length_cm", 0.0))
		if al > bl and bl > 0.0:
			out.append("Her barrel fills out, growing longer and heavier beneath her.")

	# Phallic length / girth.
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		var tags: Array = a_map[id].get("tags", [])
		if "phallic" not in tags:
			continue
		var bp: Dictionary = b_map[id].get("props", {})
		var ap: Dictionary = a_map[id].get("props", {})
		var dl := float(ap.get("length_cm", 0.0)) - float(bp.get("length_cm", 0.0))
		var dg := float(ap.get("girth_cm", 0.0)) - float(bp.get("girth_cm", 0.0))
		if dl > 0 and dg > 0:
			out.append("Her penis grows longer and thicker.")
		elif dl > 0:
			out.append("Her penis lengthens.")
		elif dg > 0:
			out.append("Her penis thickens.")
		elif dl < 0:
			out.append("Her penis shortens.")
		break

	# Vaginal depth.
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		if "vaginal" not in a_map[id].get("tags", []):
			continue
		var dd := float(a_map[id].get("props", {}).get("depth_cm", 0.0)) - float(b_map[id].get("props", {}).get("depth_cm", 0.0))
		if dd > 0:
			out.append("Her sex deepens inside.")
		break

	# Butt volume.
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		if "butt" not in a_map[id].get("tags", []):
			continue
		var dv := float(a_map[id].get("props", {}).get("volume_ml", 0.0)) - float(b_map[id].get("props", {}).get("volume_ml", 0.0))
		if dv > 0:
			out.append("Her rear swells fuller and rounder.")
		elif dv < 0:
			out.append("Her rear slims down.")
		break

	# Tail lengthening (e.g. a staged tail-grow).
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		if "tail" not in a_map[id].get("tags", []):
			continue
		var dt := float(a_map[id].get("props", {}).get("length_cm", 0.0)) - float(b_map[id].get("props", {}).get("length_cm", 0.0))
		if dt > 0:
			out.append("Her tail lengthens, growing out behind her.")
		elif dt < 0:
			out.append("Her tail draws shorter.")
		break

	# A single limb-length change not caught by the whole-body scale gestalt.
	var leg_dir := 0
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		if "leg" not in a_map[id].get("tags", []):
			continue
		var dl := float(a_map[id].get("props", {}).get("length_cm", 0.0)) - float(b_map[id].get("props", {}).get("length_cm", 0.0))
		if dl > 0: leg_dir = 1
		elif dl < 0: leg_dir = -1
	if leg_dir > 0:
		out.append("Her legs lengthen.")
	elif leg_dir < 0:
		out.append("Her legs shorten.")


static func _breast_size_line(before_seg: Dictionary, after_seg: Dictionary, std: Dictionary) -> String:
	var bp: Dictionary = before_seg.get("props", {})
	var ap: Dictionary = after_seg.get("props", {})
	var bv := int(round(float(bp.get("volume_ml", 0.0))))
	var av := int(round(float(ap.get("volume_ml", 0.0))))
	var bband := int(round(float(bp.get("band_mm", 810.0))))
	var aband := int(round(float(ap.get("band_mm", 810.0))))
	var bl := TfMeasure.cup_letter(bv, bband, std)
	var al := TfMeasure.cup_letter(av, aband, std)
	var grew := av > bv
	if bl != al:
		var verb := "swell" if grew else "subside"
		return "Her breasts %s from %s %s cup to %s %s cup." % [
			verb, _letter_article(bl), bl, _letter_article(al), al]
	# Same cup band but a real volume move (e.g. band widened with volume): keep it honest.
	if grew:
		return "Her breasts grow fuller and heavier."
	return "Her breasts ease smaller."


# --- pass 9: fluid changes ------------------------------------------------------
static func _emit_fluids(b_map: Dictionary, a_map: Dictionary, consumed: Dictionary, out: Array) -> void:
	var b_amt := 0
	var a_amt := 0
	var b_cap := 0
	var a_cap := 0
	var udder_filled := false
	for id in a_map:
		if not b_map.has(id) or id in consumed:
			continue
		var tags: Array = a_map[id].get("tags", [])
		var is_breast := "breast" in tags
		var is_udder := "udder" in tags
		if not (is_breast or is_udder):
			continue
		var before := _milk(b_map[id])
		var after := _milk(a_map[id])
		if is_udder:
			if after["amount"] > before["amount"]:
				udder_filled = true
			continue
		b_amt += before["amount"]; a_amt += after["amount"]
		b_cap += before["capacity"]; a_cap += after["capacity"]
	if b_cap == 0 and a_cap > 0:
		out.append("Her breasts begin to fill, milk coming in.")
	elif a_amt > b_amt:
		# Vary by how full she is now, so a staged refill reads as actually filling up
		# stage by stage rather than the same line repeated.
		var pct := float(a_amt) / float(a_cap) if a_cap > 0 else 0.0
		if pct >= 1.0:
			out.append("Her breasts swell full and tight with milk.")
		elif pct >= 0.6:
			out.append("Her breasts grow heavy with milk.")
		else:
			out.append("Her breasts fill further with milk.")
	elif b_amt > 0 and a_amt == 0:
		out.append("Her milk dries up and her breasts empty.")
	if udder_filled:
		out.append("Her udder swells heavy with milk.")


# {amount, capacity} of the milk reservoir on a segment (zeroes if none).
static func _milk(seg: Dictionary) -> Dictionary:
	for f in seg.get("fluids", []):
		if str(f.get("type", "")) == "milk":
			return {"amount": int(f.get("amount", 0)), "capacity": int(f.get("capacity", 0))}
	return {"amount": 0, "capacity": 0}
