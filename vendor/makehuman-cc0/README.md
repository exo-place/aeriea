# vendor/makehuman-cc0 — Minimal CC0 MakeHuman subset

These files are a minimal subset of the MakeHuman project, vendored here to
enable fetch-free, cross-platform regeneration of the aeriea body asset with
only Godot — no network access, no Nix required.

## License

All files in this directory are licensed under **CC0 1.0 Universal** (Public
Domain Dedication). MakeHuman's core base mesh and macro targets have been
explicitly CC0 since September 2020. The pinned source's `LICENSE.md` §C ("The
license for the bundled assets") explicitly enumerates "**Targets and
modifiers**" among the CC0 1.0 Universal bundled assets, with the full legal text
in `LICENSE.ASSETS.md` (verbatim first line: `# Creative Commons CC0 1.0
Universal`) — so the vendored `data/modifiers/*.json` (modifier definitions, UI
slider trees, and tooltip descriptions) are CC0 along with the mesh and targets.
The JSON files carry no per-file header (JSON has no comment syntax); their CC0
status is established by `LICENSE.md` §C as above.

See: https://github.com/makehumancommunity/makehuman/blob/master/makehuman/data/3dobjs/README.md
and: https://www.makehumancommunity.org/wiki/License

## Source

- **Repository:** https://github.com/makehumancommunity/makehuman
- **Tag / revision:** `v1.3.0`
- **Pinned hash (nix fetchFromGitHub):** `sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=`

Only core CC0 bundled assets are included. No community-DB assets, no non-CC0
content. The full MakeHuman repository (~200 MB) is NOT vendored here.

## Vendored files (mesh/rig + modifier-definition JSON)

Mesh, targets and rig (Slice 1 / Slice 3):

```
data/3dobjs/base.obj                                               (1.7 MB)  base mesh
data/targets/macrodetails/caucasian-female-old.target              (400 KB)  age_old blendshape
data/targets/macrodetails/caucasian-female-baby.target             (453 KB)  age_baby blendshape
data/targets/macrodetails/caucasian-female-child.target            (436 KB)  age_child blendshape
data/targets/macrodetails/caucasian-male-young.target              (388 KB)  gender_male blendshape
data/targets/macrodetails/universal-female-young-maxmuscle-averageweight.target   (135 KB)  muscle_max blendshape
data/targets/macrodetails/universal-female-young-averagemuscle-maxweight.target   (122 KB)  weight_max blendshape
data/targets/macrodetails/height/female-young-averagemuscle-averageweight-maxheight.target  (412 KB)  height_max blendshape
data/targets/macrodetails/proportions/female-young-averagemuscle-averageweight-idealproportions.target     proportions_ideal
data/targets/macrodetails/proportions/female-young-averagemuscle-averageweight-uncommonproportions.target  proportions_uncommon
data/targets/expression/units/caucasian/{eye,eyebrows,mouth}-*.target  (15 files)  facial-expression action units (see below)
data/rigs/default.mhskel                                           (116 KB)  skeleton (bone tree + joint cubes)
data/rigs/default_weights.mhw                                      (898 KB)  per-vertex LBS skin weights (Slice 3)
```

Proxy geometry — eyes / teeth / tongue / genitals (the *rigged, morph-following*
face/organ pieces built by `tools/body_proxy_build.gd`; see
`docs/decisions/body-parameterization.md` §11). The **teeth, tongue and genitals**
are NOT separate files — they are `helper-*` groups already inside `base.obj`
(above), so nothing extra is vendored for them. Only the **eye** proxy is a
standalone asset, plus the **genital detail-morph** targets. (**Eyebrows + eyelashes**
are NOT vendored from MakeHuman: the pinned v1.3.0 *core* ships no CC0 eyebrow mesh —
only `data/eyebrows/clear.thumb` + brow morph targets, the meshes being community-DB
assets without uniform CC0 — so aeriea AUTHORS its own brow/lash geometry in-repo
[`tools/body_proxy_build.gd` `_build_authored_face_hair`], which carries no
third-party licence; see §11.1.):

```
data/eyes/low-poly/low-poly.obj                  (6.6 KB)  eyeball proxy mesh (96 verts, UV'd)
data/eyes/low-poly/low-poly.mhclo                (1.3 KB)  eye→base-mesh fitting (single-index)
data/targets/genitals/penis-{circ,length,testicles}-{decr,incr}.target  (~13 KB)  genital detail morphs
```

Each of these carries an explicit per-file `# This asset was explicitly released as
CC0 in september 2020` header (mesh/mhclo) or is covered by `LICENSE.md` §C
("The base mesh and **proxies**", "**Targets**") for the targets — all CC0 1.0.
(The eyeball's *appearance* is no longer vendored: the prior CC0 `brown.mhmat` +
`brown_eye.png` iris texture were removed once the eye material became PROCEDURAL —
`assets/body/eye.gdshader`, iris/pupil/sclera computed analytically from the proxy
UVs — so the eye carries no third-party texture and the proxy build emits no PNG.)
Verified byte-identical to the pinned `v1.3.0` source by `cmp`. **NSFW caveat:** the
genital *targets* and *helper geometry* are vendored so the NSFW-first full-body goal
is served; the Layer-1 body gate (DESIGN.md / `body-parameterization.md` §5) is
unaffected — it guards the NSFW *verb* affordances on adult body-state, independent of
whether the genital mesh renders.

Facial-expression action units — the 15 CC0 FACS-like `.target` files under
`data/targets/expression/units/caucasian/` that `tools/body_converter.gd`
(`EXPR_BLENDSHAPES`) composes into the facial-expression blendshapes that drive the
`FaceRig` channels (`scripts/body/face/face_rig.gd`). These close the prior gap where
the head had the expression RIG but ZERO expression geometry. The caucasian race set
is used (the base mesh's own race anchor). Each is the same ASCII sparse-delta
`.target` format as the macro anchors, byte-identical to the pinned `v1.3.0` source
(verified by `cmp`), and explicitly CC0 (per-file `# This asset was explicitly
released as CC0 in september 2020` header + `LICENSE.md` §C "Targets"):

```
eye-{left,right}-closure.target          → EyesClosed   (full lid closure)
eye-{left,right}-slit.target             → EyesSexy     (narrowed fissure; approximated)
eyebrows-{left,right}-inner-up.target    → BrowsShy     (inner-brow raise, worry/shy)
eyebrows-{left,right}-down.target        → BrowsAngry   (brow lower/furrow)
mouth-open.target                        → MouthOpen    (jaw-drop mouth, lip geometry)
mouth-corner-puller.target               → MouthSmile   (zygomatic smile)
mouth-depression.target                  → MouthSad     (corner depressor frown)
mouth-{upward-retraction,eversion}.target→ MouthSnarl   (upper-lip raise + sneer)
mouth-{protusion,pursing}.target         → MouthBlep    (lip protrude+purse; approximated*)
```

`*` Approximations are honest: the CC0 unit set has no dedicated "sultry"/half-lidded
unit (the eye-slit AU is the closest) and no tongue-protrusion unit (a true blep needs
the tongue proxy, which has no expression target). The `MouthPanting`, `Talking`
(viseme detail), and `LookCross` channels have NO faithful CC0 AU and remain
geometry-uncovered (see `face_rig.gd` BLENDSHAPE COVERAGE).

Modifier-definition JSON (Slice B — the data-driven modifier registry,
`docs/decisions/body-parameterization.md` §6; parsed by
`scripts/body/modifier_registry.gd` into `assets/body/modifier_registry.json`).
These are `data/modifiers/` verbatim from the pinned source (~68 KB total). The
modifier JSON is fully vendorable even though the full 1,280-target detail set is
not — so the registry is complete from the subset; only the per-target *presence*
flags differ between the subset (detail targets absent → flagged "not present",
Slice C supplies them) and the full pinned tree (all present). Each is
byte-identical to its counterpart under `makehuman/data/modifiers/` in the pinned
`v1.3.0` source (verified by `cmp` against the `fetchFromGitHub` store path):

```
data/modifiers/modeling_modifiers.json        (17 KB)  head/face/torso/limb/breast/genitals/macro defs
data/modifiers/modeling_sliders.json          (27 KB)  modeling UI tab/group/label tree (+ macro sliders)
data/modifiers/modeling_modifiers_desc.json   (11 KB)  modeling tooltips
data/modifiers/measurement_modifiers.json     (1.5 KB) circumference/length measure defs
data/modifiers/measurement_sliders.json       (2.1 KB) measure UI tree
data/modifiers/measurement_modifiers_desc.json (1.0 KB) measure tooltips
data/modifiers/bodyshapes_modifiers.json       (1.2 KB) hormonal/silhouette bodyshape defs
data/modifiers/bodyshapes_sliders.json         (2.7 KB) bodyshapes UI tree
data/modifiers/bodyshapes_modifiers_desc.json  (3.4 KB) bodyshapes tooltips
```

`default_weights.mhw` (Slice 3) carries the MakeHuman default mesh's per-vertex
bone weights as plain JSON (`{ "weights": { bone: [[vertex_index, weight], ...] }}`).
Its own header declares CC0 ("Symmetric weights for default makehuman mesh",
(c) 2021 Data Collection AB). It is byte-identical to the file at
`makehuman/data/rigs/default_weights.mhw` in the pinned `v1.3.0` source archive
(verified by `cmp` against the `fetchFromGitHub` store path). The `.mhskel`
references it via its `weights_file` field; it is NOT embedded in the skeleton.

## Usage

`tools/body_converter.gd` automatically falls back to this vendored subset
when the `MAKEHUMAN_SRC` environment variable is unset:

```sh
# Fetch-free regen (uses vendored subset):
xvfb-run -a godot4 --path . res://tools/body_converter.tscn --quit-after 600

# Nix regen (fetches pinned source, sets MAKEHUMAN_SRC):
nix build .#body-assets
```

Both paths consume identical content (same v1.3.0 files) and produce a
byte-identical `assets/body/base_body.res`.

`tools/modifier_registry_build.gd` (Slice B) uses the same `MAKEHUMAN_SRC`
fallback to parse `data/modifiers/*.json` into the modifier registry manifest
`assets/body/modifier_registry.json`:

```sh
# Fetch-free regen (uses vendored subset):
xvfb-run -a godot4 --headless --path . res://tools/modifier_registry_build.tscn --quit-after 600

# Nix regen (fetches pinned source):
nix build .#modifier-registry
```

The committed manifest is the **vendored-subset** build (the fetch-free dev/test
path). The registry's 291 modifier entries are identical between the subset and
the full pinned tree; only the per-target `present` flags differ — subset: detail
targets flagged not-present (Slice C supplies them); full pinned tree: all 531
detail target files present. Both builds are byte-deterministic on rebuild.
