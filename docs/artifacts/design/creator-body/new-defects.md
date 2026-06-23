# Creator + Body — new defects (for the in-progress creator+body design revision)

**Status:** RECORDED, NOT FIXED. User-reported defects from running the app,
lightly located in code. These fold into the IN-PROGRESS creator+body design
(see `SYNTHESIS.md` and the candidate/attack docs in this dir) — the design
revision should pick them up. No fix or design has been done here.

**Scope:** `scripts/body/character_creator.gd` (sculpt-mode glow overlay),
`scripts/body/body_rig.gd` + `scripts/body/proxy_morph.gd` (tongue proxy).

---

## Defects

1. **Tongue positioning is off.** — The tongue is part of the EYE/TEETH/TONGUE/
   GENITAL proxy mesh, not a facial expression target. Built in `body_rig.gd`
   `_build_proxy` (~lines 367-370, 775-802) and colored at ~line 923 ("tongue"
   case); morph-follows the body via `proxy_morph.gd`. `face_rig.gd:41-44` notes
   the tongue proxy has no expression target. Symptom: the tongue sits in the
   wrong place in the mouth. Would check the proxy piece's bind transform /
   morph-follow offset for the tongue surface vs. the jaw/mouth cavity.

2. **Sculpt-mode glow mesh stays at the neutral pose regardless of morph state.**
   — `character_creator.gd`: `_glow_base_pos` is captured ONCE at build from the
   neutral bind-pose mesh arrays (`_build_morph_drag`, lines 242-243), and the
   glow overlay is rebuilt from that same frozen array every hover
   (`_rebuild_glow_mesh`, lines 420-440, uses `_glow_base_pos` at 434). It is
   never re-read from the live morphed surface after a morph bake, so the glow
   tracks the neutral body, not the current one. (The build comment at ~lines
   244-248 even says it should be "rebuilt lazily on the next pick after a morph
   bake marks it dirty" — that dirty-rebuild is not happening for the overlay
   geometry.) Glow built at `_build_glow_overlay` lines 269-284.

3. **Sculpt-mode glow mesh clips through the body.** — `_rebuild_glow_mesh`
   (lines 420-440) stamps the overlay using the EXACT body vertex positions
   (`_glow_base_pos`, line 434) with no outward normal offset, and the material
   has `no_depth_test = false` (`_build_glow_overlay` line 281). Coincident geometry
   + depth testing → z-fighting / the glow reads as clipping through the body.
   Would address via a small outward offset along vertex normals and/or depth
   bias / `no_depth_test` for the overlay.
