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

## The region groups, in display order. Each is [group_label, [slider_spec, ...]] where a
## slider_spec is [full_name, display, lo_pole, hi_pole]. lo/hi poles label the slider ends:
## for a bidirectional axis lo = the decr/min direction (negative), hi = the incr/max
## (positive); for a unipolar axis lo = "none"/neutral (0), hi = the effect at full (1).
##
## CURATED, not exhaustive: the registry has 291 modifiers (incl. dense per-finger / per-AU
## micro-targets). This is the MEANINGFUL set — the regions a player customizes — chosen so
## the panel is deep but navigable. The long tail stays reachable via drag-to-modify.
const GROUPS := [
	["Breasts", [
		# NOTE (Phase 3a, breast-size guard): "breast/breast-volume-vert-down|up" was
		# proposed as the "size" control (SYNTHESIS §5), but a render probe proved it is a
		# PURELY VERTICAL redistribution axis (net displacement is ±y; forward/projection z
		# ≈ 0 at both poles) — driving it does NOT change apparent size. Shipping it as "size"
		# would be a size slider that doesn't change size (the guard's stop condition). It is
		# therefore labeled HONESTLY as breast height/lift, not size. The real size fix is the
		# DEFERRED cup-cube import (a decision item). The genuine size axes already ship below:
		# "fullness" (bust circumference) and "projection" (breast point).
		["breast/breast-volume-vert-down|up", "height / lift", "low", "high"],
		["breast/breast-dist-decr|incr", "spacing", "close", "wide"],
		["breast/breast-point-decr|incr", "projection", "flat", "pointed"],
		["breast/breast-trans-down|up", "position", "low", "high"],
		["breast/nipple-size-decr|incr", "nipple size", "small", "large"],
		["breast/nipple-point-decr|incr", "nipple out", "in", "out"],
		["measure/measure-bust-circ-decr|incr", "fullness", "narrow", "full"],
		["measure/measure-underbust-circ-decr|incr", "underbust", "narrow", "full"],
	]],
	["Glutes & pelvis", [
		["buttocks/buttocks-volume-decr|incr", "butt size", "flat", "full"],
		["pelvis/pelvis-tone-decr|incr", "pelvis tone", "soft", "toned"],
		["pelvis/bulge-decr|incr", "bulge", "less", "more"],
	]],
	# Belly group (SYNTHESIS §3): the pregnancy "belly" slider is RETIRED — the gravid
	# stomach-pregnant morph leaves base creation (it belongs to the future pregnancy
	# simulation). The persistent-identity belly shape is the soft/tone axis + belly-forward
	# depth; girth is the existing single waist slider (NOT re-added here — no modifier driven
	# by two controls); whole-body fat is the Weight headline axis. Navel/love-handle fine
	# detail moves to the T3 "Fine detail" group below.
	["Belly & stomach", [
		["stomach/stomach-tone-decr|incr", "belly softness / tone", "soft", "defined"],
		["torso/torso-scale-depth-decr|incr", "belly forward", "flat", "deep"],
	]],
	["Waist & hips", [
		["measure/measure-waist-circ-decr|incr", "waist", "narrow", "wide"],
		["measure/measure-hips-circ-decr|incr", "hips circumference", "narrow", "wide"],
		["hip/hip-scale-horiz-decr|incr", "hip width", "narrow", "wide"],
		["hip/hip-waist-down|up", "hip line", "low", "high"],
		["measure/measure-waisttohip-dist-decr|incr", "torso-to-hip", "short", "long"],
	]],
	["Torso & shoulders", [
		["torso/torso-vshape-decr|incr", "V-taper", "straight", "tapered"],
		["measure/measure-shoulder-dist-decr|incr", "shoulder width", "narrow", "broad"],
		["torso/torso-muscle-pectoral-decr|incr", "pectorals", "soft", "defined"],
		["torso/torso-muscle-dorsi-decr|incr", "back muscle", "soft", "defined"],
		["measure/measure-frontchest-dist-decr|incr", "chest depth", "shallow", "deep"],
	]],
	["Arms", [
		["measure/measure-upperarm-circ-decr|incr", "upper-arm size", "thin", "thick"],
		["l-upperarm-muscle", "upper-arm muscle", "soft", "muscular"],
		["l-upperarm-fat", "upper-arm fat", "lean", "soft"],
		["l-lowerarm-muscle", "forearm muscle", "soft", "muscular"],
		["measure/measure-upperarm-length-decr|incr", "upper-arm length", "short", "long"],
		["measure/measure-lowerarm-length-decr|incr", "forearm length", "short", "long"],
		["measure/measure-wrist-circ-decr|incr", "wrist", "thin", "thick"],
	]],
	["Legs", [
		["measure/measure-thigh-circ-decr|incr", "thigh size", "thin", "thick"],
		["l-upperleg-muscle", "thigh muscle", "soft", "muscular"],
		["l-upperleg-fat", "thigh fat", "lean", "soft"],
		["measure/measure-calf-circ-decr|incr", "calf size", "thin", "thick"],
		["l-lowerleg-muscle", "calf muscle", "soft", "muscular"],
		["armslegs/upperlegs-height-decr|incr", "thigh length", "short", "long"],
		["armslegs/lowerlegs-height-decr|incr", "shin length", "short", "long"],
		["measure/measure-knee-circ-decr|incr", "knee", "thin", "thick"],
		["measure/measure-ankle-circ-decr|incr", "ankle", "thin", "thick"],
	]],
	["Neck", [
		["measure/measure-neck-circ-decr|incr", "neck thickness", "thin", "thick"],
		["measure/measure-neck-height-decr|incr", "neck length", "short", "long"],
		["neck/neck-double-decr|incr", "double chin", "less", "more"],
	]],
	["Head & face shape", [
		["head/head-scale-horiz-decr|incr", "face width", "narrow", "wide"],
		["head/head-scale-vert-decr|incr", "face height", "short", "tall"],
		["head/head-scale-depth-decr|incr", "face depth", "flat", "deep"],
		["head/head-fat-decr|incr", "face fullness", "gaunt", "full"],
		["head/head-age-decr|incr", "face age", "young", "old"],
		["head/head-oval", "oval shape", "none", "oval"],
		["head/head-round", "round shape", "none", "round"],
		["head/head-square", "square shape", "none", "square"],
		["head/head-rectangular", "rectangular shape", "none", "rectangular"],
		["head/head-triangular", "triangular shape", "none", "triangular"],
		["chin/chin-jaw-drop-decr|incr", "jaw drop", "less", "more"],
		["nose/nose-scale-vert-decr|incr", "nose size", "small", "large"],
	]],
	# T3 fine detail (SYNTHESIS §3): the navel rows and love-handle axes, demoted from the
	# headline belly/hip groups to a fine-detail group for power users.
	["Fine detail", [
		["stomach/stomach-navel-in|out", "navel depth", "in", "out"],
		["stomach/stomach-navel-down|up", "navel height", "low", "high"],
		["hip/hip-scale-depth-decr|incr", "love-handle depth", "less", "more"],
		["hip/hip-trans-in|out", "love-handle out", "in", "out"],
	]],
]

## Per-slider value clamps by kind.
const BIDIR_MIN := -1.0
const BIDIR_MAX := 1.0
const UNIPOLAR_MIN := 0.0
const UNIPOLAR_MAX := 1.0
const STEP := 0.02

## Some bilateral measure modifiers exist only as left/right pairs (e.g. arm/leg muscle is
## `l-...` and `r-...`, NOT a single midline modifier). To present ONE intuitive slider that
## shapes BOTH sides symmetrically, a spec whose first token is "l-..." is expanded to the L
## AND R modifier full_names. This map gives the registry-prefix each bare bilateral stem lives
## under, so the lookup resolves the real full_names. (Both sides verified present in the
## registry as `armslegs/l-...` and `armslegs/r-...`.)
const BILATERAL_PREFIX := "armslegs/"

## Resolve a slider spec's full_name(s) to the ACTUAL registry modifier full_name(s) it drives.
## Most specs are a single literal full_name. A bilateral stem ("l-upperarm-muscle") expands to
## BOTH "armslegs/l-upperarm-muscle-decr|incr" and the "r-" twin, so one slider shapes both
## arms/legs symmetrically. Returns a PackedStringArray (1 or 2 entries).
static func resolve_full_names(spec_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	if spec_name.begins_with("l-") and not spec_name.contains("/"):
		# bilateral stem: drive left + right symmetric modifiers.
		var stem := spec_name.substr(2)   # drop the "l-"
		out.append("%sl-%s-decr|incr" % [BILATERAL_PREFIX, stem])
		out.append("%sr-%s-decr|incr" % [BILATERAL_PREFIX, stem])
	else:
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
