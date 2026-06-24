## RegionSliders — the DATA-DRIVEN per-region body-customization slider table.
##
## The macro headline axes (age / masculinity / muscle / weight / proportions / height)
## are coarse whole-body dials. Deep customization — the breasts/butt/belly/waist/hips/
## limbs/face a player actually wants to shape — already lives in BodyState.modifiers (the
## sparse MakeHuman-fullName → value detail envelope, projected through the data-driven
## ModifierRegistry + the sparse DetailLibrary CPU morph path). Until now that envelope was
## reachable ONLY by drag-to-modify (sculpt mode); there were no NAMED region sliders.
##
## This module IS that slider definition table — pure DATA, no per-slider code. Each entry
## binds an aeriea slider (display name + region group) to ONE MakeHuman modifier `full_name`
## the ModifierRegistry already knows. The character creator builds an HSlider per entry that
## writes `BodyState.modifiers[full_name]`; the existing BodyState→registry→DetailLibrary path
## morphs the mesh. So adding/removing/retuning a slider is editing this table, never code.
##
## SIGN / RANGE convention (matches BodyState._project_modifiers + the registry):
##   - bidirectional modifiers (MakeHuman "<a>-decr|incr") are SIGNED axes in [-1, 1],
##     default 0 = neutral. v<0 drives the min/decr pole by |v|; v>0 drives the max/incr
##     pole by v. The slider's lo_pole/hi_pole label the two directions.
##   - unipolar modifiers are [0, 1], default 0 = neutral (e.g. a face-shape "oval" amount).
##
## EVERY full_name below is verified present in assets/body/modifier_registry.json with the
## stated kind, and every bound target is verified present with nonzero deltas in the sparse
## DetailLibrary (assets/body/base_body_detail.index.json) — so each slider actually morphs
## the mesh (see tests/body_region_sliders_test.gd). CC0 throughout (MakeHuman v1.3.0 targets).
class_name RegionSliders
extends RefCounted

const KIND_BIDIRECTIONAL := "bidirectional"
const KIND_UNIPOLAR := "unipolar"

## The NAVIGABLE REGION TREE (character-creator-ux.md §3). The creator navigates this tree
## one level at a time (breadcrumb), never a flat wall — Miller-compliant (≤~7 children) at
## every node. Two node shapes:
##   - an INTERMEDIATE node: { "label": String, "children": [node, ...] } — a navigation step
##     with no sliders of its own (e.g. Face, Torso).
##   - a LEAF group: { "label": String, "key": String, "specs": [slider_spec, ...] } — the
##     body part you actually edit; "key" is a stable id; specs are [full_name, display,
##     lo_pole, hi_pole] (poles: bidirectional lo = decr/min/negative, hi = incr/max/positive;
##     unipolar lo = neutral 0, hi = the effect at full 1). A leaf may have EMPTY specs (Mouth,
##     Eyes & brow today) — an honest home awaiting named sliders (§3 honest-edges).
##
## CURATED, not exhaustive: the registry has 291 modifiers (incl. dense per-finger / per-AU
## micro-targets). This is the MEANINGFUL set — the regions a player customizes. The long tail
## stays reachable via drag-to-modify. (The legacy flat GROUPS / all_specs() / count() derive
## from this tree's leaves, so the morph-wiring + tests are unchanged by the reshape.)
const TREE := [
	{"label": "Face", "children": [
		{"label": "Jaw & chin", "key": "jaw_chin", "specs": [
			["chin/chin-jaw-drop-decr|incr", "jaw drop", "less", "more"],
		]},
		{"label": "Nose", "key": "nose", "specs": [
			["nose/nose-scale-vert-decr|incr", "nose size", "small", "large"],
		]},
		# Mouth: the registry mouth family is reachable by on-body grab; no NAMED flat-table
		# sliders today. An honest home awaiting named sliders (§3).
		{"label": "Mouth", "key": "mouth", "specs": []},
		# Eyes & brow: eye COLOR is a value-node surfaced here in code (§8.7); the brow family
		# populates as named sliders land. No region sliders yet (honest, §3).
		{"label": "Eyes & brow", "key": "eyes_brow", "specs": []},
		{"label": "Skull", "key": "skull", "specs": [
			["head/head-scale-horiz-decr|incr", "face width", "narrow", "wide"],
			["head/head-scale-vert-decr|incr", "face height", "short", "tall"],
			["head/head-scale-depth-decr|incr", "face depth", "flat", "deep"],
			["head/head-fat-decr|incr", "face fullness", "gaunt", "full"],
			["head/head-age-decr|incr", "face age", "young", "old"],
		]},
		# Cheeks: the genuine bilateral cheek family (§3.1) — 4 stems × L/R paired into 4
		# midline-symmetric sliders via the generalized resolve_full_names (the /-prefixed form).
		{"label": "Cheeks", "key": "cheeks", "specs": [
			["cheek/l-cheek-bones-decr|incr", "cheekbones", "soft", "high"],
			["cheek/l-cheek-volume-decr|incr", "cheek fullness", "gaunt", "full"],
			["cheek/l-cheek-trans-down|up", "cheek height", "low", "high"],
			["cheek/l-cheek-inner-decr|incr", "inner cheek", "hollow", "full"],
		]},
		{"label": "Face shape", "key": "face_shape", "specs": [
			["head/head-oval", "oval", "none", "oval"],
			["head/head-round", "round", "none", "round"],
			["head/head-square", "square", "none", "square"],
			["head/head-rectangular", "rectangular", "none", "rectangular"],
			["head/head-triangular", "triangular", "none", "triangular"],
		]},
	]},
	{"label": "Torso", "children": [
		{"label": "Chest & breasts", "key": "chest_breasts", "specs": [
			# NOTE (breast-size guard): "breast/breast-volume-vert-down|up" is a PURELY VERTICAL
			# redistribution axis (a render probe proved it does NOT change apparent size) — so it
			# is labeled HONESTLY as Lift, not size. The real Cup size axis is a later phase
			# (cup-cube import). The genuine shape axes ("fullness", "projection") ship here.
			["breast/breast-volume-vert-down|up", "lift", "low", "high"],
			["breast/breast-dist-decr|incr", "spacing", "close", "wide"],
			["breast/breast-point-decr|incr", "projection", "flat", "pointed"],
			["breast/breast-trans-down|up", "position", "low", "high"],
			["breast/nipple-size-decr|incr", "nipple size", "small", "large"],
			["breast/nipple-point-decr|incr", "nipple out", "in", "out"],
			["measure/measure-bust-circ-decr|incr", "fullness", "narrow", "full"],
			["measure/measure-underbust-circ-decr|incr", "underbust", "narrow", "full"],
		]},
		# Belly: soft/tone + belly-forward depth, PLUS the navel power-detail (no junk-drawer —
		# power detail lives under the part it shapes, §3 honest-edges).
		{"label": "Belly", "key": "belly", "specs": [
			["stomach/stomach-tone-decr|incr", "belly softness", "soft", "toned"],
			["torso/torso-scale-depth-decr|incr", "belly forward", "flat", "deep"],
			["stomach/stomach-navel-in|out", "navel depth", "in", "out"],
			["stomach/stomach-navel-down|up", "navel height", "low", "high"],
		]},
		# Waist & hips: the waist/hip axes PLUS the love-handle power-detail (under the part).
		{"label": "Waist & hips", "key": "waist_hips", "specs": [
			["measure/measure-waist-circ-decr|incr", "waist", "narrow", "wide"],
			["measure/measure-hips-circ-decr|incr", "hips circumference", "narrow", "wide"],
			["hip/hip-scale-horiz-decr|incr", "hip width", "narrow", "wide"],
			["hip/hip-waist-down|up", "hip line", "low", "high"],
			["measure/measure-waisttohip-dist-decr|incr", "torso-to-hip", "short", "long"],
			["hip/hip-scale-depth-decr|incr", "love-handle depth", "less", "more"],
			["hip/hip-trans-in|out", "love-handle out", "in", "out"],
		]},
		{"label": "Back & shoulders", "key": "back_shoulders", "specs": [
			["torso/torso-vshape-decr|incr", "V-taper", "straight", "tapered"],
			["measure/measure-shoulder-dist-decr|incr", "shoulder width", "narrow", "broad"],
			["torso/torso-muscle-pectoral-decr|incr", "pectorals", "soft", "defined"],
			["torso/torso-muscle-dorsi-decr|incr", "back muscle", "soft", "defined"],
			["measure/measure-frontchest-dist-decr|incr", "chest depth", "shallow", "deep"],
		]},
		{"label": "Glutes & pelvis", "key": "glutes_pelvis", "specs": [
			["buttocks/buttocks-volume-decr|incr", "butt size", "flat", "full"],
			["pelvis/pelvis-tone-decr|incr", "pelvis tone", "soft", "toned"],
			["pelvis/bulge-decr|incr", "bulge", "less", "more"],
		]},
	]},
	{"label": "Arms", "key": "arms", "specs": [
		["measure/measure-upperarm-circ-decr|incr", "upper-arm size", "thin", "thick"],
		["l-upperarm-muscle", "upper-arm muscle", "soft", "muscular"],
		["l-upperarm-fat", "upper-arm fat", "lean", "soft"],
		["l-lowerarm-muscle", "forearm muscle", "soft", "muscular"],
		["measure/measure-upperarm-length-decr|incr", "upper-arm length", "short", "long"],
		["measure/measure-lowerarm-length-decr|incr", "forearm length", "short", "long"],
		["measure/measure-wrist-circ-decr|incr", "wrist", "thin", "thick"],
	]},
	# Legs split into Thighs (4) + Lower legs (5) — no 9-item wall (§3).
	{"label": "Thighs", "key": "thighs", "specs": [
		["measure/measure-thigh-circ-decr|incr", "thigh size", "thin", "thick"],
		["l-upperleg-muscle", "thigh muscle", "soft", "muscular"],
		["l-upperleg-fat", "thigh fat", "lean", "soft"],
		["armslegs/upperlegs-height-decr|incr", "thigh length", "short", "long"],
	]},
	{"label": "Lower legs", "key": "lower_legs", "specs": [
		["measure/measure-calf-circ-decr|incr", "calf size", "thin", "thick"],
		["l-lowerleg-muscle", "calf muscle", "soft", "muscular"],
		["armslegs/lowerlegs-height-decr|incr", "shin length", "short", "long"],
		["measure/measure-knee-circ-decr|incr", "knee", "thin", "thick"],
		["measure/measure-ankle-circ-decr|incr", "ankle", "thin", "thick"],
	]},
	{"label": "Neck", "key": "neck", "specs": [
		["measure/measure-neck-circ-decr|incr", "neck thickness", "thin", "thick"],
		["measure/measure-neck-height-decr|incr", "neck length", "short", "long"],
		["neck/neck-double-decr|incr", "double chin", "less", "more"],
	]},
]


## A node is a LEAF group iff it carries "specs" (intermediate nodes carry "children").
static func is_leaf(node: Dictionary) -> bool:
	return node.has("specs")


## The flat list of LEAF groups (depth-first, display order) as [group_label, [spec, ...]] —
## the legacy GROUPS shape, DERIVED from the tree's leaves so all_specs()/count()/the morph
## wiring + tests see exactly the same specs the tree presents. Computed once (a const can't
## hold a derived value, so this is the canonical accessor; GROUPS mirrors it for callers).
static func leaf_groups() -> Array:
	var out := []
	_collect_leaves(TREE, out)
	return out

static func _collect_leaves(nodes: Array, out: Array) -> void:
	for node in nodes:
		if is_leaf(node):
			out.append([node["label"], node["specs"]])
		else:
			_collect_leaves(node["children"], out)


## GROUPS — the flat leaf list (legacy shape: [label, [spec,...]]), derived from TREE. Kept so
## existing callers (all_specs / count / morph-wiring / tests) are unchanged by the tree reshape.
static var GROUPS: Array = leaf_groups()

## Per-slider value clamps by kind.
const BIDIR_MIN := -1.0
const BIDIR_MAX := 1.0
const UNIPOLAR_MIN := 0.0
const UNIPOLAR_MAX := 1.0
const STEP := 0.02

## Some bilateral measure modifiers exist only as left/right pairs (e.g. arm/leg muscle is
## `l-...` and `r-...`, NOT a single midline modifier). To present ONE intuitive slider that
## shapes BOTH sides symmetrically, a bilateral spec is expanded to the L AND R modifier
## full_names. Two spec forms are accepted (the prefix is GENERALIZED, not hardcoded to one
## registry group — the design's cheek-prefix generalization, §3.1):
##   1. A BARE bilateral stem ("l-upperarm-muscle") — no "/" — defaults to the armslegs/ group
##      (where the limb-muscle/fat pairs live) and gets the "-decr|incr" suffix appended.
##   2. An ALREADY-`<group>/`-PREFIXED left full_name ("cheek/l-cheek-bones-decr|incr") — its
##      r- twin is paired within the SAME group via twin(). This reaches the cheek/ family (and
##      any future /-prefixed bilateral family) without a hardcoded group constant.
const BILATERAL_PREFIX := "armslegs/"

## Resolve a slider spec's full_name(s) to the ACTUAL registry modifier full_name(s) it drives.
## Most specs are a single literal full_name. A bilateral spec expands to BOTH the L and R
## modifier full_names, so one slider shapes both sides symmetrically:
##   - a bare stem ("l-upperarm-muscle") → "armslegs/l-…-decr|incr" + its r- twin;
##   - a /-prefixed left full_name ("cheek/l-cheek-bones-decr|incr") → that name + twin() of it.
## Returns a PackedStringArray (1 or 2 entries). A right-only or midline name returns as-is.
static func resolve_full_names(spec_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	if spec_name.begins_with("l-") and not spec_name.contains("/"):
		# bare bilateral stem: drive left + right symmetric modifiers under armslegs/.
		var stem := spec_name.substr(2)   # drop the "l-"
		out.append("%sl-%s-decr|incr" % [BILATERAL_PREFIX, stem])
		out.append("%sr-%s-decr|incr" % [BILATERAL_PREFIX, stem])
		return out
	# A /-prefixed LEFT full_name (e.g. "cheek/l-cheek-bones-decr|incr"): pair its r- twin within
	# the SAME group. twin() flips l-↔r- at the path-segment boundary, generalizing past armslegs/.
	var tw := twin(spec_name)
	if tw != spec_name and spec_name.contains("/l-"):
		out.append(spec_name)
		out.append(tw)
		return out
	out.append(spec_name)
	return out

## The contralateral MIRROR-application map (SYNTHESIS §1.3 / decision §2.3): given a registry
## `full_name`, return its left/right TWIN — the same name with the side marker flipped (l-↔r-)
## — or the SAME name when it has no twin (a MIDLINE modifier: the midline guard). This is the
## sole map the MIRROR toggle uses to ALSO apply a one-sided edit to the opposite side. It is
## ORTHOGONAL to resolve_full_names (which is structural bilateral RESOLUTION, always on):
## resolution turns a bare bilateral STEM into both side full_names regardless of the toggle;
## this map flips the side of an already-resolved full_name only when mirror is ON.
##
## A side marker is `l-`/`r-` at a path-segment boundary — either right after the registry group
## prefix ("armslegs/l-…" ↔ "armslegs/r-…") or at the very start of a bare name ("l-…" ↔ "r-…").
## A name with neither (e.g. "nose/nose-scale-vert-decr|incr", "stomach/stomach-tone-decr|incr")
## is midline and returns unchanged, so the caller's `twin(M) != M` guard suppresses a
## double-apply on midline edits.
static func twin(full_name: String) -> String:
	# "<prefix>/l-<rest>" ↔ "<prefix>/r-<rest>" (the armslegs bilateral modifiers).
	var slash := full_name.rfind("/")
	if slash >= 0:
		var head := full_name.substr(0, slash + 1)
		var tail := full_name.substr(slash + 1)
		if tail.begins_with("l-"):
			return "%sr-%s" % [head, tail.substr(2)]
		if tail.begins_with("r-"):
			return "%sl-%s" % [head, tail.substr(2)]
		return full_name
	# Bare name with a leading side marker ("l-…" ↔ "r-…"); else midline (unchanged).
	if full_name.begins_with("l-"):
		return "r-%s" % full_name.substr(2)
	if full_name.begins_with("r-"):
		return "l-%s" % full_name.substr(2)
	return full_name


## A flat list of every slider spec across all groups, as Dictionaries:
##   { group, name (spec token), display, lo_pole, hi_pole }. Iteration order = display order.
static func all_specs() -> Array:
	var out := []
	for grp in GROUPS:
		var label: String = grp[0]
		for spec in grp[1]:
			out.append({
				"group": label, "name": spec[0], "display": spec[1],
				"lo_pole": spec[2], "hi_pole": spec[3],
			})
	return out

## Total slider-axis count (counts a bilateral stem as ONE slider, though it drives 2 modifiers).
static func count() -> int:
	var n := 0
	for grp in GROUPS:
		n += (grp[1] as Array).size()
	return n


# ---------------------------------------------------------------------------
# TREE NAVIGATION (character-creator-ux.md §3 / §4). The contextual dock renders ONE level at
# a time, addressed by a PATH of child indices from the root. These helpers resolve a path to
# its node + child list so the dock never sees more than one level's children at once.
# ---------------------------------------------------------------------------

## The child nodes at a given PATH (a list of child-indices from the root). An empty path = the
## top-level region list (the tree itself). A leaf node has no children → returns []. Returns the
## raw node Array so the dock can read each child's "label", "key"/"specs" or "children".
static func children_at(path: Array) -> Array:
	var nodes: Array = TREE
	for idx in path:
		var i := int(idx)
		if i < 0 or i >= nodes.size():
			return []
		var node: Dictionary = nodes[i]
		if is_leaf(node):
			return []   # a leaf has no child regions
		nodes = node["children"]
	return nodes


## The node AT a path (the focused node), or {} for the root (empty path). Used for the
## breadcrumb label + to decide whether the focused node is a leaf (show its specs) or an
## intermediate (show its child regions).
static func node_at(path: Array) -> Dictionary:
	var nodes: Array = TREE
	var node := {}
	for idx in path:
		var i := int(idx)
		if i < 0 or i >= nodes.size():
			return {}
		node = nodes[i]
		if is_leaf(node):
			return node if idx == path[path.size() - 1] else {}
		nodes = node["children"]
	return node


## The breadcrumb labels along a path (["Face", "Jaw & chin"] for the path into Jaw & chin).
static func breadcrumb(path: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var nodes: Array = TREE
	for idx in path:
		var i := int(idx)
		if i < 0 or i >= nodes.size():
			break
		var node: Dictionary = nodes[i]
		out.append(String(node["label"]))
		if is_leaf(node):
			break
		nodes = node["children"]
	return out
