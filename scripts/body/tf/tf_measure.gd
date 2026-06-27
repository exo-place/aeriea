## TfMeasure — aeriea's size/measurement model (compound-parts-and-fluids.md §4.3).
##
## Canonical body size is stored as INTEGER per-segment props (no derived/banded field
## is ever stored): breasts carry `volume_ml` + `band_mm`, the butt carries `volume_ml`,
## genitals keep `length_cm`/`girth_cm`. The figure measurements (ribcage band, waist, hip)
## are stored in MILLIMETERS so the proportions survive at any overall body scale — at whole
## centimeters they truncated to single digits at sprite scale (a 62 cm waist became 6 cm at
## 0.1×) and the shape distorted; in mm a 620 mm waist scales to 62 mm and the ratios hold.
## The cup/size a player READS is DERIVED on every
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
#
# The band is the ribcage/underbust circumference stored canonically in MILLIMETERS at a
# REALISTIC value (a "32 band" person ≈ 810 mm ribcage, NOT 32). The cup difference is the
# bust projection OVER that ribcage, so it must be measured against the ribcage span, not the
# bare number: BAND_ANCHOR_MM is the ribcage at which the volume term alone sets the cup (a
# person with a small/average ribcage); larger ribcages spread the same volume into a smaller
# cup. Anchored so a ~650 ml breast on an ~810 mm ribcage still reads ~C — the value the model
# carried before the unit correction. The band term works in CENTIMETER granularity
# ((band_mm - anchor) / 10) so the cup LETTER is unchanged from the old whole-cm derivation
# at human ribcages (which are multiples of 10 mm); the finer mm storage only matters for the
# scale-invariant figure proportions, not the coarse cup banding.
const K_V := 8
const K_B := 4
const BAND_ANCHOR_MM := 490


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


## The cup "difference" in mm: K_V * isqrt(volume_ml) - K_B * (band_mm - BAND_ANCHOR_MM)/10,
## floored at 0. Bigger volume -> bigger cup; bigger ribcage (at fixed volume) -> smaller
## cup (the same breast spread over a wider chest reads a smaller cup). The band term is
## anchored to BAND_ANCHOR_MM so it stays gentle on a realistic ribcage (~810 mm) rather than
## swamping the volume term. The /10 keeps the band term at centimeter granularity so the cup
## LETTER matches the old whole-cm model at human ribcages.
static func diff_mm(volume_ml: int, band_mm: int) -> int:
	return maxi(0, K_V * isqrt(volume_ml) - K_B * (band_mm - BAND_ANCHOR_MM) / 10)


# --- measurement standards ------------------------------------------------------
# A standard = { step_mm, letters[], length_unit, volume_unit, band_render }.
# `length_unit`/`volume_unit`/`band_render` name the unit conventions a standard renders
# under; the conversion helpers below apply them.

# `figure` block: the configurable banding for the BWH figure read (the size analog of
# the cup `letters`/`step_mm` — thresholds live in the standard, NOT hardcoded in describe).
#
# EVERY figure threshold is a RATIO (× RATIO_SCALE = a percentage), never an absolute cm,
# so the figure DESCRIPTOR is a pure function of the BWH PROPORTIONS and overall scale
# drops out: a body and a uniformly 3× (giant) or 0.3× (fae) copy of it read the IDENTICAL
# shape / build / descriptor. All comparisons are integer cross-multiplications (no float in
# the decision path), following the integer-WHR pattern.
#   - `whr_defined`: the waist-to-hip RATIO (× RATIO_SCALE) at/above which the waist is NOT
#     clearly smaller than the hips — the low-definition gate (straight / apple).
#   - `whr_apple`: WHR at/above which the (undefined) figure reads apple rather than straight.
#   - `balance_pct`: the bust-vs-hip balance margin as a PERCENT of the larger of the two.
#     |bust - hip| within this percent of max(bust, hip) counts as balanced (hourglass-
#     eligible); hips proportionally bigger read pear; bust proportionally bigger read
#     top-heavy. (was an absolute-cm margin — scale-dependent.)
#   - `build_slim_whr` / `build_thick_whr`: hip-to-waist FLARE ratio (hip * RATIO_SCALE /
#     waist) cut-points for the build word. Below slim -> slim, at/above thick -> thick, else
#     curvy. Build now measures how much the hips flare over the waist (a proportion), so it
#     does NOT change when the whole body is uniformly scaled. (was absolute hip cm.)
#   - `wide_hip_whr`: hip-to-waist flare ratio at/above which the figure reads wide-hipped.
#   - `slim_waist_pct`: waist as a PERCENT of the bust/hip average, at/below which the figure
#     reads slim-waisted. (both were absolute cm cut-points — scale-dependent.)
# These ratios are UNIT-FREE, so the IMPERIAL and METRIC figure blocks are identical: a ratio
# reads the same in cm or inches. Only the rendered triple differs by unit.
const FIGURE_RATIOS := {
	"whr_defined": 88, "whr_apple": 100,
	"balance_pct": 8,
	"build_slim_whr": 130, "build_thick_whr": 160,
	"wide_hip_whr": 165, "slim_waist_pct": 75,
}

const IMPERIAL := {
	"id": "imperial",
	"name": "Imperial (in / floz)",
	"step_mm": 25,
	"letters": ["AA", "A", "B", "C", "D", "DD", "DDD", "G", "H", "I", "J"],
	"length_unit": "in",
	"volume_unit": "floz",
	"band_render": "in",
	"bwh_unit": "in",
	"figure": FIGURE_RATIOS,
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
	"figure": FIGURE_RATIOS,
}

# Fixed-point scale for the integer ratios in the figure decision path (WHR, balance,
# flare, slim-waist) — every comparison is an integer cross-multiplication against a
# RATIO_SCALE-scaled threshold, so there is no float in the path that picks a figure word.
const RATIO_SCALE := 100
const WHR_SCALE := RATIO_SCALE


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
static func cup_letter(volume_ml: int, band_mm: int, std: Dictionary) -> String:
	var letters: Array = std["letters"]
	var idx: int = diff_mm(volume_ml, band_mm) / int(std["step_mm"])
	idx = clampi(idx, 0, letters.size() - 1)
	return str(letters[idx])


## The full cup LABEL: band-number (in the standard's band unit) + cup letter, e.g.
## "13DD" (imperial) or "81G" (metric).
static func cup_label(volume_ml: int, band_mm: int, std: Dictionary) -> String:
	return "%d%s" % [band_in_unit(band_mm, std), cup_letter(volume_ml, band_mm, std)]


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


## The band number shown for the bra size, in the standard's band-render unit. Metric is
## the ribcage in cm (band_mm/10 rounded); imperial is the bra-band convention: ribcage
## inches (band_mm/25.4) rounded to the nearest EVEN number (bra bands run 30/32/34/…). So
## an ~810 mm ribcage reads "81" (metric) / "32" (imperial).
static func band_in_unit(band_mm: int, std: Dictionary) -> int:
	if std["band_render"] == "in":
		var inches := int(round(float(band_mm) / 25.4))
		# Round to the nearest even band number (the bra-band convention).
		return inches + (inches & 1)
	return int(round(float(band_mm) / 10.0))


# --- human-readable size phrases (for describe) ---------------------------------

## A breast's size phrase under a standard: the cup label + the canonical volume rendered
## in the standard's volume unit, e.g. "32G (650ml)" or "13DD (22floz)".
static func breast_phrase(volume_ml: int, band_mm: int, std: Dictionary) -> String:
	return "%s (%d%s)" % [cup_label(volume_ml, band_mm, std),
		volume_in_unit(volume_ml, std), std["volume_unit"]]


## A butt's size phrase: just the canonical volume in the standard's unit (butts carry no
## cup), e.g. "800ml" / "27floz".
static func butt_phrase(volume_ml: int, std: Dictionary) -> String:
	return "%d%s" % [volume_in_unit(volume_ml, std), std["volume_unit"]]


## A genital's length phrase under a standard, e.g. "15cm" / "6in".
static func length_phrase(length_cm: float, std: Dictionary) -> String:
	return "%d%s" % [length_in_unit(length_cm, std), std["length_unit"]]


# --- BWH figure measurements (the size analog of cup, for the whole figure) ------
# Canonical state: waist_mm + hip_mm are STORED integers (MILLIMETERS) on the body-core
# carrier; the bust is DERIVED (never stored) from the ribcage band + total breast volume —
# the same concave isqrt projection the cup uses, so a bigger chest reads as a bigger bust
# for free. All three are integer mm; storing in mm (not whole cm) keeps the PROPORTIONS
# intact at any overall scale — a uniformly 0.1× (sprite) copy keeps 62 mm of waist where a
# whole-cm store would have truncated 6.2 cm to 6. The figure WORDS are derived per standard
# from the numbers and their ratios, with the cut-points living in the standard.

# Bust projection: bust_mm = ribcage_mm + isqrt(total_breast_volume_ml) * BUST_MM_PER_ISQRT.
# Concave in volume (via isqrt) so the bust grows but tapers, like the cup difference. The
# ribcage is a realistic circumference (~810 mm), so the projection is a small chest-depth
# add-on (a ~1300 ml pair adds isqrt(1300)=36 -> 72 mm -> ~88 cm bust ≈ 35 in), NOT a
# doubling of the band.
const BUST_MM_PER_ISQRT := 2


## Derived bust CIRCUMFERENCE in mm (canonical unit): ribcage circumference + a small,
## concave projection from total breast volume. Integer-only; 0-volume (flat) reads as the
## bare ribcage.
static func bust_mm(band_mm: int, total_breast_volume_ml: int) -> int:
	return band_mm + isqrt(maxi(0, total_breast_volume_ml)) * BUST_MM_PER_ISQRT


## A measurement in mm rendered in the standard's BWH unit (cm = mm/10 rounded, or inches =
## mm/25.4 rounded). Integer result — shared by all three of B/W/H.
static func bwh_in_unit(mm: int, std: Dictionary) -> int:
	if std.get("bwh_unit", "cm") == "in":
		return int(round(float(mm) / 25.4))
	return int(round(float(mm) / 10.0))


## The measurement TRIPLE string under a standard, e.g. "88-62-90" (metric) or
## "35-24-35" (imperial). Inputs are mm; rendered as pure integers in the standard's unit.
static func figure_triple(bust_mm_v: int, waist_mm: int, hip_mm: int, std: Dictionary) -> String:
	return "%d-%d-%d" % [bwh_in_unit(bust_mm_v, std), bwh_in_unit(waist_mm, std),
		bwh_in_unit(hip_mm, std)]


## Integer waist-to-hip ratio × WHR_SCALE (no float in the decision path). 0 hip -> 0.
## Unit-free: the inputs may be mm or cm, the ratio is the same.
static func whr_scaled(waist_mm: int, hip_mm: int) -> int:
	if hip_mm <= 0:
		return 0
	return waist_mm * WHR_SCALE / hip_mm


## The SHAPE word from the FULL bust-waist-hip figure (all inputs in mm), cut by the
## standard's `figure` RATIO thresholds. Uses all three measurements as PROPORTIONS, so the
## shape is fully scale-invariant — a body and its uniform 3× / 0.1× copy read the SAME shape:
##   - straight / rectangle: the waist is NOT proportionally smaller than the hips (the WHR
##     low-definition gate; apple when the waist meets/exceeds the hips), regardless of bust≈hips.
##   - pear / bottom-heavy: hips proportionally larger than the bust (beyond the balance %).
##   - top-heavy / inverted: bust proportionally larger than the hips (beyond the balance %).
##   - hourglass: bust ≈ hips (within the balance PERCENT) AND a clearly defined waist.
## Returns "" when no figure data is meaningful (hips/waist absent). Every comparison is an
## integer cross-multiplication (no float in the decision path).
static func figure_shape(bust_mm_v: int, waist_mm: int, hip_mm: int, std: Dictionary) -> String:
	if hip_mm <= 0 or waist_mm <= 0:
		return ""
	var fig: Dictionary = std.get("figure", {})
	var whr := whr_scaled(waist_mm, hip_mm)
	# Definition gate first: an undefined (proportionally non-narrow) waist reads
	# straight/rectangle (apple if the waist meets the hips) no matter how bust and hips compare.
	if whr >= int(fig.get("whr_defined", 88)):
		return "apple" if whr >= int(fig.get("whr_apple", 100)) else "straight"
	# A defined waist: the bust-vs-hip balance picks pear / top-heavy / hourglass as a RELATIVE
	# difference — |bust - hip| as a percent of the larger of the two. Integer cross-multiply:
	# diff * RATIO_SCALE vs balance_pct * max(bust, hip). Bust > 0 always (ribcage band).
	var diff := absi(bust_mm_v - hip_mm)
	var larger := maxi(bust_mm_v, hip_mm)
	var bal := int(fig.get("balance_pct", 8))
	if diff * RATIO_SCALE > bal * larger:
		return "pear" if hip_mm > bust_mm_v else "top-heavy"
	return "hourglass"


## The overall BUILD word from the hip-to-waist FLARE ratio (hip * RATIO_SCALE / waist),
## cut by the standard's build_* thresholds: slim / curvy / thick. Build is a PROPORTION
## (how much the hips flare over the waist), so it is scale-invariant — uniformly scaling the
## whole figure does not change the build word. "" when hips/waist absent.
static func figure_build(waist_mm: int, hip_mm: int, std: Dictionary) -> String:
	if hip_mm <= 0 or waist_mm <= 0:
		return ""
	var fig: Dictionary = std.get("figure", {})
	var flare := hip_mm * RATIO_SCALE / waist_mm
	if flare < int(fig.get("build_slim_whr", 130)):
		return "slim"
	if flare >= int(fig.get("build_thick_whr", 160)):
		return "thick"
	return "curvy"


## Targeted figure descriptors (wide-hipped / slim-waisted), cut by the standard's RATIO
## thresholds — both proportions of the figure's own measurements, so they are scale-
## invariant. wide-hipped: hip-to-waist flare ratio at/above wide_hip_whr. slim-waisted:
## waist at/below slim_waist_pct of the bust/hip average. Returns an Array (possibly empty).
## Every comparison is an integer cross-multiplication (no float in the decision path).
static func figure_descriptors(bust_mm_v: int, waist_mm: int, hip_mm: int, std: Dictionary) -> Array:
	var fig: Dictionary = std.get("figure", {})
	var out: Array = []
	if hip_mm > 0 and waist_mm > 0:
		var flare := hip_mm * RATIO_SCALE / waist_mm
		if flare >= int(fig.get("wide_hip_whr", 165)):
			out.append("wide-hipped")
	if waist_mm > 0 and bust_mm_v > 0 and hip_mm > 0:
		# waist <= slim_waist_pct% of avg(bust, hip). Avoid the /2 in the average by doubling:
		# waist * 2 * RATIO_SCALE <= slim_waist_pct * (bust + hip).
		var slim := int(fig.get("slim_waist_pct", 75))
		if waist_mm * 2 * RATIO_SCALE <= slim * (bust_mm_v + hip_mm):
			out.append("slim-waisted")
	return out
