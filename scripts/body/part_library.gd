## PartLibrary — the DATA registry of swappable BODY PARTS across named SLOTS.
##
## The generalization of the original HairLibrary: where that registry knew only
## hairstyles, this one is slot-based. A SLOT is an attach point on the character
## (hair, ears, tail, horns, …); a PART is one row of data fillable into a slot.
## Data-over-code at the part seam: a part is a row {slot, id, name, glbs, attach_bone,
## sway, source}, NOT a bespoke scene/script per part. BodyRig reads this registry to
## load + attach a chosen part and (where it sways) drive its bones with aeriea's own
## spring-bone physics. Adding a part = adding a row + dropping its GLB(s).
##
## A part may carry MULTIPLE GLBs (e.g. an ear set is a left GLB + a right GLB; a horn
## set is left + right). Each GLB row is {glb, attach_bone}: the file (relative to the
## slot's BDCC2 dir) and the aeriea skeleton bone it rides.
##
## SLOT ATTACH BONES (aeriea's CC0 MakeHuman rig):
##   hair, ears, horns -> "head"   tail -> "spine05" (lowest spine joint, the pelvis base)
## BDCC2 authored its parts against ITS OWN skeleton's attach points (ear.L/ear.R, tail,
## horn.L/horn.R); aeriea re-homes each onto the equivalent MakeHuman bone above, then
## drives the parts that should sway with its own springs (tails + the ear physics bones).
## Horns are RIGID in BDCC2 (a bare MeshInstance3D, no skeleton) — they attach but do NOT
## sway (correct: horn is bone). The mesh transform from the GLB carries the L/R placement.
##
## ASSET PROVENANCE. The "bdcc2/*" parts are the ACTUAL rigged meshes mined from BDCC2
## (alexofp / Rahi, MIT — Copyright (c) 2025 Rahi; "use as a base for your own game").
## Tail/ear GLBs ship their own little Skeleton3D (DEF-Tail1..N / DEF-Ear.* etc.); aeriea
## attaches that skeleton under the appropriate bone and registers a SpringBone on every
## non-Root physics bone, so aeriea's OWN spring physics sways BDCC2's geometry. The hair
## "cap" entry is the project's CC0 helper-hair fallback (no BDCC2 art). Full attribution:
## NOTICE.md + assets/body/parts/bdcc2/NOTICE.md (+ hair: assets/body/hair/bdcc2/NOTICE.md).
class_name PartLibrary
extends RefCounted

## Slot names. Hair is the original (its GLBs live in the legacy hair dir); ears/tail/horns
## are the newly-mined BDCC2 accessory slots.
const SLOT_HAIR := "hair"
const SLOT_EARS := "ears"
const SLOT_TAIL := "tail"
const SLOT_HORNS := "horns"
## CORE-BODY slot: the HEAD itself. Unlike the accessory slots (which ATTACH a GLB + its own
## little skeleton under a bone), a core-body part is RE-SKINNED onto aeriea's OWN 169-bone
## skeleton (a committed ArrayMesh whose verts ride a mapped aeriea bone) — so it DEFORMS with
## the body via aeriea's LBS, exactly like the base body mesh. See tools/bdcc2_head_reskin.gd.
## The default ("human") keeps aeriea's own head (no overlay); a BDCC2 id overlays the
## re-skinned animal head riding the `head` bone and hides aeriea's default face proxy surfaces.
const SLOT_HEAD := "head"
## CORE-BODY slot: the LEGS. The MULTI-BONE generalization of the head slot. Where a head
## re-skins onto ONE bone, a leg part is skinned across MANY bones (thigh/shin/foot/toe) and
## re-skinned onto aeriea's corresponding MH leg bones via the bone-map (tools/bdcc2_body_reskin.gd):
## a committed ArrayMesh carrying REAL aeriea bone indices, so it DEFORMS joint-by-joint when
## aeriea walks (bend the knee, the shin follows). The default ("human") keeps aeriea's own legs
## (no overlay); a BDCC2 id overlays the re-skinned digitigrade / plantigrade leg variant.
const SLOT_LEGS := "legs"
const SLOTS := [SLOT_HAIR, SLOT_EARS, SLOT_TAIL, SLOT_HORNS, SLOT_HEAD, SLOT_LEGS]

## Re-skinned core-body assets live here (ArrayMesh .res produced by tools/bdcc2_head_reskin.gd).
const RESKIN_DIR := "res://assets/body/parts/bdcc2/reskin/"

## The "none / default" id for a slot: empty geometry (a clean human head/back), never a
## broken state. Every slot has it; it is the per-slot fallback. For hair, the project's
## CC0 helper cap doubles as the default (id "cap"); for the accessory slots the default is
## "none" (no accessory attached — a plain human).
const NONE := "none"
## Hair keeps its legacy default id ("cap" = the CC0 helper-hair scalp on the body rig).
const HAIR_CAP := "cap"

const HAIR_DIR := "res://assets/body/hair/bdcc2/"
const PARTS_DIR := "res://assets/body/parts/bdcc2/"

## The aeriea-skeleton attach bone per slot.
const SLOT_ATTACH_BONE := {
	SLOT_HAIR: "head",
	SLOT_EARS: "head",
	SLOT_TAIL: "spine05",
	SLOT_HORNS: "head",
	SLOT_HEAD: "head",
	# Legs are MULTI-BONE: no single attach bone. The re-skin carries per-vertex aeriea bone
	# indices; this fallback is only used for the single-bind path (unused for legs).
	SLOT_LEGS: "root",
}

## The registry: slot -> ordered Array of part rows. Each row:
##   id          stable id (apply_part key)
##   name        display name
##   glbs        Array of {glb: <res path or "">, attach_bone: <aeriea bone>}; [] = empty slot
##   sway        true => register spring physics on the attached skeleton's physics bones
##   source      provenance ("bdcc2" | "aeriea-cc0")
## The first row of each slot is its default/fallback.
const PARTS := {
	SLOT_HAIR: [
		{"id": "cap", "name": "Helper Cap (CC0 fallback)", "glbs": [], "sway": true, "source": "aeriea-cc0"},
		{"id": "ponytail1", "name": "Ponytail 1", "glbs": [{"glb": HAIR_DIR + "Ponytail1.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "ponytail2", "name": "Ponytail 2", "glbs": [{"glb": HAIR_DIR + "Ponytail2.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "ponytail3", "name": "Ponytail 3", "glbs": [{"glb": HAIR_DIR + "Ponytail3.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "ponytail4", "name": "Ponytail 4 (with bow)", "glbs": [{"glb": HAIR_DIR + "Ponytail4.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "ponytails_back", "name": "Twin Tails (back)", "glbs": [{"glb": HAIR_DIR + "PonytailsBack.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "long", "name": "Long Hair", "glbs": [{"glb": HAIR_DIR + "LongHair.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "long_cute", "name": "Long Cute Hair", "glbs": [{"glb": HAIR_DIR + "LongCuteHair.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "long_chaos", "name": "Long Chaos Hair", "glbs": [{"glb": HAIR_DIR + "LongChaosHair.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "long_side", "name": "Long Side Hair", "glbs": [{"glb": HAIR_DIR + "LongSideHair.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "long_bow", "name": "Long Hair (bow)", "glbs": [{"glb": HAIR_DIR + "LongHairBow.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "short", "name": "Short Hair", "glbs": [{"glb": HAIR_DIR + "ShortHair.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "short2", "name": "Short Hair 2 (Artica)", "glbs": [{"glb": HAIR_DIR + "ShortHair2.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "side", "name": "Side Hair", "glbs": [{"glb": HAIR_DIR + "SideHair.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "ferri", "name": "Ferri Hair", "glbs": [{"glb": HAIR_DIR + "FerriHair.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
		{"id": "cool_bangs", "name": "Cool Bangs (Kidlat)", "glbs": [{"glb": HAIR_DIR + "CoolBangsHair.glb", "attach_bone": "head"}], "sway": true, "source": "bdcc2"},
	],
	# SEATING. BDCC2 authored each accessory against ITS OWN skeleton's attach point, offset from
	# the bone origin. aeriea attaches to the head/spine05 BONE ORIGIN. Ears + horns now have NO
	# hand-tuned `offset`: BodyRig RE-CENTERS them from the part's geometric center onto a per-slot
	# anatomical target expressed in the attach bone's REST BASIS (BodyRig.ACCESSORY_SEAT_TARGET +
	# _accessory_seat_offset) — replacing the former AABB-center approximations that ignored the
	# bone's basis (and mis-placed the ears off the head). Tails keep their tuned bone-local offset
	# (they sit at the pelvis base, not driven by the head-rest-basis re-center).
	SLOT_EARS: [
		{"id": "none", "name": "None (human ears)", "glbs": [], "sway": false, "source": "aeriea-cc0"},
		{"id": "feline", "name": "Feline Ears (fluffy)", "sway": true, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "ears/FelineEarL.glb", "attach_bone": "head"},
					 {"glb": PARTS_DIR + "ears/FelineEarR.glb", "attach_bone": "head"}]},
		{"id": "round", "name": "Round Ears", "sway": true, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "ears/RoundEarL.glb", "attach_bone": "head"},
					 {"glb": PARTS_DIR + "ears/RoundEarR.glb", "attach_bone": "head"}]},
		{"id": "small", "name": "Small Ears", "sway": true, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "ears/SmallEarL.glb", "attach_bone": "head"},
					 {"glb": PARTS_DIR + "ears/SmallEarR.glb", "attach_bone": "head"}]},
	],
	SLOT_TAIL: [
		{"id": "none", "name": "None (no tail)", "glbs": [], "sway": false, "source": "aeriea-cc0"},
		{"id": "fluffy", "name": "Fluffy Tail", "sway": true, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "tails/FluffyTail.glb", "attach_bone": "spine05", "offset": Vector3(0.0, -0.03, -0.07)}]},
		{"id": "dragon", "name": "Dragon Tail", "sway": true, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "tails/DragonTail.glb", "attach_bone": "spine05", "offset": Vector3(0.0, -0.03, -0.07)}]},
		{"id": "feline", "name": "Feline Tail (long)", "sway": true, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "tails/FelineTail.glb", "attach_bone": "spine05", "offset": Vector3(0.0, -0.03, -0.07)}]},
		{"id": "huge_fluffy", "name": "Huge Fluffy Tail", "sway": true, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "tails/HugeFluffyTail.glb", "attach_bone": "spine05", "offset": Vector3(0.0, -0.03, -0.07)}]},
		{"id": "paintbrush", "name": "Paintbrush Tail", "sway": true, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "tails/PaintbrushTail.glb", "attach_bone": "spine05", "offset": Vector3(0.0, -0.03, -0.07)}]},
	],
	SLOT_HORNS: [
		{"id": "none", "name": "None (no horns)", "glbs": [], "sway": false, "source": "aeriea-cc0"},
		{"id": "horn1", "name": "Horns (curved)", "sway": false, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "horns/Horn1L.glb", "attach_bone": "head"},
					 {"glb": PARTS_DIR + "horns/Horn1R.glb", "attach_bone": "head"}]},
		{"id": "chaos", "name": "Chaos Horns", "sway": false, "source": "bdcc2",
			"glbs": [{"glb": PARTS_DIR + "horns/HornChaosL.glb", "attach_bone": "head"},
					 {"glb": PARTS_DIR + "horns/HornChaosR.glb", "attach_bone": "head"}]},
	],
	# CORE-BODY HEAD swap. The default keeps aeriea's OWN head (no overlay mesh). A BDCC2 id is a
	# RE-SKINNED ArrayMesh (tools/bdcc2_head_reskin.gd): its verts are rebound onto aeriea's `head`
	# bone, so it DEFORMS with the skeleton (rides the head bone when the body nods/turns) via
	# aeriea's own LBS — a true weight-transfer, not a static attach. `reskin` = the committed .res;
	# `attach_bone` = the aeriea bone the verts ride. Applying it hides aeriea's default face proxy
	# surfaces (eyes/brows/lashes) so the two heads don't co-render. (alexofp/Rahi, BDCC2, MIT.)
	SLOT_HEAD: [
		{"id": "human", "name": "Human (aeriea default)", "reskin": "", "source": "aeriea-cc0"},
		{"id": "canine", "name": "Canine Head", "reskin": RESKIN_DIR + "canine_head.res",
			"attach_bone": "head", "source": "bdcc2"},
		{"id": "feline", "name": "Feline Head", "reskin": RESKIN_DIR + "feline_head.res",
			"attach_bone": "head", "source": "bdcc2"},
	],
	# CORE-BODY LEGS swap — the MULTI-BONE re-skin (tools/bdcc2_body_reskin.gd). Each BDCC2 id is a
	# committed ArrayMesh whose verts carry REAL aeriea bone indices spanning the leg chain
	# (upperleg01/lowerleg01/foot/toe1-1, L+R), so it DEFORMS joint-by-joint with aeriea's skeleton
	# under aeriea's OWN LBS — a true multi-bone weight transfer. `multibone: true` selects the full
	# identity-Skin bind path in BodyRig (bind i -> aeriea bone i). The default keeps aeriea's own
	# legs (no overlay). (alexofp/Rahi, BDCC2, MIT — legs mined from FeminineBody.glb.)
	SLOT_LEGS: [
		{"id": "human", "name": "Human (aeriea default)", "reskin": "", "source": "aeriea-cc0"},
		{"id": "digitigrade", "name": "Digitigrade Legs", "reskin": RESKIN_DIR + "digi_legs.res",
			"multibone": true, "source": "bdcc2"},
		{"id": "plantigrade", "name": "Plantigrade Legs", "reskin": RESKIN_DIR + "planti_legs.res",
			"multibone": true, "source": "bdcc2"},
	],
}


## True iff (slot, id) is a MULTI-BONE re-skin (verts carry per-vertex aeriea bone indices
## across many bones, bound with a full identity Skin) vs a SINGLE-bone re-skin (head: one bind).
static func is_multibone(slot: String, id: String) -> bool:
	return bool(get_part(slot, id).get("multibone", false))


## True iff (slot, id) is a RE-SKINNED core-body part (carries a `reskin` .res to bind onto
## aeriea's own skeleton), vs an attached-GLB accessory or an empty/default.
static func is_reskin(slot: String, id: String) -> bool:
	return String(get_part(slot, id).get("reskin", "")) != ""


## The committed re-skin ArrayMesh path for (slot, id), or "" if it is not a re-skin part.
static func reskin_path(slot: String, id: String) -> String:
	return String(get_part(slot, id).get("reskin", ""))


## All slot names in stable order.
static func slots() -> Array:
	return SLOTS.duplicate()


## The default/fallback part id for a slot (the first row), or "" if the slot is unknown.
static func default_id(slot: String) -> String:
	if not PARTS.has(slot):
		return ""
	var rows: Array = PARTS[slot]
	return String(rows[0]["id"]) if rows.size() > 0 else ""


## All part ids for a slot, in stable order.
static func ids(slot: String) -> Array:
	var out := []
	if not PARTS.has(slot):
		return out
	for row in PARTS[slot]:
		out.append(row["id"])
	return out


## The row for (slot, id), or {} if unknown.
static func get_part(slot: String, id: String) -> Dictionary:
	if not PARTS.has(slot):
		return {}
	for row in PARTS[slot]:
		if row["id"] == id:
			return row
	return {}


## True iff (slot, id) is a BDCC2-sourced part (vs. an aeriea CC0 default/empty).
static func is_bdcc2(slot: String, id: String) -> bool:
	return String(get_part(slot, id).get("source", "")) == "bdcc2"


## True iff (slot, id) should sway (register spring physics on its attached skeleton).
static func sways(slot: String, id: String) -> bool:
	return bool(get_part(slot, id).get("sway", false))


## The GLB rows ({glb, attach_bone}) for (slot, id); [] for an empty/default part.
static func glbs(slot: String, id: String) -> Array:
	var p := get_part(slot, id)
	return (p.get("glbs", []) as Array) if not p.is_empty() else []
