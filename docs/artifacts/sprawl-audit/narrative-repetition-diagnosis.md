# TF Audit narrative repetition — root-cause diagnosis

Read-only investigation. No code changed. All claims verified against the cited source.

## Symptom

Staged-TF cards in the audit read cheap/repetitive:
- "Her breasts fill further with milk." ×4, then "grow heavy" ×4 (milk).
- "Her barrel fills out, growing longer and heavier beneath her." ×4 (identical every stage).
- "Her breasts swell from a C cup to a D cup." → "…D to F" → "…F to G" → "…G to H" (one per stage).
- Spreading: "Her left hind leg hardens into a chitin shell." → right hind → left fore → right fore → barrel (one part per line).

## The verified mechanism, end to end

### 1. The model chops a continuous quantity into N equal discrete stages

A staged TF is `{staged:true, stage_seconds, max_stages:N, ops:[…]}`. The holder fires it stage by stage on the sim clock:

- `tf_holder.gd:89-103` `_drain_due` — `while next_stage < max_stages and clock >= due: apply_stage(…); next_stage += 1; due += stage_seconds`.
- `tf_applier.gd:96-118` `apply_stage` — each stage rolls its op deltas once and writes them.

So gradual change is literally **N arbitrary equal samples of a continuous process**. The TF records:

- `lactation_production` (`tf_content.gd:269-279`): `max_stages:8`, each stage `fluid_delta` `milk += roll(40..70)` mL into capacity.
- `grow_breasts` (`tf_content.gd:310-319`): `max_stages:4`, each stage `prop_delta` `volume_ml += roll(120..240)`.
- `graft_quadruped_lower_staged` (`tf_content.gd:170-195`): `max_stages:5`; stage 0 grafts the barrel, stages 1-4 each `prop_delta` `barrel.length_cm += roll(3..8)`.
- `set_lower_material_chitin` (`tf_content.gd:113-129`): `max_stages:5`, **`one_op_per_stage:true`** — exactly ONE segment hardens per clock step (legs lowest-first, then barrel). `set_covering_fur_upward` (`136-150`) is the same pattern for fur.

The continuous quantity (milk amount, breast volume, barrel length) and the spreading boundary (which segment is chitin yet) are both represented only as "how many of N stages have fired."

### 2. The audit captures one snapshot per stage and narrates each gap

`tools/tf_audit.gd:206-223` `_run_staged`: snapshot the body, then `for i in stages: advance_time(step); snaps.append(dup_state(body))`, then `describe_progression(snaps)`. One body snapshot per stage boundary.

### 3. `describe_progression` narrates every consecutive gap atomically — zero temporal aggregation

`tf_describe.gd:906-913`:
```
for i in range(1, snapshots.size()):
    for s in describe_transition(snapshots[i-1], snapshots[i], std):
        lines.append(s)
```
It simply concatenates one-stage diffs. There is **no run-collapse**: a run of identical or same-kind deltas across stages is never merged into one paced line.

### 4. Each single-stage `describe_transition` emits one template line per delta/part

- **Milk** — `_emit_fluids` (`1464-1502`): bands on *current* fill pct — `<0.6` → "fill further", `0.6-1.0` → "grow heavy", `>=1.0` → "swell full and tight". The comment at `1489-1490` is an explicit attempt to "vary … rather than the same line repeated", but with only 3 bands and 8 small stages, many stages land in the same band ⇒ "fill further" ×4, "grow heavy" ×4.
- **Breast volume** — `_breast_size_line` (`1443-1460`): if the cup letter changed, "swell from {a} cup to {b} cup", else "grow fuller and heavier". Each 120-240 mL stage happens to cross one cup boundary ⇒ C→D, D→F, F→G, G→H, one per stage.
- **Barrel** — `_emit_size` (`1357-1367`): a single hard-coded string with **no band/magnitude variation at all** ⇒ identical every stage.
- **Chitin / fur** — `_emit_material` (`1179-1207`) / `_emit_covering` (`1221-1251`): groups changed segments by `from>to`; if it touches the trunk **or `segs.size() >= 3`** it emits one body-wide line, else one per segment via `_part_label` (`956-962`, which reads "left hind leg" off the id suffix).

### 5. The spatial aggregation the describer HAS is defeated by the discretization

This is the crux. `_emit_material` already collapses ≥3 same-change segments into "across her whole frame" (`1203-1204`). But `one_op_per_stage:true` means each stage's diff contains **exactly one** changed segment, so `segs.size()` is always 1 — the ≥3 threshold never trips, and it always falls to the per-segment branch (`1205-1207`). The aggregation logic is present and correct; the staging splits the five parts across five separate snapshot-diffs so it has nothing to aggregate. The per-part "left hind → right hind → …" sprawl is **manufactured by the model's one-part-per-stage sampling**, then faithfully rendered.

## Proximate vs. root cause

- **Proximate cause (describer):** `describe_progression` narrates each discrete stage/part delta independently with a fixed template and performs **no temporal run-aggregation**. The within-stage spatial aggregation that does exist is bypassed because each stage carries only one changed part.
- **Root cause (model):** continuous/spreading change is represented as **N discrete equal stages** (`max_stages` × per-stage delta / `one_op_per_stage`). The narration is faithfully rendering arbitrary sample points of a process whose continuity was discarded at the model layer. The repetition is over-discretization, not bad prose.

## Relation to the deferred dynamical-transformation model

`docs/decisions/dynamical-transformation.md` (Not green, design-only) models gradual change as **one driven transition** `{from, to, progress ∈ [0,1]}`, `value(T) = interpolate(from, to, progress(T))` (§2, lines 79-96). §2.1 (line 117) explicitly names "staged `prop_delta` growth over N ticks" as the special case it subsumes — "the smooth law the staircase approximated." Under it, milk-fill / breast-growth / barrel-growth are each **one** transition, narratable once with net magnitude and pacing ("her breasts swell from a C to an H cup over the afternoon"), not 4-8 stage lines. So the cheap repetition is a direct symptom of still using discrete staging instead of the continuous-progress model.

## What each fix layer would and wouldn't solve (the honest layered view)

**Describer aggregation alone (no model change) CAN fix the visible repetition.** Two moves, both implementable in `describe_progression`/`describe_transition`:
- *Temporal run-collapse*: detect a monotone run of same-kind deltas across snapshots and emit once with net magnitude/pacing. Trivially, narrating `describe_transition(snaps[0], snaps[-1])` instead of every gap already collapses milk to one banded line, breast C→H to one "swell from C to H cup", and — crucially — feeds all five chitin segments into ONE diff, which then trips the existing `segs.size() >= 3` branch and reads "chitin spreads across her lower body." Much of the cheapness is thus removable without touching the model.
- This works because the snapshots still carry the net before/after; the describer can re-aggregate them.

**But describer aggregation is reconstruction, not representation.** To collapse correctly the describer must *re-infer* the continuous transition from discrete samples — guess that 4 same-kind deltas are one process vs. genuinely distinct events, reconstitute magnitude and pacing — re-deriving exactly what the dynamical model stores natively as `from`/`to`/`progress`. It is fragile (heuristic run-detection over erased structure) and it cannot recover what was never sampled.

**What ONLY the continuous-transition model can give:** pacing/timing as a first-class narratable property ("over the afternoon", "quickly then slowing as it nears full" from a saturating progress), driver-driven reversal, and the honest fact that this is ONE change of a known magnitude rather than N. The audit also amplifies the symptom by deliberately snapshotting per stage (`_run_staged`, to show "frame by frame") — under the dynamical model there are no stages to over-sample.

**Verdict: both layers, with the model as root.** The describer has a real temporal-aggregation gap and a spatial-aggregation path that the staging defeats — fixing it would genuinely improve the current output. But that is treating the symptom: the root is that the model over-discretizes a continuous process into arbitrary equal stages, and the describer is faithfully rendering the samples. A describer fix is a reconstruction patch over erased continuity; the dynamical-transformation model removes the discretization at the source. Recommend not framing this as "just fix the describer."
