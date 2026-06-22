## MicroLifeParams — the single TUNABLE data resource for the procedural micro-life
## + secondary-motion layer (breathing, idle weight-shift/sway, eye-saccade jitter,
## hair spring-bones, soft-region jiggle).
##
## This is the "dial board" the owner asked for: every rate / amplitude / stiffness
## is a field here, not a hardcoded magic number scattered through the rig. Pass an
## instance to BodyRig.micro (or edit it in the inspector); leave it null and the
## rig builds a default instance (conservative-by-default — the owner noted BDCC's
## jiggle is overtuned, so jiggle gain ships LOW).
##
## RENDER-SIDE / COSMETIC ONLY. Nothing here feeds the deterministic sim; the
## resource is pure tuning data (no behaviour). See BodyRig.apply_micro_life for the
## off-the-sim-determinism-path argument.
class_name MicroLifeParams
extends Resource

# --- breathing -----------------------------------------------------------------
## Master enable for the breathing rise/fall (spine + clavicle + arm lift).
@export var breathing_enabled: bool = true
## Breaths per second at rest (~0.25 Hz ≈ 15 breaths/min — a calm adult). Exertion
## can scale this up later (the rig reads breath_rate_hz * exertion_breath_mult).
@export var breath_rate_hz: float = 0.25
## Overall amplitude multiplier for the breath (1.0 = the tuned subtle default).
@export var breath_amplitude: float = 1.0
## Cosmetic per-cycle rate jitter (±fraction), drawn from the COSMETIC rng so each
## breath is not metronomic. 0 = perfectly periodic. Render-only, reproducible.
@export var breath_rate_jitter: float = 0.12

# --- idle weight-shift / sway --------------------------------------------------
## Master enable for the idle sway / weight-shift (never-frozen stand).
@export var sway_enabled: bool = true
## Weight-shift cycles per second (~0.08 Hz — a slow lean from foot to foot).
@export var sway_rate_hz: float = 0.08
## Overall amplitude multiplier for the sway (1.0 = the tuned subtle default).
@export var sway_amplitude: float = 1.0

# --- eye saccades --------------------------------------------------------------
## Master enable for the micro eye-saccade jitter layered UNDER the headlook/gaze
## and the existing LookWander gesture (so the eyes are never dead-still).
@export var saccade_enabled: bool = true
## Mean seconds between micro-saccades (small darts). Each interval is jittered by
## the cosmetic rng around this mean.
@export var saccade_interval_s: float = 0.9
## Peak saccade offset in normalized look units (val_look_dir is ~[-1,1]); kept
## SMALL — these are micro-darts, not the big LookWander glances.
@export var saccade_amplitude: float = 0.04

# --- hair spring-bones ---------------------------------------------------------
## Master enable for hair secondary motion (spring-bone chains).
@export var hair_enabled: bool = true
## Spring stiffness (how hard a hair bone is pulled back to its rest pose). Higher
## = snappier / less floppy. Per-second restoring rate.
@export var hair_stiffness: float = 40.0
## Damping (velocity bleed). Higher = settles faster, less jiggle overshoot.
@export var hair_damping: float = 6.0
## How much body/head motion drives the hair (gain on the inherited acceleration).
@export var hair_inertia: float = 1.0
## Max angular deflection (radians) a hair bone may swing from rest — a safety clamp
## so violent motion can't fling hair through the head.
@export var hair_max_angle: float = 0.5

# --- soft-region jiggle --------------------------------------------------------
## Master enable for the soft-region jiggle (breast / belly / glute spring-bones).
@export var jiggle_enabled: bool = true
## Spring stiffness for the soft regions. Per-second restoring rate.
@export var jiggle_stiffness: float = 55.0
## Damping for the soft regions. Higher = less bounce.
@export var jiggle_damping: float = 9.0
## CONSERVATIVE BY DEFAULT. Gain on inherited motion -> jiggle deflection. The owner
## noted BDCC's jiggle is overtuned; this ships LOW (0.35) so the default reads as a
## subtle settle, not a bounce. Dial up per-character via this knob.
@export var jiggle_gain: float = 0.35
## Max angular deflection (radians) a soft-region bone may swing from rest.
@export var jiggle_max_angle: float = 0.18
