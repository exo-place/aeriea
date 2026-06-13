# aeriea

**A place to be.** An embodied modern-life sandbox built around 100% immersion as the single non-negotiable design goal.

> The single non-negotiable goal: 100% immersion. Every design decision is evaluated against one test: does this preserve, or break, the player's immersion?

See [DESIGN.md](./DESIGN.md) for the full design doc.

## What this is

A place — somewhere worth being in, where you spend time, where you exist. Not a game to play. Not a content treadmill. A synthesis of:

- Parkour 2.0 movement (Mirror's Edge / Ghostrunner / Dying Light feel)
- Fashion-frame cosmetic depth with live toggles/sliders/items (VRChat-style, curated)
- KIM-grade NPCs with autonomous presence and memory
- Modern-life activity surfaces: clothing shops, bars, clubs, parks, concerts, cafes, gyms
- NSFW-first with SFW toggle
- Self-hosted multiplayer (Minecraft/Valheim model)
- Cross-platform: flat (KB+M / gamepad) + PCVR + Quest standalone

Built on Godot 4.x. Deep simulation layer following the `existence` deterministic-seeded-sim pattern. Rust via gdext for hot paths when needed.

## Development

```bash
# Enter dev shell (provides godot_4, rust toolchain, bun)
nix develop

# Open project in Godot editor (main scene: scenes/launcher.tscn)
godot4 project.godot

# Docs site
cd docs && bun install && bun run dev
```

## License

TBD.
