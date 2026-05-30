# TODO

## Immediate

- Open `project.godot` in Godot 4.x editor; verify it loads.
- Run `bun install` in `docs/` once nix shell is active (needed before vitepress works).
- Fill `docs/.vitepress/config.ts` and `docs/index.md` for design docs site (currently scaffolded but empty).
- Wire up git hooks path: `git config core.hooksPath .githooks`

## First prototype: movement

Parkour 2.0 movement is load-bearing per DESIGN.md (the per-second dopamine engine). First prototype: get a player capsule moving fluently with carve/momentum feel in a basic level. Reference: Mirror's Edge, Ghostrunner, Redout 2 (for the carving feel even though it's vehicular).

## Open design questions (from DESIGN.md)

- Project name (aeriea is tentative; pronounced "area")
- Per-activity design (each item in Activity surfaces needs its own loop/dopamine/authoring pass)
- Persistence model detail (deterministic action log + per-server state; specifics TBD)
- Sources of change priority (which sources the project leans on hardest)
- Specific power-fantasy enumeration (movement/cosmetics/NPCs/variety/lived-history/environment-authoring committed; more if needed)
- Content authoring strategy detail

## Cross-references

- `~/git/rhizone/playmate` — body/transformation/tag system (`frond`); revisit during refining stage as cross-reference, not as initial dependency
- `~/git/paragarden/existence` — simulation-underneath-rendering pattern, ~67k LOC working code
- [ ] propagate ecosystem-common region (Ecosystem Design Principles) from github-io CLAUDE.md — see tooling/propagate-claude-md.sh

- [ ] Propagate ECOSYSTEM RULES region: removed main-session-only orchestrator/delegation rules (now in a main-session hook, see rhizone/github-io). This repo was dirty during the 2026-05-30 ecosystem propagation — run `tooling/propagate-claude-md.sh` from github-io against this repo's CLAUDE.md and commit when the tree is clean.
