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
# weight, distinct from the upright torso). A plain biped's lower body carries `lower_body`
# but NOT `body_core` (it is an ordinary groin-bearing segment, uniform with how a barrel/
# naga lower is just a tag arrangement), so these never false-match a biped. No special
# `spine` tag: a barrel and a torso are both body-core.
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


# The structural form as a readable clause: arms, lower body, optional tail.
static func _structural_clause(root: Dictionary) -> String:
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
	var clause := "%s torso over %s" % [_count_word(arms, "armed", "armless"), _lower_clause(legs)]
	if has_tail:
		clause += ", with a tail"
	return clause


# The lower-body half of the form clause, reading from the leg count.
static func _lower_clause(legs: int) -> String:
	if legs <= 0:
		return "a legless lower body"
	return "a %s-legged lower body" % _num_word(legs)


# "two-armed" / "an armless" — count + adjective, with a sensible zero case.
static func _count_word(n: int, plural_adj: String, zero_adj: String) -> String:
	if n <= 0:
		return "an %s" % zero_adj
	return "a %s-%s" % [_num_word(n), plural_adj]


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
	bits.append("%d-armed upper body" % arms)
	bits.append("%d-legged lower body" % legs)
	if has_tail:
		bits.append("tailed")
	return ", ".join(bits)


# --- per-segment player prose ---------------------------------------------------

# Collapse the segment list into player phrases: identical descriptions for symmetric
# parts merge into a count ("two bare-skinned arms"), preserving first-seen order.
static func _part_phrases(root: Dictionary, std: Dictionary) -> Array:
	var order: Array = []        # phrase (singular) in first-seen order
	var counts := {}
	var pluralizers := {}        # singular -> plural form, captured once
	for seg in BodyGraph.all_segments(root):
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
			# Inherently-plural part nouns ("hips") take no article and read bare.
			if _is_plural_noun_phrase(key):
				out.append("- " + _capitalize(key))
			else:
				out.append("- " + _capitalize(_article(key) + " " + key))
		else:
			out.append("- %s %s" % [_num_word(n).capitalize(), pluralizers[key]])
	return out


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


# True if the phrase's head noun is inherently plural (reads bare, no "a"/"an"). The
# biped lower body reads as "hips" — a pair-shaped noun with no singular here.
static func _is_plural_noun_phrase(phrase: String) -> bool:
	return phrase.ends_with("hips")


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
	if "breast" in tags and props.has("volume_ml") and props.has("band_cm"):
		var letter := TfMeasure.cup_letter(
			int(round(float(props["volume_ml"]))), int(round(float(props["band_cm"]))), std)
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
	if "breast" in tags and props.has("volume_ml") and props.has("band_cm"):
		return "<%s>" % TfMeasure.breast_phrase(
			int(round(float(props["volume_ml"]))), int(round(float(props["band_cm"]))), std)
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
	# A biped lower body (the groin-bearing `lower_body` region, NOT a body_core
	# barrel/naga lower) reads as "hips" — a uniform tag-driven noun, no `pelvis` id/tag.
	if ("lower_body" in tags or "groin" in tags) and not ("body_core" in tags):
		return "hips"
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
	# Hips read a width band off width_cm so widen_hips is VISIBLE (the base lower body is
	# ~36 cm; widen_hips raises it). Below the generic length band so it wins for the lower
	# body. (§4.3 — a real prop the describer reads, replacing the old no-op width_cm.)
	if ("lower_body" in tags or "groin" in tags) and props.has("width_cm"):
		var w := float(props["width_cm"])
		if w < 30: return "narrow"
		if w < 44: return ""
		if w < 58: return "wide"
		return "broad"
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
