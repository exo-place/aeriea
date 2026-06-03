# vendor/makehuman-cc0 — Minimal CC0 MakeHuman subset

These files are a minimal subset of the MakeHuman project, vendored here to
enable fetch-free, cross-platform regeneration of the aeriea body asset with
only Godot — no network access, no Nix required.

## License

All files in this directory are licensed under **CC0 1.0 Universal** (Public
Domain Dedication). MakeHuman's core base mesh and macro targets have been
explicitly CC0 since September 2020.

See: https://github.com/makehumancommunity/makehuman/blob/master/makehuman/data/3dobjs/README.md
and: https://www.makehumancommunity.org/wiki/License

## Source

- **Repository:** https://github.com/makehumancommunity/makehuman
- **Tag / revision:** `v1.3.0`
- **Pinned hash (nix fetchFromGitHub):** `sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=`

Only core CC0 bundled assets are included. No community-DB assets, no non-CC0
content. The full MakeHuman repository (~200 MB) is NOT vendored here.

## Vendored files (10 files, ~5.0 MB)

```
data/3dobjs/base.obj                                               (1.7 MB)  base mesh
data/targets/macrodetails/caucasian-female-old.target              (400 KB)  age_old blendshape
data/targets/macrodetails/caucasian-female-baby.target             (453 KB)  age_baby blendshape
data/targets/macrodetails/caucasian-female-child.target            (436 KB)  age_child blendshape
data/targets/macrodetails/caucasian-male-young.target              (388 KB)  gender_male blendshape
data/targets/macrodetails/universal-female-young-maxmuscle-averageweight.target   (135 KB)  muscle_max blendshape
data/targets/macrodetails/universal-female-young-averagemuscle-maxweight.target   (122 KB)  weight_max blendshape
data/targets/macrodetails/height/female-young-averagemuscle-averageweight-maxheight.target  (412 KB)  height_max blendshape
data/rigs/default.mhskel                                           (116 KB)  skeleton (bone tree + joint cubes)
data/rigs/default_weights.mhw                                      (898 KB)  per-vertex LBS skin weights (Slice 3)
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
