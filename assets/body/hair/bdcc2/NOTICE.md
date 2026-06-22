# BDCC2 rigged hairstyle meshes — © 2025 Rahi (MIT)

These `.glb` files are the **actual rigged hair meshes** mined from **BDCC2** by
**alexofp / Rahi**, used as-is per BDCC2's README ("use as a base for your own game").

- License: **MIT**, **Copyright (c) 2025 Rahi**. Full text: repo-root `NOTICE.md`.
- Upstream path: BDCC2 `Mesh/Parts/Hair/<Style>/<Name>.glb`.
- aeriea claims **no ownership**; these remain © 2025 Rahi under MIT.
- Only the GLB geometry + per-GLB `Skeleton3D` are mined. BDCC2's wigglebone addon and
  Kajiya-Kay hair shader are NOT used — aeriea drives the bones with its own spring-bone
  physics (`scripts/body/spring_bone.gd`), registered via `BodyRig.apply_hairstyle()` and
  the `HairLibrary` registry (`scripts/body/hair_library.gd`).
- Courtesy note: confirming the art reuse with Rahi is an outstanding nicety (the owner
  accepts the MIT art-license under attribution), not a blocker.

Files: Ponytail1–4, PonytailsBack, LongHair, LongCuteHair, LongChaosHair, LongSideHair,
LongHairBow, ShortHair, ShortHair2, SideHair, FerriHair, CoolBangsHair.
