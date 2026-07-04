# Judge — Determinism & Replay Integrity (adversarial)

> Lens: determinism = deterministic EVAL ORDER over in-place mutation; NO previous-value
> buffer / NO whole-world snapshot / NO stored previous value; cycles resolve by order
> only; replay = seed + action log. Attack, not praise. Constructions cited inline.

---

## Candidate 1 — SUBTRACT — verdict: **FRAGILE** (fixable)

**Eval order claimed (§3):** `(structural order of bound part, author priority, authoring
order of binding)`. **Same-key fold (§3):** non-commutative threading of the in-place value.

### Worst finding — pattern-instance co-bound writers tie on the FULL tuple

The design's own crux feature breaks its own total order. §4 binds the body-contribution
expression to a **key-pattern** `contribute → skin/material`, which "instantiates once per
discriminator actually present." With two runs present (Case 1/3) this produces **N
co-bound writers to the *same* `(part, skin/material)` cell** — and all N instances descend
from **one** binding, so they share:

- the same bound part → same structural index,
- the same priority (one binding, one priority integer),
- the same authoring index (one registration).

They tie on **all three** components of the §3 tuple. The fold is explicitly
non-commutative (`lerp(self_current, STONE, p)` threads the previous output), so the
left-fold result **depends on the order of these tied instances** — an order §3 does not
define. §4 mentions instances are "discoverable by reading the keys, ordered
deterministically by value," but that clause is **not wired into §3's evaluation order**;
as written, the substrate's stated total order is **not total** for exactly the
construction the candidate built to showcase concurrency.

Construction: `petrify/phase#r0 = 0.30`, `petrify/phase#r1 = 0.70`, both feed `contribute`
into `skin/material`. Result = `fold(lerp(·,STONE,0.30), lerp(·,STONE,0.70))` — order-
dependent, order undefined by the order rule.

### Replay / snapshot / iteration

- **Snapshot:** clean. No previous-value buffer; `self_current` is read in-place. PASS.
- **Replay/discriminator origin:** SOUND **as scoped**. `<disc>` comes from the starting
  action (logged input) or `seeded_draw(seed, action_index)` — in the action log, not
  wall-clock. §8 honestly flags that a *mid-tick spawn with no action* would need a seeded
  minter; that case is out of the current design, so replay holds for what's specified.
- **Iteration:** instances iterated "by value" — deterministic IF canonical-value order is
  used; underspecified but not fatal.

**Fixable:** yes, cheaply. Append a **4th tie-break = canonical order over the discriminator
value** to the §3 tuple (or, better, forbid instance-multiplication and move plurality
inside one value à la C3/C4). Either closes the hole.

---

## Candidate 2 — INVERT — verdict: **SOUND** (determinism); stability caveat

**Eval order (§3/§5):** DFS pre-order by attachment index; within a part, authoring order.
Attachment index is unique per parent → **total over parts**; authoring order total within a
part. No instance-multiplication (one expression per carrier). The order **is total**.

### Snapshot / replay / iteration

- **Snapshot:** clean. `prog` lives on the carrier, read in-place; no buffer. PASS.
- **Replay:** SOUND. The carrier deposit is an external action (logged); `applied_seq` is
  the action-log counter; removal is a logged action. Reconstructs identically from
  seed + log. No wall-clock discriminator.
- **Iteration:** carriers are tree parts, walked by DFS — no hashmap iteration anywhere.
  PASS.

### Worst finding — concurrent *absolute* writers: who-wins is set by tree position

Determinism itself is intact (the fold has a defined order). The attack is **stability**:
the design admits (§"honesty", §weak-points) that two concurrent *absolute-value* writers
to `torso.size` resolve by **last-write-wins in eval order**, i.e. by the carriers' DFS
position. Construct: carriers `C_A`, `C_B` both `size := lerp(base,target,prog_i)`. Which
run's value survives is decided by attachment index. **Re-parent or re-slot a carrier
subtree** (an edit unrelated to either run) and the surviving run silently flips —
*deterministic on replay, but the same author intent yields a different body after a
structural edit.* This is a determinism-stability defect, not a nondeterminism. It is the
one-tick-lag-control attack in another dress: the outcome rides an index the author did not
mean to load-bear.

**Fixable:** yes — additive-delta-toward-cap authoring (the design's own prescription)
makes the fold commutative-in-effect and removes the dependence. Determinism never broke;
expressiveness + edit-stability is the cost.

---

## Candidate 3 — FOLD — verdict: **SOUND** (tuple genuinely total, with one pin)

**Tuple (§4.2):** `(host_preorder_index, priority, authoring_index)`.

### Totality attack — can two expressions tie on all three?

Constructed attempt: two expressions on the **same host** (same preorder index), **same
key**, **both default priority** → tie on (preorder, priority); broken by `authoring_index`.
To tie all three you need two distinct static expressions with **equal authoring_index** —
impossible **iff authoring_index is a GLOBAL monotonic registration order** (the doc's
§4.2.3 claim: "two distinct authored expressions have distinct authoring positions").

The pin: if any implementation makes `authoring_index` **per-key or per-part local** instead
of global, then two same-priority expressions on one part writing **different keys** A and B
both get local index 0 → they tie on the full tuple → their relative eval order is undefined
→ if A reads B, the lag edge is nondeterministic. So the tuple is total **only under a global
authoring_index**; pin it explicitly. As written (global reading) it **is total** — and
notably C3 **avoids C1's hole** by putting plurality *inside* a value (`morph` is a list,
mapped element-wise by ONE expression), so there is never an instance-multiplication tie.
This is the cleanest totality story of the four.

### Snapshot smuggling — the order-freeze (§4.1/§7.2)

C3 freezes the **shape and order of the expression set `E`** at tick start. Verdict:
**legitimate ordering, NOT a forbidden snapshot.** The certified invariant forbids a
previous-*value* buffer / whole-world *value* snapshot for replay; it does not forbid fixing
the evaluation order — *every* deterministic tick must fix an order, and C3 fixes order while
mutating values in place with no buffer (the §4.3 accumulator starts from the in-place
cell). Structural edits landing next tick is the correct consequence. Defensible; not the
worst.

### Replay / iteration

- **Iteration:** `morph` is a **list**, iterated positionally; appends are `old ++ [new]`.
  No hashmap. PASS.
- **Replay:** `disc`/`started` are author metadata seeded from the action; structural order
  derives from the log. Reconstructs identically.

### Worst finding — eval order leans on creation order via the sibling tie-break

§5/§9.1: when attachment positions collide (or a plan gives none), siblings break by
**action-log creation order**. This makes `host_preorder_index` — and thus the *entire* eval
order and every lag edge — **partly a function of build history, not geometry**. Two
"geometrically identical" bodies assembled in different log orders evaluate differently.
This is replay-deterministic (the log is blessed) but **fragile for author lag control under
tree edits**. Mitigation is in-design: C3 gives `priority` as an **edit-stable** lever that
overrides structural position, so an author who wants stable lag uses priority, not tree
placement. Honestly disclosed.

**Fixable / already-mitigated:** pin authoring_index global (spec tightening); steer lag
control to `priority`. The creation-order tie-break is actually the *correct* noun-free last
resort (see family rule below), not a flaw to remove.

---

## Candidate 4 — FLEX — verdict: **FRAGILE** (fixable)

**Cell order (§3):** `(structural-order(part), canonical-order(key))`; **fold within cell:**
`(priority, authoring-index)`. Structural order total over distinct parts; canonical order
over V total. Order is total **for a fixed contributor set** — and that qualifier is the
problem.

### Worst finding — write-by-selection (PUSH) makes the contributor set data-dependent

C4 alone permits `target = select(P)` (§3, §F.2): an expression writes **whichever parts
match a predicate**. This breaks the property C1/C3 rely on — that a cell's writers are
*exactly the expressions statically bound to it*, hence a statically knowable fold. Under
push, **which** expressions contribute to cell `(X,K)` depends on metadata that an
earlier-ordered cell mutated **this same tick**.

Construction: E1 `target = select(p.flag==true), key=K`; E2 sets `X.flag=true`. Whether E1
writes `X.K` depends on whether E2's cell ran before `X.K`'s cell. C4 rescues determinism
with the rule "contributor membership and order are resolved against in-place state at the
instant that cell's fold runs, in the global cell order" — which IS deterministic, but the
design itself flags it as subtle, and it means the fold's contributor set is not knowable
without simulating the tick. Determinism survives; **predictability and the static-writer-set
guarantee do not.** FRAGILE, not BROKEN.

### Iteration determinism — the latent FATAL

Per-run progress is an **opaque map** `tf_progress = { discA: …, discB: … }`, iterated in
"the canonical total order over V" (§1.2, §4). This is fine **only if** the canonical order
is computed from value structure (type-tag then lexicographic) and the map is **never**
realized as a native hashmap iterated by hash/insertion order. If an implementer reaches for
the language's default map and iterates it natively, run-to-run/engine-to-engine iteration
order diverges → **replay FATAL**. The design mandates canonical order (so it's sound on
paper) but this is the single place a careless implementation silently breaks replay. §F.1
correctly names canonical-V-order as load-bearing.

### Snapshot / replay

- **Snapshot:** clean — `current` and map entries read in-place, no buffer. PASS.
- **Replay discriminator:** author values / seeds from the action; no wall-clock. SOUND
  provided canonical iteration holds.

**Fixable:** yes — (a) drop push, go **pull-only**, restoring statically-knowable writer
sets and removing the data-dependent contributor membership; (b) mandate canonical-V-order
iteration and forbid native hashmap traversal. Both are local fixes.

---

## Family rule 1 — the cleanest TOTAL-ORDER tie-break (no blessed id)

Derive purely from structure + metadata + authoring order, in this lexicographic order:

1. **`host_preorder_index`** — pre-order DFS of the body tree; **siblings by attachment
   position**; if positions collide or are absent, **action-log attach order** (the
   replay-blessed last resort — no noun, fully reconstructible). Recomputed each tick, never
   stored.
2. **`priority`** — optional author-metadata integer, default neutral. The author's
   **edit-stable** lever for immediate-vs-lagged; nothing else touches lag.
3. **`authoring_index`** — **GLOBAL** monotonic registration order over distinct static
   expressions. *This alone is already a strict total order* over static expressions, so
   collisions are impossible **iff it is global** — pin that explicitly (C3's claim only
   holds globally; per-key-local reintroduces ties).

**The decisive structural rule that closes C1's hole:** plurality (concurrent runs) MUST live
**inside a single value** (list/map) advanced by **one** expression that iterates entries by
**canonical order over V**, never as multiple co-bound expression-instances sharing one
binding. Then steps 1–3 never tie, and the only per-entry ordering — canonical-V-order —
lives *inside* one expression's deterministic fold, where it cannot collide with another
expression. (C1 violates this with key-pattern instancing; C3/C4 obey it.) If instancing is
kept, a **4th key = canonical order over the instantiating discriminator value** is mandatory.

Map/set iteration anywhere: **canonical total order over V only**; lists iterate
positionally. Native hashmap/hash-order iteration is forbidden (replay-fatal).

## Family rule 2 — where the discriminator comes from on replay

Every per-run discriminator must originate **inside the seeded timeline**, one of exactly two
ways:

- a **literal value carried by an action** in the log (player/author choice); or
- `seeded_draw(seed, <deterministic coordinate>)` where the coordinate is itself already
  deterministic — `action_index` for action-spawned runs, or
  `(host_preorder_index, authoring_index, canonical-entry-order)` for a run spawned by a
  transition mid-tick.

**Forbidden (FATAL):** any discriminator minted from wall-clock, native RNG outside the seed,
pointer/hashmap address, or a tick-local counter not derived from the seed. With this rule a
seeded probabilistic TF reproduces (the draw is `seeded_draw` over logged coordinates), and a
mid-tick sub-run spawn — C1's flagged stress case — reconstructs identically, because its
discriminator is a pure function of seed + already-deterministic structural coordinates, all
present on replay.

---

### Scoreboard

| Cand | Verdict | Worst determinism finding | Fixable |
|------|---------|----------------------------|---------|
| 1 SUBTRACT | FRAGILE | pattern-instance co-bound writers to `skin/material` tie on the full §3 tuple; non-commutative fold result undefined by the stated order | yes — 4th key = canonical disc order, or no instancing |
| 2 INVERT | SOUND | concurrent absolute-writer "winner" set by carrier DFS position → tree edit silently flips outcome (stability, not nondeterminism) | yes — delta-toward-cap authoring; determinism never broke |
| 3 FOLD | SOUND | eval order leans on action-log creation order for sibling ties → lag fragile under tree edits | mitigated in-design (priority lever); pin authoring_index global |
| 4 FLEX | FRAGILE | push/write-by-selection makes a cell's contributor set depend on same-tick mutations; opaque-map iteration FATAL if ever a native hashmap | yes — pull-only + mandated canonical iteration |
