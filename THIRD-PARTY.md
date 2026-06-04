# Third-party assets & attributions

aeriea bundles and builds upon third-party data. This file records each source,
its license, and the attribution it requires. Keep it current whenever a pinned
external asset is added (see `docs/decisions/body-and-locomotion-slice.md`).

---

## Body mesh, morphs & skeleton — MakeHuman (CC0 1.0)

- **What:** the base mesh (`base.obj`), macro morph `.target` files, default
  skeleton (`default.mhskel`) and skin weights (`default_weights.mhw`) that the
  body pipeline (`tools/body_converter.gd`, `nix/body-assets.nix`) compiles into
  `assets/body/base_body.res` + rig; and the **modifier-definition JSON**
  (`data/modifiers/{modeling,measurement,bodyshapes}_modifiers.json` + their
  `*_sliders.json` UI trees and `*_modifiers_desc.json` tooltip maps) that the
  data-driven modifier registry (`scripts/body/modifier_registry.gd`,
  `tools/modifier_registry_build.gd`, `nix/modifier-registry.nix`) parses into
  `assets/body/modifier_registry.json` (Slice B,
  `docs/decisions/body-parameterization.md` §6).
- **Source:** MakeHuman — <https://github.com/makehumancommunity/makehuman>,
  tag `v1.3.0` (pinned `fetchFromGitHub` hash
  `sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=`). A minimal CC0 subset is
  vendored under `vendor/makehuman-cc0/` for fetch-free regeneration.
- **License:** **CC0 1.0 Universal** (Public Domain Dedication). MakeHuman's core
  base mesh and macro targets have been explicitly CC0 since September 2020. The
  pinned source's `LICENSE.md` §C explicitly lists "**Targets and modifiers**"
  among the CC0 bundled assets (full text in `LICENSE.ASSETS.md`), so the
  vendored modifier-definition JSON is CC0 alongside the mesh/targets. No
  attribution is legally required; recorded here for provenance.
- **Scope caveat:** only *core bundled* MakeHuman assets are CC0. Community-DB
  assets (user-contributed clothes/hair/morphs) are **not** uniformly CC0 and are
  out of scope.

---

## Locomotion motion-capture — Motion Matching (Slice 4)

The Motion-Matching feature DB (`assets/body/locomotion_mm.res`, built by
`tools/motion_ingest.gd` / `nix build .#motion-assets`) is derived from:

### 100STYLE — **CC BY 4.0** (SHIPPED)

> **The 100STYLE Dataset - Ian Mason**

- **What:** 60 fps BVH stylized locomotion. aeriea curates a locomotion subset
  (`Neutral`/`StartStop`/`March` styles × idle/walk/run/back/strafe/turn) and
  builds the MM feature database from it. A trimmed CC BY excerpt of the
  `Neutral` clips is vendored under `vendor/100style-cc-by/` for fetch-free regen.
- **Source:** Zenodo record **8127870**, DOI `10.1145/3522618`. `100STYLE.zip`,
  md5 `3cf627852fd8192024c04a8d0ef49583`
  (nix SRI `sha256-LDtAF/jiOX7mkEybn0NVHYtCbTndw1WNEh/unlXLLVg=`).
- **Authors:** Ian Mason (MIT), Sebastian Starke (Meta), Taku Komura (HKU) —
  *Real-Time Style Modelling of Human Locomotion via Feature-Wise Transformations
  and Local Motion Phases* (2022).
- **License:** **Creative Commons Attribution 4.0** — commercial use permitted
  with attribution. **Required attribution (ship this string):**
  *"The 100STYLE Dataset - Ian Mason"*.

### CMU Motion Capture Library — liberal CMU license (PINNED, ingest DEFERRED)

> **data from mocap.cs.cmu.edu, NSF EIA-0196217**

- **What:** the CMU Graphics Lab Motion Capture Database. Sourcing + pin are
  resolved; ingest is **deferred** because the available mirror ships Kaydara
  *binary* FBX and Godot has no runtime FBX parser (see the decision doc §3.4).
  It drops in at the same BVH ingest seam once a CMU BVH mirror / FBX→BVH step
  lands.
- **Source (pinned):** HuggingFace dataset `gbionics/cmu-fbx` @ commit
  `d18e9d3d14c08318eaa6c0602a6ead7fac40e58c` (derived from
  <http://mocap.cs.cmu.edu>).
- **License:** liberal CMU mocap license — free to copy, modify, redistribute,
  and use commercially; the raw database must **not** be resold directly.
  **Required attribution (ship this string):**
  *"data from mocap.cs.cmu.edu, NSF EIA-0196217"*. (Confirm the live FAQ wording
  at ship time; re-read the precise license text when CMU ingest is implemented.)

### Disqualified motion datasets (not used)

These were evaluated and **rejected** — their licenses are incompatible with
shipping a commercial product:

- **LAFAN1** (Ubisoft) — CC-BY-**NC**-ND (NonCommercial + NoDerivatives).
- **Bandai-Namco Research Motion** — CC-BY-**NC** (NonCommercial).
- **AMASS / ACCAD / SFU** and the **SMPL/AMASS** family — academic / research-only
  terms; commercial use requires separate licensing.
