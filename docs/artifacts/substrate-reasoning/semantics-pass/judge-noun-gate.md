# Adversarial Judge — the NEW-NOUN GATE

> Single lens: the substrate must bless NOTHING semantic. Allowed: uninterpreted
> author metadata + predicates + part-tree (1-hop + predicate-guided traversal) +
> authoring order. Rich values allowed ONLY if the substrate treats them as fully
> opaque — **no structure it interprets**. I attack; a candidate scores by
> surviving, not by sounding good.

The decisive fault line that separates these four is one question the gate forces:
**what must the substrate interpret to keep per-run plurality deterministic?**
Three answers are on offer — parse the *key name* (C1), order *values* (C4),
iterate *list position* (C3) — and a fourth that relocates the question off the
target entirely (C2). The container shape is not a detail; it is the whole game.

---

## C1 — SUBTRACT — verdict: **FATAL**

**Most damaging finding.** The per-run carrier is a discriminator embedded in the
**key name** (`petrify/phase#<disc>`), and the advancing expression binds to a
**key-pattern** `petrify/phase#*` that "instantiates once per discriminator
actually present in the part's map (discriminators discovered by reading the keys,
ordered deterministically by value)" (§4). That single sentence smuggles **three**
blessed operations:

1. **Lexical key-parsing.** To match `phase#*` and extract the wildcard, the
   substrate must treat `#` as a blessed delimiter and destructure every key into
   `(stem, discriminator)`. Keys are metadata; the gate's opacity clause forbids
   the substrate interpreting metadata *structure*. A delimiter it parses is
   interpretation.
2. **A grouping/registry.** "Instantiate once per discriminator present" is
   precisely **grouping keys by stem** to build a per-stem discriminator set — a
   registry the substrate constructs and iterates. This directly contradicts C1's
   own load-bearing claim: "The substrate never groups discriminated keys, so it
   never needs to know a run exists" (§4). The `#*` binding *is* that grouping.
3. **A value-order.** "ordered deterministically by value" — C1 *also* needs the
   canonical-value-order that it nowhere admits to (the C4 problem), to enumerate
   discriminators stably.

C1 thus carries BOTH the key-parser AND the value-comparator. The self-reported
near-misses (minter for in-tick spawn; attachment ordinal) are real but *secondary*
— the spawn-minter is only forced because the disc must be a unique addressable
**key**, which is itself a consequence of the fatal key-name choice.

**Fixable without abandoning the core idea?** No. The core idea *is* "plurality in
the key name so distinct keys never fold." Removing the key-parser means moving
plurality into the value — which is C3 or C4. The fix abandons the subtraction.

---

## C2 — INVERT — verdict: **CLEAN (contingent)**

**Most damaging finding.** This is not a smuggled noun — it is a **contingency**.
C2 is genuinely clean on the literal gate: the carrier is an ordinary part on the
tree, reached by the same DFS walk as anatomy; `role:"carrier"` is metadata the
substrate never reads; progress is ordinary keys on an ordinary part; no
value-order, no key-parse, no minter, no registry. The substrate blesses nothing.
That makes it the cleanest of the four **as written**.

But the cleanliness is purchased entirely by the move "carrier = part in the
anatomical tree," and C2 admits (§weak-point-1) that if that deposit is disallowed
— carriers must not pollute anatomy — the only alternative is a substrate
**registry** of off-tree carriers, which is FATAL. So C2's gate-pass is *conditional
on a design choice the gate itself does not grant*. Second, C2 does not actually
**answer** the container question: for two *absolute-value* out-of-step runs the
fold is last-write-wins and one run is erased (C2's own honesty note), forcing
per-run state back onto the **target** — at which point C2 must adopt a list or map
container and inherits the C3/C4 question it claimed to dissolve. It relocates the
container decision, it does not retire it.

**Fixable?** Yes, trivially, *within* the gate's allowance that carriers may be
parts: keep carriers-on-tree; for absolute-value concurrency use a list-valued
target key (the C3 shape). The core inversion survives.

---

## C3 — FOLD — verdict: **VENIAL**

**Most damaging finding.** §4.1 **freezes the expression set `E`** (the shape and
order, not the values) at tick start, so structural writes land next tick. This is
a per-tick **held order-structure** — a critic's "snapshot." I press it and it
holds: the certified ban is on *previous-VALUE* buffers/whole-world snapshots that
would make replay depend on stored value-state; `E` is order, not value, it is
transient (one tick), and replay is still `seed + log` with `E` re-derived each
tick. It blesses an *evaluation discipline*, not a noun. Genuine spend, not a
smuggle. The sibling tie-break leaning on action-log order (§5) is **shared by C1,
C2 and C4** verbatim and rides the already-blessed log — venial, and unfair to pin
on C3 alone just because C3 disclosed it.

Decisively, C3's container — **one list element per run** — needs **no
value-comparator** anywhere: a list carries intrinsic positional order, so
iteration is left-to-right by authoring position; cell/key sort is by *authoring*
order (§4.1), not value order; selection order is structural. C3 is the only
candidate that never compares two arbitrary values. It also handles **in-tick
spawn** with no minter: starting a run appends an author-constructed element
(`old ++ [new]`), the disc an inert author field — the exact case that is fatal for
C1.

**Fixable?** The venial freeze is fine as-is; if challenged, state it as the rule
"structural writes take effect next tick" without materializing `E`. Core idea
untouched.

---

## C4 — FLEX — verdict: **VENIAL, leaning FATAL**

**Most damaging finding.** The **canonical total order over V** (§1.2, §F.1). C4
needs it to (a) iterate opaque maps/sets deterministically and (b) sort cells by
`(structural-order(part), canonical-order(key))` (§3). To totally-order arbitrary
values the substrate must **recurse into nested maps/sets/tuples and compare their
internals**. That is the substrate interpreting value *structure* — the precise
thing the opacity clause forbids ("no structure it interprets"). C4's defense ("it
carries no *semantics* — never means time or rank") misreads the gate: the gate
bars interpreting *structure*, not only meaning. A comparator that destructures a
value to order it interprets structure regardless of whether the result is called
"rank." Worse, C4 made it load-bearing even in the scalar case by sorting **keys**
(which are values in V) by canonical order — where C1/C3 sort keys by *authoring*
order and need no comparator. So C4 leans on the value-noun hardest and most
gratuitously. (Write-by-selection's data-dependent contributor set, §F.2, is a
determinism-clarity cost, not a noun.)

**Fixable without abandoning the discriminated map?** Yes: iterate the map by
author **insertion/authoring order** (an ordered association list) and sort
keys/cells by authoring order. That deletes the value-comparator. But note what the
fix *is*: it demotes the map to an ordered list-of-pairs — i.e. it concedes the
container point to **C3**.

---

## Ranking by noun-gate cleanliness (cleanest first)

1. **C2 (INVERT)** — blesses literally nothing; cleanest as written. Demoted from
   an outright win only because its pass is *contingent* on carriers-as-parts and
   it *punts* the container question rather than answering it.
2. **C3 (FOLD)** — one venial spend (per-tick order-freeze); the only candidate
   with **zero value-comparator** and a minter-free in-tick spawn. Cleanest among
   the candidates that actually commit a per-run container.
3. **C4 (FLEX)** — discriminated map is sound in spirit but, as written, forces a
   canonical total order over V that breaks the opacity clause; fixable only by
   converging on C3's ordered iteration.
4. **C1 (SUBTRACT)** — strictly worst: the only candidate forcing the substrate to
   interpret the **lexical structure of keys**, plus a stem-grouping registry it
   denies, plus a value-order. Carries every other candidate's worst noun at once.

---

## Container-shape call (the key sub-decision)

Among the three committed shapes — **key-name discriminator suffix [C1]**,
**list elements [C3]**, **discriminated map [C4]** — the cleanest under the gate is
**C3's list elements**, decisively.

A **list carries its own positional order**, so deterministic iteration of
concurrent runs needs *nothing the substrate must interpret*: not a key-name parser
(C1's `#` delimiter + stem-grouping, which is the gate's single clearest
violation), and not a canonical total order over values (C4's opacity-breaking
value-comparator). The discriminator is an inert field the substrate never reads;
spawning a run in-tick is an author-appended element with no minter. The
**discriminated map [C4] is acceptable only when iterated by insertion/authoring
order** — at which point it *is* an ordered list-of-pairs, conceding to C3. The
**key-suffix [C1] is unsalvageable**: it is the one shape that puts metadata-key
*structure* under the substrate's interpretation, which the gate forbids outright.

(C2's carrier-part shape sidesteps the shootout by relocating progress off the
target; where absolute-value concurrency forces it back onto the target, it too
should adopt the list. So the list answer is what every surviving frame converges
on.)
