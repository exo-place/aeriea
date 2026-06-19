# g-toy — a feasibility probe for the constrain-then-generate crux

Standalone R&D probe (NOT engine code, NOT Godot). Python 3 standard library
only. Lives under `experiments/`, outside the engine build; `python3` is provided
by the repo dev shell (`flake.nix`).

## What it tests

It probes the open core of the substrate architecture decided in
`docs/decisions/simulation-depth-and-materialization.md`:

> `G(seed, constraints, query) → answer` — a deterministic generator that returns
> a value consistent with **every** committed constraint, or correctly reports
> that no consistent completion exists (unsat), at **bounded cost**, while the
> committed constraint set only ever grows.

The sharp sub-problem is **painting into a corner**: as commitments accumulate,
`G` can reach a query with no consistent completion because an earlier greedy
draw foreclosed it. The prior-art map
(`docs/research/crux-prior-art-constraint-generation.md`) gives two load-bearing
claims this toy tries to reproduce or break:

1. **The locality lever** — corner-risk is driven by **GLOBAL** (instance-spanning)
   constraints, not **LOCAL** (within-entity / pairwise) ones.
2. **Incomplete but never wrong** — a correct-by-design solver detects unsat and
   never emits an inconsistent/approximate answer.

## What it actually is

- **Domain** (`g_toy.py:build_domain`): `N` people, each with attributes
  `birth_year`, `parent`, `trait`. A `global_fraction ∈ [0,1]` knob selects how
  many of three GLOBAL constraints are active (`round(global_fraction·3)`):
  - LOCAL: `parent_year_before_child` (a parent born strictly before its child by
    a gap) — relates an entity to ONE neighbor.
  - GLOBAL: `acyclic` family tree (all parent vars), `distinct_years`
    all-different / total temporal order (all birth-year vars), `trait_cardinality`
    "exactly K have trait 0" (all trait vars).
  - Year domain is scaled to `3N-1` so `distinct_years` has slack — this keeps the
    sweep measuring **locality**, not pigeonhole near-infeasibility from a tight
    value domain (see *Honesty notes*).
- **G** (`g_toy.py:assign_with_dbt`): a hand-rolled CSP solver using
  **dynamic backtracking (Ginsberg 1993)** — per-variable eliminating
  explanations, and on a dead end it backjumps to the most-recent *movable*
  culprit and revises only that, **keeping unrelated committed work** (it does NOT
  global-restart). Committed (observed) variables are immovable. Draw discipline
  is seeded and keyed per-variable, so value order is a pure function of
  `(seed, var)` — order-independent.
- **Observer loop** (`g_toy.py:observer_run`): a seeded random probe order over
  all `3N` attributes; each answered query **commits** (binds forever); the
  committed set grows monotonically.
- **Bounded cost**: each query has a per-query step budget (`max_steps`). Hitting
  it returns a `BUDGET` sentinel — a *measured corner that exceeded bounded cost*,
  reported, never fabricated. This is "incomplete, never wrong" extended to "and
  never silently over-budget."
- **Determinism** is asserted in code (`g_toy.py:check_determinism`): same seed ⇒
  identical commit log + identical stats; and the whole sweep is byte-for-byte
  reproducible across runs.

This is the CSP-under-determinism shape, over a *growing* committed set, exactly
as the crux doc poses it — at toy scale.

## How to run

```sh
nix develop --command python3 experiments/g-toy/run.py
# or, inside the dev shell, from this directory:
python3 run.py
```

Completes in well under a minute. Config (in `run.py:main`): `N=8`,
`global_fraction ∈ {0, 0.25, 0.5, 0.75, 1.0}`, 24 seeds per config, per-query
step budget 1500.

## Falsification criterion

- **In trouble:** cost-per-query blows up with committed-set size **even under
  mostly-local constraints** ⇒ the approach is in trouble.
- **Direction viable:** cost stays bounded under mostly-local constraints, and
  corner-rate / cost rise specifically as `global_fraction` increases ⇒ the
  locality lever is real and the direction is viable (at this scale).

A falsification is a valuable result; the verdict below reports which way the
**real** data points.

## RESULTS (measured, N=8, 24 seeds/config, budget=1500)

Determinism: **PASS** (same seed ⇒ identical commit log + stats, asserted in
code). Reproducibility: **PASS** (two independent full runs byte-identical).
Never-wrong consistency: **PASS** (every committed assignment satisfies every
constraint, all configs/seeds — independently re-checked in `run.py`).

**Table 1 — corner-rate & budget-exceeds vs `global_fraction`**

| global_frac | mean backjumps | median bj | max bj | seeds hitting budget |
|------------:|---------------:|----------:|-------:|---------------------:|
| 0.00        | 1.8            | 0.5       | 13     | 0 / 24               |
| 0.25        | 1.8            | 0.5       | 13     | 0 / 24               |
| 0.50        | 273.5          | 0.5       | 3918   | 6 / 24               |
| 0.75        | 273.5          | 0.5       | 3918   | 6 / 24               |
| 1.00        | 273.5          | 0.5       | 3918   | 6 / 24               |

**Table 2 — cost distribution (constraint-checks)**

| global_frac | median total | mean total | max total | max / query |
|------------:|-------------:|-----------:|----------:|------------:|
| 0.00        | 718          | 1141       | 5327      | 5159        |
| 0.25        | 742          | 1169       | 5402      | 5226        |
| 0.50        | 782          | 22145      | 289911    | 54296       |
| 0.75        | 782          | 22145      | 289911    | 54296       |
| 1.00        | 800          | 22273      | 290297    | 54296       |

**Table 3 — cost-per-query vs committed-set size (median checks/query)**

| global_frac | early (small committed set) | late (large committed set) | late/early |
|------------:|----------------------------:|---------------------------:|-----------:|
| 0.00        | 7                           | 7                          | 1.00       |
| 0.25        | 8                           | 8                          | 1.00       |
| 0.50–1.00   | 8                           | 8                          | 1.00       |

### Interpretation — VERDICT: locality lever VALIDATED (with a sharp caveat)

- **The local regime is cheap and flat.** At `global_fraction = 0` (and 0.25,
  which still rounds to zero active globals), **no seed** hits the budget,
  backjumps stay tiny (max 13), and cost-per-query does **not** grow with the
  committed-set size (late/early = 1.00×). The falsification criterion's
  "blows-up-even-when-local" branch is **NOT triggered**.
- **Turning on global constraints produces a heavy-tailed blowup.** The *median*
  query stays cheap at every `global_fraction` (median checks/query flat at ~8;
  median backjumps 0.5) — but the **tail** explodes: mean total checks jump from
  ~1.1k to ~22k, max total from ~5.3k to ~290k, and **6 of 24 seeds** paint into
  a corner and exceed the per-query step budget. Max backjumps rise from 13 to
  3918. Corner-risk rides the **global** constraints, exactly as the prior art
  predicted.
- **Net:** cost stays bounded under local-only constraints, and corner-rate/cost
  rise specifically with `global_fraction` ⇒ the **direction is viable IFF global
  constraints are kept few and bounded.** The residual heavy tail — rare seeds
  with catastrophic corners — **is** the crux's unsolved "painting into a corner"
  problem, reproduced in miniature.

## Honesty notes — what this does and does NOT establish

- **Does establish (at toy scale):** the locality lever is real here — local-only
  constraints are cheap and corner-free; global constraints introduce a
  heavy-tailed corner cost. Dynamic backtracking keeps the *median* case cheap.
  "Incomplete, never wrong" holds: every committed answer is consistent, and
  budget-exceeded queries are reported as such, never fabricated. The whole thing
  is deterministic and reproducible.
- **Does NOT establish:**
  - **Nothing about the unbounded-incremental regime** — the genuinely open
    residue (`crux-prior-art…md`: belief-revision history grows exponentially).
    This toy runs one finite world to completion; it does not test cost as the
    committed set grows *without bound* over a long-lived world.
  - **Tightness ≠ locality.** An earlier version used a tight year domain
    (`0..9`); its blowup was largely a **pigeonhole-tightness artifact** of the
    all-different constraint, not the locality lever. The year domain is now
    scaled to `3N-1` so the measured global cost reflects constraint *scope*, not
    near-infeasibility. (Tightness is a separate, real corner-driver — out of
    scope here.)
  - **Quantization:** with only 3 global constraints, `global_fraction` 0.5 and
    0.75 both activate 2 globals (`round`), so their rows are identical; 0.25
    rounds to 0 active globals. The 0 → global transition is what the data shows;
    finer granularity would need more global constraints.
  - **Scale.** `N=8` is a probe, not a benchmark. The blowup gets dramatically
    worse with `N` (informal probes: `N≥10` with globals on, individual seeds
    fail to complete within minutes) — consistent with the NP-hard-in-general
    floor, and a reason the budget cap exists.
  - **No claim about `G`'s real constraint language, query identity, commitment
    boundary, or multiplayer ordering** — all open per the crux doc; untouched
    here.

## Files

- `g_toy.py` — domain, the dynamic-backtracking `G`, observer loop, determinism
  check.
- `run.py` — sweep, metrics tables, consistency re-check, falsification verdict.
