# Feature Ledger

The single source of truth for what is and isn't trustworthy. A feature is **Green** only when the user has personally verified it is good; everything else is **Not green**.

**Promotion rule.** A feature moves from Not green to Green ONLY with the user's express permission. Claude never self-promotes, never calls its own work "done" or "green", and never treats passing tests, a playtest verdict, or an agent's success-report as a promotion. When in doubt, it is Not green.

**Design-pass rule.** No feature is started without a design pass first — a recorded artifact (a `docs/decisions/` doc or section) that decides what the feature is, its shape, defaults, naming, interactions, and a concrete quality bar, *before* any code.

## Green (user-verified good)

_(none yet — nothing has been blessed)_

## Not green (unverified / in progress / broken / design-only)

Initial inventory, derived from git history — correct as needed. Everything built so far is here by default until the user verifies it.

- **Character creator** — built; UX known-poor (typography, default look, export controls, sculpt-mode surfacing, state not persisted); unverified.
- **Body rig / MakeHuman base render** — built; BDCC core-body graft removed, single MakeHuman head; unverified.
- **Cosmetic parts (hair / ears / tail / horns)** — built; hair geometry known-broken; accessory seating quirks; unverified.
- **Retargeted animation clips** — built; known-broken/snapping in the parkour sandbox; unverified.
- **Face rig (expressions / gaze)** — built; unverified.
- **Movement / parkour sandbox** — course mechanically works; player render, orientation, FP camera clipping, and can't-leave-scene known-broken; unverified.
- **Affordance / interaction substrate** — built; unverified.
- **Text sandbox + NPC (memory / relationship / mood / realizer)** — built; known-poor (numbered-CLI UX; greeting→arousal model is wrong); unverified.
- **SimClock (deterministic time)** — built; unverified.
- **Launcher shell (mode switching)** — built; persistent top-bar tabs that swap creator/parkour/text-sandbox mode scenes with mouse-capture handoff; unverified.
- **Rebindable controls + options/pause menu + HUD** — built; fully rebindable input, options menu (sprint tap/hold, dynamic-FOV toggle, persisted leniency), pause menu, crosshair/control-legend overlay; unverified.
- **Body parameterization engine (MakeHuman modifier pipeline)** — built; data-driven modifier registry + sparse CPU delta morph library, factor-product macros, natural-unit BodyState, CDC-cited age→stature curve, nix-reproducible asset regen; unverified.
- **Per-region detail sliders** — built; 56 data-driven per-region detail sliders in the creator; unverified.
- **Creator edit-history + drag-to-modify + export/import** — built; branching undo tree, ChatGPT-style branch nav, drag-to-modify with region glow, per-format JSON/PNG export with embedded metadata + round-trip import; unverified.
- **Surface-picking subsystem** — built; backend-agnostic Picker (CPU spatial-grid + GPU ID-buffer backends) backing creator drag-to-modify, reusable for in-world picking; unverified.
- **Procedural micro-life / secondary motion** — built; spring-bone layer driving breathing/sway/saccades/jiggle and belly/glute/hair bones; unverified.
- **Procedural locomotion (motion matching + IK)** — built; 100STYLE motion-matching locomotion, foot-IK, analytic two-bone arm IK/FK with world-target reach; distinct from the retargeted clip layer; unverified.
- **CxG prose realizer (text-gen first experiment)** — built; the §8 runtime experiment from `docs/decisions/text-generation-architecture.md`. Deterministic Construction-Grammar realizer (`scripts/text/cxg_realizer.gd`) with the three C-disciplines (lexeme-level provenance gate, total-ordered draws, integer splitmix64) + RST-style cohesion constructions + a licensed-falsity frame (Maren lies in dialogue). Hand-authored micro-constructicon for two contrasting voices; tests assert determinism/gate/voice; self-playtest in `tools/cxg_playtest.tscn`. The §7 bet (does composition+cohesion add generative value beyond authored fragments) is only partially borne out — see implementer verdict. Build-time net-mining deferred. Unverified.
