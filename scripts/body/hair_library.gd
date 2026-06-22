## HairLibrary — the DATA registry of swappable hairstyles.
##
## Data-over-code at the hairstyle seam: a hairstyle is a row of data (id, display
## name, GLB source path, attribution), NOT a bespoke scene/script per style. BodyRig
## reads this registry to load + attach a chosen style and to drive its bones with the
## existing spring-bone physics. Adding a style = adding a row + dropping a GLB.
##
## ASSET PROVENANCE. The "bdcc2/*" entries are the ACTUAL rigged hair meshes mined from
## BDCC2 (alexofp / Rahi, MIT — Copyright (c) 2025 Rahi; "use as a base for your own
## game"). Each BDCC2 GLB ships its own little Skeleton3D (a Root bone + 1..6 hair-
## physics bones such as Tail1/Back.L/Front.R/WiggleL); aeriea attaches that skeleton
## under the character's `head` bone and registers a SpringBone on every non-Root bone,
## so aeriea's OWN spring physics (scripts/body/spring_bone.gd) sways BDCC2's geometry.
## The "cap" entry is the project's CC0 helper-hair fallback (no BDCC2 art) — see
## tools/body_proxy_build.gd. Full attribution: NOTICE.md + assets/body/hair/bdcc2/NOTICE.md.
class_name HairLibrary
extends RefCounted

## The fallback id: the project's own CC0 helper-hair cap (rigged onto the body's
## hair01/02/03 chain). Always present; selected when no BDCC2 style is applied or a
## requested style id is unknown. NOT a BDCC2 asset.
const CAP := "cap"

const BDCC2_DIR := "res://assets/body/hair/bdcc2/"

## One row per style. `glb` is null for the CC0 cap (it lives on the body rig itself).
## `source` records provenance for attribution surfacing. Ordered for stable iteration.
const STYLES := [
	{"id": "cap", "name": "Helper Cap (CC0 fallback)", "glb": "", "source": "aeriea-cc0"},
	{"id": "ponytail1", "name": "Ponytail 1", "glb": "Ponytail1.glb", "source": "bdcc2"},
	{"id": "ponytail2", "name": "Ponytail 2", "glb": "Ponytail2.glb", "source": "bdcc2"},
	{"id": "ponytail3", "name": "Ponytail 3", "glb": "Ponytail3.glb", "source": "bdcc2"},
	{"id": "ponytail4", "name": "Ponytail 4 (with bow)", "glb": "Ponytail4.glb", "source": "bdcc2"},
	{"id": "ponytails_back", "name": "Twin Tails (back)", "glb": "PonytailsBack.glb", "source": "bdcc2"},
	{"id": "long", "name": "Long Hair", "glb": "LongHair.glb", "source": "bdcc2"},
	{"id": "long_cute", "name": "Long Cute Hair", "glb": "LongCuteHair.glb", "source": "bdcc2"},
	{"id": "long_chaos", "name": "Long Chaos Hair", "glb": "LongChaosHair.glb", "source": "bdcc2"},
	{"id": "long_side", "name": "Long Side Hair", "glb": "LongSideHair.glb", "source": "bdcc2"},
	{"id": "long_bow", "name": "Long Hair (bow)", "glb": "LongHairBow.glb", "source": "bdcc2"},
	{"id": "short", "name": "Short Hair", "glb": "ShortHair.glb", "source": "bdcc2"},
	{"id": "short2", "name": "Short Hair 2 (Artica)", "glb": "ShortHair2.glb", "source": "bdcc2"},
	{"id": "side", "name": "Side Hair", "glb": "SideHair.glb", "source": "bdcc2"},
	{"id": "ferri", "name": "Ferri Hair", "glb": "FerriHair.glb", "source": "bdcc2"},
	{"id": "cool_bangs", "name": "Cool Bangs (Kidlat)", "glb": "CoolBangsHair.glb", "source": "bdcc2"},
]


## All style ids in stable order.
static func ids() -> Array:
	var out := []
	for s in STYLES:
		out.append(s["id"])
	return out


## The row for `id`, or {} if unknown.
static func get_style(id: String) -> Dictionary:
	for s in STYLES:
		if s["id"] == id:
			return s
	return {}


## Absolute res:// path to the GLB for `id`, or "" for the CC0 cap / unknown id.
static func glb_path(id: String) -> String:
	var s := get_style(id)
	if s.is_empty() or String(s.get("glb", "")) == "":
		return ""
	return BDCC2_DIR + String(s["glb"])


## True iff `id` is a BDCC2-sourced mesh (vs. the CC0 cap).
static func is_bdcc2(id: String) -> bool:
	return String(get_style(id).get("source", "")) == "bdcc2"
