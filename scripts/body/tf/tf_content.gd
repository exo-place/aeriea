## TfContent — the MVP setting-neutral content (TF system §7).
##
## A starting biped body built from GENERIC segments + conventional tags, and the
## ~5 TF records spanning every op category. These are PURE MECHANISM DEMOS — no lore,
## no setting flavor (§2, §4.3). Shipped OPEN: few values, not a closed enum (§7) —
## the same applier/traversal work unchanged as values are added.
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")


# --- the starting biped (§7) ----------------------------------------------------
# torso_upper (root) -> head, arm_l, arm_r, breast_l, breast_r, leg_l, leg_r, butt,
# genital_1 (phallic), genital_2 (vaginal). Breasts + the phallic genital carry fluid
# reservoirs (milk / seed / nectar), all amount 0 with capacity set. A biped has NO
# separate lower-body part: the legs hang directly off the torso, and the butt + genital
# mounts carry the `groin` region tag (so they stay tag-targetable) while attaching to
# the torso just like any other segment. The torso stays `body_core`/`upper_body` only —
# never `lower_body` — so a biped never false-matches the taur/naga detector. A real
# lower-body STRUCTURE (a barrel/serpent) is an added body_core segment, not present here.
static func biped() -> Dictionary:
	var seg := BodyGraph.segment
	var c := BodyGraph.child
	var fl := BodyGraph.fluid
	var root: Dictionary = seg.call("torso_upper", "flesh", "skin",
		{"length_cm": 55.0, "waist_mm": 620, "hip_mm": 900},
		["torso", "body_core", "upper_body", "groin_mount"], [
			c.call("neck", seg.call("head", "flesh", "skin", {}, ["head"], [])),
			c.call("shoulder_l", seg.call("arm_l", "flesh", "skin", {"length_cm": 62.0}, ["arm"], [])),
			c.call("shoulder_r", seg.call("arm_r", "flesh", "skin", {"length_cm": 62.0}, ["arm"], [])),
			c.call("chest_l", seg.call("breast_l", "flesh", "skin", {"volume_ml": 650, "band_mm": 810},
				["breast"], [], [fl.call("milk", 0, 400)])),
			c.call("chest_r", seg.call("breast_r", "flesh", "skin", {"volume_ml": 650, "band_mm": 810},
				["breast"], [], [fl.call("milk", 0, 400)])),
			c.call("leg_l", seg.call("leg_l", "flesh", "skin", {"length_cm": 85.0}, ["leg"], [])),
			c.call("leg_r", seg.call("leg_r", "flesh", "skin", {"length_cm": 85.0}, ["leg"], [])),
			c.call("rear", seg.call("butt", "flesh", "skin", {"volume_ml": 800}, ["butt", "groin"], [])),
			c.call("genital_mount_a", seg.call("genital_1", "flesh", "skin",
				{"length_cm": 15.0, "girth_cm": 11.0}, ["genital", "groin", "phallic"], [],
				[fl.call("seed", 0, 30)])),
			c.call("genital_mount_b", seg.call("genital_2", "flesh", "skin",
				{"depth_cm": 12.0}, ["genital", "groin", "vaginal"], [],
				[fl.call("nectar", 0, 40)])),
		])
	return {"root": root, "scalars": {"height_cm": 170.0}}


# --- subtrees for the compound/genital TFs --------------------------------------
static func phallic_genital(id: String) -> Dictionary:
	return BodyGraph.segment(id, "flesh", "skin",
		{"length_cm": 14.0, "girth_cm": 10.0}, ["genital", "groin", "phallic"], [],
		[BodyGraph.fluid("seed", 0, 30)])


static func vaginal_genital(id: String) -> Dictionary:
	return BodyGraph.segment(id, "flesh", "skin",
		{"depth_cm": 11.0}, ["genital", "groin", "vaginal"], [],
		[BodyGraph.fluid("nectar", 0, 40)])


static func breast_seg(id: String) -> Dictionary:
	return BodyGraph.segment(id, "flesh", "skin", {"volume_ml": 500, "band_mm": 810},
		["breast"], [], [BodyGraph.fluid("milk", 0, 400)])


# --- a quadruped-lower subtree (for the graft / merge demo) ----------------------
# A from-scratch second body-core barrel + four legs, tagged lower_body/body_core/leg by
# convention. A barrel and an upright torso are BOTH body-core — same `body_core` tag, no
# special `spine` tag. Shipped SKIN-covered so the set_covering_fur_upward demo (§4.3c)
# actually creeps a visible skin->fur boundary up the structure stage by stage.
static func quadruped_lower() -> Dictionary:
	var seg := BodyGraph.segment
	var c := BodyGraph.child
	return seg.call("barrel", "flesh", "skin", {"length_cm": 90.0, "waist_mm": 700, "hip_mm": 1100},
		["barrel", "body_core", "lower_body", "groin_mount"], [
			c.call("leg_fl", seg.call("leg_fl", "flesh", "skin", {"length_cm": 80.0}, ["leg"], [])),
			c.call("leg_fr", seg.call("leg_fr", "flesh", "skin", {"length_cm": 80.0}, ["leg"], [])),
			c.call("leg_bl", seg.call("leg_bl", "flesh", "skin", {"length_cm": 80.0}, ["leg"], [])),
			c.call("leg_br", seg.call("leg_br", "flesh", "skin", {"length_cm": 80.0}, ["leg"], [])),
		])


# --- a small tail subtree (for the grow demo) -----------------------------------
static func tail_seg() -> Dictionary:
	return BodyGraph.segment("tail", "flesh", "fur", {"length_cm": 5.0}, ["tail"], [])


# --- the TF registry (id -> TF record) ------------------------------------------
static func registry() -> Dictionary:
	return {
		# (a) FORM graft, instant: biped -> taur. A biped has no lower-body part — its legs
		# hang off the torso — so the form edit removes every `leg`, grafts the quadruped
		# barrel (a real body_core lower structure) at the hip, then REPARENTS the groin
		# parts (genitals + butt) onto the barrel so they're carried by the new lower body
		# instead of being lost. Gate: not already a barrel.
		"graft_quadruped_lower": {
			"id": "graft_quadruped_lower",
			"name": "Graft quadruped lower body",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "barrel"}},
			"ops": [
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": quadruped_lower()},
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "barrel", "at": "groin_mount"},
			],
		},

		# (b) MATERIAL set, staged, ONE segment per stage, lowest-first (chitin creeps up
		# the lower body the same way fur-creep advances a covering boundary). Ordered ops,
		# each guarded by `material != chitin`; `one_op_per_stage` fires only the FIRST
		# effective op per stage so exactly one segment hardens per clock step. Setting
		# chitin nulls covering (§3.2). 5 segments (4 legs + barrel) -> 5 stages.
		"set_lower_material_chitin": {
			"id": "set_lower_material_chitin", "name": "Harden lower body to chitin",
			"staged": true, "stage_seconds": 1200, "max_stages": 5, "one_op_per_stage": true,
			"gate": {"op": "has_tag", "tag": "lower_body"},
			"ops": [
				{"effect": "set_material", "target_node": "leg_bl", "value": "chitin",
					"when": {"op": "ne", "path": "#leg_bl.material", "v": "chitin"}},
				{"effect": "set_material", "target_node": "leg_br", "value": "chitin",
					"when": {"op": "ne", "path": "#leg_br.material", "v": "chitin"}},
				{"effect": "set_material", "target_node": "leg_fl", "value": "chitin",
					"when": {"op": "ne", "path": "#leg_fl.material", "v": "chitin"}},
				{"effect": "set_material", "target_node": "leg_fr", "value": "chitin",
					"when": {"op": "ne", "path": "#leg_fr.material", "v": "chitin"}},
				{"effect": "set_material", "target_node": "barrel", "value": "chitin",
					"when": {"op": "ne", "path": "#barrel.material", "v": "chitin"}},
			],
		},

		# (c) COVERING set, staged, ONE segment per stage, lowest-first (fur creeps up).
		# Ordered ops, each guarded by `covering == skin`; `one_op_per_stage` makes the
		# applier fire only the FIRST effective op per stage, so exactly one boundary
		# advances per clock step (§4.3c). The current skin<->fur joint is a describable
		# transition zone (§6). leg_fl/leg_fr are intentionally NOT in the path.
		"set_covering_fur_upward": {
			"id": "set_covering_fur_upward", "name": "Fur creeps up lower body",
			"staged": true, "stage_seconds": 900, "max_stages": 4, "one_op_per_stage": true,
			"gate": {"op": "material_is", "node": "barrel", "v": "flesh"},
			"ops": [
				{"effect": "set_covering", "target_node": "leg_bl", "value": "fur",
					"when": {"op": "eq", "path": "#leg_bl.covering", "v": "skin"}},
				{"effect": "set_covering", "target_node": "leg_br", "value": "fur",
					"when": {"op": "eq", "path": "#leg_br.covering", "v": "skin"}},
				{"effect": "set_covering", "target_node": "barrel", "value": "fur",
					"when": {"op": "eq", "path": "#barrel.covering", "v": "skin"}},
				{"effect": "set_covering", "target_node": "torso_upper", "value": "fur",
					"when": {"op": "eq", "path": "#torso_upper.covering", "v": "skin"}},
			],
		},

		# (d) PROPERTY delta, staged + seeded: grow the tail's length each stage.
		"grow_tail_length": {
			"id": "grow_tail_length", "name": "Grow tail",
			"staged": true, "stage_seconds": 900, "max_stages": 5,
			"gate": {"op": "has_tag", "tag": "tail"},
			"ops": [
				{"effect": "prop_delta", "target_node": "tail", "prop": "length_cm",
					"amount": {"roll": "uniform", "lo": 2.0, "hi": 5.0}, "clamp": [0.0, 120.0]},
			],
		},

		# (a2) FORM graft, STAGED: the same biped -> taur graft, but progressive. Form
		# edits (remove/graft) are stageable like any op (§4.2) — there's no reason a graft
		# must be instant. Stage 0 removes the biped lower body and grafts the quadruped
		# barrel (one_op_per_stage off, so both form ops fire together as the single "graft"
		# stage); stages 1-4 then GROW the newly-grafted legs, so the lower body is grafted
		# then grows in over the clock. Gate: not already taur. The grow op's `when` guard
		# makes the trailing stages no-op cleanly once legs reach length.
		"graft_quadruped_lower_staged": {
			"id": "graft_quadruped_lower_staged",
			"name": "Graft quadruped lower body, gradual",
			"staged": true, "stage_seconds": 1200, "max_stages": 5,
			# NB: no TF-level `gate` here. The "not already taur" guard lives on the graft op
			# as a `when` instead — a TF-level gate is re-checked every stage and would FALSE
			# out (and kill the staged TF) the moment the barrel lands. Op-level `when` lets
			# the form fire once in stage 0 while the grow stages keep running.
			"ops": [
				# stage 0: the form edit. A biped's legs hang off the torso, so remove every
				# `leg`, graft the barrel, and reparent the groin parts (genitals/butt) onto
				# it. On later stages these no-op (the legs are gone / the graft+reparent
				# `when` guards keep them from re-firing once the barrel is present).
				{"effect": "remove_subtree", "target": {"select": "all_tagged", "tag": "leg"},
					"when": {"op": "not", "of": {"op": "has_tag", "tag": "barrel"}}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": quadruped_lower(),
					"when": {"op": "not", "of": {"op": "has_tag", "tag": "barrel"}}},
				{"effect": "reparent", "target": {"select": "all_tagged", "tag": "groin"},
					"new_parent_tag": "barrel", "at": "groin_mount",
					"when": {"op": "has_tag", "tag": "barrel"}},
				# stages 1-4: grow the grafted barrel a little each step (visible progression
				# after the form lands). Guarded so it stops once grown.
				{"effect": "prop_delta", "target_node": "barrel", "prop": "length_cm",
					"amount": {"roll": "uniform", "lo": 3.0, "hi": 8.0}, "clamp": [0.0, 130.0],
					"when": {"op": "lt", "path": "#barrel.props.length_cm", "v": 130.0}},
			],
		},

		# (e) a graft to add the tail (instant) — used before grow_tail_length.
		"graft_tail": {
			"id": "graft_tail", "name": "Graft a tail", "staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "tail"}},
			"ops": [
				{"effect": "graft_subtree", "target_node": "barrel", "at": "tail_base",
					"subtree": tail_seg()},
			],
		},

		# === COMPOUND PARTS / GENITALIA / FLUIDS (compound-parts-and-fluids.md §8) ===

		# (f) add a member — graft a phallic genital at a free groin mount. Proves "the
		# Nth member" grows by one (an ordinary graft, like a tail); derived sex follows.
		"add_phallic_genital": {
			"id": "add_phallic_genital", "name": "Graft a phallic genital", "staged": false,
			"gate": {"op": "has_tag", "tag": "groin"},
			"ops": [
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "genital_mount_c",
					"subtree": phallic_genital("genital_3")},
			],
		},

		# (g) remove a member — drop the 1st phallic genital by ORDINAL (node-id order).
		# Proves nth_tagged ordinal targeting; undo re-grafts it exactly (§3.3).
		"remove_first_phallic": {
			"id": "remove_first_phallic", "name": "Remove first phallic genital",
			"staged": false,
			"gate": {"op": "has_tag", "tag": "phallic"},
			"ops": [
				{"effect": "remove_subtree",
					"target": {"select": "nth_tagged", "tag": "genital", "kind": "phallic", "index": 0}},
			],
		},

		# (h) grow a member — prop_delta length+girth on the 1st phallic genital, staged
		# + seeded. (grow targets a single node via nth_tagged resolving to one.)
		"grow_first_phallic": {
			"id": "grow_first_phallic", "name": "Grow first phallic genital",
			"staged": true, "stage_seconds": 600, "max_stages": 4,
			"gate": {"op": "has_tag", "tag": "phallic"},
			"ops": [
				{"effect": "prop_delta",
					"target": {"select": "nth_tagged", "tag": "genital", "kind": "phallic", "index": 0},
					"prop": "length_cm",
					"amount": {"roll": "uniform", "lo": 1.0, "hi": 3.0}, "clamp": [0.0, 40.0]},
				{"effect": "prop_delta",
					"target": {"select": "nth_tagged", "tag": "genital", "kind": "phallic", "index": 0},
					"prop": "girth_cm",
					"amount": {"roll": "uniform", "lo": 0.5, "hi": 1.5}, "clamp": [0.0, 25.0]},
			],
		},

		# (i) set lactating — open the milk reservoir capacity AND begin production. The
		# fluid_delta fans across ALL breasts (all_tagged), seeded integer fill, clamped
		# to [0, capacity]. Instant kick-start; see lactation_production for the staged
		# refill on sim_clock (§5.4).
		"set_lactating": {
			"id": "set_lactating", "name": "Begin lactating", "staged": false,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [
				{"effect": "fluid_delta",
					"target": {"select": "all_tagged", "tag": "breast"}, "fluid": "milk",
					"amount": {"roll": "uniform_int", "lo": 80, "hi": 160},
					"capacity_delta": 0, "clamp_amount": [0]},
			],
		},

		# (i2) standing milk production — a staged fluid_delta refilling on sim_clock,
		# self-clamping at capacity (§5.4). Integer mL per stage.
		"lactation_production": {
			"id": "lactation_production", "name": "Milk production over time",
			"staged": true, "stage_seconds": 3600, "max_stages": 8,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [
				{"effect": "fluid_delta",
					"target": {"select": "all_tagged", "tag": "breast"}, "fluid": "milk",
					"amount": {"roll": "uniform_int", "lo": 40, "hi": 70},
					"capacity_delta": 0, "clamp_amount": [0]},
			],
		},

		# (j) feminize — pure PART OPS that shift the DERIVED sex (no gender field, §6.2):
		# remove every phallic genital, graft a vaginal one if absent, graft a 3rd breast
		# row if not already present, and open milk capacity. Derived sex flips
		# male/herm -> female for free. Every graft is GUARDED by a `when` so re-applying
		# the TF is idempotent — a second pass adds no duplicate-id parts (the breast graft
		# fires only while fewer than three breasts are present).
		"feminize": {
			"id": "feminize", "name": "Feminize", "staged": false,
			"ops": [
				{"effect": "remove_subtree",
					"target": {"select": "all_tagged", "tag": "genital", "kind": "phallic"},
					"when": {"op": "has_tag", "tag": "phallic"}},
				{"effect": "graft_subtree", "parent_tag": "groin_mount", "at": "genital_mount_v",
					"subtree": vaginal_genital("genital_v"),
					"when": {"op": "not", "of": {"op": "has_tag", "tag": "vaginal"}}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "chest_c",
					"subtree": breast_seg("breast_c"),
					"when": {"op": "not", "of": {"op": "eq", "path": "#breast_c.id", "v": "breast_c"}}},
				{"effect": "fluid_delta",
					"target": {"select": "all_tagged", "tag": "breast"}, "fluid": "milk",
					"amount": {"v": 0}, "capacity_delta": 100, "clamp_amount": [0]},
			],
		},

		# === SIZE TFs (compound-parts-and-fluids.md §4.3) — prop_delta on the canonical
		# integer volume/length, staged + seeded + clamped. The derived cup/size under
		# the current measurement standard re-reads off the new volume for free.

		# (k) grow every breast — fan a seeded volume_ml delta across all breasts.
		"grow_breasts": {
			"id": "grow_breasts", "name": "Grow breasts", "staged": true,
			"stage_seconds": 600, "max_stages": 4,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "breast"},
					"prop": "volume_ml",
					"amount": {"roll": "uniform", "lo": 120.0, "hi": 240.0}, "clamp": [0.0, 6000.0]},
			],
		},

		# (l) shrink every breast — the same fan with a negative seeded delta.
		"shrink_breasts": {
			"id": "shrink_breasts", "name": "Shrink breasts", "staged": true,
			"stage_seconds": 600, "max_stages": 4,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "breast"},
					"prop": "volume_ml",
					"amount": {"roll": "uniform", "lo": -240.0, "hi": -120.0}, "clamp": [0.0, 6000.0]},
			],
		},

		# (m) widen the rib band on every breast — raises band_mm at fixed volume, which
		# LOWERS the derived cup letter (band-dependence is real, not cosmetic).
		"widen_band": {
			"id": "widen_band", "name": "Widen rib band", "staged": false,
			"gate": {"op": "has_tag", "tag": "breast"},
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "breast"},
					"prop": "band_mm",
					"amount": {"v": 60.0}, "clamp": [600.0, 1200.0]},
			],
		},

		# === FIGURE (BWH) TFs (compound-parts-and-fluids.md §4.3) — prop_delta on the
		# canonical integer waist_mm / hip_mm (MILLIMETERS) stored on the body-core carrier
		# (the `groin_mount` segment). The derived figure line (shape/build/triple) re-reads
		# off the new measurements for free. Authored against the `groin_mount` tag, not a
		# node id, so they work whether the carrier is a biped torso or a taur barrel. Deltas
		# and clamps are in mm (a centimeter is 10 units).

		# (o) widen the hips — raise hip_mm; widens the figure toward pear/wide-hipped.
		"widen_hips": {
			"id": "widen_hips", "name": "Widen hips", "staged": true,
			"stage_seconds": 600, "max_stages": 4,
			"gate": {"op": "has_tag", "tag": "groin_mount"},
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
					"prop": "hip_mm",
					"amount": {"roll": "uniform", "lo": 40.0, "hi": 80.0}, "clamp": [400.0, 1600.0]},
			],
		},

		# (p) cinch the waist — shrink waist_mm; deepens the hourglass / slims the waist.
		"cinch_waist": {
			"id": "cinch_waist", "name": "Cinch waist", "staged": true,
			"stage_seconds": 600, "max_stages": 4,
			"gate": {"op": "has_tag", "tag": "groin_mount"},
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
					"prop": "waist_mm",
					"amount": {"roll": "uniform", "lo": -60.0, "hi": -30.0}, "clamp": [300.0, 1400.0]},
			],
		},

		# (q) thicken the waist — grow waist_mm toward a straighter / apple figure.
		"thicken_waist": {
			"id": "thicken_waist", "name": "Thicken waist", "staged": true,
			"stage_seconds": 600, "max_stages": 4,
			"gate": {"op": "has_tag", "tag": "groin_mount"},
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
					"prop": "waist_mm",
					"amount": {"roll": "uniform", "lo": 40.0, "hi": 80.0}, "clamp": [300.0, 1400.0]},
			],
		},

		# (r) hourglass figure — cinch the waist AND widen the hips together for a pronounced
		# hourglass. Two integer deltas, both clamped, both on the carrier.
		"hourglass_figure": {
			"id": "hourglass_figure", "name": "Hourglass figure", "staged": true,
			"stage_seconds": 600, "max_stages": 4,
			"gate": {"op": "has_tag", "tag": "groin_mount"},
			"ops": [
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
					"prop": "waist_mm",
					"amount": {"roll": "uniform", "lo": -50.0, "hi": -30.0}, "clamp": [300.0, 1400.0]},
				{"effect": "prop_delta", "target": {"select": "all_tagged", "tag": "groin_mount"},
					"prop": "hip_mm",
					"amount": {"roll": "uniform", "lo": 30.0, "hi": 60.0}, "clamp": [400.0, 1600.0]},
			],
		},

		# (n) grow the butt — a seeded volume_ml delta on the butt segment.
		"grow_butt": {
			"id": "grow_butt", "name": "Grow butt", "staged": true,
			"stage_seconds": 600, "max_stages": 4,
			"gate": {"op": "has_tag", "tag": "butt"},
			"ops": [
				{"effect": "prop_delta", "target_node": "butt", "prop": "volume_ml",
					"amount": {"roll": "uniform", "lo": 150.0, "hi": 300.0}, "clamp": [0.0, 8000.0]},
			],
		},
	}
