# Text slice — first playable text-gameplay loop

The smallest playable text-gameplay vertical slice, built on the already-implemented
affordance substrate (`scripts/interaction/`, `docs/decisions/affordance-substrate.md`).
You talk to **Maren**, a stateful NPC; her mood and rapport change as you interact,
and the changes are rendered as prose.

## What it is

- **NPC as affordance DATA.** `npc_maren` lives in `interaction/sandbox.kit.json` —
  no engine code. State: `mood`, `rapport` (continuous 0..1 axes), `last_social_act`
  (enum memory), `times_complimented` (remembered count). Five command verbs —
  `greet`, `compliment`, `tease`, `push_away`, `offer_gift` — built from the
  **existing** guard/effect vocabulary only (`state_enum`, `state_cmp`, `all`,
  `add_fill` with lo/hi clamp, `set_state`, guarded effects). Zero new primitives.
- **Driven HEADLESSLY** through `InteractionInterpreter` (the reference semantics the
  3D world uses) via a tiny `HeadlessHost` shim — the same `ScriptedHost` driver
  pattern as `tests/interaction_golden_trace_test.gd`. No scene/physics coupling.
- **Realizer** (`scripts/text/npc_realizer.gd`) turns state into prose.
- **Loop** lives in `scripts/text_sandbox.gd` (Mode 3 in the launcher): it presents
  only the verbs whose guards currently pass, fires the chosen one, and renders
  `describe_outcome(before, after, verb)` then `describe_npc(after)`.

## Verb dispatch is data

The interpreter's command-fire path picks the *first* command verb whose guard
passes. To select a *specific* verb, the host sets `state.selected` to the verb name
before `step()`; every verb guards on `state_enum selected == <name>` (combined via
`all` with its real precondition), so exactly that verb's guard passes and the
substrate's normal fire path runs it. The host clears `selected` after. The guard
layer does the dispatch — not a host bypass. `step()` is called with `dt = 1.0` so
each `add_fill` `rate` reads as a per-interaction delta.

## The realizer is the FLOOR behind a stable seam

`NpcRealizer` is a **deterministic, state-faithful** prose generator. The stable
public interface — the contract callers depend on — is:

```
describe_npc(state) -> String
describe_outcome(before, after, verb) -> String
```

Properties (enforced by `tests/text_slice_test.gd`):

- **Pure function of state** — no `randf()`, no time, no global mutable state, no
  I/O, no LLM (anywhere). Optional phrasing variation takes a seeded
  `RandomNumberGenerator` so replay stays bit-identical.
- **Faithful** — asserts only what is true of the state passed in; no invented facts.
- **Not mad-libs** — phrasing bands on field VALUES and on COMBINATIONS
  (mood × rapport × last_act), so the same verb reads differently as the
  relationship changes (delight when she trusts you, guarded surprise when she
  barely knows you, off the same `compliment`).
- **Changes as prose** — mood/rapport deltas render as the NPC warming/cooling,
  drawing closer/pulling back, remembering — never raw numbers.

This body is the **functional floor / scaffold** named in
`docs/decisions/prose-generation.md`: still-good, state-driven prose, never trash.
The richer climb — figuration/subtext data-driven resources, then a
constrain-then-generate substrate — replaces the **internals** of these two
functions behind this **same interface**. Callers never change.

## Simplification noted

`offer_gift` is a **guarded command** (guarded on rapport), not a literal held-gift
`place` verb. Expressing a real held gift headlessly would require a separate gift
interactable plus carry state — out of scope for the smallest slice. The seam is
unchanged when a real held-item gift lands later.

## Run it

- Playable (launcher → "Text Sandbox", or standalone):
  `xvfb-run -a godot4 --path . res://scenes/text_sandbox.tscn`
- Tests (part of the canonical suite): `nix run .#test`, or just this suite:
  `xvfb-run -a godot4 --path . res://tests/text_slice_test.tscn --quit-after 2000`

## Regenerating compiled interaction

`npc_maren` is part of the kit, so the compiled projection must stay bit-identical:
`xvfb-run -a godot4 --path . res://tools/regen_compiled_interaction.tscn --quit-after 120`
(the `interaction_golden_trace_test` asserts interpreter == compiled).
