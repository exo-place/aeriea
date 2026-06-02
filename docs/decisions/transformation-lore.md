# Sketch: Transformation lore — the malleable-body premise

Status: **SKETCH / WIP — not frozen canon** (2026-06-03)

Scope: a faithful capture of a transformation-lore sketch developed in
design conversation. This records the *delivery stance* and a set of
*lineages / modalities*, plus the key withheld design device that ties
them together — it does **not** specify the deeper cosmology, and it
does not finalize any names. Everything here is provisional. Where a
thing is deliberately secret or open, it is recorded **as** secret /
open and must not be resolved by anyone reading this doc.

This sketch begins to address the deferred "why is the avatar
superhuman?" open question in `units-and-scale.md` (see *The frame*
below), but does not close it — the grounding lore is WIP.

---

## The frame (decided this session)

- **Bodily malleability is ambient and normal.** In this world, changing
  your body is mundane and verb-like — live, mid-session form-swapping is
  something people *just do*. It is not a rare or remarkable power. This is
  a setting-defining choice: it reshapes the social fabric, i.e. how NPCs,
  relationships, and society read and respond to bodies that are not fixed.

- **Fully worldbuilt, delivered "Second Dream"–style.** The premise is
  fully worldbuilt underneath, but on the surface it is mundane and
  unremarked: a deep truth / horror is withheld and surfaced as an *earned
  reveal*. NPCs take the whole thing for granted; the player learns what it
  *means* over time. Rich lore conveyed through a world that never stops to
  explain itself.

- **Diegetic-only and per-server-coherent.** Delivery is diegetic — no
  menu / narrator exposition. And these are standing *kinds of being* /
  standing conditions of every world instance, **not** a single global
  live event or a central lore authority. Self-hosted worlds + seeded
  determinism (DESIGN.md, *Deterministic seeded simulation*; *Self-hosted
  multiplayer*) forbid a central live-service lore event; the premise must
  hold per-server, coherently, with no central authority.

- **Unifies with the superhuman-capability question.** The same fact that
  makes bodies malleable is *why* they are superhuman. A body here is not a
  fixed inheritance — it is assembled / regrown / fabricated / reconfigured
  / projected to spec — so superhuman feats are simply "what that body can
  do." This is the intended answer to the deferred "why is the avatar
  superhuman?" open question (`units-and-scale.md`, *Diegetic framing →
  Open question*; echoed in DESIGN.md, *Platforms and presentation*). The
  lore is WIP, so the question is being **addressed, not closed**.

---

## The lineages / modalities

Loosely "species" (the term used in design conversation, kept verbatim),
but these are **not mutually exclusive** — see *The carveout* below. The
seven, as given:

1. **Scavenger** — scavenge body parts and attach / swap them; acquire
   parts externally. (For where the parts come from, see *Provenance
   ecology*.)
2. **Weaver** — genetic recombinants; primarily regrow body parts from
   saved genetic material. Produce regrown spares.
3. **Puppeteer** — *own* multiple bodies, typically piloting one as their
   avatar. What becomes of the inactive bodies — whether they have brains,
   whether they're "just regular people" — is a deliberate **per-individual
   secret** (see *Provenance ecology*). **Do not resolve this.**
4. **Synthetic** — fabricate their own body parts; manufactured, but **not
   necessarily non-biological** (manufactured ≠ inorganic).
5. **Shifter** — bistable / N-stable physiology (a small set of discrete
   stable forms); the deliberately "cliché" shapeshifter.
6. **Shapeless** — umbrella term for any being composed of something
   dynamically reshapeable — mechanical, biological, a swarm, or otherwise.
7. **Projection** — (near-)incorporeal beings whose form is *projected* by
   some means through a **core** that is **not** the same shape as the
   (non)physical projected form.

These read as composable **modalities / lineages**, not exclusive
biological species, and several overlap:

- **Shapeless subsumes shifter** as a special case (discrete stable forms
  are a constrained case of continuous reshape).
- **Synthetic vs scavenger** differ only in the *origin* of the part —
  made vs found.
- **Weaver and synthetic** both "produce" parts (grown vs fabricated).

> **OPEN design question:** at the *system* level, does a player pick one
> lineage as an identity, or compose traits across lineages? Unresolved —
> see *The carveout*, which makes composition the withheld truth, and the
> *Open threads* list.

---

## The carveout (the key withheld idea)

- **The lineages are NOT mutually exclusive.** It is never stated that a
  being is only one. Most beings *tend* to stick to one method — out of
  familiarity, not necessity — so exclusivity *looks* true.

- **Design device — lie by omission.** The game can present the lineages to
  the playerbase as if they were discrete, exclusive kinds, while
  withholding that they compose. The discovery that they are composable is
  itself a Second-Dream-style reveal: the taxonomy the player was taught is
  a deliberate simplification / lie.

- **Architecture rhyme (through-line):** this mirrors the project's own
  composition-over-enumeration ethos exactly — the same principle as the
  data-driven movement substrate (composable primitives presented as
  discrete presets; "collapse asymmetries to primitives"). The "species"
  are to the body what `verbs/*.kit.json` are to movement; "they're
  exclusive" is a surface lie over a composable substrate. The fiction and
  the engine rhyme. (See `movement-substrate.md`, *Composition model*; and
  the named-presets seam in *Configurability surface*.)

### Worked example — Puppeteer × any lineage (canonical composability illustration)

The Puppeteer lineage is the clearest worked example of the carveout,
because its composition is **not flat but nested**.

- **A puppeteer's bodies need not be static.** Each body a puppeteer
  pilots can itself be malleable — a given piloted body might be
  shapeless, a weaver body that regrows its own spares, a shifter with
  its own N stable forms, and so on.

- **Puppeteer is therefore effectively a meta-modality.** It operates
  *on* bodies — not *as* a body-shape — so "puppeteer × any other
  lineage" nests naturally rather than merely adding traits side-by-side.
  Composition here does not flatten: it nests. A composite being whose
  components are themselves composite.

- **This deepens the personhood question already flagged in the
  Provenance ecology.** A piloted body that can itself transform, regrow,
  or shift reads even more like a being with its own agency being worn —
  which loops directly back into the deliberate ambiguity around whether
  inactive bodies are people, and whether they were acquired or created.
  **That question is not answered here; the ambiguity is preserved.**

- **Architecture rhyme (brief).** The nesting maps onto the substrate
  cleanly: each body is its own composed body-kit, and the puppeteer
  layer selects which kit is active. Composition nests in the data model
  exactly as it nests in the fiction — the same composition-over-
  enumeration through-line already noted above.

---

## Provenance ecology

The dark Second-Dream substrate — withheld, mundane on the surface.

- **Weavers' regrown spares are the source of scavengers' parts** — a quiet
  supply chain of flesh between the lineages.
- **Puppeteer body acquisition is a deliberate per-individual secret**:
  phrased as bodies "acquired… created" — some may be genuinely created,
  some perhaps not. This ambiguity is **intentional**; the game never
  resolves it to one canonical answer (and per-server, it needn't). **The
  ambiguity is the horror.**
- **Overall tone:** mundane surface, not-okay underneath — the Second-Dream
  shape.

---

## Physics / capability mapping (cross-link, brief)

The lineages map cleanly onto the soft-body **predict-then-project
surrogate** already specced in DESIGN.md (*Secondary / soft-body
physics*; the physics-driven-transformation R&D paragraph), as evidence
that lore and tech reinforce each other. A transformation is an *authored
moving rest-state target* the surrogate tracks dynamically:

- **Shifter** — discrete rest-target morphs.
- **Shapeless** — continuous reshape (the surrogate's core case).
- **Weaver** — grown rest-targets.
- **Projection** — a rest-target authored from a differently-shaped core.
- **Puppeteer** — multiple avatar instances.
- **Scavenger / synthetic** — **topology change** (the genuinely hard case
  for the surrogate; mesh/part identity changes, not just shape).

Cross-reference the physics-driven-transformation R&D paragraph in
DESIGN.md and `~/git/rhizone/playmate` (`frond`, the body/transformation/
tag system).

---

## Open threads (explicitly unresolved)

- **The deeper "fully worldbuilt" ORIGIN / cosmology of WHY bodies are
  malleable is not yet specified** — to be developed. This doc records the
  *delivery stance* (Second-Dream, fully worldbuilt) and the lineages, not
  the root cause.
- **Lineage-as-identity vs composable-traits** at the system level.
- **How transformation history persists / accumulates** — ties to
  DESIGN.md's open *Persistence model* question (what *accumulates*).
- **Staging of the Second-Dream reveal(s)** — when and how the withheld
  truth (composability; provenance) surfaces.
- **Names** are the user's to set — this doc coins no names for the deeper
  premise or any new concept, by design.
