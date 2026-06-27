## TfLibrary — aeriea's broad authored transformation set (TF system §4, §7).
##
## A large, varied, AUDITABLE library of named TF sequences, authored DECLARATIVELY
## against the converged conventions of the engine (body_graph / tf_applier):
##
##   - The body is a graph of GENERIC segments, each tagged by ROLE (breast/leg/arm/
##     head/tail/horn/wing/ear/genital/nipple/...), REGION (upper_body/lower_body/groin/
##     chest/...) and RELATION (front/hind/left/right) where it matters.
##   - Three primitives only: transform-in-place (set_material / set_covering /
##     prop_delta / tag ops / fluid ops), add (graft_subtree), remove (remove_subtree).
##   - Targeting is by tag / structural query / ordinal select — NEVER a global id or a
##     numeric ordinal hand-picked from authored content. (Grafts name the PARENT mount,
##     which is part of the stable starting body, not an ordinal.)
##   - A body-core trunk (upright torso OR horizontal barrel) carries the `body_core`
##     tag; there is no special `spine` tag. Genitals carry natural-noun kind tags
##     (phallic/vaginal) so description reads "penis"/"vagina", never "phallic genital".
##
## These are SHIPPED CONTENT (not engine mechanism): the applier/traversal are unchanged.
## Each record is a plain Dictionary with {id, name, blurb, staged, ops, ...}. `blurb` is
## a one-line, player-facing description of what the TF does (plain language, no dev-ese).
##
## This file is the source of truth for the TF audit sandbox (tools/tf_audit.gd), which
## applies every entry to a fresh base body and shows the resulting description + ops.
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")


# =============================================================================== parts
# Reusable subtree builders. Each grows a part "from zero" conceptually (a graft adds a
# whole subtree). Tags follow the role/region/relation convention; coverings/materials
# match the part's nature. Ids are unique, stable strings (the audit applies one TF to a
# fresh body, so cross-TF id collisions never co-occur).

static func _seg(id, material, covering, props := {}, tags := [], children := [], fluids := []) -> Dictionary:
	return BodyGraph.segment(id, material, covering, props, tags, children, fluids)


static func _child(at: String, node: Dictionary) -> Dictionary:
	return BodyGraph.child(at, node)


# --- tails (role: tail; relation: hind) ---
static func _equine_tail() -> Dictionary:
	return _seg("tail", "flesh", "fur", {"length_cm": 75.0}, ["tail"], [])


static func _feline_tail() -> Dictionary:
	return _seg("tail", "flesh", "fur", {"length_cm": 60.0}, ["tail"], [])


static func _draconic_tail() -> Dictionary:
	return _seg("tail", "flesh", "scales", {"length_cm": 95.0}, ["tail"], [])


# --- wings (role: wing; relation: left/right) ---
static func _feathered_wing(id: String) -> Dictionary:
	return _seg(id, "flesh", "feathers", {"length_cm": 110.0}, ["wing"], [])


static func _membrane_wing(id: String) -> Dictionary:
	return _seg(id, "flesh", "scales", {"length_cm": 120.0}, ["wing"], [])


# --- head features ---
static func _horn(id: String) -> Dictionary:
	return _seg(id, "keratin", null, {"length_cm": 18.0}, ["horn"], [])


static func _short_horn(id: String) -> Dictionary:
	return _seg(id, "keratin", null, {"length_cm": 9.0}, ["horn"], [])


static func _animal_ear(id: String, covering: String) -> Dictionary:
	return _seg(id, "flesh", covering, {"length_cm": 8.0}, ["ear"], [])


# --- limbs / extremities ---
static func _extra_arm(id: String, covering: String) -> Dictionary:
	return _seg(id, "flesh", covering, {"length_cm": 62.0}, ["arm"], [
		_child("wrist", _seg(id + "_hand", "flesh", covering, {"length_cm": 18.0},
			["hand"], [])),
	])


static func _bird_leg(id: String) -> Dictionary:
	# A digitigrade bird leg ending in a clawed foot (role: leg, digitigrade; foot: claw).
	return _seg(id, "flesh", "scales", {"length_cm": 80.0}, ["leg", "digitigrade"], [
		_child("ankle", _seg(id + "_foot", "keratin", null, {"length_cm": 14.0},
			["foot", "claw"], [])),
	])


# --- compound parts / reproductive ---
static func _penis(id: String) -> Dictionary:
	return _seg(id, "flesh", "skin", {"length_cm": 15.0, "girth_cm": 11.0},
		["genital", "groin", "phallic"], [], [BodyGraph.fluid("seed", 0, 30)])


static func _vagina(id: String) -> Dictionary:
	return _seg(id, "flesh", "skin", {"depth_cm": 12.0},
		["genital", "groin", "vaginal"], [], [BodyGraph.fluid("nectar", 0, 40)])


static func _breast(id: String, volume: int = 500) -> Dictionary:
	return _seg(id, "flesh", "skin", {"volume_ml": volume, "band_mm": 810},
		["breast"], [], [BodyGraph.fluid("milk", 0, 400)])


static func _udder(id: String) -> Dictionary:
	# A bovine udder: a body-mounted milk reservoir carrying teats (crotch breasts).
	return _seg(id, "flesh", "skin", {"volume_ml": 1800}, ["udder"], [
		_child("teat_fl", _teat(id + "_teat_fl")),
		_child("teat_fr", _teat(id + "_teat_fr")),
		_child("teat_bl", _teat(id + "_teat_bl")),
		_child("teat_br", _teat(id + "_teat_br")),
	], [BodyGraph.fluid("milk", 0, 3000)])


static func _teat(id: String) -> Dictionary:
	return _seg(id, "flesh", "skin", {"length_cm": 6.0}, ["teat"], [],
		[BodyGraph.fluid("milk", 0, 200)])


static func _nipple(id: String) -> Dictionary:
	return _seg(id, "flesh", "skin", {"length_cm": 1.5}, ["nipple"], [])


# --- whole quadruped / serpentine lowers (body-core barrels) ---
static func _quad_barrel(id: String, covering: String) -> Dictionary:
	# A horizontal body-core barrel carrying four legs. `body_core` (NOT a special spine
	# tag) + `lower_body`; `barrel` role tag so a graft can guard on "barrel absent". The
	# `groin_mount` tag marks it as the carrier the genitals/butt/tail dock onto (the role
	# a biped's torso plays, since a biped has no separate lower-body part).
	return _seg(id, "flesh", covering, {"length_cm": 90.0, "waist_mm": 700, "hip_mm": 1100},
		["barrel", "body_core", "lower_body", "groin_mount"], [
		_child("leg_fl", _seg("leg_fl", "flesh", covering, {"length_cm": 80.0}, ["leg", "front"], [])),
		_child("leg_fr", _seg("leg_fr", "flesh", covering, {"length_cm": 80.0}, ["leg", "front"], [])),
		_child("leg_bl", _seg("leg_bl", "flesh", covering, {"length_cm": 80.0}, ["leg", "hind"], [])),
		_child("leg_br", _seg("leg_br", "flesh", covering, {"length_cm": 80.0}, ["leg", "hind"], [])),
	])


static func _serpent_tail(id: String) -> Dictionary:
	# A long legless lower body (naga): a body-core lower segment, no legs. Carries
	# `groin_mount` so the genitals reparent onto it (a naga keeps its sex, just no legs).
	return _seg(id, "flesh", "scales", {"length_cm": 240.0, "waist_mm": 640, "hip_mm": 800},
		["body_core", "lower_body", "serpentine", "groin_mount"], [])


# =============================================================================== records
# The registry: id -> TF record. Grouped by category in the order the audit shows them.
# `cat` is the display category; `blurb` the one-line player description.

static func registry() -> Dictionary:
	var r: Dictionary = {}
	for group in [
		_size_tfs(), _material_tfs(), _covering_tfs(), _appendage_tfs(),
		_plan_tfs(), _species_tfs(), _reproductive_tfs(), _hybrid_tfs(),
	]:
		for k in group:
			r[k] = group[k]
	return r


# Ordered list of (category, [tf_id...]) for the audit's grouped layout.
static func categories() -> Array:
	return [
		["Size and scale", _size_tfs().keys()],
		["Material", _material_tfs().keys()],
		["Covering", _covering_tfs().keys()],
		["Appendages", _appendage_tfs().keys()],
		["Whole-body plans", _plan_tfs().keys()],
		["Species configurations", _species_tfs().keys()],
		["Reproductive and fluids", _reproductive_tfs().keys()],
		["Hybrids", _hybrid_tfs().keys()],
	]


# ------------------------------------------------------------------- size / scalar
static func _size_tfs() -> Dictionary:
	return {
		"grow_breasts_big": {
			"id": "grow_breasts_big", "name": "Grow breasts", "cat": "Size and scale",
			"blurb": "Swells every breast a few cup sizes larger.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "breast"},
				"prop": "volume_ml", "amount": {"v": 1400.0}, "clamp": [0.0, 8000.0]}],
		},
		"shrink_breasts_small": {
			"id": "shrink_breasts_small", "name": "Shrink breasts", "cat": "Size and scale",
			"blurb": "Reduces every breast to a small, flatter size.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "breast"},
				"prop": "volume_ml", "amount": {"v": -500.0}, "clamp": [0.0, 8000.0]}],
		},
		"grow_butt_big": {
			"id": "grow_butt_big", "name": "Grow butt", "cat": "Size and scale",
			"blurb": "Adds a generous amount of volume to the rear.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "butt"},
			"ops": [{"effect": "prop_delta", "target_node": "butt", "prop": "volume_ml",
				"amount": {"v": 1600.0}, "clamp": [0.0, 12000.0]}],
		},
		"lengthen_penis": {
			"id": "lengthen_penis", "name": "Lengthen penis", "cat": "Size and scale",
			"blurb": "Makes every penis noticeably longer.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "phallic"},
			"ops": [{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "genital", "kind": "phallic"},
				"prop": "length_cm", "amount": {"v": 10.0}, "clamp": [0.0, 45.0]}],
		},
		"thicken_penis": {
			"id": "thicken_penis", "name": "Thicken penis", "cat": "Size and scale",
			"blurb": "Adds girth to every penis without changing its length.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "phallic"},
			"ops": [{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "genital", "kind": "phallic"},
				"prop": "girth_cm", "amount": {"v": 5.0}, "clamp": [0.0, 25.0]}],
		},
		"deepen_vagina": {
			"id": "deepen_vagina", "name": "Deepen vagina", "cat": "Size and scale",
			"blurb": "Increases the depth of every vagina.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "vaginal"},
			"ops": [{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "genital", "kind": "vaginal"},
				"prop": "depth_cm", "amount": {"v": 6.0}, "clamp": [0.0, 40.0]}],
		},
		"widen_hips": {
			"id": "widen_hips", "name": "Widen hips", "cat": "Size and scale",
			"blurb": "Broadens the hips for a wider, curvier lower figure.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "groin_mount"},
			"ops": [{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
				"prop": "hip_mm", "amount": {"v": 220.0}, "clamp": [400.0, 1600.0]}],
		},
		"cinch_waist": {
			"id": "cinch_waist", "name": "Cinch waist", "cat": "Size and scale",
			"blurb": "Pulls the waist in for a tighter, more hourglass shape.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "groin_mount"},
			"ops": [{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
				"prop": "waist_mm", "amount": {"v": -140.0}, "clamp": [300.0, 1400.0]}],
		},
		"thicken_waist": {
			"id": "thicken_waist", "name": "Thicken waist", "cat": "Size and scale",
			"blurb": "Thickens the midsection toward a straighter, sturdier build.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "groin_mount"},
			"ops": [{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
				"prop": "waist_mm", "amount": {"v": 260.0}, "clamp": [300.0, 1400.0]}],
		},
		"hourglass_figure": {
			"id": "hourglass_figure", "name": "Hourglass figure", "cat": "Size and scale",
			"blurb": "Cinches the waist and widens the hips together for a pronounced hourglass.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "groin_mount"},
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
					"prop": "waist_mm", "amount": {"v": -120.0}, "clamp": [300.0, 1400.0]},
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
					"prop": "hip_mm", "amount": {"v": 180.0}, "clamp": [400.0, 1600.0]},
			],
		},
		"grow_taller": {
			"id": "grow_taller", "name": "Grow taller", "cat": "Size and scale",
			"blurb": "Lengthens the legs and torso for greater overall height.",
			"staged": false,
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "leg"},
					"prop": "length_cm", "amount": {"v": 18.0}, "clamp": [0.0, 200.0]},
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "torso"},
					"prop": "length_cm", "amount": {"v": 10.0}, "clamp": [0.0, 140.0]},
			],
		},
		"shrink_to_fae": {
			"id": "shrink_to_fae", "name": "Shrink to fae size", "cat": "Size and scale",
			"blurb": "Shrinks the whole body down to a tiny, delicate fae stature.",
			"staged": false,
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "leg"},
					"prop": "length_cm", "amount": {"v": -70.0}, "clamp": [4.0, 200.0]},
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "arm"},
					"prop": "length_cm", "amount": {"v": -50.0}, "clamp": [4.0, 200.0]},
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "torso"},
					"prop": "length_cm", "amount": {"v": -42.0}, "clamp": [4.0, 140.0]},
			],
		},
		"grow_to_giant": {
			"id": "grow_to_giant", "name": "Grow to giant size", "cat": "Size and scale",
			"blurb": "Scales the whole body up to a towering giant frame.",
			"staged": false,
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "leg"},
					"prop": "length_cm", "amount": {"v": 160.0}, "clamp": [0.0, 400.0]},
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "arm"},
					"prop": "length_cm", "amount": {"v": 120.0}, "clamp": [0.0, 400.0]},
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "torso"},
					"prop": "length_cm", "amount": {"v": 90.0}, "clamp": [0.0, 300.0]},
			],
		},
	}


# ------------------------------------------------------------------- material
static func _material_tfs() -> Dictionary:
	return {
		"flesh_to_chitin": {
			"id": "flesh_to_chitin", "name": "Harden to chitin", "cat": "Material",
			"blurb": "Turns the whole body to a hard insectile chitin shell.",
			"staged": false,
			"ops": [{"effect": "set_material", "subtree_under": "torso_upper", "value": "chitin"}],
		},
		"flesh_to_slime": {
			"id": "flesh_to_slime", "name": "Become slime", "cat": "Material",
			"blurb": "Transmutes the whole body into a soft translucent slime.",
			"staged": false,
			"ops": [{"effect": "set_material", "subtree_under": "torso_upper", "value": "slime"}],
		},
		"flesh_to_scalehide": {
			"id": "flesh_to_scalehide", "name": "Scale-harden the hide", "cat": "Material",
			"blurb": "Replaces soft skin with a tough scaled hide across the body.",
			"staged": false,
			"ops": [{"effect": "set_covering", "subtree_under": "torso_upper", "value": "scales"}],
		},
		"darken_skin": {
			"id": "darken_skin", "name": "Deepen skin tone", "cat": "Material",
			"blurb": "Shifts skin to a deep, warm brown tone across the body.",
			"staged": false,
			"ops": [{"effect": "set_covering", "subtree_under": "torso_upper", "value": "skin_deep"}],
		},
		"redden_fur": {
			"id": "redden_fur", "name": "Recolor fur red", "cat": "Material",
			"blurb": "Tints any fur on the body to a russet red.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "tail"},
			"ops": [{"effect": "set_covering", "tag": "tail", "value": "fur_red",
				"when": {"op": "eq", "path": "#tail.covering", "v": "fur"}}],
		},
	}


# ------------------------------------------------------------------- covering
static func _covering_tfs() -> Dictionary:
	return {
		"grow_body_fur": {
			"id": "grow_body_fur", "name": "Grow body fur", "cat": "Covering",
			"blurb": "Covers the whole body in a soft coat of fur.",
			"staged": false,
			"ops": [{"effect": "set_covering", "subtree_under": "torso_upper", "value": "fur"}],
		},
		"grow_back_scales": {
			"id": "grow_back_scales", "name": "Grow scales", "cat": "Covering",
			"blurb": "Grows overlapping scales across the body surface.",
			"staged": false,
			"ops": [{"effect": "set_covering", "subtree_under": "torso_upper", "value": "scales"}],
		},
		"grow_feathers": {
			"id": "grow_feathers", "name": "Grow feathers", "cat": "Covering",
			"blurb": "Sprouts a layer of feathers over the body.",
			"staged": false,
			"ops": [{"effect": "set_covering", "subtree_under": "torso_upper", "value": "feathers"}],
		},
		"revert_to_skin": {
			"id": "revert_to_skin", "name": "Revert to bare skin", "cat": "Covering",
			"blurb": "Sheds any fur, scales, or feathers back to bare skin.",
			"staged": false,
			"ops": [{"effect": "set_covering", "subtree_under": "torso_upper", "value": "skin"}],
		},
	}


# ------------------------------------------------------------------- appendages
static func _appendage_tfs() -> Dictionary:
	return {
		"add_equine_tail": {
			"id": "add_equine_tail", "name": "Add a horse tail", "cat": "Appendages",
			"blurb": "Grows a long, flowing horse-like tail at the base of the spine.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "tail"}},
			"ops": [{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "tail_base",
				"subtree": _equine_tail()}],
		},
		"add_feline_tail": {
			"id": "add_feline_tail", "name": "Add a cat tail", "cat": "Appendages",
			"blurb": "Grows a slim, expressive feline tail at the base of the spine.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "tail"}},
			"ops": [{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "tail_base",
				"subtree": _feline_tail()}],
		},
		"add_draconic_tail": {
			"id": "add_draconic_tail", "name": "Add a dragon tail", "cat": "Appendages",
			"blurb": "Grows a thick, scaled dragon tail at the base of the spine.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "tail"}},
			"ops": [{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "tail_base",
				"subtree": _draconic_tail()}],
		},
		"add_feathered_wings": {
			"id": "add_feathered_wings", "name": "Add feathered wings", "cat": "Appendages",
			"blurb": "Grows a pair of large feathered wings from the upper back.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "wing"}},
			"ops": [
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_l",
					"subtree": _feathered_wing("wing_l")},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_r",
					"subtree": _feathered_wing("wing_r")},
			],
		},
		"add_membrane_wings": {
			"id": "add_membrane_wings", "name": "Add bat-like wings", "cat": "Appendages",
			"blurb": "Grows a pair of leathery membrane wings from the upper back.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "wing"}},
			"ops": [
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_l",
					"subtree": _membrane_wing("wing_l")},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_r",
					"subtree": _membrane_wing("wing_r")},
			],
		},
		"add_horns": {
			"id": "add_horns", "name": "Add horns", "cat": "Appendages",
			"blurb": "Grows a pair of curved horns from the head.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "horn"}},
			"ops": [
				{"effect": "graft_subtree", "target_node": "head", "at": "brow_l",
					"subtree": _horn("horn_l")},
				{"effect": "graft_subtree", "target_node": "head", "at": "brow_r",
					"subtree": _horn("horn_r")},
			],
		},
		"add_animal_ears": {
			"id": "add_animal_ears", "name": "Add animal ears", "cat": "Appendages",
			"blurb": "Grows a pair of furred animal ears on top of the head.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "ear"}},
			"ops": [
				{"effect": "graft_subtree", "target_node": "head", "at": "crown_l",
					"subtree": _animal_ear("ear_l", "fur")},
				{"effect": "graft_subtree", "target_node": "head", "at": "crown_r",
					"subtree": _animal_ear("ear_r", "fur")},
			],
		},
		"add_extra_arms": {
			"id": "add_extra_arms", "name": "Add a second pair of arms", "cat": "Appendages",
			"blurb": "Grows an extra pair of arms below the first.",
			"staged": false,
			"ops": [
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "lower_shoulder_l",
					"subtree": _extra_arm("arm_ll", "skin")},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "lower_shoulder_r",
					"subtree": _extra_arm("arm_rr", "skin")},
			],
		},
		"add_claws": {
			"id": "add_claws", "name": "Grow claws", "cat": "Appendages",
			"blurb": "Hardens the fingertips of every arm into sharp claws.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "arm"},
			"ops": [
				{"effect": "graft_subtree", "target_node": "arm_l", "at": "fingertips",
					"subtree": _seg("claw_l", "keratin", null, {"length_cm": 4.0}, ["claw"], [])},
				{"effect": "graft_subtree", "target_node": "arm_r", "at": "fingertips",
					"subtree": _seg("claw_r", "keratin", null, {"length_cm": 4.0}, ["claw"], [])},
			],
		},
		"make_hooves": {
			"id": "make_hooves", "name": "Grow hooves", "cat": "Appendages",
			"blurb": "Caps each leg with a hard keratin hoof.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "leg"},
			"ops": [
				{"effect": "graft_subtree", "target_node": "leg_l", "at": "foot",
					"subtree": _seg("hoof_l", "keratin", null, {"length_cm": 10.0}, ["hoof"], [])},
				{"effect": "graft_subtree", "target_node": "leg_r", "at": "foot",
					"subtree": _seg("hoof_r", "keratin", null, {"length_cm": 10.0}, ["hoof"], [])},
			],
		},
		"make_digitigrade": {
			"id": "make_digitigrade", "name": "Make legs digitigrade", "cat": "Appendages",
			"blurb": "Reshapes the legs to a digitigrade stance that walks on the toes.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "leg"},
			"ops": [{"effect": "tag_add", "tag": "leg", "value": "digitigrade"}],
		},
	}


# ------------------------------------------------------------------- whole-body plans
static func _plan_tfs() -> Dictionary:
	return {
		"biped_to_taur": {
			"id": "biped_to_taur", "name": "Become a taur", "cat": "Whole-body plans",
			"blurb": "Replaces the two legs with a four-legged barrel below the upright torso.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "barrel"}},
			"ops": [
				# A biped has no lower-body part — its legs hang off the torso. Remove every
				# leg, graft the barrel (a real body_core lower structure), then reparent the
				# groin parts (genitals/butt) onto the barrel so they aren't lost.
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": _quad_barrel("barrel", "skin")},
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "barrel", "at": "groin_mount"},
			],
		},
		"taur_to_biped": {
			"id": "taur_to_biped", "name": "Return to two legs", "cat": "Whole-body plans",
			"blurb": "Removes a taur barrel and restores an ordinary two-legged stance.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "barrel"},
			"ops": [
				# Bring the groin parts (genitals/butt) back onto the torso, drop the barrel,
				# then regrow two legs directly on the torso — a biped has no lower part.
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "upper_body", "at": "groin_mount"},
				{"effect": "remove_subtree", "target_node": "barrel"},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "leg_l",
					"subtree": _seg("leg_l", "flesh", "skin", {"length_cm": 85.0}, ["leg"], [])},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "leg_r",
					"subtree": _seg("leg_r", "flesh", "skin", {"length_cm": 85.0}, ["leg"], [])},
			],
		},
		"biped_to_naga": {
			"id": "biped_to_naga", "name": "Become a naga", "cat": "Whole-body plans",
			"blurb": "Replaces the legs with a single long, scaled serpentine tail.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "leg"},
			"ops": [
				# Remove the legs, graft the serpentine lower, then carry the groin parts
				# (genitals/butt) onto it — a naga keeps its sex, just loses the legs.
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": _naga_lower()},
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "serpentine", "at": "groin_mount"},
			],
		},
		"biped_to_quadruped": {
			"id": "biped_to_quadruped", "name": "Become a quadruped", "cat": "Whole-body plans",
			"blurb": "Drops to all fours: the arms become front legs on a four-legged barrel.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "barrel"}},
			"ops": [
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "arm"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": _quad_barrel("barrel", "skin")},
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "barrel", "at": "groin_mount"},
				{"effect": "tag_add", "target_node": "torso_upper", "value": "quadruped"},
			],
		},
		"biped_to_harpy": {
			"id": "biped_to_harpy", "name": "Become a harpy", "cat": "Whole-body plans",
			"blurb": "Trades arms for feathered wings and legs for clawed bird legs.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "leg"},
			"ops": [
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "arm"}},
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_l",
					"subtree": _feathered_wing("wing_l")},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_r",
					"subtree": _feathered_wing("wing_r")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "leg_l",
					"subtree": _bird_leg("leg_bird_l")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "leg_r",
					"subtree": _bird_leg("leg_bird_r")},
				{"effect": "set_covering", "subtree_under": "torso_upper", "value": "feathers",
					"when": {"op": "has_tag", "tag": "torso"}},
			],
		},
	}


static func _naga_lower() -> Dictionary:
	return _serpent_tail("naga_tail")


# ------------------------------------------------------------------- species configs
static func _species_tfs() -> Dictionary:
	return {
		"config_wolf_anthro": {
			"id": "config_wolf_anthro", "name": "Wolf-folk", "cat": "Species configurations",
			"blurb": "A furred upright canine: body fur, wolfish ears, a bushy tail, and claws.",
			"staged": false,
			"ops": [
				{"effect": "set_covering", "subtree_under": "torso_upper", "value": "fur"},
				{"effect": "graft_subtree", "target_node": "head", "at": "crown_l",
					"subtree": _animal_ear("ear_l", "fur")},
				{"effect": "graft_subtree", "target_node": "head", "at": "crown_r",
					"subtree": _animal_ear("ear_r", "fur")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "tail_base",
					"subtree": _seg("tail", "flesh", "fur", {"length_cm": 70.0}, ["tail"], [])},
				{"effect": "graft_subtree", "target_node": "arm_l", "at": "fingertips",
					"subtree": _seg("claw_l", "keratin", null, {"length_cm": 3.0}, ["claw"], [])},
				{"effect": "graft_subtree", "target_node": "arm_r", "at": "fingertips",
					"subtree": _seg("claw_r", "keratin", null, {"length_cm": 3.0}, ["claw"], [])},
			],
		},
		"config_fox_anthro": {
			"id": "config_fox_anthro", "name": "Fox-folk", "cat": "Species configurations",
			"blurb": "A slim red-furred vulpine: russet fur, large ears, and a long brush tail.",
			"staged": false,
			"ops": [
				{"effect": "set_covering", "subtree_under": "torso_upper", "value": "fur_red"},
				{"effect": "graft_subtree", "target_node": "head", "at": "crown_l",
					"subtree": _animal_ear("ear_l", "fur_red")},
				{"effect": "graft_subtree", "target_node": "head", "at": "crown_r",
					"subtree": _animal_ear("ear_r", "fur_red")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "tail_base",
					"subtree": _seg("tail", "flesh", "fur_red", {"length_cm": 80.0}, ["tail"], [])},
			],
		},
		"config_dragon": {
			"id": "config_dragon", "name": "Dragon-kin", "cat": "Species configurations",
			"blurb": "A scaled draconic form: scaled hide, horns, membrane wings, and a heavy tail.",
			"staged": false,
			"ops": [
				{"effect": "set_covering", "subtree_under": "torso_upper", "value": "scales"},
				{"effect": "graft_subtree", "target_node": "head", "at": "brow_l",
					"subtree": _horn("horn_l")},
				{"effect": "graft_subtree", "target_node": "head", "at": "brow_r",
					"subtree": _horn("horn_r")},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_l",
					"subtree": _membrane_wing("wing_l")},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_r",
					"subtree": _membrane_wing("wing_r")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "tail_base",
					"subtree": _draconic_tail()},
			],
		},
		"config_naga": {
			"id": "config_naga", "name": "Naga", "cat": "Species configurations",
			"blurb": "A serpent-folk: the legs give way to one long scaled tail, with a scaled hide.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "leg"},
			"ops": [
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": _naga_lower()},
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "serpentine", "at": "groin_mount"},
				{"effect": "set_covering", "subtree_under": "torso_upper", "value": "scales",
					"when": {"op": "has_tag", "tag": "torso"}},
			],
		},
		"config_harpy": {
			"id": "config_harpy", "name": "Harpy", "cat": "Species configurations",
			"blurb": "A bird-folk: feathered body, winged arms, and clawed digitigrade bird legs.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "leg"},
			"ops": [
				{"effect": "set_covering", "subtree_under": "torso_upper", "value": "feathers",
					"when": {"op": "has_tag", "tag": "torso"}},
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "arm"}},
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_l",
					"subtree": _feathered_wing("wing_l")},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_r",
					"subtree": _feathered_wing("wing_r")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "leg_l",
					"subtree": _bird_leg("leg_bird_l")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "leg_r",
					"subtree": _bird_leg("leg_bird_r")},
			],
		},
		"config_slime": {
			"id": "config_slime", "name": "Slime-person", "cat": "Species configurations",
			"blurb": "A soft translucent body of living slime, from head to toe.",
			"staged": false,
			"ops": [{"effect": "set_material", "subtree_under": "torso_upper", "value": "slime"}],
		},
		"config_holstaur": {
			"id": "config_holstaur", "name": "Bovine holstaur", "cat": "Species configurations",
			"blurb": "A bovine form: short horns, big lactating breasts, a tufted tail, and a teated udder.",
			"staged": false,
			"ops": [
				{"effect": "graft_subtree", "target_node": "head", "at": "brow_l",
					"subtree": _short_horn("horn_l")},
				{"effect": "graft_subtree", "target_node": "head", "at": "brow_r",
					"subtree": _short_horn("horn_r")},
				{"effect": "graft_subtree", "target_node": "head", "at": "crown_l",
					"subtree": _animal_ear("ear_l", "fur")},
				{"effect": "graft_subtree", "target_node": "head", "at": "crown_r",
					"subtree": _animal_ear("ear_r", "fur")},
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "breast"},
					"prop": "volume_ml", "amount": {"v": 1600.0}, "clamp": [0.0, 8000.0]},
				{"effect": "fluid_delta", "target": {"select": "all_tagged", "tag": "breast"},
					"fluid": "milk", "amount": {"v": 300}, "capacity_delta": 600, "clamp_amount": [0]},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "tail_base",
					"subtree": _seg("tail", "flesh", "fur", {"length_cm": 70.0}, ["tail"], [])},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "udder_mount",
					"subtree": _udder("udder")},
				{"effect": "fluid_delta", "tag": "udder", "fluid": "milk",
					"amount": {"v": 1500}, "capacity_delta": 0, "clamp_amount": [0]},
			],
		},
	}


# ------------------------------------------------------------------- reproductive / fluids
static func _reproductive_tfs() -> Dictionary:
	return {
		"start_lactation": {
			"id": "start_lactation", "name": "Start lactating", "cat": "Reproductive and fluids",
			"blurb": "Opens milk capacity in every breast and begins production.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [{"effect": "fluid_delta", "target": {"select": "all_tagged", "tag": "breast"},
				"fluid": "milk", "amount": {"v": 200}, "capacity_delta": 200, "clamp_amount": [0]}],
		},
		"dry_up_lactation": {
			"id": "dry_up_lactation", "name": "Dry up milk", "cat": "Reproductive and fluids",
			"blurb": "Empties every breast of milk.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [{"effect": "fluid_delta", "target": {"select": "all_tagged", "tag": "breast"},
				"fluid": "milk", "amount": {"v": -5000}, "capacity_delta": 0, "clamp_amount": [0]}],
		},
		"add_penis": {
			"id": "add_penis", "name": "Add a penis", "cat": "Reproductive and fluids",
			"blurb": "Grows a penis at a free groin mount; derived sex follows the new part.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "groin"},
			"ops": [{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "genital_mount_c",
				"subtree": _penis("genital_added")}],
		},
		"remove_penis": {
			"id": "remove_penis", "name": "Remove penis", "cat": "Reproductive and fluids",
			"blurb": "Removes every penis; derived sex follows the loss of the part.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "phallic"},
			"ops": [{"effect": "remove_subtree",
				"target": {"select": "all_tagged", "tag": "genital", "kind": "phallic"}}],
		},
		"add_vagina": {
			"id": "add_vagina", "name": "Add a vagina", "cat": "Reproductive and fluids",
			"blurb": "Grows a vagina at a free groin mount; derived sex follows the new part.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "vaginal"}},
			"ops": [{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "genital_mount_v",
				"subtree": _vagina("genital_v")}],
		},
		"feminize_parts": {
			"id": "feminize_parts", "name": "Feminize", "cat": "Reproductive and fluids",
			"blurb": "Removes every penis, adds a vagina if absent, and adds a third breast row.",
			"staged": false,
			"ops": [
				{"effect": "remove_subtree",
					"target": {"select": "all_tagged", "tag": "genital", "kind": "phallic"},
					"when": {"op": "has_tag", "tag": "phallic"}},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "genital_mount_v",
					"subtree": _vagina("genital_v"),
					"when": {"op": "not", "of": {"op": "has_tag", "tag": "vaginal"}}},
				# Guarded so a second application adds no duplicate-id breast row (idempotent).
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "chest_c",
					"subtree": _breast("breast_c", 650),
					"when": {"op": "not", "of": {"op": "eq", "path": "#breast_c.id", "v": "breast_c"}}},
			],
		},
		"masculinize_parts": {
			"id": "masculinize_parts", "name": "Masculinize", "cat": "Reproductive and fluids",
			"blurb": "Removes every vagina, adds a penis if absent, and removes the breasts.",
			"staged": false,
			"ops": [
				{"effect": "remove_subtree",
					"target": {"select": "all_tagged", "tag": "genital", "kind": "vaginal"},
					"when": {"op": "has_tag", "tag": "vaginal"}},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "genital_mount_c",
					"subtree": _penis("genital_added"),
					"when": {"op": "not", "of": {"op": "has_tag", "tag": "phallic"}}},
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "breast"}},
			],
		},
		"add_extra_breasts": {
			"id": "add_extra_breasts", "name": "Add a second breast row", "cat": "Reproductive and fluids",
			"blurb": "Grows an extra row of breasts below the first.",
			"staged": false,
			"ops": [
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "chest_lower_l",
					"subtree": _breast("breast_ll", 450)},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "chest_lower_r",
					"subtree": _breast("breast_rr", 450)},
			],
		},
		"add_extra_nipples": {
			"id": "add_extra_nipples", "name": "Add extra nipples", "cat": "Reproductive and fluids",
			"blurb": "Grows a second nipple on each breast.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [
				{"effect": "graft_subtree", "target_node": "breast_l", "at": "areola_2",
					"subtree": _nipple("nipple_l2")},
				{"effect": "graft_subtree", "target_node": "breast_r", "at": "areola_2",
					"subtree": _nipple("nipple_r2")},
			],
		},
		"add_teats": {
			"id": "add_teats", "name": "Add crotch teats", "cat": "Reproductive and fluids",
			"blurb": "Grows a row of small teats along the lower belly.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "groin"},
			"ops": [
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "belly_l",
					"subtree": _teat("teat_belly_l")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "belly_r",
					"subtree": _teat("teat_belly_r")},
			],
		},
	}


# ------------------------------------------------------------------- hybrids
static func _hybrid_tfs() -> Dictionary:
	return {
		"hybrid_chitin_naga": {
			"id": "hybrid_chitin_naga", "name": "Chitin naga", "cat": "Hybrids",
			"blurb": "A serpentine lower body of hard chitin under a chitin-shelled torso.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "leg"},
			"ops": [
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": _serpent_tail("naga_tail")},
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "serpentine", "at": "groin_mount"},
				{"effect": "set_material", "subtree_under": "torso_upper", "value": "chitin"},
			],
		},
		"hybrid_furred_taur": {
			"id": "hybrid_furred_taur", "name": "Furred taur", "cat": "Hybrids",
			"blurb": "A four-legged taur barrel and torso both covered in fur.",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "barrel"}},
			"ops": [
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": _quad_barrel("barrel", "fur")},
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "barrel", "at": "groin_mount"},
				{"effect": "set_covering", "subtree_under": "torso_upper", "value": "fur",
					"when": {"op": "has_tag", "tag": "torso"}},
				{"effect": "graft_subtree", "target_node": "barrel", "at": "tail_base",
					"subtree": _seg("tail", "flesh", "fur", {"length_cm": 70.0}, ["tail"], [])},
			],
		},
		"hybrid_slime_harpy": {
			"id": "hybrid_slime_harpy", "name": "Slime harpy", "cat": "Hybrids",
			"blurb": "A winged bird-legged harpy whose whole body is translucent slime.",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "leg"},
			"ops": [
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "arm"}},
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_l",
					"subtree": _feathered_wing("wing_l")},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "back_r",
					"subtree": _feathered_wing("wing_r")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "leg_l",
					"subtree": _bird_leg("leg_bird_l")},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "leg_r",
					"subtree": _bird_leg("leg_bird_r")},
				{"effect": "set_material", "subtree_under": "torso_upper", "value": "slime"},
			],
		},
	}
