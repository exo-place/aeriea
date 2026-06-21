# Paperdoll & Modular Character Asset Packs

Status: research — decision-grade survey as of 2026-06-21
Scope: 2D layered/paperdoll and relevant 3D modular character packs for aeriea's visual channel. SFW is sufficient (NSFW capability noted only as bonus). Licenses verified against source pages — entries marked "unverified — confirm before use" where the source was not directly checkable.

---

## Summary Table

| Pack | Type | Views | Anim | License (verified?) | Class | aeriea-compat | Notes |
|---|---|---|---|---|---|---|---|
| Universal LPC Spritesheet / Generator | 2D pixel paperdoll generator | 4-dir | walk/idle/attack/etc. | GPL 3.0 + CC-BY-SA 3.0 + OGA-BY 3.0 (per-asset mix) — **verified via GitHub README** | copyleft (CC-BY-SA / GPL) or attribution-only (OGA-BY) | CC-BY-SA/GPL: only if aeriea is SA/GPL; OGA-BY assets: compatible with any aeriea license with attribution | Large composable art corpus. Individual layers span CC0 through GPL — must use CREDITS.csv per export. OGA-BY is the most permissive tier available. |
| LPC Medieval Fantasy Character Sprites (wulax/Sjölund) | 2D pixel modular spritesheet | 4-dir | walk/slash/thrust/bow/etc. | CC-BY-SA 3.0 + GPL 3.0 + OGA-BY 3.0 — **verified via OGA page** | copyleft/attribution-only (same as LPC above) | OGA-BY assets compatible with any aeriea license (attribution required) | 64×64px. Derives from LPC base; high quality, widely used. |
| Kenney Modular Characters | 2D vector/flat modular | front-facing only | none (static) | CC0 — **verified via kenney.nl asset page** | permissive | compatible with any aeriea license | 425 PNGs + 6 spritesheets + SVGs. Presentation/UI characters; not animated, limited to front view. Good for portraits/menus. |
| Kenney Roguelike Characters / Mini / Blocky | 2D pixel / 3D low-poly | top-down/isometric | varies | CC0 — **verified via kenney.nl** | permissive | compatible with any aeriea license | Many packs; mostly non-modular complete characters. |
| rgsdev — Free CC0 Modular Animated Vector Characters 2D | 2D vector modular | side-view | idle/walk/roll/jump/hit/death | CC0 — **verified via itch.io page** | permissive | compatible with any aeriea license | 2048×2048px canvas; white parts for in-engine colorization. Very limited body/hair variety (3 heads, 3 hairs, 7 eyes, 5 horns). Sidescroller orientation. |
| Quaternius — Modular Character Outfits (Fantasy) | 3D low-poly modular | any (3D) | retargetable | CC0 — **verified via itch.io page** | permissive | compatible with any aeriea license | 12 outfits, 62 parts; pairs with Universal Base Characters. Godot 4.3+ project included. Needs 3D pipeline. |
| Quaternius — Universal Base Characters | 3D low-poly | any (3D) | humanoid rig | CC0 — **verified via quaternius.com** | permissive | compatible with any aeriea license | 6 base models (Superhero/Regular/Teen ×M/F); 20 hairstyles; FBX + glTF. |
| KayKit — Character Pack: Adventurers | 3D low-poly | any (3D) | walk/run/idle/attack | CC0 — **verified via itch.io + GitHub** | permissive | compatible with any aeriea license | 5 characters, single 1024×1024 gradient atlas. |
| Mana Seed "Character Base" (Seliel the Shaper) | 2D pixel paperdoll | 4-dir | walk/run/jump/combat/farm (paged) | Custom (single-product commercial) — **verified via selieltheshaper.weebly.com/user-license.html** | restrictive | free demo commercially usable; full pack single-product-only, no redistribution, no AI/Web3 | Free demo (walk + combat + 2 hairstyles + 4 outfits) explicitly allowed commercial. Full system ($20+): 10 skin tones, farming/fishing/smithing animations, paper-doll layered, 64×64px on 512×512 sheets. High quality. Single-product constraint matters if aeriea ships expansions as separate products. |
| Mana Seed "Farmer Sprite System" (Seliel the Shaper) | 2D pixel paperdoll | 4-dir | extensive farm/social | Custom (single-product commercial) — **verified via selieltheshaper.weebly.com/user-license.html** | restrictive | same as Character Base above | Extends the Character Base with farming activities. |
| Pixeline — Character NPC Top Down Base | 2D pixel paperdoll | 4-dir | idle/walk/run/tool/combat/bow (4-dir each) | Custom (commercial OK, no redistribution) — **verified via itch.io page** | restrictive (proprietary permissive-ish) | commercially usable in a game; no redistribution. Check if "no redistribution" blocks open-source aeriea releasing art layers. | 2 bases (M/F) × 5 skin tones; 12 hairstyles; 42 clothing pieces; 14×29px on 34×36 grid. Paper-doll layered. Very complete. |
| edermunizz — Pixel Art Modular RPG Characters | 2D pixel modular | side-view? | walk/idle/jump/attack/death/etc. | CC BY 4.0 + custom restrictions (no redistribution of source files, no NFT/blockchain) — **verified via itch.io page** | permissive (with attribution) + partial restriction | CC-BY-compatible with any aeriea license; but source redistribution blocked (GPLv3 aeriea might be technically incompatible — verify) | 7 classes, 5 skin/eye/clothing colors, 5 hairstyles × 9 color vars; 36×36px frames. Aseprite source. $12 paid. |
| Sutemo — Female/Male Character Sprite (VN style) | 2D anime paperdoll (visual novel) | front-facing | static (VN presentation) | Custom permissive (commercial OK, no resale) — **verified via itch.io page** | restrictive (proprietary permissive-ish) | commercially usable; layered PSD | Free/name-your-price. Anime art style, layered PSD. Not suited for top-down/side movement. |
| Cyangmou — Pixel RPG Topdown Character Template | 2D pixel paperdoll | 3-dir (mirrored to 4) | idle/walk/run/combat/projectile (500+ frames) | Proprietary paid (Cyangmou's Itch.io Licence Agreement) — **verified via itch.io page** | restrictive | commercial use unknown — license agreement must be read in full before use | $19.99; ~33px characters; male + female bases × 4 skin tones; 3-dir with mirror. Paper-doll "mannequin" framing. High quality professional pixel art. |
| Pixel Frog — Treasure Hunters | 2D pixel characters | side-view platformer | walk/idle | CC0 — **verified via itch.io page** | permissive | compatible with any aeriea license | Not modular/paperdoll; complete pre-drawn characters. Good sidescroller style reference. |
| Pixel Frog — Tiny Swords | 2D pixel characters | side-view | walk/idle/attack | Custom permissive (no redistribution/resell) — **verified via itch.io search result** | restrictive | commercially usable in a game; no redistribution | Not modular. |
| 0x72 — pixeldudesmaker (generator tool) | 2D pixel generator | front+side? | output sprites | Custom permissive (commercial OK, no NFTs) — **verified via itch.io page** | permissive (non-copyleft) | compatible with any aeriea license; no attribution required | Generates low-res pixel dudes; limited customization. Free tool. |
| Cup Nooble — Sprout Lands | 2D pixel characters | 4-dir | walk/idle/run/farm | Custom, **non-commercial free / commercial paid** ($3.99) — **verified via itch.io page** | restrictive | paid tier: commercially usable, no redistribution; free tier: non-commercial only | Not modular/paperdoll; 6 animation types × 4 dirs = 24. Farming game style. |
| VRoid Studio (3D avatar generator) | 3D anime avatar generator | any (3D) | retargetable via VRM | Pixiv VRoid Terms (commercial OK for output; cannot build competing avatar-generation app without separate license) — **partially verified via VRoid FAQ** | proprietary (permissive for output) | output models usable in games commercially; Godot VRM importer exists (V-Sekai/godot-vrm, MIT) | Character output is per-creator-set VRM license. Application restriction: cannot ship an app that generates/outputs deformed VRoid meshes/textures without a pixiv license. Anime 3D style. |
| Ready Player Me | 3D realistic avatar SaaS | any (3D) | retargetable | **Service shut down January 2026** (acquired by Netflix Dec 2025) — **verified via search result** | N/A — defunct | not available | Do not use. |
| FLARE Avatar Clothes Spritesheet (OpenGameArt, Metapixelatron) | 2D pixel isometric modular | 8-dir isometric | 256 poses (32 frames × 8 dirs) | CC-BY-SA 3.0 — **verified via OGA page** | copyleft | only if aeriea is SA-licensed | Isometric, 8-directional; cloth shirt/pants/sandals/gloves as separate layers. Derives from FLARE/Clint Bellanger assets. |
| rubberduck — Customizable Character Pack (OGA) | 2D pixel modular | front-facing (from Kenney RPG Urban) | none | CC0 — **verified via OGA page** | permissive | compatible with any aeriea license | GIMP XCF with parts (skin/shoes/pants/tops/hair) + 16 sample combos. Limited; derived from Kenney RPG Urban Pack. |
| Sprit — Pixel Character Creator (Ranitaya Studios) | 2D pixel generator tool | varies | spritesheets | **License unverified — itch.io page does not state terms** — **unverified — confirm before use** | unknown | unknown | Free tool; generates pixel sprites with outfits/colors. Contact creator before commercial use. |

---

## Per-Pack Detail

### 1. Universal LPC Spritesheet & Character Generator

- **Source:** https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/ (live tool) · https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator (canonical repo) · https://github.com/sanderfrenken/Universal-LPC-Spritesheet-Character-Generator (active fork)
- **Type:** 2D pixel paperdoll spritesheet generator (web tool + raw spritesheets)
- **Views/angles:** 4-directional (up/down/left/right)
- **Animations:** walk, idle, combat (slash/thrust/spellcast/bow), hurt, die; sit/jump/run/emotes being expanded (issue open Jan 2025)
- **Customization axes:** body type, skin tone, hair (color + style), eyes, clothing (shirts, pants, shoes, belt, armor layers), weapons, accessories — hundreds of combinations
- **Art style:** 64×64px pixel art; cohesive LPC style
- **License (verified):** Per-asset mix: most core/clothing assets are dual-licensed **GPL 3.0 + CC-BY-SA 3.0**; many additional assets also carry **OGA-BY 3.0**; some are **CC0**. Source confirmed via README at https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator/blob/master/README.md — each generated export comes with a CREDITS.csv listing per-layer licenses.
- **aeriea-compat:** If using only OGA-BY or CC0 layers: compatible with any aeriea license (with attribution for OGA-BY). If using CC-BY-SA or GPL layers: aeriea must be CC-BY-SA or GPL (copyleft-gated). The generator lets you filter by license tier.
- **Notes:** The most mature, widely used paperdoll system for 2D pixel RPGs. Actively maintained under LiberatedPixelCup org (Jan 2025 issues show ongoing expansion). A license filter on the generator lets you restrict output to only OGA-BY/CC0 layers to avoid copyleft. This is the strongest overall ecosystem even with the licensing complexity. Not NSFW-capable by default (all content SFW).

### 2. LPC Medieval Fantasy Character Sprites (wulax / Johannes Sjölund)

- **Source:** https://opengameart.org/content/lpc-medieval-fantasy-character-sprites
- **Type:** 2D pixel modular spritesheets (layered clothing/armor over base character)
- **Views/angles:** 4-directional
- **Animations:** walk, slash, thrust, spellcast, bow, hurt, die
- **Customization axes:** body (human/skeleton), robes/leather/armor, weapons (sword/dagger/bow/spear), shields, combat dummy
- **Art style:** 64×64px pixel art, LPC style
- **License (verified):** CC-BY-SA 3.0 + GPL 3.0 + OGA-BY 3.0 (OGA-BY added Nov 2022). Verified via OGA page. Derives from original LPC base sprites; wulax cannot independently relicense away from SA.
- **aeriea-compat:** OGA-BY tier: attribution-only, compatible with any aeriea license. CC-BY-SA/GPL: copyleft-gated.
- **Notes:** High quality, cohesive with the broader LPC ecosystem. Pairs naturally with the generator above.

### 3. Kenney — Modular Characters

- **Source:** https://kenney.nl/assets/modular-characters · https://opengameart.org/content/modular-character-pack
- **Type:** 2D vector/flat modular (static, non-animated)
- **Views/angles:** Front-facing only (no back/side); limited to presentation / UI use
- **Animations:** None (static sprites)
- **Customization axes:** Body, hair, clothing, accessories — 425 PNGs + 6 spritesheets + SVG vectors; "hundreds of elements, thousands of combinations"
- **Art style:** Flat vector/cartoon; non-pixel
- **License (verified):** CC0. Confirmed via kenney.nl page and OGA page.
- **aeriea-compat:** Full compatibility with any aeriea license; no attribution required (though Kenney requests credit as courtesy).
- **Notes:** Best for menus, character select screens, portraits, or top-down overhead games where only top views matter. Not useful for side-scrolling or 4-directional walking since back/side views are absent. Stylistically distinct from pixel-art LPC. No animation frames.

### 4. rgsdev — Free CC0 Modular Animated Vector Characters 2D

- **Source:** https://rgsdev.itch.io/free-cc0-modular-animated-vector-characters-2d · https://opengameart.org/content/free-cc0-modular-animated-vector-characters-2d
- **Type:** 2D vector modular (separated animated body parts)
- **Views/angles:** Side-view (sidescroller orientation)
- **Animations:** idle, walk, roll, jump, hit, death
- **Customization axes:** 3 heads, 3 hairstyles, 7 eye variants, 5 horn variants, 8 mouth variants, body/hands/feet/wings, 3 weapons; white-colored parts for in-engine tinting
- **Art style:** Vector, 2048×2048px canvas; stylized/cartoon
- **License (verified):** CC0. Confirmed via itch.io page: "The license is CC0, so you can use any way you want, even commercially. Credits is not needed."
- **aeriea-compat:** Full compatibility with any aeriea license.
- **Notes:** Best free CC0 option for sidescroller animation. Limited variety out of the box (only 3 heads/hairs), but white-parts design means all colorization is code-side. Not top-down or 4-directional. Stylistically incompatible with LPC pixel art.

### 5. Quaternius — Universal Base Characters + Modular Character Outfits (Fantasy)

- **Sources:** https://quaternius.com/packs/universalbasecharacters.html · https://quaternius.itch.io/modular-character-outfits-fantasy
- **Type:** 3D low-poly modular
- **Views/angles:** Any (3D, camera-controlled)
- **Animations:** Humanoid rig with retargeting support; paired animation packs available
- **Customization axes:** 6 base models (Superhero/Regular/Teen × M/F); 20 hairstyles; customizable eye/skin color; 12 outfits with 62 modular parts, 3 texture variants each
- **Art style:** Low-poly 3D; stylized/cartoonish
- **License (verified):** CC0. Confirmed via quaternius.com and itch.io pages. "Free to use in personal, educational and commercial projects."
- **aeriea-compat:** Full compatibility with any aeriea license.
- **Notes:** Best free CC0 3D option. Godot 4.3+ project included in source files. Pairs with KayKit animations or any standard humanoid animation set. Requires a 3D pipeline in Godot. FBX + glTF formats.

### 6. KayKit — Character Pack: Adventurers

- **Source:** https://kaylousberg.itch.io/kaykit-adventurers · https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- **Type:** 3D low-poly characters (not modular outfit swapping per se, but animation-retargetable)
- **Views/angles:** Any (3D)
- **Animations:** Basic movement pack included; separate animation library available
- **Customization axes:** 5 character models + accessories (weapons/shields); single 1024×1024 gradient atlas (downscalable to 128×128)
- **Art style:** Low-poly 3D, stylized
- **License (verified):** CC0. Confirmed via itch.io page and GitHub README. "Compatible with pretty much any 3D game engine on the market."
- **aeriea-compat:** Full compatibility with any aeriea license.
- **Notes:** Mobile-optimized polygon counts. Best as foundation for a 3D-rendered visual channel. Less "modular clothing swap" and more "distinct pre-designed characters."

### 7. Mana Seed "Character Base" (Seliel the Shaper)

- **Source:** https://seliel-the-shaper.itch.io/character-base · License: https://selieltheshaper.weebly.com/user-license.html
- **Type:** 2D pixel paperdoll (paper-doll layered spritesheets)
- **Views/angles:** 4-directional
- **Animations:** walk, run, jump, push, combat (sword/shield), plus extended pages (farming, fishing, blacksmithing, ranged)
- **Customization axes:** 10 skin tones, multiple hairstyles/outfits, layered separate sheets per category; Aseprite source files
- **Art style:** ~32px height pixel art, 64×64px cells on 512×512 sheets; clean, highly professional
- **License (verified):** Custom "Mana Seed User License." Verified via license page directly. Key terms:
  - Allows commercial use in a single product per purchase
  - No redistribution or resale of assets (modified or not)
  - No NFT/Web3; no AI training
  - Free demo is explicitly commercially usable
- **aeriea-compat:** Free demo: commercially usable with any aeriea license. Full paid pack: single-product constraint — if aeriea ships DLC as separate SKUs, each needs its own purchase. Redistribution restriction means source layers cannot be bundled in an open-source repo's assets folder if it's publicly accessible (clarify with creator).
- **Notes:** Highest artistic quality 2D pixel paperdoll option in this survey. The most complete animation coverage. If aeriea is a single shipped game product (not a platform), this is the best-quality option, accepting the custom license terms.

### 8. Pixeline — Character NPC Top Down Base

- **Source:** https://pixeline-k.itch.io/character-spritesheet-32-px-walk-idle
- **Type:** 2D pixel paperdoll (layered spritesheets, paper-doll system)
- **Views/angles:** 4-directional
- **Animations:** idle, walk, run, holding items, flying-on-broom, picking up, watering, mining, swinging tools, sword swing, bow; all in 4 directions
- **Customization axes:** 2 bases (M/F) × 5 skin tones; 12 hairstyles; 42 clothing pieces (head/hair, chest, legs)
- **Art style:** Pixel art, 14×29px characters on 34×36 animation grid; small/cute style
- **License (verified):** Custom commercial license verified via itch.io page. Commercial use in games allowed. No redistribution/resale, no physical products.
- **aeriea-compat:** Usable in aeriea under any aeriea license as long as asset files are not redistributed in a publicly accessible form. If aeriea is fully open-source with assets in repo — clarify with creator whether "no redistribution" blocks this.
- **Notes:** Strong completeness for a small pixel size. 42 clothing pieces is impressive. Well-suited to farming/life-sim genre which overlaps aeriea's scope.

### 9. edermunizz — Pixel Art Modular RPG Characters

- **Source:** https://edermunizz.itch.io/pixel-art-modular-rpg-characters
- **Type:** 2D pixel modular (Aseprite layered, 7 character classes)
- **Views/angles:** Unclear from available info — likely side-view
- **Animations:** walk, idle, jump, attack, defend, damage, death, special
- **Customization axes:** 5 skin colors, 5 eye colors, 5 clothing colors, 5 hairstyles × 9 color variants; 7 classes + accessories (hoods, helmets, capes, shields)
- **Art style:** Pixel art, 36×36px frames on 360×288 spritesheets
- **License (verified):** CC BY 4.0 with additional restrictions (no redistribution of source files; no NFT/blockchain/P2E). Verified via itch.io page.
- **aeriea-compat:** CC-BY-compatible with any aeriea license (attribution required). Source-file redistribution restriction may conflict if aeriea ships source assets in an open repo — treat as binary asset, not source-distributable.
- **Notes:** Paid ($12 on sale / $20 regular). Rich class/color variety. Aseprite source files. The source-redistribution restriction is the key constraint.

### 10. Sutemo — Character Sprites (Visual Novel)

- **Sources:** https://sutemo.itch.io/female-character · https://sutemo.itch.io/male-character-sprite-for-visual-novel
- **Type:** 2D anime paperdoll (layered PSD, visual novel presentation)
- **Views/angles:** Front-facing only (VN style)
- **Animations:** Static (no walk cycles)
- **Customization axes:** Hair color/style, costumes; layered PSD for editing
- **Art style:** Anime, high resolution
- **License (verified):** Custom permissive. Verified via itch.io page. Commercial use allowed; no resale of the raw sprite. Attribution not required.
- **aeriea-compat:** Compatible with any aeriea license for in-game use. Not suitable for a character moving through a world.
- **Notes:** Free/PWYW. Best suited for dialogue portrait / character menu use, not in-world movement. Likely NSFW-compatible (layered PSD makes modifications straightforward, though the available packs are SFW).

### 11. Cyangmou — Pixel RPG Topdown Character Template

- **Source:** https://cyangmou.itch.io/pixel-rpg-character-template
- **Type:** 2D pixel paperdoll (3-directional mannequin system)
- **Views/angles:** 3-dir (mirrored to cover all 4 cardinal directions)
- **Animations:** idle, fighting stance, walk, run, attack (fist/light/heavy), hit, sit, death; 500+ frames total
- **Customization axes:** Male (Pete) + female (Cathe) bases × 4 skin tones; paperdoll framing for helmets/spears/oversize items
- **Art style:** Pixel art, ~33px character height
- **License (verified):** Proprietary paid ($19.99). Cyangmou's Itch.io Licence Agreement (linked from page). Restrictions confirmed: no redistribution as your own, no printed media, no physical product design basis. Commercial game use terms not fully clear in public summary — the full licence must be read before any use.
- **aeriea-compat:** **Unverified for commercial use — read the full licence agreement before use.** Mark as "confirm before use."
- **Notes:** Highly professional pixel art. Optimized for GameMaker sprite atlases but engine-agnostic PNG strips. The animation depth (500+ frames) is exceptional. If the licence confirms commercial game use, this is a premium quality option.

### 12. VRoid Studio (3D Avatar Generator)

- **Source:** https://vroid.com/en/studio · https://vroid.pixiv.help/hc/en-us/articles/4405813333657
- **Type:** 3D anime avatar generator (output: VRM files)
- **Views/angles:** Any (3D)
- **Animations:** Retargetable via VRM; Godot VRM importer (V-Sekai/godot-vrm, MIT licensed) supports Godot 4.1+
- **Customization axes:** Full anime character design (face, hair, body, clothing, accessories)
- **Art style:** 3D anime
- **License (partially verified):** VRoid Studio output is generally commercially usable per pixiv guidelines; each model can have per-creator VRM license settings. Key restriction from FAQ: cannot build an application that generates/outputs 3D models, avatars, or items consisting of deformed/combined VRoid meshes/textures without a separate pixiv license. Partial verification — full guidelines at https://vroid.com/en/studio/guidelines returned 403.
- **aeriea-compat:** Using VRoid to create aeriea's own character assets: likely fine for commercially shipping those assets baked into the game. Building a runtime avatar-generation system that outputs VRoid-derived meshes: requires a pixiv license. **Confirm full guidelines before building a user-facing avatar creator on top of VRoid assets.**
- **Notes:** Strong pipeline for anime-style 3D characters. V-Sekai VRM Godot plugin is actively maintained and MIT licensed. NSFW: VRoid models can be made NSFW by creators, but the Studio itself ships SFW. Individual model licenses on VRoid Hub set per-creator terms.

### 13. Ready Player Me

- **Status: DEFUNCT.** Acquired by Netflix December 2025; service shut down January 31, 2026. Do not use.

### 14. FLARE Avatar Clothes Spritesheet (OpenGameArt — Metapixelatron)

- **Source:** https://opengameart.org/content/flare-avatar-clothes-spritesheet-modular-isometric-fantasy-character-sprite
- **Type:** 2D pixel isometric modular spritesheet
- **Views/angles:** 8-directional isometric (256 poses: 32 frames × 8 directions)
- **Animations:** Full 8-dir movement/pose coverage
- **Customization axes:** Cloth shirt, pants, sandals, gloves as separate sprite files; modular isometric fantasy clothing
- **Art style:** Pixel art, isometric
- **License (verified):** CC-BY-SA 3.0. Confirmed via OGA page. Derives from FLARE/Clint Bellanger's original CC0 isometric hero; updated to CC-BY-SA to reflect derivative nature.
- **aeriea-compat:** Copyleft-gated — only if aeriea is CC-BY-SA-licensed. If aeriea is permissive or GPL, this is not compatible without relicensing (not possible since it derives from CC-BY-SA).
- **Notes:** Only option in this survey for isometric 8-directional modular clothing sprites. Significant if aeriea moves to isometric view.

### 15. 0x72 — pixeldudesmaker (generator tool)

- **Source:** https://0x72.itch.io/pixeldudesmaker
- **Type:** 2D pixel generator (web/desktop tool)
- **Views/angles:** Front-facing small pixel characters
- **Animations:** Output sprite sheets (basic)
- **Customization axes:** Heads, bodies, color palettes (Island Joy 16, Endesga 32, Zughy-32, others)
- **Art style:** Low-res pixel art (8-16px range)
- **License (verified):** Custom permissive. Confirmed via itch.io page: "permission is granted, free of charge, to any person, to use the assets generated with the software in any commercial or non-commercial projects." No NFT restriction. Attribution not required but appreciated.
- **aeriea-compat:** Compatible with any aeriea license.
- **Notes:** Very low-resolution / charming style. More suitable for NPCs or prototype than a hero-character paperdoll system. Not modular in the layered-clothing sense.

### 16. Cup Nooble — Sprout Lands Asset Pack

- **Source:** https://cupnooble.itch.io/sprout-lands-asset-pack
- **Type:** 2D pixel character sprites (not modular/paperdoll)
- **Views/angles:** 4-directional
- **Animations:** idle, walk, run, tilling, chopping, watering (24 animations total)
- **Customization axes:** None (pre-drawn characters, no layering)
- **Art style:** 16-bit pixel art, pastel colors, farming aesthetic
- **License (verified):** Free tier: non-commercial only, credit required. Paid tier ($3.99): commercial OK, no redistribution. Confirmed via itch.io page.
- **aeriea-compat:** Paid tier: commercially usable in any aeriea license. No redistribution blocks open-source asset distribution — same caveat as Pixeline. Not modular; limited visual-channel extensibility.
- **Notes:** Lovely aesthetic but wrong tool for a deep character system. Better as environment/NPC reference or supplemental.

### 17. Sprit — Pixel Character Creator (Ranitaya Studios)

- **Source:** https://ranitaya-studios.itch.io/sprit-pixel-character-creator
- **Type:** 2D pixel generator tool
- **License:** **Unverified — no license terms stated on the itch.io page as of research date. Confirm before use.**
- **Notes:** Free tool; outfits/colors/randomization. Contact creator directly before commercial use.

---

## Recommended Permissive (CC0 / OGA-BY) Subset

These are the packs where a permissive aeriea license (MIT, Apache, CC-BY) works cleanly:

**2D pixel / paperdoll pipeline:**

1. **Universal LPC Generator (OGA-BY/CC0 layers only)** — Use the license filter to restrict output to OGA-BY and CC0 assets only. This gives 4-directional walk/combat animation, a large clothing/hair corpus, and an established community art style. Requires per-export CREDITS.csv attribution. This is the backbone choice for a top-down 2D character visual channel.
2. **LPC Medieval Fantasy Sprites (wulax) — OGA-BY tier** — Pairs naturally with (1); adds armor/weapons as modular layers. Same attribution requirement.

**2D vector / sidescroller supplement:**

3. **rgsdev CC0 Modular Animated Vector Characters 2D** — If aeriea ever has a sidescroller or isometric secondary view; pure CC0, in-engine colorization, but very limited variety. Use as a prototype/secondary-view starting point, not primary paperdoll stock.

**3D pipeline (if aeriea adopts 3D rendering):**

4. **Quaternius Universal Base Characters + Modular Outfits** — Best CC0 3D option. Godot 4.3+ project included. 62 outfit parts across 12 fantasy themes, CC0.
5. **KayKit Adventurers** — CC0 supplement for KayKit characters; pairs well with Quaternius if mixing styles is acceptable (both are low-poly stylized).

**Paid but high-quality, commercially usable under any aeriea license:**

6. **Mana Seed Character Base (free demo tier)** — The free demo is explicitly commercially usable with no attribution requirement. For a single-product shipping game, the full paid pack ($20) is the highest-quality 2D pixel paperdoll option in this survey. Custom license (not copyleft, not open).

---

## Art-Style Consistency Caveat

Aggregating multiple packs from this list will produce visual incoherence unless constrained to a style-compatible subset. The major style families present here are:

- **LPC pixel art (64×64px):** Universal LPC Generator, LPC Medieval Fantasy Sprites, LPC-derived assets — all share a unified style and can be safely mixed
- **Small-pixel (14–32px) life-sim:** Mana Seed, Pixeline, Sprout Lands — compatible with each other in size/aesthetic; incompatible with LPC's larger frames
- **Vector/flat:** Kenney Modular Characters — conflicts with all pixel art options; use only for UI/menus, not in-world characters
- **Vector 2D animated:** rgsdev CC0 Modular — conflicts with pixel art options; sidescroller-only
- **3D low-poly:** Quaternius, KayKit — visually consistent with each other; requires 3D pipeline; incompatible with 2D sprite options

**Practical implication:** Pick one family and stick to it. The most defensible choices:
- **Pure permissive 2D:** LPC ecosystem (OGA-BY/CC0 layers) — widest art corpus, active community, cohesive style.
- **High-quality 2D with custom license:** Mana Seed — best pixel art, single-product commercial license.
- **Pure permissive 3D:** Quaternius + KayKit — CC0, Godot-ready, renders from any angle.

Do not mix, e.g., Mana Seed's small-pixel style with LPC's 64×64 frames in the same character view — the inconsistency will read as unprofessional.

---

## License Classification Quick Reference

| License | Class | aeriea-compat (permissive aeriea) | aeriea-compat (GPL aeriea) |
|---|---|---|---|
| CC0 | permissive | yes | yes |
| OGA-BY 3.0 | permissive (attribution) | yes (credit required) | yes (credit required) |
| CC-BY 4.0 | permissive (attribution) | yes (credit required) | yes (credit required) |
| CC-BY-SA 3.0/4.0 | copyleft | NO — aeriea must be SA | yes (if aeriea is CC-BY-SA) |
| GPL 3.0 | copyleft | NO — aeriea must be GPL | yes (if aeriea is GPL) |
| Custom permissive (Sutemo, Pixeline, Pixel Frog) | proprietary-permissive | yes (in-game use); redistribution restrictions apply | yes (same caveat) |
| Custom single-product (Mana Seed) | proprietary | yes for single product; no for platform/expansions-as-SKUs | yes (same caveat) |
| Proprietary paid (Cyangmou) | proprietary | unverified — read full licence | unverified — read full licence |
| VRoid output | proprietary-permissive | yes for baked assets; cannot build competitor generator | yes (same caveat) |
| CC BY-NC-SA (Ready Player Me) | N/A | N/A — service defunct | N/A |

---

## Provenance Concerns

- **LPC composite assets:** Because the generator draws from dozens of contributors, some assets may have GPL 3.0 in their license stack. If aeriea is permissive (MIT/Apache), restrict the generator's output to OGA-BY + CC0 tiers only. The CREDITS.csv export from the generator lists each layer's license — this must be checked for every generated export.
- **FLARE sprites derive from LPC base:** Metapixelatron correctly escalated the license to CC-BY-SA after incorporating CC-BY-SA source material; this is a well-documented derivative chain.
- **Kenney Modular Characters on OGA:** Listed there by Kenney themselves; CC0 confirmed both at source (kenney.nl) and OGA.
- **Ready Player Me shutdown:** Confirmed via search result (December 2025 Netflix acquisition, January 2026 shutdown). Any existing integrations should be removed.
