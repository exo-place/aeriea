# Visual Channel Licensing Assessment

Status: Verified 2026-06-21 against actual license files on disk. Do not treat any entry as "green" without reading the caveat column.

Scope: Two candidate visual-asset sources — BDCC (locally cloned at `~/git/BDCC/`) and MakeHuman models (vendored in `vendor/makehuman-cc0/`) — assessed for reuse in aeriea (Godot 4.x, self-hosted, NSFW-first, potentially commercial). The strictest case is assumed: shipping reused code AND art, no copyleft obligations acceptable.

---

## Summary Table

| Source | Code license | Asset license | Obligations | Usable for aeriea? | Copyleft risk | Caveats |
|--------|-------------|---------------|-------------|--------------------|---------------|---------|
| BDCC — GDScript / system | MIT (root `LICENSE`) | — | Preserve copyright notice in copies or substantial portions | Yes, if copying code | **None** (MIT is permissive) | MIT covers everything committed to the repo with no separate per-directory exception found; contributor-submitted skins in `SkinsPartsByAuthor/` have **no per-directory license** — they fall under the root MIT by default, but this has not been confirmed with those contributors |
| BDCC — 3D art (meshes, textures, `.glb`/`.blend`/`.png`) | n/a | Implicit: root MIT (no separate art license file exists) | Same as code: preserve copyright notice | **Unclear — do not rely without confirmation** | None from BDCC itself | No separate asset license or CREDITS file exists anywhere in the repo. Art from named contributors (`SkinsPartsByAuthor/AverageAce/`, various named Skins/) is present with no individual attribution or sub-license. Whether those contributors understood their submissions as MIT when they PR'd is unverified. |
| MakeHuman — vendored CC0 subset | n/a (not shipping MH software) | CC0 1.0 Universal (as documented in `vendor/makehuman-cc0/README.md`, quoting upstream `LICENSE.md §C`) | None (CC0 = public domain dedication) | **Yes — cleanly** | **None** | Already vendored; NSFW geometry (genital targets/helpers) explicitly included; README documents per-file CC0 headers on mesh/proxy files. Eyebrow/lash mesh not from MH (authored in-repo). |

---

## Source 1: BDCC (`~/git/BDCC/`)

### License files found

```
~/git/BDCC/LICENSE                      — root project license
~/git/BDCC/Fonts/LICENSE.DroidSans.txt — Apache 2.0 for DroidSans font only
~/git/BDCC/addons/godot-notes/LICENSE  — MIT, Roboweb 2019 (editor addon)
~/git/BDCC/Util/gdunzip.gd             — inline MIT header, Jelle Hermsen 2018
```

No `CREDITS`, `CONTRIBUTORS`, `AUTHORS`, `NOTICE`, or `COPYING` files exist anywhere in the repository (verified with `find ~/git/BDCC -name "CREDITS*" -o -name "CONTRIBUTORS*" -o -name "AUTHORS*" -o -name "COPYING*"`).

No per-directory license files exist under any of: `Images/`, `AssetsSource/`, `Player/Player3D/Parts/`, `Player/Player3D/Skins/`, `Player/Player3D/SkinsParts/`, `Player/Player3D/SkinsPartsByAuthor/`.

### Root license (verbatim)

```
MIT License

Copyright (c) 2021 Alex K

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

File: `~/git/BDCC/LICENSE`

### Code license

**MIT.** The root `LICENSE` file is "Alex K" 2021, MIT. No copyleft. Reusing the GDScript (doll system, skin system, Part3D logic, etc.) requires preserving the copyright notice in copies or substantial portions. No source-disclosure obligation. No NSFW or commercial restriction.

### Asset license

**Implicitly MIT via the root LICENSE — but this is legally ambiguous for third-party contributor art.**

The root `LICENSE` text covers "the Software," which by the standard MIT interpretation covers all files in the repo. The README (`~/git/BDCC/README.md`) says:

> "This game will stay open source. You can use this as a learning resource, help me expand it or use as a base for your own game."

That is a statement of intent, not a license grant. It does not override or clarify the MIT.

However, `Player/Player3D/SkinsPartsByAuthor/AverageAce/` contains art (PNGs, `.gd` skin scripts) submitted by an author named "AverageAce." Multiple named character skins exist under `Player/Player3D/Skins/` (ArconSkin, ArticSkin, FerriSkin, KidlatSkin, LuxeSkin, LynxSkin, NovaSkin, etc.) — character names matching named NPCs and presumably created by different contributors. None of these have per-directory licenses or attribution files. Whether contributors to this adult-content FOSS game understood their submissions as covered by MIT is not documented in-repo.

**Conservative verdict: the BDCC art is unclear — do not rely on it without direct confirmation from the repo maintainer (Alexofp / Alex K) that all contributed assets are MIT.**

### Doll architecture note

BDCC uses a **3D skeletal doll system** (Godot 3.x, not 4.x), NOT a 2D side-view layered sprite system. Key architecture:

- **`Player/Player3D/Doll3D.gd`** — top-level controller. Holds a `parts` dict keyed by slot name (`"body"`, `"head"`, `"hair"`, `"ears"`, `"tail"`, `"penis"`, `"breasts"`, `"hands"`, `"legs"`, `"horns"`). Propagates state changes (facing direction, gag/blindfold/cuffed states, jiggle physics toggles) to all attached parts. Manages cum/leaking particle nodes via `BoneAttachment` nodes.
- **`Player/Player3D/DollSkeleton.gd` + `DollSkeleton.glb`** — shared skeletal rig. Parts attach their mesh instances to this skeleton via `child.skeleton = child.get_path_to(skeleton)`. Source `.blend` files are in `AssetsSource/character/`.
- **`Player/Player3D/Parts/Part3D.gd`** — base class for each slot's part. Walks children recursively to bind `MeshInstance` nodes to the shared skeleton, sets material flags (unshaded, depth-draw, cull-disabled). Each part is a separate `.tscn` referencing its own `.glb` mesh.
- **`Player/Player3D/Parts/PartStatePicker.gd` / `PartState.gd`** — state machine: each part has named states (e.g. `"gagged"`, `"blindfolded"`, `"cuffed"`) that swap child node visibility.
- **`Player/Player3D/Skins/SkinBase.gd`** — defines skin color/pattern applied as material textures. `CustomSkin.gd` reads per-slot color values.
- **`Player/Player3D/SkinsPartsByAuthor/`** — contributor-submitted additional parts with their own `.gd` skin variants.
- **Art format:** 3D meshes as `.glb` exports of Blender `.blend` files. Per-body-part PNG textures (e.g. `Parts/Body/HumanBody/body.png`). No flat side-view 2D sprite sheets.

The `UI/LayeredSprite.gd` (`TextureRectLayered`) is a simple 2D UI helper that stacks `TextureRect` nodes — used for UI display of stacked images, not the doll rendering itself.

**Direct relevance to aeriea:** BDCC's doll is a different paradigm (3D skeletal, Godot 3.x) from aeriea's MakeHuman-based 3D morph-target body (Godot 4.x). The conceptual slot/state model (named slots, state propagation, skin layering) is useful reference, but the code cannot be dropped in without substantial porting.

### Copyleft contamination risk

**None** from the BDCC license itself. MIT is permissive; copying BDCC code into aeriea does not impose any copyleft obligation on aeriea.

### Bottom line — BDCC

| | Assessment |
|---|---|
| **Code (GDScript)** | Safe to reuse under MIT with attribution. No copyleft risk. |
| **Art (3D meshes, textures, PNGs)** | **Unclear — do not rely without confirmation.** Implicitly MIT via root LICENSE, but contributor-submitted assets have no per-contributor sign-off. Seek explicit confirmation from repo maintainer before shipping BDCC art in aeriea. |
| **Commercial + NSFW** | No restriction in MIT. |

---

## Source 2: MakeHuman models (`vendor/makehuman-cc0/`)

### Location

`~/git/exoplace/aeriea/vendor/makehuman-cc0/`

The subset is already vendored in aeriea. It contains:

```
data/3dobjs/base.obj                      — base mesh (1.7 MB)
data/targets/macrodetails/               — age/gender/muscle/weight/height blendshapes
data/targets/genitals/                   — genital detail morphs
data/eyes/low-poly/low-poly.obj/.mhclo  — eyeball proxy
data/rigs/default.mhskel                 — skeleton definition
data/rigs/default_weights.mhw           — per-vertex LBS weights
data/modifiers/*.json                    — modifier registry definitions (9 files)
```

### License

As documented in `vendor/makehuman-cc0/README.md`:

> "All files in this directory are licensed under **CC0 1.0 Universal** (Public Domain Dedication). MakeHuman's core base mesh and macro targets have been explicitly CC0 since September 2020. The pinned source's `LICENSE.md §C` ("The license for the bundled assets") explicitly enumerates "**Targets and modifiers**" among the CC0 1.0 Universal bundled assets…"

The README further states per-file verification:

> "Each of these carries an explicit per-file `# This asset was explicitly released as CC0 in september 2020` header (mesh/mhclo)…"

> "`default_weights.mhw` … Its own header declares CC0 ("Symmetric weights for default makehuman mesh", (c) 2021 Data Collection AB). It is byte-identical to the file at `makehuman/data/rigs/default_weights.mhw` in the pinned `v1.3.0` source archive (verified by `cmp` against the `fetchFromGitHub` store path)."

The MakeHuman *software* is AGPL-3.0. That license applies to the application code, not to the assets it generates or ships as CC0 bundled data. The vendored files are the CC0 bundled data subset, not the MakeHuman application code.

### What CC0 means

CC0 1.0 Universal is a public domain dedication. The licensor waives all copyright and related rights to the extent possible under law. No attribution required. No restrictions on commercial use, NSFW use, modification, or distribution. No copyleft.

### Verification gaps

The `vendor/makehuman-cc0/README.md` documents the upstream license chain (MH `LICENSE.md §C`, per-file headers, `cmp` byte-identity checks against pinned `v1.3.0`) but this assessment has not independently re-verified the upstream `LICENSE.md §C` text against `makehumancommunity/makehuman` — it reads what is documented in aeriea's own vendored README. If independent re-verification is needed, see: https://github.com/makehumancommunity/makehuman/blob/master/makehuman/data/3dobjs/README.md and the upstream `LICENSE.md`.

### Bottom line — MakeHuman

| | Assessment |
|---|---|
| **Assets** | **Cleanly usable.** CC0 1.0 Universal (public domain dedication). No attribution required, no commercial or NSFW restriction, no copyleft. |
| **Software (not vendored)** | AGPL-3.0 — not applicable, not vendored or shipped. |
| **NSFW** | Genital geometry and morphs are included and CC0. |

---

## Verification still needed

1. **BDCC art / contributor-submitted assets:** The root MIT license nominally covers all repo files, but named contributors (`AverageAce`, and the authors behind `ArconSkin`, `ArticSkin`, `FerriSkin`, `KidlatSkin`, `LuxeSkin`, `LynxSkin`, `NovaSkin`, etc.) have no per-contribution sign-off, no CLA, and no CREDITS file. Before shipping any BDCC-originated art in aeriea, obtain confirmation from Alexofp (repo maintainer) that all merged contributions are MIT-licensed. The game's itch.io page or contributor guidelines may provide this — they were not checked here.

2. **MakeHuman upstream `LICENSE.md §C`:** The CC0 claim for vendored assets is documented in aeriea's own `vendor/makehuman-cc0/README.md`, which in turn cites the upstream `LICENSE.md`. If independent upstream verification is desired (versus trusting the vendored README), read `LICENSE.md §C` in the pinned `v1.3.0` tag of `makehumancommunity/makehuman`.

3. **BDCC `addons/bone_editor/`:** No LICENSE file found in `addons/bone_editor/` (only plugin files). If any of this addon code were reused in aeriea, its provenance would need to be traced — but it is an editor tool and unlikely to be a reuse target.

---

## What is NOT a concern

- **MakeHuman AGPL:** Does not apply to the vendored CC0 assets. The AGPL governs the MakeHuman application, which is not shipped in aeriea.
- **DroidSans font (BDCC/Fonts/):** Apache 2.0, separate from the rest of BDCC. Not a visual-doll asset.
- **`gdunzip.gd` (MIT, Jelle Hermsen):** Utility, not art or doll system.
- **`addons/godot-notes/` (MIT, Roboweb):** Editor plugin, not shipped.
