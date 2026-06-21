# substrate-consumer — the poison-detector for aeriea's synthesized core

Standalone R&D probe (NOT engine code, NOT Godot). Python 3 standard library
only (`fractions.Fraction` for all core rationals — **no float in core**).
Lives under `experiments/`, outside the engine build; `python3` is provided by
the repo dev shell (`flake.nix`).

This is the **empirical de-poisoning step** of design-it-twice for the substrate
core synthesized in `docs/decisions/substrate-core-design.md`. The design doc is
explicit that it is "a design output, not a decision" until a real consumer runs
against it (`substrate-foundations.md`: *poison is invisible from inside the
interface; only a real consumer reveals it*). This is that consumer.

A failure here is a **valuable finding** — poison the paper design could not see.
This probe found one (Stress #2). It is reported loudly, not hidden.

## What it tests

A minimal, runnable slice of the core algebra (`core.py`) — `Value` (rationals
via `Fraction`, serializable `AST` for behavior), `Fact`, `commit` (sole mutator,
append-only, commits effect + existence-of-cause), `query` (the
**`Sat | Incomplete | Unsat`** trichotomy — no-facade as a *type*), `materialize`
(the eager↔lazy slide as one continuous per-key budget knob; droppable pure
`Memo`), `draw` / `elapse` (the seeded generators — **content = f(seed, key,
committed CONE)**, NOT f(name)), `at` (time as a coordinate), `grant` (capability
attenuation), `replay` (bit-for-bit).

**Driving trace (the §5 hard case, `trace.py`):** a player carves a glyph into a
rock (`commit`), walks away, returns 3 in-game years later (`elapse` — ONE
coordinate jump, no per-tick), inspects it closely (`materialize`/`draw`
weathering detail, cone-constrained by the rock's adjacent committed flaws), with
ZERO facade. Depth weathers `4 → 15/4` by an exact-rational closed-form law in a
single coordinate jump; 3 unobserved years add **0** log rows.

## The three stress-tests (explicit pass/fail criteria)

Each can PASS, FAIL, or PARTIAL. Stress #1 reuses g-toy's CSP / dynamic-
backtracking / corner-rate machinery (`experiments/g-toy/g_toy.py`) directly —
its `global_fraction` knob is exactly the local-vs-global cone mix this needs.

1. **Cone-constrained draw/elapse: bounded-cost and corner-free?**
   PASS iff (a) cost-per-`draw` (cone facts touched) stays bounded — grows ~linearly,
   not super-linearly — as the committed *local* cone grows; (b) every local draw
   returns `Sat` (no false corner it painted itself into); (c) the local-only
   regime is corner-free (no budget-exceeds, tiny backjumps). The locality lever
   (global constraints, not local, drive corners) is reported as corroboration.

2. **Faithful coarsening as a theorem for `draw` (no-popping)?**
   Control: deepen budget with NO cone change → fine detail must contain the coarse
   glance as a prefix. Variant: glance, then `commit` something ADJACENT (grows the
   cone), then lean in → **assert the fine detail does not CONTRADICT the earlier
   glance** (a revealed microdetail value must not change). PASS iff control holds
   AND no seed pops after the adjacent commit. Tested on 5 seeds.

3. **Stable key across access paths + commitment boundary.**
   PASS iff (a) the glyph reached ≥2 ways mints the same key, and a generated
   sub-thing (microdetail, no obvious canonical descriptor) has a stable key; (b)
   deep inspection (draws only) adds 0 log rows; (c) a data-expressed commitment
   policy binds only load-bearing detail, transient glances add 0 rows — the
   boundary is livable.

## How to run

```sh
nix develop --command python3 experiments/substrate-consumer/run.py
# or, inside the dev shell, from this directory:
python3 run.py
```

Completes in a few seconds. Prints all measured numbers, a per-test verdict, and
the canonical `=== RESULTS: N passed, M failed ===` completion line (the repo's
anti-truncation marker convention). Exit code nonzero iff any check failed.

## RESULTS (measured — real output of `run.py`)

**Determinism / replay: PASS.** `state = f(seed, log)`: same seed+log → bit-
identical world digest (asserted via `world_digest`); `replay(log, seed)`
reproduces the world bit-for-bit; a different seed produces different drawn
content. Verified in code.

**§5 driving trace: PASS.** Carve = 2 committed rows (glyph + flaw setup); 3
unobserved years add 0 rows (nothing ticks); `elapse` weathers depth `4 → 15/4`
in one coordinate jump by an exact-rational closed-form law; the coarse glance
(budget=0, 1 fact) is a literal ordered prefix of the deep inspect (budget=4, 3
facts). Zero facade — every revealed fact is `f(seed, key, cone)`.

### Stress #1 — cone-constrained draw bounded-cost & corner-free? **PASS**

(A) cost-per-draw vs committed cone size (radius-1 local cone):

| cone_size | facts touched | draw Sat? |
|----------:|--------------:|:---------:|
| 0  | 6   | True |
| 1  | 8   | True |
| 2  | 10  | True |
| 4  | 14  | True |
| 8  | 22  | True |
| 16 | 38  | True |
| 32 | 70  | True |
| 64 | 134 | True |

Cost grows **linearly** (≈ `2·cone_size + 6`), not super-linearly; every local
draw is `Sat`. The §2 repair's bill is bounded **when the cone is kept local**.

(B) corner-rate vs local/global cone mix (g-toy sweep, N=8, 8 seeds):

| global_frac | mean backjumps | max backjumps | seeds hitting budget |
|------------:|---------------:|--------------:|---------------------:|
| 0.00 | 1.0   | 5   | 0 |
| 0.25 | 1.0   | 5   | 0 |
| 0.50 | 147.8 | 767 | 2 |
| 0.75 | 147.8 | 767 | 2 |
| 1.00 | 147.8 | 767 | 2 |

Local-only is cheap and corner-free; turning on **global** cone constraints
produces a heavy-tailed corner blowup (2/8 seeds paint into a budget-exceeding
corner). Corner-risk rides the *global* constraints, exactly as the prior art and
§6.1 predicted. **Verdict: bounded-cost and corner-free for local cones — PASS,
with the standing caveat that global cone constraints reintroduce the NP-hard
corner (fenced, not dissolved, per the design doc).**

### Stress #2 — faithful coarsening / no-popping for `draw`? **FAIL** (the central finding)

| seed | control prefix? | glance microdetail | lean-in microdetail | popped? |
|:----:|:---------------:|:-------------------|:--------------------|:-------:|
| `b'a'` | True | lichen=0, crack=F, pit=1 | lichen=2, crack=T, pit=7 | **YES** |
| `b'b'` | True | lichen=1, crack=F, pit=6 | lichen=3, crack=T, pit=7 | **YES** |
| `b'c'` | True | lichen=3, crack=F, pit=3 | lichen=3, crack=T, pit=4 | **YES** |
| `b'd'` | True | lichen=2, crack=T, pit=2 | lichen=2, crack=T, pit=1 | **YES** |
| `b'e'` | True | lichen=3, crack=T, pit=0 | lichen=2, crack=F, pit=2 | **YES** |

- **Control holds:** with NO cone change, deepening the budget yields the coarse
  glance as a strict prefix of the fine look (faithful coarsening is structural
  for ordered `query`/`materialize` evaluation, and re-deriving after dropping the
  Memo cache gives the identical result — purity confirmed).
- **The variant POPS on every one of 5 seeds.** After committing one ADJACENT
  flaw between the glance and the lean-in, the fine `draw` *contradicts* values
  the glance already revealed: `pit` flips (a → 1→7, c → 3→4, d → 2→1, e → 0→2),
  `lichen` changes (a → 0→2, b → 1→3, e → 3→2), `crack` flips (every seed).

**Root cause — a real poison the §2 repair carries:** `draw` is seeded by
`H(seed, key, cone-digest, salt)`. The cone-digest is **global to the whole
draw**, so *any* change to the cone re-rolls the *entire* RNG stream — including
microdetail dimensions (`pit`, `lichen`) that have **no causal dependence on the
newly-committed flaw**. Only `crack` legitimately depends on the adjacent flaw;
but because the seed is monolithic, committing the flaw also silently re-rolls
`pit` and `lichen`. The coarse glance is therefore **not a marginal of the fine
draw** once the cone grows — no-popping breaks at exactly the moment §6.2 warned
it would (cone-dependence in direct tension with no-popping).

**What it implies for the core (the single most important result):** the design's
`draw(key, cone, salt)` with a *single monolithic cone-digest seed* is poison. The
de-poisoned core must make each drawn dimension depend **only on the slice of the
cone it causally needs** — i.e. seed each dimension by a *per-dimension cone
projection*, not the whole-cone digest, so that committing a neighbor that touches
only `crack` cannot re-roll `pit`/`lichen`. Equivalently: a drawn value, once
revealed, must be a stable function of `(seed, key, the specific cone-facts that
value reads)`; the glance must commit-on-observe the values it showed, or the draw
must be *monotone in the cone* (growing the cone may ADD detail dimensions but must
not MUTATE already-revealed ones). The current spec does neither. **No-popping is
NOT a theorem for cone-constrained `draw` as specified.**

### Stress #3 — stable key across paths + commitment boundary. **PASS**

- Key reached 3 ways — direct scan, via the rock (region query), via the
  adjacency edge — all mint `g7`. Stable.
- The generated sub-thing (microdetail, no canonical descriptor) has a stable,
  derived key `('glyph_microdetail', 'g7', 3)` and is identical across two draws
  (same seed+cone).
- Deep inspection (draws only) adds **0** log rows — `materialize` returns
  droppable Memos, not commits. A data-expressed commitment policy bound exactly
  the 2 load-bearing rows (`glyph_depth`, `glyph_microdetail`); a subsequent
  transient glance added **0** rows. The boundary is livable at this scale.
  *(Caveat: this probe's policy is a flat relation allow-list; the harder
  "inspects a city → commits a city" explosion is not exercised here — log growth
  is bounded only because the inspected entity is a single glyph.)*

## Verdict summary

| Test | Result |
|------|:------:|
| Determinism / replay (bit-for-bit) | **PASS** |
| §5 driving trace (carve→elapse→inspect, zero facade) | **PASS** |
| #1 cone-constrained draw bounded-cost & corner-free (local) | **PASS** |
| #2 faithful coarsening / no-popping for `draw` | **FAIL** |
| #3 stable key across paths + commitment boundary | **PASS** |

**The de-poisoned core holds empirically on 4 of 5 axes — and breaks on the one
the design doc flagged as the sharpest tension (§6.2).** Cone-constrained `draw`
is deterministic, replayable, bounded-cost for local cones, and key-stable; but
its **no-popping promise is false as specified**, because a monolithic
cone-digest seed re-rolls causally-unrelated drawn dimensions whenever the cone
grows. This is the concrete, reproducible poison the paper design could not see.

## Honesty notes — what this does and does NOT establish

- **Establishes (at probe scale):** the §5 trace runs end-to-end through the real
  primitives; determinism + bit-for-bit replay hold; cost-per-draw is bounded for
  local cones; the corner-rate locality lever reproduces; keys are stable across
  paths; the commitment boundary is livable for a single entity; **and the
  no-popping property FAILS for cone-constrained `draw` under cone growth (5/5
  seeds), with an identified root cause (monolithic cone-digest seed).**
- **Does NOT establish:** multi-observer canonical commit order (assumed, not
  designed — untouched here); `elapse` for *path-dependent* evolution (only the
  closed-form weathering law is exercised; the NPC-3-years case is not);
  defeasible belief vs append-only facts; the unbounded-incremental regime
  (one finite world); the city-scale commitment-boundary explosion; the relational
  tax on continuous/heterogeneous physics. The Stress-#2 fix proposed above
  (per-dimension cone projection / commit-on-observe / cone-monotone draw) is a
  *direction inferred from the failure*, not validated here — validating it is the
  next probe.

## Files

- `core.py` — the core algebra slice: `Value`/`AST`, `Fact`, `commit`, `query`
  (trichotomy), `materialize` (Memo), `draw`/`elapse` (cone-constrained), `at`,
  `grant`, `replay`, `world_digest`.
- `trace.py` — the §5 driving trace (carve → walk away → elapse → inspect).
- `stress.py` — the three stress-tests + determinism check (reuses g-toy for #1).
- `run.py` — the runnable harness; prints measured numbers + the canonical
  `=== RESULTS ===` line.
