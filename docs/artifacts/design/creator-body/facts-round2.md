# Facts — round 2 ground truth (creator-body)

Resolves four contested facts where SYNTHESIS.md, attack-round2.md, and redteam-fidelity.md
disagree. Each verdict is checked against CURRENT HEAD source/assets. No code changed, no design.

Pin = `/nix/store/f17xilfqj8v2xphny6qfy4xvp8pzg4mi-source/makehuman` (MakeHuman v1.3.0,
sha pinned in `vendor/makehuman-cc0/README.md:26-27`).

---

## Q1 — Higher-poly CC0 eye asset: does one exist in the pin? — **TRUE (but NOT vendored)**

Both prior artifacts are partly wrong. redteam-fidelity was right that a 1064-vert CC0 eye
exists; attack-round2 was right that it is NOT in `vendor/`. The truth combines both:

- **In the pin, a high-poly eye exists.** `data/eyes/high-poly/high-poly.obj`:
  **1064 verts** (`grep -c '^v '` = 1064), **1020 faces**. Plus `high-poly.mhclo` (fitting)
  and `high-poly.thumb`. The pin's `data/eyes/` also has `low-poly/` (96 verts), `materials/`
  (`brown.mhmat`, `brown_eye.png` 1024² iris), and `clear.thumb`.
- **License: CC0.** Pin `license.txt` §C ("The license for the bundled assets") lists "The
  base mesh and **proxies**" and "**Clothes (any MHCLO-based asset)**" as CC0 1.0 Universal.
  The high-poly eye is an MHCLO-based proxy → covered. §D additionally disclaims any output.
- **NOT in the vendored tree.** `vendor/makehuman-cc0/data/eyes/` contains ONLY `low-poly/`
  (`low-poly.obj` = 96 verts for both eyes combined, `low-poly.mhclo`). `find vendor -iname
  '*eye*'` returns only the low-poly obj/mhclo + expression targets. README:65 declares the
  vendored eyeball as "96 verts, UV'd" and README:73-76 says the iris PNG was deliberately
  removed when the eye went procedural. The high-poly variant was simply never vendored.

**Verdict:** A usable higher-resolution CC0 eye (1064 verts, MHCLO proxy, CC0 §C) DOES exist
in the pinned source — no authoring/subdivision needed. It must be **re-vendored** (Nix-fetch
or copy from pin), not generated. attack-round2's "must be sourced or authored from scratch"
is FALSE; redteam-fidelity's "1064-vert high-poly exists, no need to author" is TRUE, with the
caveat (which redteam stated for the iris and applies equally here) that it needs re-vendoring.

Cite: `/nix/store/f17xilfqj8v2xphny6qfy4xvp8pzg4mi-source/makehuman/data/eyes/high-poly/high-poly.obj`
(1064 v / 1020 f); pin `license.txt` §C; `vendor/makehuman-cc0/README.md:65`;
`vendor/makehuman-cc0/data/eyes/low-poly/low-poly.obj` (96 v).

---

## Q2 — `decompose_drag` output type / mirror space — **TRUE (modifier-space)**

- `decompose_drag` (`scripts/body/morph_drag.gd:320-372`) returns `out: Dictionary` of
  `{full_name: value_delta}` — modifier registry full_names → SCALAR value deltas
  (`:369-371`, `vd := clamped - cur; out[full_name] = vd`). It clamps each modifier's
  *value* against its registry range (`:368`). No per-vertex 3D displacement anywhere.
- The sculpt apply path consumes exactly that: `character_creator.gd:460-471` reads
  `deltas[full_name]` as a scalar and adds it to `_body_state.modifiers[full_name]`. Geometry
  is reconstructed wholesale later from the weight vector in `bake_morphed_normals`.

**Consequence confirmed:** a sculpt-mirror must apply the mirrored SCALAR to the l-/r- paired
MODIFIER (modifier-space / registry-twin mirror). There is no per-vertex displacement to
"x-reflect at a mirror-vertex index" — that data does not exist in the drag path.
attack-round2 B1 is correct; the SYNTHESIS §1.3 "negate Δx at the x-mirrored anchor vertex"
mechanism operates on data the pipeline never produces.

Cite: `scripts/body/morph_drag.gd:319,361-372`; `scripts/body/character_creator.gd:460-471`.

---

## Q3 — Shared-vertex apportionment for the no-monster bound — **FALSE (no apportionment; pure sum)**

There is NO existing normalization or apportionment. Morph deltas simply accumulate per
render vertex:

- Per-modifier VALUE is clamped to its range only (`body_state.gd` `_project_modifiers`
  ~:554/:563). No cumulative bound.
- Application is pure addition: `detail_library.gd:104` —
  `morphed[ri] = morphed[ri] + Vector3(dx,dy,dz) * weight`; called per-target additively from
  `bake_morphed_normals` (`body_state.gd:673-676`), and blend-shape axes accumulate the same
  way (`body_state.gd:664-665`, `morphed[vi] = morphed[vi] + dv[vi] * w`).
- Multiple overlapping region morphs touching one base/render vertex SUM with no combined
  clamp anywhere. Matches `body-reverify.md:26-40` ("CONFIRMED unbounded").

**Verdict:** today, deltas just sum; there is no contribution-apportionment. A per-vertex
total-displacement budget WOULD need an apportionment rule, because each shared vertex is
written by many targets/regions and nothing today divides a shared vertex's budget among its
contributors. attack-round2 M1's apportionment gap is real.

Cite: `scripts/body/detail_library.gd:104`; `scripts/body/body_state.gd:664-665,673-676`;
`docs/artifacts/diagnosis/body-reverify.md:26-40`.

---

## Q4 — Is there a pregnancy SIMULATION? — **FALSE (~0% sim; one morph slider only)**

`grep -rln -i pregnan scripts/` returns exactly ONE file:
`scripts/body/region_sliders.gd:57` —
`["stomach/stomach-pregnant-decr|incr", "belly", "flat", "round"]` — a slider label/axis
binding, not a simulation. No `gestation|trimester|progression` state anywhere
(`grep -iE 'gestation|trimester' scripts/` empty). No second writer, no time-progression, no
pregnancy state object.

**Verdict:** pregnancy is ~0% built as a sim. A creator "belly fullness" control would drive
the `stomach-pregnant` MORPH directly (with a cap) — there is no sim to integrate with.
attack-round2 B3 is correct; SYNTHESIS §2's "additive write channel `at_rest_belly +
sim_pregnancy`" is a contract with a counterparty that does not exist.

Cite: `scripts/body/region_sliders.gd:57` (sole pregnancy reference in scripts/).
