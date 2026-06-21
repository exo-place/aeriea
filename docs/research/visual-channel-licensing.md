# Visual Channel Licensing Assessment

Status: Verified 2026-06-21 against actual license files on disk (BDCC, MakeHuman); web-researched 2026-06-21 (FC-pregmod, Kisekae family). Do not treat any entry as "green" without reading the caveat column.

Scope: Four candidate visual-asset sources — BDCC (locally cloned at `~/git/BDCC/`), MakeHuman models (vendored in `vendor/makehuman-cc0/`), FC-pregmod vector/SVG body art, and Kisekae 2 / Minna no Kisekae dress-up parts — assessed for reuse in aeriea (Godot 4.x, self-hosted, NSFW-first, potentially commercial). The strictest case is assumed: shipping reused art, no copyleft obligations acceptable.

---

## Summary Table

| Source | Code license | Asset license | Obligations | Usable for aeriea? | Copyleft risk | Caveats |
|--------|-------------|---------------|-------------|--------------------|---------------|---------|
| BDCC — GDScript / system | MIT (root `LICENSE`) | — | Preserve copyright notice in copies or substantial portions | Yes, if copying code | **None** (MIT is permissive) | MIT covers everything committed to the repo with no separate per-directory exception found; contributor-submitted skins in `SkinsPartsByAuthor/` have **no per-directory license** — they fall under the root MIT by default, but this has not been confirmed with those contributors |
| BDCC — 3D art (meshes, textures, `.glb`/`.blend`/`.png`) | n/a | Implicit: root MIT (no separate art license file exists) | Same as code: preserve copyright notice | **Unclear — do not rely without confirmation** | None from BDCC itself | No separate asset license or CREDITS file exists anywhere in the repo. Art from named contributors (`SkinsPartsByAuthor/AverageAce/`, various named Skins/) is present with no individual attribution or sub-license. Whether those contributors understood their submissions as MIT when they PR'd is unverified. |
| MakeHuman — vendored CC0 subset | n/a (not shipping MH software) | CC0 1.0 Universal (as documented in `vendor/makehuman-cc0/README.md`, quoting upstream `LICENSE.md §C`) | None (CC0 = public domain dedication) | **Yes — cleanly** | **None** | Already vendored; NSFW geometry (genital targets/helpers) explicitly included; README documents per-file CC0 headers on mesh/proxy files. Eyebrow/lash mesh not from MH (authored in-repo). |
| FC-pregmod — vector/SVG body art | GNU GPLv3 (confirmed by multiple forks, web search consistent) | No separate asset license found; falls under project GPLv3 by default | If GPLv3 applies to art: copyleft obligation — any derived work shipping these assets must be GPLv3; source of art must be provided | **Not permitted for aeriea** | **HIGH — GPLv3 copyleft; would infect aeriea** | gitgud.io serves 403 to scrapers; repo not cloned locally. GPLv3 status confirmed by multiple forks/mirrors. Deepmurk vector art has no separate permissive license found. GPLv3 art in a commercial NSFW product creates irreconcilable copyleft conflicts. Even if GPLv3 were somehow acceptable, contributor provenance of community-submitted SVGs is unverified. |
| Kisekae 2 / Minna no Kisekae — dress-up art parts | Proprietary freeware (no open-source license) | All rights reserved — pochi (pochikou). SWF source redistribution explicitly prohibited. No grant for extraction or reuse in other products. | No redistribution, no modification, no commercial use | **Not permitted** | **n/a (proprietary, not copyleft)** | Official pochi.lix.jp page states verbatim: "ソースファイル(swfファイル)の改変・再配布・転載は禁止" (modification/redistribution/reposting of source SWF files is prohibited). No license grants asset extraction. Kisekae CH community site further prohibits copying/reproducing/distributing content without express written permission. |

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

---

## FC-pregmod assets

### What the project is

FC-pregmod (Free Cities pregmod) is an adult text game mod hosted on gitgud.io (`pregmodfan/fc-pregmod`). The visual component most relevant to aeriea is the **Deepmurk vector/SVG body art** — a set of 2D layered SVG images depicting character bodies with modular clothing, body-part overlays, and accessory layers, served as `.tw` (Twine) and `.svg` fragments. The Deepmurk vector sources are maintained in a separate sub-repo (`deepmurk/fc-deepmurk-vector`) on the same gitgud.io instance.

### License

**GNU General Public License v3 (GPLv3).** No local clone exists (not found under `~/git/`). The gitgud.io instance served HTTP 403 to all WebFetch attempts, so the license file text could not be read directly. However, the GPLv3 status is consistently confirmed by:

- Multiple forks and mirrors on gitgud.io each displaying "GNU General Public License v3.0" in the GitLab project sidebar.
- Web search results from 2023–2024 consistently describing the project as GPLv3.
- The original Free Cities (the upstream game this mods) was also GPLv3; pregmod carries that forward.

No separate permissive license was found for the Deepmurk vector art subdirectory. The `deepmurk/fc-deepmurk-vector` repository (also on gitgud.io, also 403-blocked) shows no indication of a separate license in any search result or crawlable snippet. The art falls under the project-wide GPLv3 by default.

### What GPLv3 means for art reuse

GPLv3 requires that any work that is a "covered work" (which includes distributing verbatim copies, or modified versions, of the GPLv3 material) must itself be released under GPLv3, with source available. Applied to art assets:

- Shipping FC-pregmod SVG/vector art in aeriea would make aeriea a distribution of covered GPLv3 material.
- GPLv3 section 5 requires that if you convey a covered work, the entire combined work must be licensed under GPLv3.
- For a commercial NSFW game, this is irreconcilable: aeriea cannot be simultaneously GPLv3 (which prohibits adding further restrictions) and commercially sold with proprietary components.
- Even for a free/open-source aeriea, the GPLv3 copyleft would propagate to the entire project.

Note: there is scholarly and community debate about whether GPL is even well-suited for art (the GPL FAQ and OpenGameArt discussions note ambiguity in what constitutes "source" for art). However, the absence of any permissive carve-out means the conservative default is that GPLv3 governs.

### Contributor provenance

The vector art is community-contributed across many merge requests (`!1887`, `!3285`, and others). No CLA, no CONTRIBUTORS file, no per-contributor sign-off is visible in any crawlable search result. Even if the project-wide GPL were somehow acceptable, the provenance of individual SVG contributions is unverified — an additional compounding risk.

### Bottom line — FC-pregmod vector art

| | Assessment |
|---|---|
| **Art (SVG/vector body art, Deepmurk)** | **Not permitted for aeriea.** GPLv3 copyleft would propagate; irreconcilable with commercial or proprietary use. No separate permissive license found for the art subdirectory. |
| **Commercial + NSFW** | GPLv3 does not prohibit commercial use per se, but requires releasing the entire combined work as GPLv3 with source — incompatible with aeriea's architecture. |
| **Verification still needed** | Direct read of `pregmodfan/fc-pregmod/LICENSE` and `deepmurk/fc-deepmurk-vector` root files (gitgud.io was inaccessible). If a local clone could be obtained, the exact license text and any per-directory exceptions should be read. The GPLv3 conclusion is high-confidence but technically based on multiple secondary corroborating sources rather than a direct file read. |

---

## Kisekae family assets

### What the project is

Kisekae 2 (also "Minna no Kisekae!" / "みんなの着せ替え！") is a Japanese Flash/SWF dress-up doll application by **pochi** (pochikou; `@pochikou_flash` on X/Twitter). It provides a set of 2D layered character parts — heads, bodies, hair, clothing, accessories — in a modular dress-up system. KKL (Kisekae Local) is a community-maintained offline port of the same SWF art by the Strip Poker Night at the Inventory (SPNati) community. Kisekae CH (`kisekae-ch.com`) is an unrelated community website built around the game.

There is no public source repository for the art assets. The application is distributed as a compiled SWF binary; the art parts are embedded within it.

### License / terms of use

**Proprietary freeware. All rights reserved. No redistribution grant exists.**

The official pochi page (`pochi.lix.jp/k_kisekae2.html`) states the following (retrieved 2026-06-21):

> **「ソースファイル(swfファイル)の改変・再配布・転載は禁止です。」**
>
> Translation: "Modification, redistribution, and reposting of source files (SWF files) is prohibited."

This explicitly prohibits:
1. Redistributing the SWF (which contains the art parts).
2. Modifying the SWF.
3. Reposting the SWF.

The same page states regarding images produced with the tool:

> **「画像の利用についての報告は不要で、著作権表記も不要です。」**
>
> Translation: "Reports on image usage are unnecessary, and copyright attribution is not required."

This is a limited grant for *screenshots/output images only* — it allows users to post images created with the tool without attribution. It is **not** a grant to extract, redistribute, or use the underlying art parts. The grant is for rendered output, not source assets.

The Kisekae CH community site (`kisekae-ch.com/terms-of-service/`) separately states:

> "You may not copy, reproduce, republish, upload, or distribute any Content without express written permission, except for personal, non-commercial use."

(This is a community site, not pochi's own page, but it reflects the same baseline: no redistribution without express permission.)

KKL is a port by the SPNati community with no new license grant from pochi — it redistributes the SWF art in a modified wrapper; the underlying pochi art terms are unchanged.

### What this means for extraction and reuse

- Extracting art parts from the Kisekae SWF and embedding them in aeriea is redistribution of pochi's proprietary assets.
- The SWF terms prohibit this explicitly ("再配布は禁止").
- No license grants reuse in another product, commercial or otherwise.
- There is no open-source release, no CC license, no permissive grant of any kind found.
- The tool is *freeware to use*, not *free as in freedom*. The art is pochi's intellectual property.

### Bottom line — Kisekae family assets

| | Assessment |
|---|---|
| **Art (dress-up parts from Kisekae 2 / KKL)** | **Not permitted.** Proprietary freeware. Explicit prohibition on SWF redistribution/modification. No license grant for extraction or reuse in another product. |
| **Commercial use** | Prohibited — no commercial license exists; default all-rights-reserved. |
| **Personal use / output images** | The pochi page grants permission to use *images produced with the tool* without attribution, for personal or non-commercial sharing. This does not extend to asset extraction. |
| **Verification status** | pochi.lix.jp page fetched and read directly (2026-06-21). The SWF prohibition is verbatim from the official page. No further confirmation needed — the answer is clear. |

---

## Verification still needed

1. **BDCC art / contributor-submitted assets:** The root MIT license nominally covers all repo files, but named contributors (`AverageAce`, and the authors behind `ArconSkin`, `ArticSkin`, `FerriSkin`, `KidlatSkin`, `LuxeSkin`, `LynxSkin`, `NovaSkin`, etc.) have no per-contribution sign-off, no CLA, and no CREDITS file. Before shipping any BDCC-originated art in aeriea, obtain confirmation from Alexofp (repo maintainer) that all merged contributions are MIT-licensed. The game's itch.io page or contributor guidelines may provide this — they were not checked here.

2. **MakeHuman upstream `LICENSE.md §C`:** The CC0 claim for vendored assets is documented in aeriea's own `vendor/makehuman-cc0/README.md`, which in turn cites the upstream `LICENSE.md`. If independent upstream verification is desired (versus trusting the vendored README), read `LICENSE.md §C` in the pinned `v1.3.0` tag of `makehumancommunity/makehuman`.

3. **BDCC `addons/bone_editor/`:** No LICENSE file found in `addons/bone_editor/` (only plugin files). If any of this addon code were reused in aeriea, its provenance would need to be traced — but it is an editor tool and unlikely to be a reuse target.

4. **FC-pregmod: direct LICENSE file read.** gitgud.io returned HTTP 403 for all direct fetch attempts; no local clone exists. The GPLv3 conclusion is high-confidence (multiple forks and mirrors consistently display GPLv3) but technically rests on secondary sources. If the conclusion is ever challenged, clone the repo locally and read `LICENSE` and `deepmurk/fc-deepmurk-vector`'s root to confirm no per-directory permissive carve-out exists. (This verification would not change the "not permitted" verdict unless a permissive carve-out is found — GPLv3 as the project license is not in doubt.)

---

## What is NOT a concern

- **MakeHuman AGPL:** Does not apply to the vendored CC0 assets. The AGPL governs the MakeHuman application, which is not shipped in aeriea.
- **DroidSans font (BDCC/Fonts/):** Apache 2.0, separate from the rest of BDCC. Not a visual-doll asset.
- **`gdunzip.gd` (MIT, Jelle Hermsen):** Utility, not art or doll system.
- **`addons/godot-notes/` (MIT, Roboweb):** Editor plugin, not shipped.
