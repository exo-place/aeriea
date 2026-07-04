# Adversarial Hard-Case Judgment — Body/Transformation Substrate Semantics

> Lens: break the claimed PASSes. Every candidate self-reported all-PASS (C2
> admits case-3 partial). This judgment constructs the concrete metadata+expression
> input that moves a PASS to CONDITIONAL/FAIL, or confirms it holds.
> Source designs: `candidate-{1-subtract,2-invert,3-fold,4-flex}.md`.
> Certified floor: `docs/decisions/body-transformation-substrate.md` —
> the load-bearing constraints the attacks exploit are **no previous-state buffer /
> no snapshot**, **eval-order-only lag**, **single value per property + non-commutative
> fold**, **no blessed run/uid/progress noun**.

---

## The two structural levers every attack turns on

1. **Where per-run state lives, and whether the visible property is a RECOMPUTE
   from that store or a BAKE into the shared cell.** A store that the visible
   property recomputes from *every tick* survives run-removal (recompute drops it);
   a contribution *baked* (folded/accumulated) into the shared cell cannot be
   un-baked without a pre-image. This single distinction decides cases 3 and 6.

2. **Priority is intra-part in ALL FOUR.** Every candidate's eval-order tuple is
   `(structural-index-of-part, priority, authoring-index)` (C1 §3; C2 §3; C3 §4.2;
   C4 §3 cell sort = `(structural-order(part), key)` then intra-cell `(priority,
   authoring)`). So **priority can never reorder two different parts** — cross-part
   immediacy is governed by structural order ALONE. This decides case 4.

---

## CASE 3 stress — two runs writing the SAME shared property as ABSOLUTE values

**Breaking construction.** Two petrification runs on one target. Each wants to set
`skin/hardness` to an *absolute* value from its own phase (not an additive delta):
run A → `hardness := SH * phaseA` (=0.32·SH), run B → `hardness := SH * phaseB`
(=0.72·SH). The property holds ONE value. Stronger variant: "render the hardness of
the run with the latest `started`, ignore the other" — a reconciliation that needs
**simultaneous access to both runs' (started, phase)**.

- **C2 — CONFIRMED FAIL (self-admitted, verified).** The carrier writes the target
  property directly; the same-property fold threads `current`, so two absolute
  writers resolve **last-write-wins** and run A's contribution is erased from the
  visible `size`. The body holds *zero* per-run fields (the frame's thesis), so there
  is **no separate store to recompute from** — the only escape is rewriting as
  additive-delta-toward-a-shared-cap, which is not absolute-value authoring. **Worse
  on removal:** the accumulated delta is baked into `size`; removing carrier B leaves
  its contribution permanently (no recompute source on the body). FAIL for
  absolute-value; CONDITIONAL (additive-delta-toward-cap only).

- **C1 — DOWNGRADE to CONDITIONAL.** Per-run progress survives in discriminated
  *keys* (`phase#r0`, `phase#r1`) — good, removal of a disc drops its `contribute`
  instance. BUT C1's reconciliation of N runs into `skin/material` is the
  **per-disc-instantiated `contribute` + same-property fold**: each `contribute`
  instance reads only *its own* `phase#disc` and the opaque running folded value
  (§4). It therefore covers only **fold-composable** reconciliations
  (`max(current, mine)`, sequential `lerp`, sum). The breaking input —
  argmax-by-`started` absolute render — needs one expression reading **all**
  `phase#*` and `started#*` together; C1 gestures at "discover discriminators by
  reading keys" but never formalizes *read-keys-by-pattern-inside-one-expression*
  (its `read(key)` is single-key; §3's input list omits sibling keys entirely except
  via that `read`). Until that affordance is blessed, C1 is **strictly weaker than a
  whole-container reconciliation** for simultaneous-all-run cases. CONDITIONAL.

- **C3 — HOLD PASS (strongest, tie).** `morph` is a list; the visible property is an
  explicit `tail_length := base_len + f(morph)` where `f` reads the **whole list**.
  The absolute/argmax reconciliation is `f = argmax(morph, .started).p`, with full
  simultaneous access to every run's state, **recomputed from scratch each tick**. No
  information is destroyed; the conflict is *relocated to `f`* but `f` sees everything,
  so the relocation is a genuine resolution, not a loss. HOLD.

- **C4 — HOLD PASS (strongest, tie; marginally ahead on re-identification).**
  `tf_progress` is a discriminator-keyed map; `mapOverEntries` / a fold over the map
  gives the same whole-container reconciliation as C3, **and the run's identity IS
  its map key** (stable across rewrites without scanning a `disc` field). HOLD.

**Verdict on the "does discriminated metadata escape, or relocate?" question:** It
escapes *only when the visible property is a pure recompute over a store that holds
ALL live runs simultaneously* (C3 list, C4 map). It **relocates and can lose** when
the store is per-run-isolated and recombined through the threaded same-property fold
(C1's per-disc instantiation; C2's carrier writes). C3/C4 truly escape; C1 partially;
C2 does not.

### CASE 3 stress — a THIRD run mid-flight; unbounded runs — slot table?

**No candidate needs a slot table.** C1: a third discriminator = a third key, the
pattern binding instantiates over it. C3: append a third list element. C4: a third
map key. C2: attach a third carrier part (ticked by the same DFS walk). All four
rely instead on **discriminator/element/carrier minting from the action log** — the
universal seam. C1 §8 flags it most honestly: if a transition must *spawn* a sub-run
mid-tick with no action, a seeded deterministic minter edges toward a blessed
id-primitive. C2's variant of the seam is sharper: a third run is fine only if it
deposits an **on-tree** carrier; a not-yet-attached causer (item in inventory) would
need a substrate registry = a blessed noun (C2's whole frame is load-bearing here).

---

## CASE 6 stress — already-transformed body, causer CONSUMED, author wants REVERSE

**Breaking construction.** Body petrified by run X (`skin/hardness = 0.9`). X's item
is consumed → X's bookkeeping (disc key / list element / map entry / carrier) is
gone. Author now wants to **un-petrify back to the original skin**. The certified
floor forbids a snapshot and any previous-value buffer. So the pre-image must be
**ordinary metadata deposited at apply-time, surviving the run's death** — or it is
unrecoverable.

- **C2 — CONFIRMED CONDITIONAL (self-admitted).** Carrier is gone → the recompute
  source died with it → the pre-image must have been written onto the **body**
  (`size_base`) at apply-time. "Body stores zero per-run fields" holds for *progress*,
  **fails for reversal data**.

- **C1 — DOWNGRADE to CONDITIONAL.** Discriminated keys die with the run; `contribute`
  lerps `self_current → STONE` and stores **no base**. To reverse it needs a
  non-discriminated body key holding the pre-image — **the same deposit C2 admits,
  unmentioned in C1.** Passes for *re-application onto* an altered body (predicate
  selection handles that); **secretly needs the base deposit for reversal.**

- **C4 — DOWNGRADE to CONDITIONAL.** `tf_progress` survives on the body, but C4's
  *worked* style (case 1: `current + rate`) **bakes into `current`** — an accumulator
  that cannot reverse after the entry is dropped. C4 *can* adopt recompute-from-base
  (`visible := f(base, tf_progress)`) but never demonstrates it; reversal still needs
  the pre-image deposited. Same secret need as C1.

- **C3 — HOLD (the one architecture that resolves it natively).** C3's visible
  property is already `base_len + f(morph)` — a **pure recompute from base + live
  runs**. Drop a run's list element → recompute → the value falls correctly. Reversal
  is *free*. The only requirement is that `base_len` be **per-body metadata captured
  at apply-time** (not a hardcoded constant) so a non-standard/already-transformed
  body reverses to *its* pre-image. C3 already treats base as a term, so this is a
  data-capture discipline, not an architectural change.

**Do C1/C3/C4 secretly need the same as C2? YES — all four need a pre-image deposited
as body metadata at apply-time.** The difference is architectural readiness: C3 is
built to consume it; C1/C4 must add it against an accumulator/per-disc-die style; C2
admits it explicitly.

---

## CASE 2 stress — recency ties and already-paused most-recent

**Breaking construction A (same-tick tie).** Two runs start on the same tick. If the
author stamps **game-tick/time** as the recency key, both get the same value →
`argmax` over runs ties. All four break the tie by iteration/structural/authoring
order → **deterministic but arbitrary** (not necessarily the run the player means).
**Resolution (universal, no noun):** stamp **action-index** (monotonic per action in
the log, never ties) as recency, not tick-time. C1 `seq`, C2 `applied_seq`, C3/C4
`started` must all be action-index. With that discipline, **all HOLD PASS**;
tick-time stamping is a latent authoring footgun, not a substrate failure.

**Breaking construction B (most-recent already paused).** "Pause the most recent
run" when argmax-recency *is already paused*: re-setting `paused:true` is a no-op and
the next-most-recent **active** run keeps running — the player's action does nothing
visible. **Resolution:** `argmax(filter(unpaused), recency)`. All four can express
filter-then-argmax. HOLD, conditional on the author filtering. Deterministic either
way; an authoring subtlety, not a break.

---

## CASE 4 stress — cross-part read of a value mutated the SAME tick by the source

**Breaking construction.** Skin part `S` must read gland `G`'s **this-tick** hormone
(forced immediate). But `G` is a child gland *deeper* in DFS than `S` (anatomy fixes
this). Pre-order DFS visits `S` before `G` → `S` reads `G`'s **stale** (last-tick)
value. Certified says lag is controlled "by choosing the order" — but **priority is
intra-part in all four**, so no priority value can move `S` after `G`. The *only*
lever is **tree placement** (re-root the gland earlier), which may contradict anatomy.

- **All four — DOWNGRADE to CONDITIONAL** for *forced-immediate-against-DFS*: immediate
  coupling is achievable only along DFS direction or by restructuring the tree; the
  named knob (priority) is inert across parts. Case 4 as literally stated (lag
  acceptable) holds; the stress (forced immediate against DFS) does not.

- **C3 — additionally dinged: its worked example is WRONG.** §case-4 claims "raise
  `pigment`'s priority so it sorts before `hormone_out`" to flip the lag — but
  `pigment` (on S) and `hormone_out` (on G) are different parts; priority is the
  **2nd** tuple element after `host_preorder_index`, so it cannot reorder them. C3
  names a lever that does not work for the cross-part case it is illustrating. The lag
  *is* achievable (by which part is structurally earlier) but **not** via the knob C3
  cites.

---

## CASE 5 stress — metadata-identical candidates, no distinguishing field

**Breaking construction.** Several fingers, byte-identical metadata, pick exactly one
deterministically with no uid. **All four HOLD PASS:** `select` returns parts in
**intrinsic structural order** (attachment position differs even when metadata is
identical), so `.first()` / `.nth(seededDraw)` picks deterministically. No uid needed.

**Stress — durably track that one across ticks while siblings change.** With no
stampable mark, the structural index is unstable (add/remove a sibling → index shifts
→ track the wrong finger). Substrate-honest answer: **stamp a distinguishing mark**
(`chosen_mark = seed`), re-find by `select(p => p.chosen_mark == seed)` — now it has a
field you created. All four support this; all four (C1 §7, C3 §7.3, C4 §5) admit it is
a **hand-rolled uid-by-convention**. HOLD, with the confirmed cost that durable
identity of an indistinguishable part requires creating a distinguishing mark. C3 §5
most honestly flags the residual: where attachment positions *collide*, determinism
falls back to action-log creation order, so two "geometrically identical" bodies built
in different orders can pick differently.

---

## Per-candidate survival table

| Case | C1 subtract | C2 invert | C3 fold | C4 flex |
|---|---|---|---|---|
| 1 gradual | HOLD | HOLD | HOLD | HOLD (accumulator style) |
| 2 pause-most-recent | HOLD\* | HOLD\* | HOLD\* | HOLD\* |
| 3 two out-of-step | **COND** (per-disc fold; no all-run read) | **FAIL/COND** (last-write-wins; additive-only) | **HOLD (strongest)** | **HOLD (strongest)** |
| 4 cross-part signal | **COND** (against-DFS) | **COND** (against-DFS) | **COND + wrong example** | **COND** (push doesn't escape) |
| 5 one-of-several | HOLD | HOLD | HOLD | HOLD |
| 6 reverse-after-consume | **COND** (needs unmentioned base) | **COND** (self-admitted) | **HOLD (native recompute)** | **COND** (accumulator; needs base) |

\* conditional on action-index recency to avoid same-tick argmax ties.

---

## The single HARDEST case for the family + noun-free resolution

**Case 6 reversal-after-consumption is hardest** — it collides head-on with the
*certified* "no previous-state buffer, no whole-world snapshot" invariant. The
substrate **structurally cannot** recover a pre-image; even the winner (C3) cannot
reverse a body whose pre-image was never captured. (Case 4 forced-immediate-against-DFS
is the runner-up shared limitation — unfixable by any author pattern, only by tree
placement — but it degrades gracefully to a one-tick lag; reversal degrades to
*impossible*.)

**Resolution — a discipline, not a new noun:**

1. **At apply-time, the external action deposits the affected property's CURRENT value
   as ordinary body metadata** (a per-run-discriminated `*_base` key if each run wants
   its own restore point). This is exactly the certified "external system writes onto
   both entities" — the body-side write is the pre-image. The action log already
   carries it; no history/version/snapshot noun is blessed.
2. **Author every visible property as a PURE RECOMPUTE from `(base + live run-states)`,
   never as a baked accumulator.** Removing any run's state and recomputing then
   reverses it *for free*. The accumulator style (C2 deltas, C4 `current+rate`) is the
   trap that makes reversal impossible; the recompute-from-base style (C3's
   `base + f(morph)`) is the discipline that makes it free.

Both steps are ordinary metadata + ordinary expressions — no new substrate primitive.

---

## Strongest case-3 / case-6 handling

- **Case 3: C4 (marginally) and C3 (tied).** Both give a whole-container store with
  simultaneous access to all runs and recompute-from-scratch; C4's **discriminator-keyed
  map** makes the run's identity its map key (native re-identification, no scan), edging
  out C3's positional list. C1 is weaker (per-disc fold can't do simultaneous-all-run
  reconciliations without an unformalized read-by-pattern); C2 fails for absolute writes.
- **Case 6: C3, decisively.** Its native `base + f(live runs)` recompute shape resolves
  reversal with no architectural change — only the discipline of capturing `base` as
  per-body metadata. C1/C4 must bolt the base deposit onto accumulator/per-disc-die
  styles; C2 loses the recompute source when the carrier dies.

**Overall on the case-3 + case-6 PAIR: C3 is strongest**, because its single shape
(pure recompute from base + a whole-run store) solves both absolute-reconciliation and
reversal at once. C4 ties on case 3 alone.
