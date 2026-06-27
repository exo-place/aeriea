## TfContent — the MVP setting-neutral content (TF system §7).
##
## A starting biped body built from GENERIC segments + conventional tags, and the
## ~5 TF records spanning every op category. These are PURE MECHANISM DEMOS — no lore,
## no setting flavor (§2, §4.3). Shipped OPEN: few values, not a closed enum (§7) —
## the same applier/traversal work unchanged as values are added.
const BodyGraph := preload("res://scripts/body/tf/body_graph.gd")


# --- the starting biped (§7) ----------------------------------------------------
# torso_upper (root) -> head, arm_l, arm_r, pelvis -> leg_l, leg_r.
# All flesh + skin, conventionally tagged. Generic segments only.
static func biped() -> Dictionary:
	var seg := BodyGraph.segment
	var c := BodyGraph.child
	var root: Dictionary = seg.call("torso_upper", "flesh", "skin", {"length_cm": 55.0},
		["torso", "upper_body"], [
			c.call("neck", seg.call("head", "flesh", "skin", {}, ["head"], [])),
			c.call("shoulder_l", seg.call("arm_l", "flesh", "skin", {"length_cm": 62.0}, ["arm"], [])),
			c.call("shoulder_r", seg.call("arm_r", "flesh", "skin", {"length_cm": 62.0}, ["arm"], [])),
			c.call("hip", seg.call("pelvis", "flesh", "skin", {"length_cm": 25.0},
				["pelvis", "lower_body"], [
					c.call("leg_l", seg.call("leg_l", "flesh", "skin", {"length_cm": 85.0}, ["leg"], [])),
					c.call("leg_r", seg.call("leg_r", "flesh", "skin", {"length_cm": 85.0}, ["leg"], [])),
				])),
		])
	return {"root": root, "scalars": {"height_cm": 170.0}}


# --- a quadruped-lower subtree (for the graft / merge demo) ----------------------
# A from-scratch second spine + four legs, tagged lower_body/spine/leg by convention.
# Shipped SKIN-covered so the set_covering_fur_upward demo (§4.3c) actually creeps a
# visible skin->fur boundary up the structure stage by stage.
static func quadruped_lower() -> Dictionary:
	var seg := BodyGraph.segment
	var c := BodyGraph.child
	return seg.call("barrel", "flesh", "skin", {"length_cm": 90.0},
		["spine", "lower_body"], [
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
		# (a) FORM graft, instant: biped -> taur. Remove the biped legs+pelvis first,
		# then graft the quadruped-lower structure at the hip. Gate: not already taur.
		"graft_quadruped_lower": {
			"id": "graft_quadruped_lower",
			"name": "graft a quadruped lower body",
			"staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "spine"}},
			"ops": [
				{"effect": "remove_subtree", "target_node": "pelvis"},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": quadruped_lower()},
			],
		},

		# (b) MATERIAL set, staged, ONE segment per stage, lowest-first (chitin creeps up
		# the lower body the same way fur-creep advances a covering boundary). Ordered ops,
		# each guarded by `material != chitin`; `one_op_per_stage` fires only the FIRST
		# effective op per stage so exactly one segment hardens per clock step. Setting
		# chitin nulls covering (§3.2). 5 segments (4 legs + barrel) -> 5 stages.
		"set_lower_material_chitin": {
			"id": "set_lower_material_chitin", "name": "harden the lower body to chitin",
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
			"id": "set_covering_fur_upward", "name": "fur creeps up the lower body",
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
			"id": "grow_tail_length", "name": "grow the tail",
			"staged": true, "stage_seconds": 900, "max_stages": 5,
			"gate": {"op": "has_tag", "tag": "tail"},
			"ops": [
				{"effect": "prop_delta", "target_node": "tail", "prop": "length_cm",
					"amount": {"roll": "uniform", "lo": 2.0, "hi": 5.0}, "clamp": [0.0, 120.0]},
			],
		},

		# (a2) FORM graft, STAGED: the same biped -> taur graft, but progressive. Form
		# edits (remove/graft) are stageable like any op (§4.2) — there's no reason a graft
		# must be instant. Stage 0 removes the biped pelvis and grafts the quadruped barrel
		# (one_op_per_stage off, so both form ops fire together as the single "graft" stage);
		# stages 1-4 then GROW the newly-grafted legs, so the lower body is grafted then
		# grows in over the clock. Gate: not already taur. The grow op's `when` guard makes
		# the trailing stages no-op cleanly once legs reach length.
		"graft_quadruped_lower_staged": {
			"id": "graft_quadruped_lower_staged",
			"name": "graft a quadruped lower body (gradual)",
			"staged": true, "stage_seconds": 1200, "max_stages": 5,
			# NB: no TF-level `gate` here. The "not already taur" guard lives on the graft op
			# as a `when` instead — a TF-level gate is re-checked every stage and would FALSE
			# out (and kill the staged TF) the moment the barrel's `spine` tag lands. Op-level
			# `when` lets the form fire once in stage 0 while the grow stages keep running.
			"ops": [
				# stage 0: the form edit (remove pelvis, graft barrel). On later stages these
				# no-op (pelvis already gone / `when` keeps the graft from re-firing).
				{"effect": "remove_subtree", "target_node": "pelvis",
					"when": {"op": "not", "of": {"op": "has_tag", "tag": "spine"}}},
				{"effect": "graft_subtree", "target_node": "torso_upper", "at": "hip",
					"subtree": quadruped_lower(),
					"when": {"op": "not", "of": {"op": "has_tag", "tag": "spine"}}},
				# stages 1-4: grow the grafted barrel a little each step (visible progression
				# after the form lands). Guarded so it stops once grown.
				{"effect": "prop_delta", "target_node": "barrel", "prop": "length_cm",
					"amount": {"roll": "uniform", "lo": 3.0, "hi": 8.0}, "clamp": [0.0, 130.0],
					"when": {"op": "lt", "path": "#barrel.props.length_cm", "v": 130.0}},
			],
		},

		# (e) a graft to add the tail (instant) — used before grow_tail_length.
		"graft_tail": {
			"id": "graft_tail", "name": "graft a tail", "staged": false,
			"gate": {"op": "not", "of": {"op": "has_tag", "tag": "tail"}},
			"ops": [
				{"effect": "graft_subtree", "target_node": "barrel", "at": "tail_base",
					"subtree": tail_seg()},
			],
		},
	}
