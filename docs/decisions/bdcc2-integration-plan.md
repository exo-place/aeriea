# BDCC2 integration plan (Path A — mine BDCC2 as replaceable surface)

Status: **PLAN — verified against both repos read-only (2026-06-22); not yet
implemented**

Scope: a concrete plan to mine BDCC2's embodiment systems into aeriea **as
replaceable SURFACE behind aeriea's OWN seams** — never as aeriea's
architectural base. The path decision is **already made and not relitigated
here**: Path A = mine BDCC2 heavily behind aeriea's own minimal seams, keeping
aeriea's foundation; **NOT** Path B (building aeriea on BDCC2's
locus-based / state-in-object architecture, which the substrate design flagged
as the poisoned framing). This doc defines the seams, the per-system
extractability verdict, the untangling work, the port-risk, the art-license
to-confirm list, and the recommended first extraction.

Cross-links:
- `../research/bdcc2-evaluation.md` — the prior read-only eval of BDCC2 (the
  basis this plan builds on; verdicts here either confirm or refine it).
- `substrate-foundations.md` — the foundation that must stay aeriea's; this doc
  is the concrete realization of its "*systems mined from prior art (BDCC2 etc.,
  MIT) placed behind aeriea's own seams as a replaceable surface — never the
  base*" channel commitment.
- `body-and-locomotion-slice.md` — aeriea's existing body/locomotion slices
  (MakeHuman CC0 body + morphs + rig + foot-IK + Motion Matching); the seams
  here plug into this.
- `procedural-body-and-animation.md` — the body/animation pillar (the
  aspirational tiers BDCC2 surface degrades toward/from).
- `prose-generation.md`, `npc-mind-and-language.md` — the show-don't-tell
  framing the expression seam serves.

---

## Lead summary

### The seams (aeriea owns the interface; BDCC2 is the first implementation)

Four minimal, assumption-free seams. Each is a pure projection
`sim-state → render`, render-side, excluded from the sim hash — the **same
shape** as the existing `MovementState → pose` seam
(`body-and-locomotion-slice.md` §3.1). BDCC2 systems are *one implementation*
behind each; a from-scratch or CC0-asset implementation is another.

1. **Expression seam** — `affect/intent → face`. `apply_expression(ExprState)`
   where `ExprState` is a small serializable record of continuous affect/intent
   channels (the aeriea-owned vocabulary). BDCC2's `FaceAnimator` is the first
   impl behind it.
2. **Body seam** — `params → morphs`. Already exists in aeriea
   (`BodyState → blendshape weights`, `body_rig.gd` / `body_state.gd`). BDCC2
   contributes *additional morph axes* (NSFW/detail), not the seam itself.
3. **Locomotion seam** — `movement-state → animation`. Already exists in aeriea
   (`MovementState → pose` via `body_rig.gd` + Motion Matching). BDCC2
   contributes *more clips* behind the same seam, nothing structural.
4. **Character seam** — `state → rendered doll`. The composing seam:
   `render_character(BodyState, ExprState, MovementState, gaze_target) → a posed,
   morphed, expressive doll`. aeriea owns this; BDCC2's `Doll` is **NOT** adopted
   as this seam — its `Doll` is the entangled hub we are explicitly *not* basing
   on (that would be Path B).

A fifth, narrow seam falls out of the expression seam:

5. **Gaze seam** — `look-target → head/neck orientation`. Backed by Godot's
   **built-in** `LookAtModifier3D` (4.4+), not BDCC2 code. BDCC2's doll.gd shows
   the *wiring pattern* (chest/neck/head chain) but contributes no code worth
   porting.

### Per-system extractability verdict

| BDCC2 system | Verdict | Why |
|---|---|---|
| `FaceAnimator` + gestures + `FaceValue` + `FaceGestureBase` + `FaceAnimatorOverrideProfile` (the **face RIG, code**) | **CLEAN** | Self-contained; only couplings are `dollPart.getDoll()/getCharacter()` (a 3-call chain, stub-able) and `RNG`/`createTween` (swap aeriea's seeded RNG / `Node.create_tween`). No `GlobalRegistry`, no skin compositor, no `LayeredAnimPlayer`. |
| Face **ANIMATIONS** (`Eyes_Close`, `Mouth_Smile`, … the blendshape clips) | **DEEPLY ENTANGLED — to ART, not code** | They live **inside `MyHumanHead.glb`** (baked blendshape animations on BDCC2's specific head mesh). The rig drives named clips; those clips are art bound to BDCC2's head topology. aeriea must **re-author equivalent clips on its MakeHuman head** (the rig is the reusable part; the clips are not portable). |
| Body morphs (`setBlendshape` / `find_blend_shape_by_name`) | **CLEAN (as a pattern); aeriea already has it** | Standard Godot blendshape API; aeriea's `body_rig.gd` already does this. BDCC2's *morph axis list* (NSFW/detail names) is a useful reference; the code is not needed. |
| Locomotion / walk anims (`Anims/Raw/LocomotionAnims.glb`, `BasicAnims.glb`) | **MODERATE — art-coupled** | Clips are on BDCC2's skeleton; aeriea already has 100STYLE MM locomotion. Reusing BDCC2 clips needs retargeting onto the MakeHuman rig (same retarget seam aeriea's `motion_ingest.gd` uses) **and** the art license. Low value: aeriea's locomotion is already covered. |
| Gaze / LookAt | **CLEAN — but it's a Godot built-in, not BDCC2** | `LookAtModifier3D` is engine-native (4.4+). Use it directly; BDCC2 contributes only the wiring pattern. No extraction. |
| Skin compositor (`MyLayeredTexture`) | **DEEPLY ENTANGLED + custom-build dependency** | Runtime `Image.compress(COMPRESS_BPTC)` needs BDCC2's custom Godot build. Resolvable (see port-risk) but **not on the critical path** for the expression seam. Defer. |
| Clothing (`DollPart` scenes) | **DEEPLY ENTANGLED** | Each clothing piece subscribes to the doll's hole-data blendshape updates and the `DollPart → Doll` chain. Tied to the very architecture Path A refuses. Treat as design reference only. |
| Hair / jiggle physics (wigglebone addon + `DMWBWiggle*`, hair shader) | **MODERATE — third-party, separable** | wigglebone is a **separate MIT-ish Godot addon** (not BDCC2-authored) — adoptable independently of BDCC2 entirely. Hair shader is *"Adapted from Godot-Hair-Shading by LiveTrower"* — third-party, needs its own license check. Neither is BDCC2-architecture-coupled. |
| `Doll` (the hub: `doll.gd`, 1074 lines) | **DO NOT EXTRACT (Path B trap)** | Couples `GlobalRegistry`, `LayeredAnimPlayer`, `MyLayeredTexture`, `BaseCharacter`, `BodySkeleton`. This *is* the locus-based hub Path A rejects. aeriea's own character seam (#4) replaces it. |

### Biggest port-risk

aeriea is **Godot 4.6**; BDCC2 is **Godot 4.7**. The hard blocker is **not**
the GDScript drift (face rig is plain 4.x GDScript, drop-in) — it is the
**custom Godot build for runtime BPTC skin compression** (`my_layered_texture.gd`
line 229: `_image.compress(Image.COMPRESS_BPTC)`). **This affects only the skin
compositor**, which is **not needed for the expression seam** (the recommended
first extraction). **Resolution CONFIRMED present in source:** lines 225–226 of
`my_layered_texture.gd` hold the commented-out
`PortableCompressedTexture2D.create_from_image(_image,
PortableCompressedTexture2D.COMPRESSION_MODE_BPTC)` substitution — the
official-Godot path the author already wrote and switched away from. So the
substitution **does hold** as a fix when/if the skin compositor is ever adopted;
it is a one-line swap to stay on stock Godot, at a (likely minor) VRAM cost.
`PortableCompressedTexture2D` exists in stock 4.6, so this is a solved problem,
deferred until skin is on the critical path.

`LookAtModifier3D` was added in Godot **4.4**, so it is present in 4.6 — the
gaze seam is safe on aeriea's engine.

### Art needing license sign-off (before shipping)

Code is MIT (`LICENSE`, "Copyright (c) 2025 Rahi"). **Art is unverified** — no
per-asset/per-directory license found (confirmed: the only asset-adjacent files
are `Sounds/README - OpenNSFW *.pdf` and `Mesh/SharedMaterials/Hair/
HairShaderCredit.txt`). Confirm with Rahi (alexofp) before shipping any of:

- **`Mesh/Parts/Head/HumanFeminine/MyHumanHead.glb`** + its baked face
  blendshape animations + its textures (`Textures/HumanSkin/*.png`,
  `Textures/Mouth/*.png`). **This is the load-bearing one** — the face clips the
  rig drives live in this GLB.
- **`Mesh/Parts/Body/FeminineBody/FeminineBody.glb`**,
  `MasculineBody/MasculineBody.glb` (only if BDCC2 body meshes are ever used —
  aeriea ships MakeHuman CC0, so likely never).
- **`Anims/Raw/*.glb`** (LocomotionAnims, BasicAnims, GestureAnims, …) — only if
  BDCC2 motion clips are reused (low value; aeriea has 100STYLE).
- **Canine/Feline head GLBs + textures** (if nonhuman heads are ever mined).
- **Hair shader** (`Mesh/SharedMaterials/Hair/`) — *third-party* ("Godot-Hair-
  Shading by LiveTrower"); check LiveTrower's license **separately** from Rahi.
- **wigglebone addon** — separate addon; check its own license (it is a known
  community addon, but verify before bundling).
- **OpenNSFW sound packs** — the two PDFs carry their own terms; read them.

**The face RIG CODE (the recommended first extraction) needs no art sign-off to
prototype against an aeriea-authored head** — see below.

### Recommended first extraction

**Extract the `FaceAnimator` face rig (CODE) and drive it from `npc_maren`'s
affect — the show-don't-tell win.** Recommended over locomotion-first because:

1. **It fills a real gap; locomotion does not.** aeriea already has walk/run via
   procedural locomotion + 100STYLE Motion Matching (see *Embodiment state*
   below — the "no walk animations" claim is **false**). aeriea has **no facial
   expression / gaze rig at all**. The expression seam is the genuine missing
   piece.
2. **It is the CLEAN extraction.** The rig code has the smallest entanglement
   surface (a 3-call doll chain + RNG/tween, both trivially stubbed); the skin
   compositor and custom-build risk are **off** this path.
3. **It proves the seam discipline on the highest-value case.** `npc_maren`
   already computes `mood`×`rapport` affect that today is shown *only in prose*
   (`scripts/text/npc_realizer.gd`). Driving a face from that same affect is the
   exact "show what prose shouldn't tell" payoff
   (`substrate-foundations.md` Channels) — and it does it behind aeriea's
   `apply_expression(ExprState)` seam, with BDCC2 as the first impl.

(The art license for the face *clips* is sidestepped at prototype stage by
authoring a handful of expression blendshapes on aeriea's MakeHuman head — see
the first-extraction steps. Rahi sign-off is needed only if aeriea ever ships
BDCC2's head GLB itself.)

---

## 1. aeriea's current embodiment / animation state

**Verified against the code, not assumed.** aeriea has a substantial embodiment
stack already — this corrects the premise that it "lacks walk animations."

**What EXISTS:**

- **Body mesh + morphs.** `scripts/body/body_rig.gd` reconstructs a
  `Skeleton3D` + skinned `MeshInstance3D` at runtime from byte-reproducible CC0
  artifacts (`assets/body/base_body.res` — MakeHuman base mesh + macro
  blendshapes + LBS weights; `base_body_rig.json` — bone hierarchy).
- **Body-state → morph projection.** `scripts/body/body_state.gd` (`BodyState`:
  `age_years`, `masculinity`, `muscle`, `weight`, `proportions`, `height_cm`,
  `modifiers`) drives blendshape weights — the **body seam already exists**.
- **Locomotion animation — PRESENT.** `body_rig.gd` runs a render-side animation
  layer: procedural leg/arm walk-run cycle (phase advances with horizontal
  speed, blends to idle at rest) + **analytic two-bone foot-IK**. **Plus Motion
  Matching** over the 100STYLE (CC BY 4.0) dataset
  (`scripts/body/motion_matcher.gd`, `motion_db.gd`,
  `assets/body/locomotion_mm.res`). Tests:
  `tests/body_locomotion_test`, `tests/body_motion_matching_test`.
  **→ The claim "aeriea lacks walk animations" is FALSE.** It has procedural
  locomotion AND data-driven Motion Matching.
- **Eyes — procedural.** `assets/body/eye.gdshader` computes iris/pupil/sclera
  analytically; eye/teeth/tongue proxy pieces follow morphs (`proxy_morph.gd`,
  `base_body_proxies.res`). So eyeballs render — but they do not *emote*.
- **Movement sim.** Full data-driven deterministic movement substrate
  (`movement-substrate.md`, Slice 4 done).

**What is MISSING (the gaps BDCC2 fills):**

| Gap | Exists in aeriea? | BDCC2 system that fills it |
|---|---|---|
| **Facial expression rig** (affect → face: brows, mouth, eyes-closed, smile/sad/snarl, talk) | **NO** | `FaceAnimator` + gestures + `FaceValue` (CLEAN extraction) |
| **Gaze / LookAt** (head/neck/eye orientation to a target) | **NO** | Pattern only — use Godot built-in `LookAtModifier3D` |
| **Autonomous idle face life** (blink, eye-wander) | **NO** | `Blinking.gd`, `LookDir.gd` gestures (CLEAN) |
| **Talk visemes / mouth-on-speech** | **NO** | `Talking.gd` gesture + `doTalk(length)` (CLEAN) |
| **NSFW / detail morph axes** (breast, genital, belly-bulge, etc.) | Partial (`BodyState.modifiers` exists; axis set thin) | BDCC2 morph **axis list** as reference (code not needed) |
| **Hair + jiggle physics** | **NO** | wigglebone addon (separable, third-party) |
| **Clothing** | **NO** | BDCC2 clothing = design reference only (Path-B-coupled) |

So BDCC2's **single highest-value contribution to aeriea is the facial
expression + gaze channel** — precisely the channel `substrate-foundations.md`
assigns to "showing": *the visual channel's job is to show what prose shouldn't
tell — expression, reaction.*

---

## 2. aeriea's OWN seams (interfaces aeriea owns; BDCC2 plugs behind)

Each seam is stated as a small interface. The discipline
(`substrate-foundations.md`): minimal, assumption-free, validated by a real
consumer. All are render-side projections excluded from the sim hash, mirroring
the existing `MovementState → pose` seam.

### 2.1 Expression seam — `affect/intent → face`

```
# aeriea-owned vocabulary (a small serializable record; NOT BDCC2's FaceValue,
# though FaceValue is a good reference for the channel set).
ExprState = {
  # affect channels, continuous, engine-neutral:
  valence: float,      # -1 sad/displeased .. +1 happy/pleased
  arousal: float,      # 0 calm .. 1 intense   (NOTE: emotional arousal, general)
  tension: float,      # 0 relaxed .. 1 tense/guarded
  attention: float,    # 0 averted/withdrawn .. 1 engaged
  # intent overlays (event-driven, transient):
  talking: float,      # 0..1 speech mouth activity
  # optional discrete overlay for strong reads:
  emphasis: String,    # "" | "surprise" | "snarl" | "shy" | ...
}

interface ExpressionSurface:
  apply_expression(e: ExprState) -> void   # set the target face for this frame
  do_talk(length: float) -> void           # transient speech pulse
```

The **adapter** maps `ExprState` → BDCC2 `FaceValue` channels (e.g.
`valence>0 → MouthSmile`; `valence<0 → MouthSad + BrowsShy`;
`tension → BrowsAngry/MouthSnarl`; `attention` → eye openness + look-at
influence). This adapter is **aeriea's**; it is where the seam's independence
lives. A non-BDCC2 impl (CC0 head + own blendshapes) implements the same
interface.

### 2.2 Body seam — `params → morphs` (ALREADY EXISTS)

```
interface BodySurface:
  apply_body_state(b: BodyState) -> void    # already in body_rig.gd
```

BDCC2 contributes only *additional axis names* to grow `BodyState`; the seam is
done. No extraction.

### 2.3 Locomotion seam — `movement-state → animation` (ALREADY EXISTS)

```
interface LocomotionSurface:
  apply_movement_state(m: MovementState) -> void   # already body_rig.gd + MM
```

BDCC2 contributes *more clips* (needs retarget + license); structurally nothing.
No extraction needed for parity.

### 2.4 Character seam — `state → rendered doll` (the composing seam, aeriea-owned)

```
interface CharacterSurface:
  render(b: BodyState, e: ExprState, m: MovementState, gaze: Vector3?) -> void
```

This composes the body, locomotion, and expression seams over **one** skeleton
and is **aeriea's node** (a thin composer on `body_rig.gd`), explicitly **NOT**
BDCC2's `Doll`. This is the line that keeps Path A from collapsing into Path B:
the hub is ours.

### 2.5 Gaze seam — `look-target → head/neck orientation`

```
interface GazeSurface:
  set_look_target(world_pos: Vector3, influence: float) -> void
```

Backed by Godot built-in `LookAtModifier3D` on a chest/neck/head bone chain
(the wiring pattern observed in BDCC2 `doll.gd` lines 17–22, 870
`processLookAt`). No BDCC2 code extracted.

---

## 3. The untangling plan (the heart of Path A)

For each minable system: its dependencies, and the minimal cut to drop it behind
the seam.

### 3.1 `FaceAnimator` face rig — CLEAN

**Files (code):** `Game/Doll/FaceAnimator/face_animator.gd` (474 lines),
`FaceGestureBase.gd` (`extends RefCounted`), `Util/FaceValue.gd`,
`Util/FaceAnimatorOverrideProfile.gd`, and the gesture classes
`Gestures/Blinking.gd`, `LookDir.gd`, `Talking.gd` (the conversational-relevant
ones; the sexual gestures `Moan/Orgasm/Sex*` can come later behind the gate).
**Resource:** `FacialAnimTree.tres` (the `AnimationNodeBlendTree` referencing
named clips).

**BDCC2-architecture dependencies and the cut for each:**

| Dependency | Cut / stub |
|---|---|
| `dollPart.getDoll()` → `Doll` (lines 156–159) | Stub: `FaceAnimator` only walks up to `Doll`/`BaseCharacter` to read arousal for autonomous gestures. **Remove the `@export var dollPart` chain**; feed affect *in* via aeriea's `apply_expression(ExprState)` instead of having the rig pull it. (This inverts control to match aeriea's seam — the rig becomes a sink, not a puller.) |
| `getCharacter()` → `BaseCharacter` (lines 161–165) | Same cut — delete; affect arrives via the seam. |
| `RNG` (seeded RNG autoload, in `Blinking`/`LookDir`) | Swap for aeriea's seeded RNG source. Keeps determinism (DESIGN.md seeded-sim invariant). |
| `createTween()` base helper | Replace with `Node`'s built-in `create_tween()` (the gestures are `RefCounted`; route tweens through the host node, or convert tween-driven values to per-frame integration to stay determinism-friendly). |
| `%AnimationTree` (the `FacialAnimTree.tres` blend tree) | Keep — but it references **named clips** that live in the head GLB (§3.2). Re-point to aeriea's head clips. |
| `GlobalRegistry` | **Not referenced by `face_animator.gd`** — confirmed; nothing to cut. |
| Skin compositor / `MyLayeredTexture` / `LayeredAnimPlayer` | **Not on this path** — confirmed. The custom-build risk does not touch the face rig. |

**Verdict: the face rig is the cleanest thing in BDCC2 to mine.** The only real
work is inverting affect-flow (push, not pull) and swapping RNG/tween — both
align it *better* with aeriea's determinism + seam discipline.

### 3.2 Face ANIMATIONS — DEEPLY ENTANGLED to ART (not code)

The clips `Eyes_Close`, `Mouth_Smile`, `Brows_Angry`, `Look_*`, `Talking`, etc.
(enumerated in `FacialAnimTree.tres`) are **baked blendshape animations inside
`MyHumanHead.glb`**, authored on BDCC2's head topology. **They do not port to
aeriea's MakeHuman head.** The rig is reusable; the clips are not.

**Cut:** author an equivalent set of expression blendshapes/clips on aeriea's
MakeHuman head (MakeHuman ships `expression` targets under
`data/targets/` per `body-and-locomotion-slice.md` §1.1 — a CC0 source for face
morphs). Re-point `FacialAnimTree.tres` clip names at the aeriea clips. This is
**authoring work, gated on no license** (uses aeriea's CC0 head).

### 3.3 Body morphs — CLEAN pattern, already in aeriea

`setBlendshape` (`doll_base_part.gd`, `DollOpenableHole.gd`) is the stock
`find_blend_shape_by_name` / `set_blend_shape_value` API — aeriea's `body_rig.gd`
already uses it. **Mine the morph axis *list* (NSFW/detail names) as a reference
to grow `BodyState`; extract no code.**

### 3.4 Locomotion / walk anims — MODERATE, low value

`Anims/Raw/LocomotionAnims.glb` etc. are clips on BDCC2's skeleton. To reuse:
retarget onto MakeHuman rig (aeriea's `tools/motion_ingest.gd` is dataset-
agnostic at the BVH/clip boundary) **+ art license**. **Low priority** — aeriea
already has 100STYLE MM. Park unless a specific clip is wanted.

### 3.5 Gaze / LookAt — CLEAN (built-in)

Use `LookAtModifier3D` directly (Godot 4.4+, present in 4.6). Wire a
chest→neck→head influence chain per BDCC2's pattern (doll.gd `processLookAt`).
**No BDCC2 code extracted.**

### 3.6 Skin compositor — DEEPLY ENTANGLED + custom-build; DEFER

`MyLayeredTexture` (runtime layered-texture compositor) needs the custom Godot
build for `Image.compress(COMPRESS_BPTC)`. **Off the critical path.** If ever
adopted: apply the in-source `PortableCompressedTexture2D` substitution (§4) to
run on stock 4.6. Until then, aeriea uses its own procedural/skin approach.

### 3.7 Clothing — DEEPLY ENTANGLED; reference only

Clothing `DollPart`s subscribe to the doll's hole-data blendshape stream and ride
the `DollPart → Doll` chain — the locus-coupled architecture Path A refuses.
**Design reference only.**

### 3.8 Hair / jiggle physics — MODERATE, separable

wigglebone is a **standalone addon** (adopt independently of BDCC2 at all). Hair
shader is third-party (LiveTrower). Neither is BDCC2-architecture-coupled; both
need their **own** license check (not Rahi's). Adopt later, on their own merits.

---

## 4. Port-risk to aeriea's Godot

- **Version:** aeriea **4.6** (`project.godot`:
  `config/features=PackedStringArray("4.6", "Forward Plus")`); BDCC2 **4.7**
  (`PackedStringArray("4.7", ...)`). Both `config_version=5` (Godot 4 format).
- **GDScript drift:** the face rig is plain 4.x GDScript (`extends Node`,
  `class_name`, `@export`, `@onready`, typed signatures). **Drop-in to 4.6** —
  no 4.7-only syntax observed in the face rig. *Caveat (unverified at the
  per-API level):* a full 4.7→4.6 API diff was not run; if any extracted file
  touches a 4.7-introduced API, it surfaces at parse time under
  `xvfb-run godot4` (the project's standing CI guard). Flag carried, not
  hand-waved.
- **`LookAtModifier3D`:** added in Godot **4.4** → present in 4.6. Gaze seam
  safe.
- **Custom-build / BPTC — the biggest risk, but OFF the critical path.**
  `my_layered_texture.gd:229` calls `_image.compress(Image.COMPRESS_BPTC)`,
  unavailable at runtime in stock Godot → BDCC2 ships a custom build.
  **Resolution CONFIRMED in source:** lines 225–226 hold the commented-out
  `PortableCompressedTexture2D.create_from_image(_image,
  COMPRESSION_MODE_BPTC)` path — the stock-Godot substitution the author wrote
  and toggled off. `PortableCompressedTexture2D` exists in stock 4.6, so **the
  substitution holds**; adopting the skin compositor later is a one-line swap
  (possible minor VRAM/quality delta vs the custom path). **The expression seam
  — the first extraction — does not touch this**, so the risk is deferred, not
  blocking.

---

## 5. Art-license to-confirm list (code is MIT; art unverified)

Confirmed: `LICENSE` is MIT (`Copyright (c) 2025 Rahi`); **no per-asset or
per-directory art license exists** (only `Sounds/*.pdf` terms and the hair
shader credit). **Get explicit sign-off from Rahi (alexofp) before shipping**
any of these; **none are needed to prototype the face rig against aeriea's CC0
head.**

1. **`Mesh/Parts/Head/HumanFeminine/MyHumanHead.glb`** + baked face blendshape
   animations + `Textures/HumanSkin/*.png` + `Textures/Mouth/*.png` — **the
   load-bearing one** (face clips live here). Needed only if aeriea ships
   BDCC2's head rather than authoring clips on its own MakeHuman head.
2. **`Mesh/Parts/Body/FeminineBody/FeminineBody.glb`**, `MasculineBody.glb` —
   only if BDCC2 body meshes are used (unlikely; aeriea ships MakeHuman CC0).
3. **`Anims/Raw/*.glb`** (Locomotion/Basic/Gesture/…) — only if BDCC2 clips are
   reused (low value).
4. **Canine/Feline head GLBs + textures** — only if nonhuman heads mined.
5. **Hair shader** (`Mesh/SharedMaterials/Hair/`, "Godot-Hair-Shading by
   LiveTrower") — **third-party; check LiveTrower's license separately.**
6. **wigglebone addon** — separate addon; verify its own license before
   bundling.
7. **OpenNSFW SFX/Voice packs** (`Sounds/*.pdf` terms) — read the PDFs.

---

## 6. Recommended first extraction — `FaceAnimator` driven by `npc_maren` affect

**Why this, not locomotion** (recap): aeriea already has locomotion (procedural
+ MM); it has **no** face/gaze rig. The face rig is the **clean** extraction
(no custom-build, no skin compositor on its path). And it lands the
**show-don't-tell** payoff against an affect source that *already exists*
(`npc_maren.mood`/`rapport`, today shown only in prose).

### Concrete steps

1. **Stand up the character seam (aeriea-owned).** Add a thin
   `CharacterSurface` composer over `body_rig.gd` exposing
   `apply_expression(ExprState)` and `set_look_target(...)`. This is the seam;
   everything below plugs behind it.
2. **Author CC0 expression clips on aeriea's MakeHuman head.** Use MakeHuman
   `expression`/face targets (CC0, per `body-and-locomotion-slice.md` §1.1) to
   build a starter blendshape set matching the `FaceValue` channels
   (eyes-closed, smile, sad, brows-shy, brows-angry, mouth-open, talk, look-
   L/R/U/D). Emit them as named clips on the head's `AnimationPlayer`. **(No
   Rahi sign-off needed — aeriea's own CC0 head.)**
3. **Port the face rig (CLEAN cut, §3.1).** Bring in `face_animator.gd`,
   `FaceGestureBase.gd`, `FaceValue.gd`, `FaceAnimatorOverrideProfile.gd`,
   `Blinking/LookDir/Talking`, and `FacialAnimTree.tres`. Apply the cuts: delete
   the `dollPart`/`getDoll`/`getCharacter` chain (invert affect to *push* via
   the seam); swap `RNG` → aeriea seeded RNG; swap `createTween` → host
   `create_tween` (or per-frame integration for strict determinism). Re-point
   `FacialAnimTree.tres` clip names at the step-2 clips.
4. **Write the `ExprState → FaceValue` adapter (aeriea-owned).** The mapping
   table from §2.1 (valence→smile/sad; tension→angry/snarl; attention→eye-
   openness + look-at; talking→`do_talk`).
5. **Drive it from `npc_maren`.** Add a thin projection
   `npc_maren.state → ExprState` (mood→valence/arousal; rapport→attention/
   tension; `last_social_act`→a transient `emphasis`/`do_talk` pulse). The same
   affect the prose realizer reads now also drives the face — *showing* what the
   prose stops *telling*.
6. **Add gaze.** `LookAtModifier3D` chest/neck/head chain; `set_look_target` →
   the player/camera so Maren meets the player's gaze, modulated by `attention`.
7. **Verify (project discipline).** New scene (a "Face Sandbox" launcher mode, or
   fold into the existing Text Sandbox) shown under `xvfb-run godot4`; a test
   suite `tests/face_expression_test.tscn` asserting: a given `ExprState`
   produces deterministic face params (same input → same output — seeded RNG +
   no hot-loop nondeterminism); the `npc_maren → ExprState → face` chain reacts
   correctly to a greet/compliment/push_away sequence; blink/look-wander run
   autonomously and deterministically. Wire the suite into `tests/run.sh`
   `SUITES`. Screenshot the face shifting across a low- vs high-rapport
   interaction as the show-don't-tell proof.

**Done-criterion:** Maren's face visibly shows the affect the prose used to
narrate, behind aeriea's `apply_expression` seam, with BDCC2's rig as the first
impl — deterministic, on stock Godot 4.6, no art license blocking (CC0 head),
no custom build, no `GlobalRegistry`, no `Doll` hub.

---

## Unknowns / flagged (not verified)

- **Full 4.7→4.6 per-API diff** not run; any 4.7-only API in an extracted file
  surfaces at parse time under xvfb (the standing CI guard). Low risk for the
  face rig (plain 4.x GDScript), flagged honestly.
- **OpenNSFW PDF terms** not read (binary); not on the face-rig path.
- **wigglebone / hair-shader exact licenses** not verified (third-party, their
  own check; off the first-extraction path).
- **Whether MakeHuman's `expression` targets fully cover the `FaceValue` channel
  set** at the needed quality — to be validated when step 2 is built ("validate
  against reality").
- **Rahi's position on art reuse** — unknown; the README grants nothing. The
  recommended first extraction is structured to need **zero** art sign-off, so
  this unknown does not block it.
