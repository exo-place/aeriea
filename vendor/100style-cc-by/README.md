# vendor/100style-cc-by — trimmed 100STYLE locomotion excerpt (CC BY 4.0)

A small, trimmed excerpt of the **100STYLE** motion-capture dataset, vendored so
the Motion-Matching feature DB (`assets/body/locomotion_mm.res`) can be
regenerated fetch-free with only Godot — no 1.5 GB download, no Nix required.

## Attribution (required by CC BY 4.0)

> **The 100STYLE Dataset - Ian Mason**

Authors: Ian Mason (MIT), Sebastian Starke (Meta), Taku Komura (HKU) — *Real-Time
Style Modelling of Human Locomotion via Feature-Wise Transformations and Local
Motion Phases* (2022).

## License

**Creative Commons Attribution 4.0 International (CC BY 4.0).** Commercial use is
permitted with attribution. See <https://creativecommons.org/licenses/by/4.0/>.

## Source & pin

- **Repository:** Zenodo record **8127870** — <https://zenodo.org/records/8127870>
- **DOI:** `10.1145/3522618`
- **Archive:** `100STYLE.zip`, md5 `3cf627852fd8192024c04a8d0ef49583`
  (nix SRI `sha256-LDtAF/jiOX7mkEybn0NVHYtCbTndw1WNEh/unlXLLVg=`)

## Vendored files (trimmed)

`100STYLE/Neutral_{ID,FW,FR,TR1}.bvh` — the Neutral style's idle / forward-walk /
forward-run / turn clips, **trimmed to the first 1200 frames** each (the full
clips are 2k–8k frames). These are an *excerpt* of the CC BY dataset, not the raw
1.5 GB archive — analogous to the vendored MakeHuman CC0 subset.

## Regeneration

```sh
# Fetch-free regen (uses this trimmed vendored subset):
godot4 --headless --path . res://tools/motion_ingest.tscn --quit-after 12000

# Production regen (fetches the pinned FULL 100STYLE, curates Neutral/StartStop/
# March, builds the richer committed DB — this is the byte-deterministic
# canonical regen path that produced the committed locomotion_mm.res):
nix build .#motion-assets
```

The committed `assets/body/locomotion_mm.res` is the **nix-built** DB from the
full pinned dataset (byte-identical on rebuild). The fetch-free vendored path
produces a smaller DB from this 4-clip excerpt for offline dev / CI smoke tests.
