# Diffusion → Composable 2D Paperdoll: Build-Time Pipeline SOTA

Status: Web-researched 2026-06-21 against primary sources (papers, repos, hands-on reports). Claims marked with confidence level; uncertainties called out explicitly. Hard constraint: **no neural net at runtime** — diffusion is only considered as a build-time asset-production step.

Scope: Can you use SDXL-class diffusion at build time to generate, separate, vectorize, and rig a composable 2D character paperdoll for deterministic, NN-free runtime use? This document covers the five sub-problems (consistency, pose control, layer separation, raster-to-vector, rigging), the end-to-end precedents that chain them, and an honest verdict for a solo/indie developer.

---

## 1. Character Consistency Across Generations

**The problem:** A paperdoll requires many assets — body, hair, multiple clothing layers, expressions, accessories — all depicting the same character. Diffusion is stochastic; getting a consistent identity across dozens of generations is not a solved problem.

### LoRA / DreamBooth

A character LoRA fine-tunes a small parameter set (or the full model for DreamBooth) on reference images of a specific character. The result is a token/trigger that biases generations toward that character's appearance.

**What works:** Face and hair are usually consistent. Art-style transfer is reliable. Costume recognition is decent when the costume was well-represented in training data.

**Known limits (verified from practitioner reports and the ORACLE paper, arXiv 2406.02820):**

- **Pose overfitting:** "Training conditioned solely on character images can lead to the network overfitting to the poses of the reference images" — meaning the LoRA locks in the pose distribution of the training set, not just the identity. Diverse-pose training data and Pose-ControlNet conditioning are required workarounds.
- **Costume drift:** Concept bleeding between outfits occurs even with augmented training sets. Fine accessories (belts, jewelry, specific fabric patterns) reproduce poorly across pose changes.
- **DreamBooth requires multiple ID-consistent training images** and significant compute; impractical for generating a completely novel character without a prior reference.
- **LoRA rank vs. fidelity trade-off:** Low rank → poor detail retention; high rank → style bleeding into the base model and reduced editability.

### IP-Adapter / InstantID / PhotoMaker

These zero-shot or few-shot adapters inject identity from a reference image at inference time without fine-tuning.

- **InstantID** (arXiv 2401.07519): Best overall for face fidelity + text editability. Still shows grayish/blurry artifact risk and disrupts the semantic space of the base model.
- **PhotoMaker / PhotoMakerV2**: Good text editing but "relatively poor facial similarity" — trades fidelity for controllability.
- **IP-Adapter-FaceID**: High fidelity but "obvious degradation of text control capabilities."
- **IP-Adapter full-body (multi-region):** Can be applied with separate attention masks for face/torso/legs (separate CLIP vision encodings per region), but the approach is fragile, adds significant ComfyUI workflow complexity, and output quality "may not be significantly better despite the increased complexity."

**Honest verdict on consistency:** For faces in portrait-cropped outputs, identity can be held to ~80–90% perceptual similarity across generations (rough practitioner consensus; no clean benchmark for full-body non-face characters). For full-body costume characters with accessories — the paperdoll use case — drift is substantial and requires heavy prompt engineering plus ControlNet pose conditioning to reduce. **There is no method today that reliably generates 50+ consistent views of a stylized non-face character without per-output manual curation.** This is the "composition wall" for the pipeline. Confidence: high, based on multiple 2024 practitioner reports and papers.

---

## 2. Pose / Structure Control

### ControlNet

ControlNet (Zhang et al., 2023) adds conditioning branches to diffusion that accept structural signals. The primary signals for character art:

- **OpenPose keypoints** — 17-point body skeleton + hand/face keypoints. Locks character position and major limb configuration reliably. Used in virtually every production character workflow.
- **Lineart / sketch** — feeds existing line art back in; useful for generating colored versions of hand-drawn separations. Quality drops at complex overlapping geometry (crossed limbs, hair occluding face).
- **Depth** — controls overall spatial layout; less precise than OpenPose for character pose but useful for perspective control.

Multi-ControlNet stacking (OpenPose weight 0.9–1.1 + lineart weight 0.9–1.1 + depth weight 0.15–0.3) is a documented production pattern (runcomfy tutorials, 2024).

**For 2025+: ControlNet Union** ("Z-Image-Turbo ControlNet Union") merges multi-signal conditioning into a single branch, reducing overhead. Flux.1-based ControlNets have emerged but the ecosystem maturity is lower than SD 1.5 / SDXL.

**Maturity:** High for OpenPose-controlled humanoid generation. Getting a specific T-pose, spread-eagle, or isolated limb pose is reliable. Getting perfectly separated, non-overlapping parts per limb for paperdoll purposes from a single generation is not — you need separate partial-body generations or inpainting passes.

---

## 3. Layer / Part Separation

This is the hardest sub-problem for the build-time paperdoll pipeline.

### SAM / SAM2

Segment Anything Model (Meta, 2023) and SAM2 (2024) provide interactive or automatic segmentation of image regions. SAM can segment clothing, hair, and accessories when prompted with points or bounding boxes. Raw boundaries often lack sub-pixel accuracy and "tight boundaries, sub-pixel accuracy and detail preservation" are acknowledged gaps, especially for hair (MGD-SAM2, arXiv 2503.23786, introduces multi-view refinement to address this).

**Practical limit for paperdolls:** SAM segments what's *visible* — it has no semantic model of what lies *underneath* the clothing layer. You get a clean mask of the shirt but you don't get the body under the shirt. Downstream compositing depends entirely on good inpainting for occluded regions.

### LayerDiffuse (lllyasviel, arXiv 2402.17113, ACM ToG 2024)

LayerDiffuse trains a "latent transparency" offset on top of SDXL that encodes an alpha channel into the diffusion latent space. It supports:

- **Single transparent image generation** — generates a foreground subject with native alpha (no post-hoc matting).
- **Joint foreground + background generation** — generates composable layers from one prompt pass.
- **Conditioned layer generation** — given a background, generates a foreground layer consistent with it.

User study result: output "preferred in most cases (97%)" over matting approaches for quality.

**Limits:** LayerDiffuse generates images *as* transparent layers — it does not decompose an existing character image into its constituent clothing/hair/body sub-layers. The alpha encodes foreground-vs-background, not intra-character semantic parts. No documented capability for body/hair/clothing decomposition. Confidence: high, based on the paper abstract and README.

### See-through (arXiv 2602.03749, SIGGRAPH 2026 conditionally accepted)

**This is the closest thing to a production-ready layer-decomposition tool for anime/2D character art.**

See-through decomposes a *single* anime illustration into ~19 semantic body-part classes as fully inpainted, depth-ordered RGBA layers:
- Front hair / back hair / side hair
- Face (split into ~7 sub-elements: eyes, brows, mouth, etc.)
- Torso, arms, hands, legs
- Topwear, bottomwear, footwear
- Accessories

**What's novel:** It inpaints occluded regions — the body *under* clothing is hallucinated from the diffusion prior. "What's visible comes from the original; what was hidden is AI-generated."

**Output:** Exports a layered PSD file with RGBA layers + a depth map PSD. A ComfyUI workflow exists (`jtydhr88/ComfyUI-See-through`).

**Honest hands-on assessment (lilting.ch test, 2026-03):** 23 layers achieved in test. Works well for: facial decomposition, front/back clothing relationships, inpainted body-under-clothing. **Fails on:** ponytails extending beyond head bounds (cut off); complex accessories (frills, chibi proportions); merged layers for unusual hair configurations; missing footwear layer in final PSD (available as PNG). Assessment: "automatic PSD draft generator requiring significant manual refinement before Live2D production use — not a finished output tool." The author describes it as a good starting point requiring expert cleanup, not a fire-and-forget pipeline.

**Critical caveat:** See-through is evaluated on commercial anime illustrations and Live2D models used as training data. **Performance on AI-generated character art is untested in the paper.** A novel AI-generated character is out-of-distribution for See-through's segmentation model, which may degrade quality.

### DiffDecompose (arXiv 2505.21541, May 2025)

DiffDecompose uses a Diffusion Transformer for layer-wise decomposition of alpha-composited images with semantic prompts. Targets: translucent flares, semi-transparent cells, glassware — **not character art with clothing/hair/body layers.** The AlphaBlend dataset covers six optical/scientific subtasks. Not applicable to the paperdoll use case without significant retraining. Confidence: high.

### Controllable Layer Decomposition (arXiv 2511.16249, Nov 2025)

"Controllable Layer Decomposition for Reversible Multi-Layer Image Generation" — emerging work, no hands-on reports found. Noted as a potential future tool.

### Inpainting-based manual decomposition

A workflow-level approach: generate the full character, mask each clothing layer with SAM, inpaint the occluded body region beneath. This is what See-through automates. Doing it manually in ComfyUI/A1111 is feasible but requires ~5–15 min of skilled prompt + mask work per layer pair. For a full paperdoll (10–20 layers), this is 1–4 hours of technical work per character — labor-intensive but deterministic and inspectable.

---

## 4. Raster → Vector

For a truly riggable SVG paperdoll (as opposed to raster layers), raster-to-vector conversion is required. This is where the pipeline has a significant quality cliff.

### Potrace

Bitmap-only (binarizes to B&W before tracing). Produces clean curves for logos/line art but cannot handle the continuous-tone, shaded, multi-color output of diffusion models. Not usable for full-color character art output directly.

### VTracer (visioncortex, Rust)

Handles color images; traces directly to SVG path clusters via boundary tracing. Originally designed for engineering blueprints but supports pixel art and character art. Output is more compact than AI Trace (stacking strategy, fewer holes). Handles 10,000×10,000 images efficiently.

**Practical quality for character art:** VTracer produces recognizable outlines but loses anti-aliased gradients, complex shading, and soft hair detail. The result is a "posterized" SVG — acceptable for flat-color illustrative style, not for detailed shaded character art. The number of paths for a detailed character can be very high (hundreds to thousands), making the SVG manually un-editable.

### Neural vectorization (SVGDreamer CVPR 2024, OmniSVG NeurIPS 2025)

- **SVGDreamer** (arXiv 2312.16476): Text-to-SVG using diffusion-guided SDS loss + DiffVG differentiable rasterizer. Produces ~512 shape primitives for complex scenes. FID 193.42. Good editability via semantic foreground/background separation but "fails to handle complex scenes."
- **OmniSVG** (arXiv 2504.06263, NeurIPS 2025): Autoregressive VLM-based SVG generator; image-to-SVG mode available; handles "simple icons to intricate anime characters." Generates token sequences up to 30,000 tokens. ~139 seconds inference per anime character. FID 145.89 (best available). Output is "fully editable SVG" but paths are model-generated and not necessarily semantically organized for rigging.

**Honest verdict on raster→vector for rigging:** There is no tool today that converts a diffusion-generated character image to a *clean, semantically organized, layer-decomposed SVG ready for skeletal rigging* without substantial manual cleanup. The challenge is that rigging requires paths that cleanly represent separate body/clothing parts, whereas auto-vectorization tools produce a flat mesh of paths with no semantic grouping. OmniSVG's anime character mode is the closest to usable but is research-grade and takes ~2 minutes per image. **For a build-time pipeline, the most realistic approach is: raster layers (PNG with alpha) per body part, not vector SVG.** Raster layers can be rigged in Spine/Live2D directly.

---

## 5. Rigging and Animation of Generated Parts

### Live2D

Live2D takes a PSD (layered Photoshop file) and applies a control-point mesh system that deforms individual layers to simulate 3D-ish rotation, facial expressions, and body motion. It is the dominant technology for anime-style 2D character animation. Requires:
- Well-separated PSD layers (exactly the problem See-through addresses)
- Manual mesh placement and deformer setup: ~20–60 hours per character for a professional; ~5–15 hours for a simple character

**Auto-rigging for Live2D:** No fully automatic Live2D rigger exists as of mid-2026. See-through gets you a draft PSD; the Live2D mesh and deformer binding remain manual.

### Spine2D / DragonBones

Skeletal animation: a bone hierarchy drives mesh deformation of sprite layers. More automation-friendly than Live2D.

- **SpriteToMesh** (arXiv 2602.21153, Feb 2026): Fully automatic mesh generation from a sprite image. Outputs triangle meshes in Spine2D-compatible JSON. Takes under 3 seconds. Does NOT generate bones/skeleton. Trained on Spine2D game assets; may not generalize to arbitrary AI-generated art styles.
- **Spiritus** (arXiv 2503.09127, Mar 2025): End-to-end pipeline: text → SDXL character → SAM segmentation → non-uniform mesh skeleton → Spine Runtime export. Achieves cross-character animation reuse via unified skeleton. Animation generation from Motion Diffusion Model is "future work" and unstable; static pose/expression rigging is the current capability. Spine-compatible export verified.
- **AniDiffusion / "How to Train Your Dragon"** (arXiv 2503.15586, Mar 2025): Diffusion-based re-posing for diverse character topologies (humanoid, animal, articulated objects). Semi-automatic: user provides 3–5 annotated keypoint frames + skeleton topology. ~25 minutes fine-tuning on A100 per character. Generates 2D image sequences — not a rigged asset, but a re-posing tool.
- **Sprite Sheet Diffusion** (arXiv 2412.03685, Dec 2024): Conditions a video-diffusion-derived model on a reference character image + pose sequence to output a consistent animation strip. SSIM ~0.655–0.659, subject consistency ~0.90. Failure modes: fine details (hairstyles, props) inconsistent across frames; object disappearance during extended sequences. Does not produce riggable parts.

### Textoon (arXiv 2501.10020, Jan 2025 — closest to a working end-to-end system)

Text → SDXL generation → component splitting/segmentation → Live2D model assembly. Completes in ~1 minute. Uses Qwen2.5 for text parsing, ControlNet + SDXL for generation, and a custom component-splitting step. Produces a functional Live2D model. Published with GitHub repo (`Human3DAIGC/Textoon`).

**Limits:** "Character variety constrained by the template's component layer structure." The segmentation is template-driven, not fully general — it works within the Live2D component taxonomy that the system was trained on. Text description limits detailed control: "text struggles conveying complex and nuanced information." Style variety within each component category is limited. This is a demo/research tool, not a production-ready plug-in.

---

## 6. End-to-End Precedents

| Tool / Paper | Year | What it does | Output | Maturity |
|---|---|---|---|---|
| **Textoon** (arXiv 2501.10020) | Jan 2025 | Text → SDXL → component split → Live2D | Live2D .model3.json | Research, GitHub available, template-constrained |
| **Spiritus** (arXiv 2503.09127) | Mar 2025 | Text → SDXL → SAM → mesh+skeleton → Spine | Spine-compatible JSON | Research, web demo |
| **See-through** (arXiv 2602.03749) | Feb 2026 | Anime image → 19-class layered PSD + depth | PSD + ComfyUI workflow | Research, GitHub, SIGGRAPH 2026 conditional |
| **Sprite Sheet Diffusion** (arXiv 2412.03685) | Dec 2024 | Ref image + pose sequence → animation strip | Sprite sheet (raster) | Research only |
| **SpriteToMesh** (arXiv 2602.21153) | Feb 2026 | Sprite → triangle mesh for Spine | Spine JSON (mesh only) | Research |
| **Scenario.com rigging sheet** | 2025+ | Character concept → parts sheet | Raster parts for Spine/Live2D/Moho | Commercial SaaS, documented; limits not disclosed |
| **AniDiffusion** (arXiv 2503.15586) | Mar 2025 | Ref image + skeleton → 2D pose sequence | 2D image sequence | Research; ~25 min/character fine-tune on A100 |
| **OmniSVG** (arXiv 2504.06263) | Apr 2025 | Image → SVG (anime character mode) | SVG | Research, NeurIPS 2025 |

**What no end-to-end system does today:** Take an arbitrary AI-generated character (novel identity, not from a template), automatically decompose it into clean semantic layers, vectorize it, and export a production-ready Spine/Godot skeleton rig — without any manual cleanup.

---

## Adversarial Verification: Key Claims Checked

**Claim: LayerDiffuse decomposes a character into body/hair/clothing layers.**
*Status: FALSE.* The paper and README describe it as transparent single-image or foreground/background generation. It does not decompose intra-character semantic layers. (Source: arXiv 2402.17113 abstract; ACM ToG 2024 publication.)

**Claim: InstantID reliably preserves full-body character identity across generations.**
*Status: OVERSTATED.* InstantID is best-in-class for *face* fidelity + text control. Full-body costume consistency is a harder problem not addressed by InstantID specifically; it requires ControlNet pose conditioning and manual curation. (Source: arXiv 2401.07519; CoFaDiff paper, MDPI 2026.)

**Claim: See-through produces production-ready Live2D layers.**
*Status: PARTIALLY TRUE.* Produces a useful PSD draft with ~19-class semantic decomposition + inpainted occluded regions, but requires "significant manual refinement" before Live2D use. (Source: lilting.ch hands-on test, 2026; paper acknowledgment that minor layer overlaps are "easy to fix in standard layer editors.")

**Claim: Auto-vectorization can produce clean riggable SVG from character art.**
*Status: FALSE for current tools as a fire-and-forget step.* OmniSVG is the best available for anime characters but produces paths without semantic grouping; Potrace/VTracer lose shading/gradients. No tool outputs rig-ready semantic SVG layers automatically. (Source: OmniSVG paper; vtracer GitHub; Wikipedia comparison of vectorization tools.)

---

## Honest Verdict

### What's realistically buildable today (mid-2026)

A **semi-automated build-time pipeline** is feasible with substantial per-character manual work:

1. **Generate base character:** SDXL + character LoRA (trained on 15–30 reference images) + OpenPose ControlNet for each required pose/orientation. Expect ~30–60 minutes of generation + curation per character to get consistent reference sheets.
2. **Separate layers:** Use See-through (ComfyUI workflow) to get a PSD draft. Expect 1–4 hours of manual cleanup per character in Photoshop/Krita (merge artifacts, fix missing layers, patch inpainting errors).
3. **Rig:** Import cleaned PSD into Live2D Cubism (for deformation-rich animation) or Spine2D (for game-engine integration). Rigging is the largest manual step: 5–20 hours depending on character complexity and animation range needed.
4. **Export to Godot:** Live2D has a Godot plugin; Spine Runtime has a Godot plugin. Both support deterministic, NN-free runtime playback of baked animations.
5. **No vectorization step required** — raster layers are fully supported by Live2D and Spine. Skip SVG entirely unless you specifically need scalable vector output.

**Total per-character effort (solo indie):** 10–30 hours for a clean paperdoll with basic animation range. More for complex costumes, accessories, or wide expression sets.

### The 2 hardest unsolved steps

1. **Character consistency across many generations (the "composition wall"):** LoRA/IP-Adapter drift over 20+ varied generations of the same character is the primary quality risk. There is no reliable zero-shot solution. Manual curation is required at every stage. This step is the gate to everything downstream.

2. **Clean semantic layer decomposition → production-ready rig:** See-through is the closest thing to a solution but it's research-grade, trained on anime illustrations (not AI-generated art), and produces draft PSD files that require expert cleanup. The jump from "draft PSD" to "Spine-ready rig" is still largely manual.

### Whether it beats clean existing assets

**MakeHuman CC0 (3D):** MakeHuman + Blender BVH render pipeline can generate consistent, multi-pose, multi-costume spritesheets with deterministic repeatability, correct anatomy across all views, and zero character-consistency risk. The output is 3D-rendered 2D art — stylistically limited (no anime/stylized look without significant Blender shading work) but technically reliable. For a Godot game that wants a non-photorealistic look, a stylized Blender render pass (e.g. Grease Pencil, toon shader) is worth serious consideration. **This is the lower-risk, lower-effort path for geometric correctness.**

**Permissive 2D packs (Spine/Dragonbones ready):** The market has CC0 and CC-BY paperdoll packs that are already rigged and animation-ready. These have zero generative pipeline overhead but constrain character design to what's available.

**Bespoke diffusion pipeline:** Worth it *only* if you need a unique stylized aesthetic (specific anime look, branded character identity) that clean asset packs cannot provide, and you accept 10–30 hours of manual cleanup per character. For a solo indie building a system that procedurally generates many characters (the aeriea use case with its transformation / customization depth), this per-character cost is probably prohibitive unless the pipeline is heavily templated (à la Textoon) — accepting lower variety in exchange for throughput.

---

## Summary Table

| Step | Maturity | Best tool/method | Honest quality | Effort (solo indie) |
|---|---|---|---|---|
| Character consistency (face) | Mature | LoRA + InstantID + OpenPose ControlNet | Good (~85% fidelity) | 2–5 hr training + curation |
| Character consistency (full body + costume) | Bleeding-edge / unsolved | LoRA + multi-region IP-Adapter | Fair; significant drift | 5–15 hr per character |
| Pose / structure control | Mature | ControlNet OpenPose | Reliable for humanoids | Low, automated |
| Layer separation (semantic) | Bleeding-edge | See-through (2026) | Draft-quality PSD | 1–4 hr cleanup / char |
| Occluded region inpainting | Bleeding-edge | See-through inpainter | Minor errors in far-back layers | Included in above |
| Raster → riggable vector | Unsolved | OmniSVG (research) | Unorganized paths; not rig-ready | Skip; use raster instead |
| Rigging (Spine2D) | Mature | Spine + SpriteToMesh (mesh) | Manual bones still required | 5–20 hr / char |
| Rigging (Live2D) | Mature | Live2D Cubism + See-through PSD | Manual deformers required | 10–30 hr / char |
| End-to-end auto-pipeline | Research | Textoon (template-constrained) | Low variety; demo-grade | ~1 hr but limited style |
| Godot integration (runtime) | Mature | Live2D/Spine Godot plugins | Deterministic, NN-free | Low once rigged |

---

## Sources

- [Transparent Image Layer Diffusion using Latent Transparency (LayerDiffuse) — arXiv 2402.17113](https://arxiv.org/abs/2402.17113) | ACM ToG 2024
- [GitHub: lllyasviel/LayerDiffuse](https://github.com/lllyasviel/LayerDiffuse)
- [See-through: Single-image Layer Decomposition for Anime Characters — arXiv 2602.03749](https://arxiv.org/abs/2602.03749) | SIGGRAPH 2026 (conditionally accepted)
- [See-through hands-on PSD test (lilting.ch, 2026)](https://lilting.ch/en/articles/see-through-anime-layer-decomposition)
- [GitHub: shitagaki-lab/see-through](https://github.com/shitagaki-lab/see-through)
- [ComfyUI-See-through plugin](https://github.com/jtydhr88/ComfyUI-See-through)
- [Textoon: Generating Vivid 2D Cartoon Characters from Text Descriptions — arXiv 2501.10020](https://arxiv.org/abs/2501.10020) | Jan 2025
- [Spiritus: An AI-Assisted Tool for Creating 2D Characters and Animations — arXiv 2503.09127](https://arxiv.org/html/2503.09127v1) | Mar 2025
- [Sprite Sheet Diffusion: Generate Game Character for Animation — arXiv 2412.03685](https://arxiv.org/abs/2412.03685) | Dec 2024
- [SpriteToMesh: Automatic Mesh Generation for 2D Skeletal Animation — arXiv 2602.21153](https://arxiv.org/html/2602.21153v1) | Feb 2026
- [How to Train Your Dragon: Automatic Diffusion-Based Rigging — arXiv 2503.15586](https://arxiv.org/html/2503.15586v1) | Mar 2025
- [ORACLE: LoRA character consistency via mutual information — arXiv 2406.02820](https://arxiv.org/abs/2406.02820) | Jun 2024
- [InstantID: Zero-shot Identity-Preserving Generation — arXiv 2401.07519](https://arxiv.org/abs/2401.07519) | Jan 2024
- [ConsistentID — arXiv 2404.16771](https://arxiv.org/html/2404.16771v2) | Apr 2024
- [CoFaDiff: Coordinating Identity Fidelity and Text Consistency — MDPI Applied Sciences 2026](https://doi.org/10.3390/app16010414)
- [DiffDecompose: Layer-Wise Decomposition via Diffusion Transformers — arXiv 2505.21541](https://arxiv.org/abs/2505.21541) | May 2025
- [OmniSVG: A Unified Scalable Vector Graphics Generation Model — arXiv 2504.06263](https://arxiv.org/html/2504.06263v2) | NeurIPS 2025
- [SVGDreamer: Text Guided SVG Generation — arXiv 2312.16476](https://arxiv.org/html/2312.16476) | CVPR 2024
- [GitHub: visioncortex/vtracer](https://github.com/visioncortex/vtracer)
- [Comparison of raster-to-vector conversion software — Wikipedia](https://en.wikipedia.org/wiki/Comparison_of_raster-to-vector_conversion_software)
- [MGD-SAM2: Multi-view Guided Detail-enhanced SAM 2 — arXiv 2503.23786](https://arxiv.org/pdf/2503.23786)
- [SAM 2: Segment Anything Model 2 — Ultralytics Docs](https://docs.ultralytics.com/models/sam-2)
- [Scenario.com 2D Animation Rigging Sheet Generator](https://www.scenario.com/apps/2d-animation-rigging-sheet)
- [Outline and Detail: Semantic-Driven Framework for Layered 2D Character Generation — ACM UIST 2025](https://dl.acm.org/doi/10.1145/3746059.3747707)
- [MakeHuman → spritesheet workflow (awentzonline.github.io)](https://awentzonline.github.io/human-sprites/)
- [StoryMaker: Holistic Consistent Characters — arXiv 2409.12576](https://arxiv.org/pdf/2409.12576)
