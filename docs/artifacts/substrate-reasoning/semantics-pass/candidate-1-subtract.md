# Operational Semantics — Candidate 1 (SUBTRACT / MINIMIZE)

> Design only. No code, no FEATURES.md change. One designer, one frame, committed hard.
> Frame: fewest moving parts. Dissolve runs / pause / stochastic / concurrency into a
> single primitive + author metadata + predicate + tree structure. Every "feature"
> below is the *absence* of a mechanism, not the addition of one.

---

## 0. The single primitive (and the dichotomies it deletes)

There is exactly **one stateful thing** and exactly **one acting thing**:

- **A part holds a flat author-keyed map of values.** (The "part tree" already exists;
  this map is the only state.)
- **A transition is a pure expression that recomputes one keyed value of one part each
  tick.**

That is the whole substrate. Everything the brief calls a special case is recovered as a
*pattern of keys + predicates + early-returns*, never a new primitive.

**Subtraction #1 — delete the property/metadata dichotomy.** There is no "property" type
distinct from "metadata." A part has one namespace: `key → value`. A key is "a property"
only in the colloquial sense that some expression rewrites it each tick; a key nobody
rewrites is "static metadata." The substrate makes **no distinction** and blesses neither
word. (I use "property" below to mean "a key a transition writes," purely for readability.)

**Subtraction #2 — delete the "combine" operator.** Same-property folding is not a second
mechanism; it is the ordinary in-place eval order applied to co-bound expressions (§3).

**Subtraction #3 — delete push.** An expression writes **only its own bound key on its own
part**. Cross-part effects are always **pull** (the affected part reads the source), never a
reach-out write (§3). This makes the writer-set of any key trivially knowable (it is exactly
the expressions bound to that key/part) and makes the fold purely local.

**Subtraction #4 — delete the "run" noun entirely.** A run is *nothing but a discriminator
string the author embeds in a key*. The substrate never groups discriminated keys, so it
never needs to know a run exists (§4).

No store, id, resolver, uid, run, cells, paths, driver, or progress-primitive is
introduced. The new-noun gate is passed by removing nouns, not adding them.

---

## 1. What a value may be; what a predicate may read

**A value** is drawn from a fixed, pure value domain: numbers, booleans, symbols/strings,
and finite tuples/records of these. **No references** (no stored part-handle, no pointer, no
closure) — you address another part by *predicate over its values*, never by holding it.
This is what keeps selection topology-independent: you cannot accidentally store a path.

**A predicate** is a pure, side-effect-free boolean expression. It may read:

- any key/value on parts within its evaluation scope;
- the **intrinsic 1-hop structure** of a part it has reached: its single parent, its direct
  children (and their values);
- nothing else. No global clock, no part outside scope except by traversal, no I/O.

"Time," "most recent," "provenance," "order" are **not** readable — they are author values
the author chose to stamp (e.g. an author-maintained counter written at an action). The
predicate reads those values like any other.

---

## 2. `select` — scope, return, ordering, determinism

`select(pred)` is the only reaching-out construct. (Traversal helpers `parent`,
`children`, and `nearest-ancestor(pred)` are sugar over it + 1-hop structure.)

- **Scope:** the entire part tree. Selection is by *content* (predicate over values), so it
  is **topology-independent** — never a fixed/relative path.
- **Return type:** an **ordered sequence of parts** (possibly empty). Always a sequence,
  never a set — because determinism needs a defined order and "one-of-several" needs
  first/last/nth.
- **Ordering rule:** the tree's **intrinsic structural order** = pre-order DFS, visiting a
  part before its children, siblings in **attachment order** (§5).
- **Determinism:** `select` is a pure function of current in-place state + structure. It
  uses **no seed**. Stochastic choice is layered *on top* by the author: `select(p).nth(
  seeded_draw(seed, salt, len))` — the draw is an ordinary seeded expression, not a
  property of `select`.

So "pick one matching part among many" is just `select(pred).first` / `.last` /
`.nth(seeded_draw(...))`. No uid, no resolver.

---

## 3. Expressions — inputs, writes, timing, order, the fold

**Bound target.** Every expression is bound to a `(part, key)` — the one value it
recomputes. It may instead be bound to a `(part, key-pattern)` (see §4) which instantiates
it once per matching discriminator.

**Inputs** (all read-only): the **current in-place value of its own bound key** (one input
among many, not special); values reachable via `select` / 1-hop structure; the **seed** (for
draws); author constants. No previous-tick buffer is ever an input — only what is currently
in place.

**What it may write:** *only its own bound key on its own part.* Returns the new value;
that is the entire write. (Subtraction #3.) Reaching another part is read-only.

**When it runs:** every expression evaluates **once per tick**. No scheduler, no subset
selection. "This run isn't advancing this tick" is expressed as the expression
**early-returning its current value unchanged** — that *is* pause and *is* a failed
probabilistic draw. Nothing is skipped at the substrate level; the no-op is authored.

**Evaluation order:** one deterministic total order over all bindings:

1. by the **structural order** of the bound part (§5),
2. then by the bound key's **author priority** (integer; lower first),
3. then by **authoring order** of the binding (registration order; a strict tie-break since
   two bindings can't register in the same step).

Mutation is **in place**. When an expression reads a value, it sees whatever is currently
there — already updated this tick if its writer ran earlier in the order, otherwise still
last tick's value. **One-tick lag emerges from order alone; no buffer, no snapshot.** The
author chooses immediate-vs-lagged purely by arranging priority/authoring order.

**The same-property fold (no separate operator).** When several expressions are bound to the
**same** `(part, key)`, they are simply consecutive in the eval order (same part, ordered by
priority then authoring order). They thread the value: the current in-place value `v0` feeds
expr₁ → `v1`; `v1` feeds expr₂ → `v2`; … `vn` is left in place. **Non-commutative** because
each consumes the previous output as its current-value input. **Priority override** =
authoring the integer that reorders that sequence. The fold is therefore *not a mechanism* —
it is §3's in-place eval order with nothing added. Distinct keys never fold; that absence of
collision is the only "isolation" the substrate provides — and it is enough (§4).

---

## 4. Where per-run progress lives — two out-of-step concurrent runs, no "run" noun

**Answer: per-run progress lives in ordinary keys whose name carries an author
discriminator. Two out-of-step runs = two discriminators = two independent values that, by
construction, never fold with each other. The substrate never groups them, so it never
learns a "run" exists.**

Concretely, split state into two authoring conventions:

- **Private (per-run) keys** carry a discriminator: `petrify/phase#<disc>`. Each run owns its
  own `phase` scalar under its own `<disc>`. Distinct discriminator ⇒ distinct key ⇒ the
  fold (§3) never mixes them ⇒ the two runs are out-of-step for free.
- **Shared (body) keys** carry no discriminator: `skin/material`. *Every* run contributes to
  it via a co-bound expression, so the visible body state is the **deterministic fold of all
  runs' contributions** (§3). Two runs both pull stone → the body's material is their fold.

**One authored expression covers unbounded runs.** Bind the advancing expression and the
body-contribution expression to a **key-pattern** `petrify/phase#*`. At each tick the binding
**instantiates once per discriminator actually present** in the part's map (discriminators
discovered by reading the keys, ordered deterministically by value). So the author writes one
"advance phase" expression and one "phase → material" expression; N present discriminators ⇒
N private advances + N contributions folding into shared `skin/material`. No noun, no slot
table, no cap.

**Where do discriminators come from?** From the **action that starts a run** (replay = seed +
action log). The starting action writes the initial `petrify/phase#<disc> = 0`, where
`<disc>` is supplied by the action (player/author choice) or `seeded_draw(seed,
action_index)`. The substrate mints nothing; the discriminator is logged input. This is the
one place the design touches "where new identity comes from," and it stays outside the
substrate (an action deposits a value).

**Honest seam:** an external minter still hands out the discriminator string. I claim this is
*not* a substrate id-primitive (the substrate stores it as opaque metadata and never
addresses by it), but it is the closest the design comes to one — flagged in §7.

---

## 5. Intrinsic structural order + tie-breaks

- A part attaches to its single parent at a position. **Sibling order = attachment order**:
  the deterministic order in which siblings were attached (action-log order of the attach
  action). This is intrinsic and deterministic, not an author-chosen uid.
- **Whole-tree order = pre-order DFS** (part before its children; siblings in attachment
  order).
- **Tie-breaks:** none needed among siblings — two parts cannot attach in the same log step,
  so attachment order is already a strict total order. Across the whole tree, DFS + that
  sibling order is total.
- Stochastic ordering (e.g. "a random matching part") is never a tie-break; it is an explicit
  authored seeded draw over the already-ordered `select` result (§2).

**Honest seam:** "attachment ordinal" is structural, but it is the one quantity the design
relies on that smells faintly id-like (§7).

---

## 6. Hard-case battery — PASS/FAIL

| # | Case | Verdict | Forced noun? |
|---|------|---------|--------------|
| 1 | Gradual transformation | **PASS** | none |
| 2 | Pause-most-recent | **PASS** | none (most-recent = author counter value) |
| 3 | Two concurrent out-of-step runs | **PASS** | none (discriminated keys) |
| 4 | Cross-part signal (hormone X→Y) | **PASS** | none (pull via `select`) |
| 5 | One-of-several selection | **PASS** | none (`select(p).first/nth`) |
| 6 | Non-standard / already-transformed body | **PASS** | none (predicate selection) |

**4 — cross-part signal.** Y's transition is `bound (Y, response)`; it
`select(produces_H)` (topology-independent), reads each producer's `H/conc`, and folds them
(deterministic structural order) into its own value. Pull, not push. Many producers → the
fold is over the `select` sequence. No edge, no noun.

**6 — non-standard / already-transformed.** Because selection is content-predicate (not
path), missing/extra/duplicated/pre-altered parts merely change *which* parts match. A
transition reads `current value` as an input, so applying it to an already-altered body just
composes from the present value. No path assumption to break. No noun.

---

## 7. Worked examples

### Case 1 — gradual transformation (petrification)

```
# static on each affected part:
petrify/rate            = 0.02      # author constant value

# private per-run key (one run here, disc = "r0"):
petrify/phase#r0        = 0.0       # written 0 by the start action

# expression bound to (part, petrify/phase#*)  -- instantiates per discriminator
advance(part, phase#disc):
    return clamp(self_current + petrify/rate, 0, 1)     # self_current = in-place phase

# expression bound to (part, skin/material), pattern-folded over discriminators:
contribute(part, skin/material):
    p = read(petrify/phase#disc)        # this instance's run
    return lerp(self_current, STONE, p) # folds into shared material with any other run
```

Each tick: every `phase#*` advances; each contributes into the single `skin/material`,
which is the fold across runs. "Progress" is never stored as a blessed thing — it *is*
`phase#disc`, an ordinary value.

### Case 2 — pause-most-recent

```
# each run stamps an author "recency" counter at its start action:
petrify/phase#r0  = 0.30 ; petrify/seq#r0 = 7
petrify/phase#r1  = 0.10 ; petrify/seq#r1 = 9    # most recent (max seq)

# the pausing ITEM writes only its OWN key (pull discipline):
# expression bound to (item, paused_disc):
choose_pause(item, paused_disc):
    runs = select(has_key 'petrify/seq#*')         # parts carrying run stamps
    return argmax_disc(runs, by = petrify/seq)     # discriminator with max seq -> "r1"

# advance() gains an early-return (this IS pause, no new mechanism):
advance(part, phase#disc):
    if exists(select(paused_disc == disc)):        # someone paused THIS run
        return self_current                        # unchanged -> no progress
    return clamp(self_current + petrify/rate, 0, 1)
```

"Most recent" is an author pattern (max of a stamped counter), pause is an early-return.
No `run`, no `time`, no scheduler.

### Case 3 — two out-of-step concurrent runs

```
# both runs live on the same target part, distinguished only by disc:
petrify/phase#r0 = 0.30
petrify/phase#r1 = 0.70        # out of step, started later / faster

# ONE authored advance() and ONE contribute() (from Case 1) instantiate per disc:
#   tick: phase#r0 -> 0.32 ,  phase#r1 -> 0.72     (independent: distinct keys never fold)
#   skin/material = fold( lerp(.,STONE,0.32), lerp(.,STONE,0.72) )   (shared: folds)
```

Per-run progress lives in `phase#r0` and `phase#r1`. The substrate sees two keys, folds
neither against the other, and never names a "run." Out-of-step is the default; keeping
them in step would be the thing requiring extra authoring.

---

## 8. Where this frame is thin (honest)

1. **Discriminator origin is a seam, not a mechanism.** Runs get their `<disc>` from the
   starting action (logged input or `seeded_draw`). I argue this stays outside the
   substrate (opaque metadata, never addressed-by), but it is the closest the design comes
   to an id-primitive. If a future requirement is "a transition *spawns* a sub-run from
   inside a tick with no action," I'd need a seeded deterministic discriminator generator —
   which edges toward a blessed minter. **Unsure this survives that stress; flagged.**

2. **Pull-only writes (Subtraction #3) trade authoring ergonomics for a clean fold.** Any
   genuinely push-shaped intent ("this event stamps 50 parts at once") must be re-expressed
   as 50 parts each pulling — correct and deterministic, but more verbose, and it forces a
   "pull"-shaped mental model onto authors who think in "apply effect to region." I believe
   the simplification is worth it (it is what makes the writer-set of every key knowable and
   the fold purely local), but it is a real usability cost and I'm **not certain authors
   will accept it** without sugar (a `broadcast` macro that compiles to per-target pulls).

Minor/contained: the **attachment-ordinal** (§5) is structural but faintly id-like — I'm
fairly confident it is fine since it is derived from action-log order and never
author-addressed, but noting it rather than hiding it.
