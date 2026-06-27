## TfMeasure — aeriea's size/measurement model (compound-parts-and-fluids.md §4.3).
##
## Canonical body size is stored as INTEGER per-segment props (no derived/banded field
## is ever stored): breasts carry `volume_ml` + `band_cm`, the butt carries `volume_ml`,
## genitals keep `length_cm`/`girth_cm`. The cup/size a player READS is DERIVED on every
## describe by a pure function of those canonical integers under a chosen MEASUREMENT
## STANDARD. The standard is a describe-layer parameter (a default + an override), NEVER
## stored on the body — so the SAME body re-renders "13DD" (imperial) vs "32G" (metric).
##
## This answers the open "who owns banding thresholds" question (§9.3): the engine ships
## a deterministic default model (K_V/K_B + the two standards) as the size analog of the
## fluid fullness bands. It is integer-only and deterministic — no float in the path that
## decides a cup letter.

# Cup derivation constants (§4.3). diff_mm is increasing in volume (concave, via isqrt)
# and decreasing in band — both monotonicities hold by construction.
const K_V := 8
const K_B := 4


## Integer floor sqrt — deterministic, integer-only (no float sqrt in the decision path).
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x


## The cup "difference" in mm: K_V * isqrt(volume_ml) - K_B * band_cm, floored at 0.
## Bigger volume -> bigger cup; bigger band (at fixed volume) -> smaller cup.
static func diff_mm(volume_ml: int, band_cm: int) -> int:
	return maxi(0, K_V * isqrt(volume_ml) - K_B * band_cm)


# --- measurement standards ------------------------------------------------------
# A standard = { step_mm, letters[], length_unit, volume_unit, band_render }.
# `length_unit`/`volume_unit`/`band_render` name the unit conventions a standard renders
# under; the conversion helpers below apply them.

# `figure` block: the configurable banding for the BWH figure read (the size analog of
# the cup `letters`/`step_mm` — thresholds live in the standard, NOT hardcoded in describe).
#   - `whr_*`: waist-to-hip RATIO cut-points (× WHR_SCALE, integer fixed-point) that pick
#     the shape word (hourglass / pear / straight / apple). Lower ratio = curvier waist.
#   - `spread_*_cm`: hip-circumference cut-points (in the standard's BWH unit) for the
#     overall build word (slim / curvy / thick).
#   - `wide_hip_cm` / `slim_waist_cm`: cut-points (BWH unit) for the targeted descriptors.
# Imperial cuts are the metric ones converted to inches; the SAME body reads consistently
# in either system because the comparison happens in the standard's own unit.
const IMPERIAL := {
	"id": "imperial",
	"name": "Imperial (in / floz)",
	"step_mm": 25,
	"letters": ["AA", "A", "B", "C", "D", "DD", "DDD", "G", "H", "I", "J"],
	"length_unit": "in",
	"volume_unit": "floz",
	"band_render": "in",
	"bwh_unit": "in",
	"figure": {
		"whr_hourglass": 75, "whr_pear": 80, "whr_straight": 92,
		"spread_slim_cm": 35, "spread_thick_cm": 41,
		"wide_hip_cm": 41, "slim_waist_cm": 26,
	},
}

const METRIC := {
	"id": "metric",
	"name": "Metric (cm / ml)",
	"step_mm": 20,
	"letters": ["AA", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"],
	"length_unit": "cm",
	"volume_unit": "ml",
	"band_render": "cm",
	"bwh_unit": "cm",
	"figure": {
		"whr_hourglass": 75, "whr_pear": 80, "whr_straight": 92,
		"spread_slim_cm": 88, "spread_thick_cm": 104,
		"wide_hip_cm": 104, "slim_waist_cm": 64,
	},
}

# Fixed-point scale for the integer waist-to-hip ratio (so WHR is computed/compared with
# no float in the decision path): ratio = waist * WHR_SCALE / hip.
const WHR_SCALE := 100


## All shipped standards, in a stable order (for the playground's cycle control).
static func standards() -> Array:
	return [METRIC, IMPERIAL]


static func default_standard() -> Dictionary:
	return METRIC


## The other standard after `std` (for a toggle/cycle control).
static func next_standard(std: Dictionary) -> Dictionary:
	var all := standards()
	for i in all.size():
		if all[i]["id"] == std.get("id", ""):
			return all[(i + 1) % all.size()]
	return all[0]


# --- cup derivation -------------------------------------------------------------

## The cup LETTER under a standard: index diff_mm/step into the standard's letter table,
## clamped to the table's range.
static func cup_letter(volume_ml: int, band_cm: int, std: Dictionary) -> String:
	var letters: Array = std["letters"]
	var idx: int = diff_mm(volume_ml, band_cm) / int(std["step_mm"])
	idx = clampi(idx, 0, letters.size() - 1)
	return str(letters[idx])


## The full cup LABEL: band-number (in the standard's band unit) + cup letter, e.g.
## "13DD" (imperial) or "32G" (metric).
static func cup_label(volume_ml: int, band_cm: int, std: Dictionary) -> String:
	return "%d%s" % [band_in_unit(band_cm, std), cup_letter(volume_ml, band_cm, std)]


# --- unit conversions (integer rendering) ---------------------------------------

## A length in cm rendered in the standard's length unit (cm as-is, or inches = cm/2.54
## rounded). Integer result.
static func length_in_unit(length_cm: float, std: Dictionary) -> int:
	if std["length_unit"] == "in":
		return int(round(length_cm / 2.54))
	return int(round(length_cm))


## A volume in ml/cc rendered in the standard's volume unit (ml as-is, or floz = cc/29.57
## rounded). Integer result.
static func volume_in_unit(volume_ml: int, std: Dictionary) -> int:
	if std["volume_unit"] == "floz":
		return int(round(float(volume_ml) / 29.57))
	return int(volume_ml)


## The band number shown for the bra size, in the standard's band-render unit (cm as-is,
## or inches = band_cm/2.54 rounded). Integer.
static func band_in_unit(band_cm: int, std: Dictionary) -> int:
	if std["band_render"] == "in":
		return int(round(float(band_cm) / 2.54))
	return int(band_cm)


# --- human-readable size phrases (for describe) ---------------------------------

## A breast's size phrase under a standard: the cup label + the canonical volume rendered
## in the standard's volume unit, e.g. "32G (650ml)" or "13DD (22floz)".
static func breast_phrase(volume_ml: int, band_cm: int, std: Dictionary) -> String:
	return "%s (%d%s)" % [cup_label(volume_ml, band_cm, std),
		volume_in_unit(volume_ml, std), std["volume_unit"]]


## A butt's size phrase: just the canonical volume in the standard's unit (butts carry no
## cup), e.g. "800ml" / "27floz".
static func butt_phrase(volume_ml: int, std: Dictionary) -> String:
	return "%d%s" % [volume_in_unit(volume_ml, std), std["volume_unit"]]


## A genital's length phrase under a standard, e.g. "15cm" / "6in".
static func length_phrase(length_cm: float, std: Dictionary) -> String:
	return "%d%s" % [length_in_unit(length_cm, std), std["length_unit"]]


# --- BWH figure measurements (the size analog of cup, for the whole figure) ------
# Canonical state: waist_cm + hip_cm are STORED integers on the body-core carrier; the
# bust is DERIVED (never stored) from the ribcage band + total breast volume — the same
# concave isqrt projection the cup uses, so a bigger chest reads as a bigger bust for
# free. All three are integer-only; the figure WORDS are derived per standard from the
# numbers and their ratios, with the cut-points living in the standard (configurable).

# Bust projection constant: bust_cm = band_cm + K_BUST * isqrt(total_breast_volume_ml).
# Concave in volume (via isqrt) so the bust grows but tapers, like the cup difference.
const K_BUST := 1


## Derived bust CIRCUMFERENCE in cm (canonical unit): ribcage band + a concave function
## of total breast volume. Integer-only; 0-volume (flat) reads as the bare band.
static func bust_cm(band_cm: int, total_breast_volume_ml: int) -> int:
	return band_cm + K_BUST * isqrt(maxi(0, total_breast_volume_ml))


## A measurement rendered in the standard's BWH unit (cm as-is, or inches = cm/2.54
## rounded). Integer result — shared by all three of B/W/H.
static func bwh_in_unit(cm: int, std: Dictionary) -> int:
	if std.get("bwh_unit", "cm") == "in":
		return int(round(float(cm) / 2.54))
	return cm


## The measurement TRIPLE string under a standard, e.g. "90-62-90" (metric) or
## "35-24-35" (imperial). Pure integers in the standard's unit.
static func figure_triple(bust_cm_v: int, waist_cm: int, hip_cm: int, std: Dictionary) -> String:
	return "%d-%d-%d" % [bwh_in_unit(bust_cm_v, std), bwh_in_unit(waist_cm, std),
		bwh_in_unit(hip_cm, std)]


## Integer waist-to-hip ratio × WHR_SCALE (no float in the decision path). 0 hip -> 0.
static func whr_scaled(waist_cm: int, hip_cm: int) -> int:
	if hip_cm <= 0:
		return 0
	return waist_cm * WHR_SCALE / hip_cm


## The SHAPE word from the waist-to-hip ratio, cut by the standard's `figure` thresholds.
## hourglass (curvy waist) / pear (wide hips, fuller below) / straight / apple (waist >=
## hips). Returns "" when no figure data is meaningful (hips absent).
static func figure_shape(bust_cm_v: int, waist_cm: int, hip_cm: int, std: Dictionary) -> String:
	if hip_cm <= 0 or waist_cm <= 0:
		return ""
	var fig: Dictionary = std.get("figure", {})
	var whr := whr_scaled(waist_cm, hip_cm)
	if whr >= int(fig.get("whr_straight", 92)):
		return "apple" if whr >= WHR_SCALE else "straight"
	if whr >= int(fig.get("whr_pear", 80)):
		# A defined waist over notably wider hips reads pear; a fuller bust balances it
		# back toward hourglass.
		if bust_cm_v >= hip_cm:
			return "hourglass"
		return "pear"
	if whr >= int(fig.get("whr_hourglass", 75)):
		return "hourglass"
	return "hourglass"


## The overall BUILD word from the hip spread (the standard's spread_* cut-points, in the
## standard's BWH unit): slim / curvy / thick. "" when hips absent.
static func figure_build(hip_cm: int, std: Dictionary) -> String:
	if hip_cm <= 0:
		return ""
	var fig: Dictionary = std.get("figure", {})
	var h := bwh_in_unit(hip_cm, std)
	if h < int(fig.get("spread_slim_cm", 88)):
		return "slim"
	if h >= int(fig.get("spread_thick_cm", 104)):
		return "thick"
	return "curvy"


## Targeted figure descriptors (wide-hipped / slim-waisted), cut by the standard's
## `figure` thresholds in its BWH unit. Returns an Array of words (possibly empty).
static func figure_descriptors(waist_cm: int, hip_cm: int, std: Dictionary) -> Array:
	var fig: Dictionary = std.get("figure", {})
	var out: Array = []
	if hip_cm > 0 and bwh_in_unit(hip_cm, std) >= int(fig.get("wide_hip_cm", 104)):
		out.append("wide-hipped")
	if waist_cm > 0 and bwh_in_unit(waist_cm, std) <= int(fig.get("slim_waist_cm", 64)):
		out.append("slim-waisted")
	return out
