# BDCC2 (alexofp/rahimew) — Visual Channel Foundation Evaluation

Status: complete
Scope: read-only investigation of `~/git/pterror/BDCC2/` (commit as of investigation date); no files modified

---

## Verdict Box

| Dimension | Finding |
|---|---|
| **Godot version** | **Godot 4.x** (`config_version=5`, `config/features=PackedStringArray("4.7", ...)`) — drop-in, no port needed |
| **Code license** | **MIT** — clean, no copyleft |
| **Asset license** | **Unverified** — no per-asset or per-directory license files found in `Mesh/`, `Anims/`, `Sounds/`; PDF terms exist for two sound packs (OpenNSFW SFX/Voice) but are machine-unreadable here |
| **"Use as base" grant** | Not present in README (README is 8 lines; says nothing about reuse rights) |
| **Expression support** | **Yes — real and substantive.** Dedicated `FaceAnimator` system with 13 continuous blend parameters, gesture compositing, look-at, blink, talk, and overrideable states |
| **3D / any-angle** | **Full 3D**, `extends Node3D` / `CharacterBody3D` throughout; LookAtModifier3D on chest/neck/head |
| **Customization** | Deep: body morphs via blendshapes (Thin/Thick/Chubby/ButtSize/Muscles/Pregnant/Breasts…), interchangeable head types (human, canine, feline), skin layer compositor, clothing system |
| **Custom Godot build required** | **Yes** — runtime BPTC texture compression (`Image.COMPRESS_BPTC` called live); official Godot 4 does not expose this at runtime |
| **Adoption effort — expression rig** | **Moderate** — the expression subsystem is self-contained and clean, but it sits inside a large game; extraction requires pulling `FaceAnimator`, `FaceGestureBase`, `FaceValue`, `DollExpressionState`, the head `DollPart` scenes, and an `AnimationPlayer` wired to the head GLB |
| **Adoption effort — full doll** | **Heavy** — deep coupling to `BaseCharacter`, `GlobalRegistry`, `MyLayeredTexture` (custom compositor), `LayeredAnimPlayer` (custom addon), and a custom Godot build |
| **Viable — expression channel** | **Conditionally yes** — the expression design is solid; the custom-build dependency is the one hard blocker to resolve |
| **Viable — full embodied character** | **Conditionally yes, with significant work** — character system is rich but heavily entangled and depends on the custom build |

---

## 1. Godot Version

`project.godot` line 9: `config_version=5` — this is the Godot 4.x project format (Godot 3.x uses `config_version=4`).

Line 21: `config/features=PackedStringArray("4.7", "Forward Plus")` — targets Godot 4.7.

GDScript confirms Godot 4 throughout: `doll.gd` line 1: `extends Node3D`; `doll_controller.gd` line 1: `extends CharacterBody3D`; `face_animator.gd` line 113: `@onready var animTree: AnimationTree = %AnimationTree`. No `extends Spatial`, no `onready var`, no `yield` anywhere found.

**Call: drop-in — no port needed for the GDScript layer.**

---

## 2. License

### Code

`LICENSE` (root): standard MIT, `Copyright (c) 2025 Rahi`. Full permissive grant. No copyleft contamination from the code itself.

No per-directory or per-file license overrides found under `Game/`, `Mesh/`, `Anims/`, or any addon subdirectory checked.

### Assets (3D meshes, textures, animations)

**No license file was found in `Mesh/`, `Anims/`, or any mesh subdirectory.** There is no CREDITS file, no README in those directories, and no embedded provenance metadata visible in the file tree.

The only asset-adjacent license documents are:

- `Sounds/README - OpenNSFW SFX Pack Terms.pdf`
- `Sounds/README - OpenNSFW Voice Pack Terms.pdf`

Both are PDFs; their content was not read (binary). "OpenNSFW" is a known CC-BY sound pack project but this is **unverified** here — read the PDFs before assuming.

The 3D art (GLBs under `Mesh/Parts/Head/HumanFeminine/MyHumanHead.glb`, `Mesh/Parts/Head/CanineHead/CanineHead.glb`, body skeleton, clothing, etc.) has **no stated license**. The MIT in the root `LICENSE` file covers "the Software" (the code) but does not automatically extend to bespoke authored art assets — the legal interpretation of whether custom 3D meshes are "the Software" is ambiguous at best. **This is a real risk; do not ship BDCC2 assets without explicit confirmation from Rahi (alexofp) that the MIT covers them, or separate art licensing.**

### README "use as a base" grant

The README contains 8 lines about the project name and how to get the custom Godot build. There is no statement like "use this as a base," "open source for derivative works," or similar, which was apparently present in some formulation of the older BDCC. **That grant does not appear in BDCC2's README.**

---

## 3. The Doll / Character System

### 2D or 3D

Fully 3D. `doll.gd` (`extends Node3D`), `doll_controller.gd` (`extends CharacterBody3D`), `body_skeleton.gd` (`extends Node3D`). The body is a rigged 3D character with a `Skeleton3D`, `LookAtModifier3D` on head/neck/chest, and a full animation tree. No fixed-view or side-on constraint found.

### Facial Expression Support

**This is the strongest part of BDCC2 for aeriea's immediate need.** The expression system is well-designed and fully operational:

**`FaceValue.gd`** — 13 typed parameters:
```
EyesClosed, EyesSexy,
BrowsShy, BrowsAngry,
MouthOpen, MouthPanting, MouthBlep, MouthSmile, MouthSad, MouthSnarl,
LookDir (Vec2), LookCross,
Talking
```

**`face_animator.gd`** — drives these 13 parameters into an `AnimationTree` `AnimationNodeBlendTree` backed by named animations (`Eyes_Close`, `Mouth_Smile`, `Brows_Angry`, `Look_Left`/`Right`/`Up`/`Down`, etc.). All float params, dirty-checked per frame.

**`FaceGestureBase.gd`** — compositing layer: priority-sorted stack of gesture objects each contributing to the final float values with tween-based influence blending. Standard override profile (`FaceAnimatorOverrideProfile`) allows external callers to pin any FaceValue to a fixed number.

**Shipped gestures** (`Game/Doll/FaceAnimator/Gestures/`):
- `Blinking.gd` — autonomous periodic blink, slows under arousal
- `LookDir.gd` — autonomous idle eye wander (Vec2)
- `Moan.gd`, `Orgasm.gd` — sexual
- `OpenMouth.gd` — triggered by `DollExpressionState.OpenMouth`
- `SexGiving.gd`, `SexReceiving.gd`, `SexReceivingMouth.gd` — sexual states
- `Talking.gd` — `doTalk(length)` event tween-drives `valTalking` up then back to 0
- `TopPlap.gd` — sexual

**`DollExpressionState.gd`** enum:
```
IgnoreChange, Normal, Unconscious, SexReceiving, SexGiving, OpenMouth
```

**External call surface**: `face_animator.setExpressionState(int)`, `face_animator.doTalk(length)`, `face_animator.setFaceOverrideData(dict)`, `face_animator.setGagMouthOverride(float)`. These are the handles aeriea would use.

**What is missing for aeriea's show-don't-tell need**: the expression states cover arousal/sex/unconscious but there are no gesture classes for neutral conversational emotions (Happy, Sad, Surprised, Disgusted, Angry, Fearful as standalone states). `BrowsAngry` and `MouthSmile`/`MouthSad` as *parameters* exist, but no `SadGesture`, `HappyGesture`, `AngryGesture` classes ship — only `DollGesture` body gestures (`HeadNod`, `HeadShake`, `Wave`, `HappyHand`, `Cocky`, `ShrugAngry`, etc.). **Bridging the FaceValue parameters to a conversational-emotion gesture layer is aeriea's job to add**, but the infrastructure to do so is clean and ready.

**Look-at**: `doll.gd` has `LookAtModifier3D` on chest, neck, and head, with `processLookAt` called each frame and influence control. This handles gaze direction in 3D automatically.

### Customization / Composability

Body morphs via `setBlendshape()` on `MeshInstance3D` targets using Godot's `find_blend_shape_by_name()` / `set_blend_shape_value()` API:
- Body: `Thin`, `Thick`, `Chubby`, `ButtSize`, `BodySmooth`, `BodyBigger`, `Muscles`, `Pregnant`
- Breasts: `BreastsHuge`, `BreastsFlat`, `BreastsCleavage`, `NipplesNormal`, `NipplesAnime`
- Body state: `BellyBulge`, `PussyOpenedWide`, `PussyPull`, `AnusOpenedWide`, `AnusPull`

Interchangeable head types (each a separate `DollPart` scene): `HumanFeminine/my_human_head.tscn`, `CanineHead/canine_head.tscn`, `FelineHead/feline_head.tscn`. All three have their own `FaceAnimator` node.

Skin is a runtime compositor (`MyLayeredTexture`) — layered color-mask and texture passes combined in a SubViewport, then optionally BPTC-compressed.

Clothing: separate `DollPart` scenes under `Mesh/Clothing/` (bra, panties, strapon harness, shorts, etc.), each subscribing to the doll's hole-data blendshape updates.

Species: `Game/Character/Species/Human.gd`, `Canine.gd`, `Feline.gd`.

### Animation System

`Doll` uses a custom `LayeredAnimPlayer` addon (`addons/LayeredAnimPlayer/`) that extends/wraps `AnimationTree` to support named layers (gesture layer, full-body gesture layer). Body animations are GLBs under `Anims/Raw/` (locomotion, gestures, sex scenes, poses, combat). Face animation is a separate `AnimationPlayer` on the head part, driven by `FaceAnimator`.

---

## 4. Relationship to Older BDCC

The README does not mention BDCC1 or describe this as a port or successor. The codebase shows no `yield`, no `Spatial`, no Godot 3 patterns — it is a native Godot 4.7 project, not a port. The project name `BDCC2` implies succession but no code lineage from an older GDScript 1/2 codebase is visible. **The relationship is unverified** — the README is silent on this.

---

## 5. Architecture and Adoption Paths

### Key files and node hierarchy

```
Doll (Node3D, doll.gd)
  ├── AnimationPlayer          ← body animations (GLB libs from GlobalRegistry)
  ├── AnimationTree            ← LayeredAnimPlayer (custom addon)
  ├── BodySkeleton (Node3D)    ← Skeleton3D, physics holes, bone attachments
  ├── Parts (Node3D)           ← DollPart instances spawned at runtime
  │     └── [HeadPart]        ← e.g. my_human_head.tscn
  │           └── FaceAnimator (Node, face_animator.gd)
  │                 └── AnimationTree (%AnimationTree)
  └── VoiceHandler
```

Character data lives in `BaseCharacter` (not a Node — a RefCounted data object) held by `DollController` / `character_pawn.gd` and referenced weakly by `Doll`. `GlobalRegistry` (autoload) holds animation library paths and doll gesture definitions.

### Adoption path A: expression rig only (aeriea's immediate need)

Extract: `FaceAnimator`, `FaceGestureBase`, `FaceValue`, `DollExpressionState`, `FaceAnimatorOverrideProfile` (6 GDScript files), the `FacialAnimTree.tres` blend tree resource, and the relevant head scene (e.g. `my_human_head.tscn` + `MyHumanHead.glb`). Wire an `AnimationPlayer` from the head GLB. The `FaceAnimator` needs a `DollPart` reference only to traverse up to `Doll` and then to `BaseCharacter` for arousal values — stub those out or remove them.

**Blockers to resolve**: (1) asset license for `MyHumanHead.glb` and texture files; (2) the custom Godot build for `Image.COMPRESS_BPTC` — this is called in `my_layered_texture.gd` which may not be on the critical path for the expression rig alone (it is the skin compositor, not the face rig); (3) `GlobalRegistry` autoload is referenced by `Doll` but not directly by `FaceAnimator` — can likely be stubbed.

**Effort: moderate.** Mostly untangling the `DollPart → Doll → BaseCharacter` reference chain. The face rig itself is clean.

### Adoption path B: full doll

Requires bringing in the entire `Game/Doll/`, `Game/Character/`, `Mesh/` tree, `GlobalRegistry`, the `LayeredAnimPlayer` addon, `MyLayeredTexture`, and the custom Godot 4.7 build (or patching out the `COMPRESS_BPTC` call). The character system is well-structured but has significant surface area (species, bodypart slots, clothing, presets, multiplayer sync via `netfox`).

**Effort: heavy.** This is not a drop-in scene; it is a full game subsystem. Realistic path is to use BDCC2 as a design reference and mesh/animation source while rebuilding the integration layer to fit aeriea's architecture.

---

## 6. The Custom Godot Build — Critical Flag

`README.md` (lines 4–11):

> Uses a custom build of godot 4. If you wanna contribute/edit this project, you will need it too. Grab the latest version here (I occasionally sync it with the official repo):
> https://nightly.link/Alexofp/godot/workflows/runner/bdcc2
> Changes compared to the official editor:
> - Enabled support for runtime texture compression in exported builds (used for compressing doll skins on the fly so they don't take up as much VRAM)

`my_layered_texture.gd` line 229: `_image.compress(Image.COMPRESS_BPTC)` — this is the runtime call that requires the custom build. In official Godot 4, `Image.compress()` with `COMPRESS_BPTC` is available only at import time (editor), not in exported builds. Alexofp's custom build re-enables it at runtime.

**Impact on aeriea**: If you only use the expression rig (Path A), `MyLayeredTexture` may not be on the hot path. If you use the full doll with skin compositing, you need either the custom build or to replace the skin compositor with a standard approach (e.g., keep skins as pre-compressed import-time textures, or use `PortableCompressedTexture2D` which is available in official Godot 4 — notably the commented-out line 225–227 shows the author considered this but switched to the `Image.compress` approach). This is a **solvable engineering problem**, not a dead end.

---

## Bottom-Line Assessment

**For the immediate show-don't-tell expression channel**: BDCC2's `FaceAnimator` is the best openly-available Godot 4 expression rig found in this investigation. It has the right shape — composited continuous parameters, gesture stack, override profile, look-at — and is native Godot 4.7 GDScript with MIT code license. The gaps are: (a) no shipped conversational-emotion gestures (Happy/Sad/Angry/Surprised as face states) — these must be authored; (b) asset license for the head meshes is unconfirmed; (c) the custom Godot build for skin compression is probably not required for the expression rig alone but must be verified.

**For a fuller embodied character**: viable as a design reference and parts source, but the integration is heavy. The body morph system (blendshapes), head interchangeability, and clothing system are solid; the skin compositor is the build-dependency risk.

**Recommended next step**: contact Rahi (alexofp) to confirm (1) whether MIT covers the 3D art assets, and (2) whether the skin compression can be replaced with `PortableCompressedTexture2D` in a fork — both are tractable asks if the author is reachable. Do not ship the 3D assets before that confirmation.
