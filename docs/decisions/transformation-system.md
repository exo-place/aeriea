# Design: Transformation (TF) system

Status: **Design pass — no code. Not green.** Awaits user approval before any
implementation. New work lands under `docs/FEATURES.md` → Not green. **This version
supersedes the prior flat-parts version of this doc** (a fixed `parts`/`groups`
slot-map body model), which could not express per-region material/covering. The
TF-as-data, deterministic-applier, and state-derived-description scaffolding is kept
and retargeted onto a compositional body graph.

Refs: `docs/artifacts/text-gen-design/ref-coc.md` (enum-type + scalar-magnitude parts,
descriptor-from-state), `docs/artifacts/text-gen-design/ref-bdcc-game.md` (reversible
staged TF as data-descriptor effects through a holder; BDCC's own lesson that
content-as-GDScript was the mistake — design the content seam as **data first**;
on-action `sim_clock`).

Aeriea principles honored: data over code at a seam; deterministic seeded sim;
description derived from state.

---

## 1. Status

- Design pass, **no code yet**, **Not green**, awaits the user's express approval.
- Supersedes the prior flat-parts (`parts`/`groups`) version of this doc.

---

## 2. Scope

In scope — a transformation system with four parts:
1. a **serializable compositional body graph** (data, not OO state);
2. **transformations as data** — declarative effect records that target regions of the graph;
3. a **single deterministic applier** that interprets a TF record against a body, seeded
   and replay-safe, with staged progression on `sim_clock`;
4. **state-derived description** — prose re-derived by traversing the graph (including the
   in-progress middle of a staged TF).

TF is **causal**: items/events trigger TFs and they unfold over in-game time. That is
expected and correct. But the **pure TF system carries no worldbuilding / setting flavor**.
The worked examples and the MVP content are **setting-neutral mechanism demos** — "graft a
quadruped-lower subtree", "set a subtree's covering to fur", "grow a tail subtree", "set a
region's material to chitin" — with **no** aeriea-modern-life framing and **no** fantasy
framing. What an item or event *is* in a setting (a pill, a field, a spell), and the lore /
register around it, is a **separate layer for another time** and is **explicitly out of
scope** here.

**Out of scope — and be honest about the hard part.** The 3D embodiment of an
arbitrary-topology body — the **rig, mesh, and animation** for a graph that can be a biped,
a taur, a naga, a hexapod, or something with no name — is the genuinely hard, unsolved
problem, and it is **deferred**. Skinning/animating a procedurally-grafted skeleton is a
large research-grade effort; nothing here pretends to solve it.

What *is* in scope is deliberately light: the **data model** is a graph + edits + a
traversal. In weight it is comparable to the flat parts/groups model it replaces — one
generic segment node, a few enumerated material/covering values, a recursive walk. We are
replacing one small data
model with another small data model that happens to be more expressive; we are **not**
signing up for the 3D doll here. Also out of scope, as before: the deep prose-quality
realizer (`docs/decisions/prose-generation.md` — the CxG engine); descriptors here are
simple state-keyed phrase pickers over a graph traversal. Combat, world graph, NPC sim,
and content bulk are likewise out — "more rows in the same tables."

---

## 3. Body model — a mutable compositional graph

The body is a **mutable compositional graph**, not a record of fixed parts. Three
**orthogonal** axes, **none of them a finite enum**:

1. **FORM** — the topology: a graph/tree of **segments** joined at **attachment points**.
2. **MATERIAL** — **per-segment**: what a region is *made of* (governs how form behaves).
3. **COVERING** — **per-segment** surface (skin/fur/scales; meaningful only for flesh).

Plus per-segment scalar **properties** (size, length, …) as needed.

**Segments are generic, built from scratch — there is no fixed part-kind vocabulary.** A
segment is not an "arm" or a "leg" or a "torso" by type; it is just `{extent/geometry,
material, covering, attachment_points[], tags[]}`. There is **no `kind` field**, no
part-kind enum, no closed set of named parts. An "arm" or a "lower body" is an
**arrangement of segments plus conventional tags**, NOT an intrinsic type. You build any
limb or region from scratch as a subtree of generic segments and tag it by convention.

### 3.0 Crucial property: FORM IS ALWAYS MUTABLE

There is **no stable baseline** and **no stability invariant** to maintain. This is a
transformation game; the graph is simply the *current* form, continuously editable. Every
body is mid-transformable by default. Slime is **not** a special "unstable" case — it just
flows more readily. Do **not** encode any "stable form" / "fixed skeleton" assumption.

### 3.1 FORM — segments and attachment points

A **segment** is a node in the graph. It carries its own geometry/extent, its material, its
covering, its scalar properties, a list of arbitrary **tags**, and a list of child segments,
each attached at a named **attachment point** on the parent. Limbs are just **subtrees**: a
limb you can graft, remove, or reparent anywhere a compatible attachment point exists.

Configurations like biped / taur / quadruped / naga / hexapod are **configurations of the
graph, NOT named types** — a name like `taur` is only an optional alias bound to such a
configuration (§3.6). A taur, concretely, is a from-scratch quadruped-lower subtree
(a second spine plus four legs, each built from generic segments) grafted onto the upper
structure's hip region and tagged `lower_body` by convention.

```
Segment = {
  "id":        "torso_upper",     # unique node id within this body
  "material":  "flesh",           # per-segment MATERIAL (axis 2)
  "covering":  "skin",            # per-segment COVERING  (axis 3); null if N/A for material
  "props":     { "length_cm": 60.0 },   # per-segment scalar PROPERTIES / extent / geometry
  "tags":      [ "torso", "upper_body" ],  # arbitrary strings; engine bakes in NONE of them
  "children":  [
    { "at": "shoulder_l", "node": Segment },   # attachment point -> child subtree
    { "at": "shoulder_r", "node": Segment }
  ]
}
```

- There is **no `kind` field**. `tags` are arbitrary strings the engine does not interpret;
  the body model itself bakes in **no** part vocabulary. Conventional tags (`torso`, `arm`,
  `hand`, `lower_body`, …) are a **shared agreement content uses to grab structure** — a
  lingua franca like CSS classes or file extensions, **not** a schema the engine polices
  (see §3.7).
- `at` names an attachment point. Attachment points are just named docking sites a segment
  exposes; the model permits **any** graft (coherence is unenforced — see §3.8).
- A limb/region is the subtree rooted at a segment; grafting = adding a child entry,
  removing = dropping one, reparenting = moving one.

### 3.2 MATERIAL — per-region, governs how form behaves

`material` is a **per-segment** open property describing what the region is *made of*. It is
**not** a surface texture and **not** a finite list to bake. Material governs behavior:

- **flesh** — soft tissue over an internal structure; takes a separate **covering**.
- **chitin** — rigid exoskeleton: structure and exterior are the **same thing**, no separate
  covering (arthropod-style joints). `covering` is `null` for chitin.
- **slime** — amorphous, translucent, no rigid joints; the form is a *held shape* rather
  than a fixed skeleton. `covering` is `null`.
- others: scale-hide, stone, energy, … — open.

### 3.3 COVERING — per-region surface

`covering` is the **per-segment** surface: skin / fur / scales / etc. It is only meaningful
when the segment's material is flesh-type; for chitin/slime it is `null`. Because covering
lives **per-segment**, a single body can be skin on one region and fur on another. (A global
"skin" field — the old model — literally cannot express this.)

### 3.4 Serialization

The body is the segment graph rooted at one node, plus optional body-wide scalars:

```
BodyState = {
  "root":    Segment,                 # the whole graph hangs off one root
  "scalars": { "height_cm": 170.0 }   # body-wide scalars not owned by any one segment
}
```

Everything is plain dicts / arrays / floats / strings → JSON round-trips trivially; the dict
**is** the truth, not a dump of live objects (BDCC's caution #4). Node ids are unique within
a body so TF ops and undo can target a segment stably.

### 3.5 Worked example — a taur (skin upper / fur lower)

A flesh+skin humanoid upper half grafted onto a flesh+fur quadruped lower half (the
configuration that carries the optional alias `taur`, §3.6 — the structure below is the
canonical thing). The graft is a from-scratch subtree (a second spine + four legs) docked at
the upper structure's hip and tagged `lower_body`. Every segment is generic — only the `tags`
mark conventional roles:

```
{ "root": {
    "id":"torso_upper", "material":"flesh", "covering":"skin",
    "props":{"length_cm":55}, "tags":["torso","upper_body"], "children":[
      { "at":"neck",   "node":{ "id":"head", "material":"flesh", "covering":"skin",
                                "props":{}, "tags":["head"], "children":[] } },
      { "at":"arm_l",  "node":{ "id":"arm_l","material":"flesh","covering":"skin",
                                "props":{"length_cm":62},"tags":["arm"],"children":[]} },
      { "at":"arm_r",  "node":{ "id":"arm_r","material":"flesh","covering":"skin",
                                "props":{"length_cm":62},"tags":["arm"],"children":[]} },
      { "at":"hip",    "node":{                          # <-- the grafted lower structure
          "id":"barrel", "material":"flesh", "covering":"fur",
          "props":{"length_cm":90}, "tags":["spine","lower_body"], "children":[
            {"at":"leg_fl","node":{"id":"leg_fl","material":"flesh","covering":"fur",
                                   "props":{"length_cm":80},"tags":["leg"],"children":[]}},
            {"at":"leg_fr","node":{"id":"leg_fr","material":"flesh","covering":"fur",
                                   "props":{"length_cm":80},"tags":["leg"],"children":[]}},
            {"at":"leg_bl","node":{"id":"leg_bl","material":"flesh","covering":"fur",
                                   "props":{"length_cm":80},"tags":["leg"],"children":[]}},
            {"at":"leg_br","node":{"id":"leg_br","material":"flesh","covering":"fur",
                                   "props":{"length_cm":80},"tags":["leg"],"children":[]}}
          ] } }
    ] } }
```

The skin/fur split is expressed **per segment** — impossible in a global-skin model — and the
upper/lower split is just the `upper_body` / `lower_body` tags by convention, not a type.

Variants are just different per-segment material/covering on the **same** form:
- **chitin-centaur** — the lower `barrel` + legs subtree has `material:"chitin"`,
  `covering:null` (exoskeleton; no separate covering).
- **slime-centaur** — the lower subtree has `material:"slime"`, `covering:null`; the form is
  a *held shape* (see §8 open question on amorphous-material/form interaction).

### 3.6 Names are optional aliases bound to configurations

A **name** (`taur`, `holstaur`, `naga`, …) is an **optional alias** bound to a *configuration*
— a structural pattern / tag-set (e.g. `taur` ↔ a humanoid-upper structure grafted on a
quadruped-lower subtree). The **structure is canonical**; the alias is shorthand on top,
conventional and unenforced, in the same spirit as the tag convention (§3.7). The engine
bakes in no enum of names.

Consequences:
- A **novel / unnamed configuration** simply has no alias → it is described **structurally**
  from the graph (§6). Structural description is **always available**; there is no closed set
  of names to fall outside of, so every configuration — named or not — is fully describable.
- Aliases **compose**: `holstaur` = `taur` + bovine features. An alias is just a label over a
  configuration, so a configuration that extends another extends its alias too.
- Aliases are **audience-dependent**. Whether to *surface* an alias (say "taur") or *expand*
  it to a structural description (a taur may pass unremarked; a holstaur may need unpacking)
  is a **description-layer** concern — downstream of the pure TF system and **deferred** (same
  bucket as setting flavor; see §8). The pure system needs only this: aliases are optional
  labels bound to configurations, and the structure is the ground truth.

### 3.7 Naming / targeting is convention, not enforcement

Tags are arbitrary strings and the engine bakes in **nothing**. There is, separately, a
**conventional shared vocabulary** — `lower_body`, `upper_body`, `arm`, `hand`, `head`, … —
that is the **lingua franca content uses to grab structure**. It works exactly like CSS
classes or file extensions: a shared agreement everyone opts into so things interoperate,
**not** a schema the engine validates or a closed set it polices. Content is free to invent
new tags; nothing forges or enforces authority over the vocabulary.

A TF op targets node(s) resolved one of two ways, **never** a global slot or a fixed
part-kind:

- **by tag (convention)** — "every segment tagged `lower_body`", "the node tagged `hand`";
- **by structural query** — "the subtree past the waist joint", "all descendants of node
  `barrel`", "the child docked at attachment point `hip`".

**Honest consequence, stated plainly:** a convention-targeting TF only affects bodies that
follow the convention. Pour "fur the `lower_body`" onto a body whose lower half is not tagged
`lower_body` and the op simply **no-ops** — or you target it structurally instead (e.g. "the
subtree past the waist joint"). That is **correct behavior, not a bug**: the engine never
guesses at a body's anatomy, so a TF written against a convention does nothing to a body that
opted out of it. If you want it to always hit, target structurally.

### 3.8 Coherence is unenforced

The core model permits **any** graft and has **no** notion of a "valid" or "coherent" body.
Two heads on one neck, a leg docked to a fingertip, a free-floating subtree — all are
expressible; the model does not police anatomy. This is deliberate and
transformation-game-faithful: there is no privileged "correct" body shape.

Coherence, if wanted at all, ships as an **opt-in validator** — a separate, unopinionated
layer you run against a body **on demand** to get a report ("this graft has no supporting
spine", "this joint is unusual"). It is never invoked by the model, never blocks a TF, and
carries no authority; it is a tool you point at a body, not a gate the body must pass. Most
content will never run it.

---

## 4. Transformations as data

A TF is a **data record interpreted by one applier**, never a bespoke `TFBase` subclass
(BDCC's class-per-pill is the anti-pattern; their later Datapack data layer is the proof).
What changed from the prior doc: ops now operate over the **graph** and the **three axes**,
and **target regions** (a segment or a subtree by id), never global slots.

### 4.1 Shape

```
TF = {
  "id": "graft_quadruped_lower",
  "name": "...",
  "gate":   <Predicate>,     # read body -> bool (data tree, no closures)
  "staged": true,            # false = instant; true = progress on sim_clock
  "stage_seconds": 1800,     # in-game seconds per stage (staged only)
  "max_stages": 4,           # ceiling; gate can stop earlier
  "ops": [ <Op>, ... ]       # ordered effect list, each a data Op
}
```

A **Predicate** is a small data tree, e.g.
`{"op":"has_tag","tag":"tail"}`,
`{"op":"material_is","node":"barrel","v":"flesh"}`,
`{"op":"lt","path":"#tail.props.length_cm","v":15}`,
`{"op":"and","of":[ ... ]}`. The applier evaluates it; `#id` selects a segment by id, and
`tag`/structural selectors resolve node sets by convention or structure (§3.7).

### 4.2 Op vocabulary (small and closed — operates over the three axes)

| effect            | axis      | what it does |
|-------------------|-----------|--------------|
| `graft_subtree`   | FORM      | dock a given subtree at `(target_node, at)` |
| `remove_subtree`  | FORM      | drop the subtree rooted at `target_node` |
| `reparent`        | FORM      | move `target_node` to a new `(parent, at)` |
| `set_material`    | MATERIAL  | change target's material (and null its covering if the new material takes none) |
| `set_covering`    | COVERING  | change target's covering (flesh-type only) |
| `prop_delta`      | PROPERTY  | add to a per-segment scalar, seeded + clamped |
| `tag` add/remove  | TAG       | add or remove a convention tag on the target |

There is **no `set_kind`** op (there is no `kind`); retagging is just `tag` add/remove. Every
op carries a **region target** resolved by node id, by **tag (convention)**, or by
**structural query** (e.g. `subtree` to fan an op across every segment under a root), plus an
optional `when` Predicate (skip unless true). No op touches a global slot or a fixed
part-kind; everything is addressed by id, tag, or structure (§3.7).

### 4.3 Worked TF records

These are **pure mechanism demos**, deliberately setting-neutral (§2): each one exercises one
op category against the graph with no lore attached. What *triggers* one in a given setting
is a separate layer (§2, §8).

**(a) graft a quadruped-lower subtree — a FORM graft (instant).** Dock a furred quadruped
lower structure (a from-scratch second spine + four legs) at the upper body's hip. (This
configuration carries the optional alias `taur`, §3.6 — the alias is shorthand; the structure
below is the canonical thing.)

```
{ "id":"graft_quadruped_lower", "name":"...", "staged":false,
  "gate":{"op":"not","of":{"op":"has_tag","tag":"lower_body","under":"hip"}},
  "ops":[ {"effect":"graft_subtree","target_node":"torso_upper","at":"hip",
           "subtree":{ "id":"barrel","material":"flesh","covering":"fur",
             "props":{"length_cm":90}, "tags":["spine","lower_body"], "children":[
               {"at":"leg_fl","node":{"id":"leg_fl","material":"flesh","covering":"fur",
                                      "props":{"length_cm":80},"tags":["leg"],"children":[]}},
               {"at":"leg_fr","node":{"id":"leg_fr","material":"flesh","covering":"fur",
                                      "props":{"length_cm":80},"tags":["leg"],"children":[]}},
               {"at":"leg_bl","node":{"id":"leg_bl","material":"flesh","covering":"fur",
                                      "props":{"length_cm":80},"tags":["leg"],"children":[]}},
               {"at":"leg_br","node":{"id":"leg_br","material":"flesh","covering":"fur",
                                      "props":{"length_cm":80},"tags":["leg"],"children":[]}}
             ] } } ] }
```

**(b) set a subtree's material to chitin — a MATERIAL set (staged, fans over a subtree).**
Converts the lower-body subtree to exoskeleton over 3 stages; setting chitin nulls the
covering:

```
{ "id":"set_lower_material_chitin", "name":"...", "staged":true, "stage_seconds":1200, "max_stages":3,
  "gate":{"op":"has_tag","tag":"lower_body"},
  "ops":[ {"effect":"set_material","subtree_tag":"lower_body","value":"chitin",
           "when":{"op":"ne","path":"#barrel.material","v":"chitin"}} ] }
```

**(c) set a subtree's covering to fur, segment by segment — a COVERING set (staged over
several clock stages).** Each stage advances fur one segment further up the lower structure
(ordered ops, one fires per stage via `when` guards — the lowest still-skin segment converts
first):

```
{ "id":"set_covering_fur_upward", "name":"...", "staged":true, "stage_seconds":900, "max_stages":4,
  "gate":{"op":"material_is","node":"barrel","v":"flesh"},
  "ops":[
    {"effect":"set_covering","target_node":"leg_bl","value":"fur",
       "when":{"op":"eq","path":"#leg_bl.covering","v":"skin"}},
    {"effect":"set_covering","target_node":"leg_br","value":"fur",
       "when":{"op":"eq","path":"#leg_br.covering","v":"skin"}},
    {"effect":"set_covering","target_node":"barrel","value":"fur",
       "when":{"op":"eq","path":"#barrel.covering","v":"skin"}},
    {"effect":"set_covering","target_node":"torso_upper","value":"fur",
       "when":{"op":"eq","path":"#torso_upper.covering","v":"skin"}} ] }
```

One covering converts per stage, lowest-first, so the fur visibly creeps upward; the
skin↔fur boundary at the current joint is a describable transition zone (§6).

**(d) grow a segment's length — a PROPERTY delta (staged, seeded).** Rolls length onto a
tail-tagged segment each stage (any scalar prop on any tagged segment works the same way):

```
{ "id":"grow_tail_length", "name":"...", "staged":true, "stage_seconds":900, "max_stages":5,
  "gate":{"op":"has_tag","tag":"tail"},
  "ops":[ {"effect":"prop_delta","target_node":"tail","prop":"length_cm",
           "amount":{"roll":"uniform","lo":2,"hi":5}, "clamp":[0,120]} ] }
```

---

## 5. The deterministic applier

One function interprets any TF record against any body. No per-TF code.

### 5.1 Seeded, replay-safe randomness

Every `{"roll":...}` resolves through a **seeded RNG derived from the action log**, never a
free `randf()`. The seed for one application is a pure function of
`(world_seed, action_id, stage_index, op_index)` — so replaying the same action log
reproduces every roll bit-for-bit. (Same stance as `scripts/sim/sim_clock.gd`: time advances
only off the seeded action-log timeline.) The applier takes the RNG as an argument; it never
reads wall-clock or unseeded global RNG.

### 5.2 Applying one stage

```
apply_stage(body, tf, stage_index, rng) -> StageResult:
  if not eval_predicate(tf.gate, body): return done
  effects = []                              # reversible record (before/after per op)
  for op_index, op in enumerate(tf.ops):
    if op.when and not eval_predicate(op.when, body): continue
    targets = resolve_targets(body, op)     # one node, or every node in a subtree
    for node in targets:
      before = capture(node, op)            # capture original region state
      amount = resolve(op.amount, rng)      # seeded roll or literal
      apply_op(body, node, op, amount)      # graft/remove/reparent/set/delta, clamped
      after  = capture(node, op)
      if after != before:
        effects.append({op, node_id, before, after})
  return StageResult(effects, prose_for(effects, body))
```

`before`/`after` capture the **region** the op touched: for FORM edits the removed/added
subtree (so undo can re-graft it); for material/covering/property the prior value. This is
BDCC's `doProgress() → effect descriptors → applied with stored originals`, collapsed to one
interpreter over the graph.

### 5.3 Staged progression on `sim_clock`

A **TFHolder** (per character; the only stateful piece) holds active staged TFs:

```
ActiveTF = { "tf_id", "next_stage": int, "due_full_time": int }
```

On each logged action that advances time, the holder calls `sim_clock.advance(seconds)`
then, while `sim_clock.full_time() >= due_full_time`, runs `apply_stage`, appends its effects
to the undo log, increments `next_stage`, sets `due_full_time += tf.stage_seconds`, and
stops when `next_stage == max_stages` or the gate fails. Because `full_time()` is
deterministic in the action log and the RNG is seeded by `(action_id, stage_index,
op_index)`, replay reproduces the exact unfolding.

### 5.4 Reversibility / coalescing

The holder keeps an **undo log** of every effect `{op, node_id, before, after}`. Three
operations fall out for free:
- **undo** — walk the log backward, restoring `before` for each (re-graft a removed subtree,
  restore a material/covering/value, etc.);
- **coalesce** — two `prop_delta`s on the same node+prop merge by summing deltas;
  `set_material`/`set_covering` on the same node keep the *earliest* `before`;
- **make permanent** — clear the undo log; the current graph is the new baseline.

Because the graph is **always** mutable (§3.0), reversibility is bookkeeping over edits, not
a return to a privileged stable form — there is no privileged form to return to, only the
captured `before` of each applied op.

---

## 6. Description from state

Prose is **re-derived by traversing the graph on every read**, never stored. The traversal
visits each segment and, per region, reads its **covering** (or material, where material is
the visible surface — chitin, slime), its **tags** (for naming in prose — convention, §3.7)
and **form** context, and its scalar **props**, emitting a phrase.

```
describe(body):
  walk root depth-first; for each segment:
    surface = (segment.covering if segment.material is flesh-type
               else segment.material)              # chitin/slime ARE the surface
    noun = noun_for_tags(segment.tags)              # "leg"/"tail"/... from convention tags
    adj  = band(segment.props) + surface_adj(surface)   # "long", "fur-covered", ...
    emit adj + noun
  describe form context (e.g. "a four-legged lower body") from the subtree shape
```

Naming in prose reads off the **convention tags** (a segment tagged `leg` says "leg"); a
segment with no conventional tag is described purely compositionally from its structure.

- **Transition zones.** Where two regions of different covering/material meet at an
  attachment point (skin upper meets fur lower at the hip; flesh meets chitin at a joint),
  the **joint** is described with a joint-level descriptor ("…where smooth skin gives way to
  fur"). This reads directly off the parent/child material+covering pair at each attachment.
- **In-progress staged TF.** Because each `apply_stage` mutates the graph in place, the body
  is **always** in a coherent describable state between stages — the half-furred lower body
  mid-`set_covering_fur_upward` describes cleanly, and the current skin↔fur joint is the
  transition zone.
- **Commitment / faithfulness gate.** A region may be described as having a feature **only if
  the structure commits it**: a phrase asserting a tail/leg/material is licensed only when
  that segment actually exists in the graph with that property. No phantom parts; mention a
  feature only if it fits cleanly off the committed graph.

The deep prose-quality engine is **out of scope**; this is simple descriptor traversal.

---

## 7. MVP slice

The smallest thing that is a *real* working TF system over the compositional graph:

- **A handful of convention tags** (shared vocabulary, §3.7): e.g. head, torso, arm, leg,
  hip, spine, tail, upper_body, lower_body — enough to build a biped from generic segments
  and graft a from-scratch quadruped-lower structure. **Open vocabulary, few values**, not a
  closed enum and not a part-kind type.
- **A few materials** (flesh, chitin, slime) and **a few coverings** (skin, fur, scales),
  per-segment. Again: open property, few shipped values.
- **~4–5 TF records** spanning all op categories:
  1. `graft_quadruped_lower` — FORM graft (instant);
  2. `set_lower_material_chitin` — MATERIAL set, staged, fans over a subtree;
  3. `set_covering_fur_upward` — COVERING set, staged, creeps up a subtree;
  4. `grow_tail_length` — PROPERTY delta, staged + seeded;
  5. a revert that invokes the holder's **undo** (proves reversibility end-to-end).
- **The deterministic applier** (§5) + **TFHolder** on `sim_clock` + seeded RNG.
- **State-derived description** (§6): graph traversal + transition-zone joints + the
  commitment gate.
- **Save/load round-trip:** body graph + holder (active TFs + undo log) → JSON → back,
  asserted identical.
- **A tiny text harness:** a `RichTextLabel` + a few buttons to pick a TF, advance the clock
  N actions, watch staged prose unfold, undo, make permanent. This is the playtest surface.
- **A test suite** (added to `tests/run.sh`): determinism (same seed+log → identical graph),
  staged progression on the clock, **region-targeting** by tag/convention and by structural
  query (an op hits only the targeted subtree; a convention-targeting op **no-ops** on a body
  that lacks the tag — §3.7), reversibility (undo restores the exact graph, including
  re-grafting removed subtrees), save/load round-trip, commitment gate (no phantom-part
  prose).

**Ship it OPEN from day one.** The model is compositional and the three axes are open
properties — do **not** ship a closed enum of body archetypes / materials / coverings and
retrofit graph-ness later; that is exactly the painful migration the principles warn against.
MVP ships **few values**, not a **closed set**: the same traversal and applier work unchanged
as values are added.

Deferred: the 3D rig/mesh/animation for arbitrary topology (§2 — the hard part), content
bulk, the rich prose realizer, combat/world/NPC triggers.

---

## 8. Open questions (genuinely open — not resolved here)

Earlier open questions are now **decided** and have moved into the design:
**coherence is unenforced** (optional opt-in validator, §3.8); **naming/targeting is
convention, not enforcement** (§3.7); **names are optional aliases bound to configurations**
(§3.6); and **the pure system is setting-neutral** — example/MVP TFs are setting-neutral
mechanism demos and setting flavor is a separate layer, deferred (§2, §4.3). What remains
genuinely open:

1. **How amorphous materials interact with form.** For slime (and other non-rigid materials)
   the form is a *held shape* rather than a skeleton. How held-shape behaves under FORM edits
   — whether a slime subtree even has stable attachment points, how it "flows" between stages
   — is **flagged, not solved** here.
