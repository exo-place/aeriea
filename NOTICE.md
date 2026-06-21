# NOTICE — third-party attributions

aeriea incorporates code and assets from third parties. This file records the
attributions required by their licenses.

## BDCC2 — facial expression rig (MIT)

The facial **expression rig** under `scripts/body/face/` is ported (Path A: mined
as a replaceable surface behind aeriea's own `apply_expression(ExprState)` seam)
from **BDCC2** by **alexofp / Rahi**.

- Upstream: BDCC2 `Game/Doll/FaceAnimator/` (`face_animator.gd`,
  `FaceGestureBase.gd`, `Util/FaceValue.gd`, `Util/FaceAnimatorOverrideProfile.gd`,
  `Gestures/Blinking.gd`, `Gestures/LookDir.gd`, `Gestures/Talking.gd`).
- License: **MIT**, **Copyright (c) 2025 Rahi**.

Ported files (`scripts/body/face/face_value.gd`, `face_gesture.gd`,
`face_override_profile.gd`, `face_rig.gd`, `gestures/blinking.gd`,
`gestures/look_wander.gd`, `gestures/talking.gd`) carry the copyright notice in
their headers. Per the MIT license, the full text follows:

```
MIT License

Copyright (c) 2025 Rahi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Scope note (Path A discipline):** only the rig CODE is mined. BDCC2's `Doll` /
`BaseCharacter` hub, `GlobalRegistry`, skin compositor (`MyLayeredTexture`), and
`LayeredAnimPlayer` are NOT adopted. No BDCC2 **art** (head GLB, baked face
blendshape clips, textures) is used — the rig drives aeriea's own CC0 MakeHuman
head. The conversational-emotion adapter (`gestures/affect_expression.gd`) and
the ExprState seam are aeriea-authored, not from BDCC2.

## Gaze (`scripts/body/face/gaze_rig.gd`) — NOT third-party

The gaze rig is aeriea-authored, backed by Godot's **built-in** `LookAtModifier3D`
pattern (engine-native since 4.4). **No BDCC2 code is mined here** — BDCC2's
`doll.gd` only showed the chest->neck->head wiring pattern, which is an idea, not
code. Listed here only to record that this file is deliberately attribution-free.

## MakeHuman — base mesh, rig, proxies, targets (CC0-1.0)

aeriea's body/head mesh, skeleton, proxies, and morph targets derive from
**MakeHuman** (makehumancommunity/makehuman v1.3.0), released **CC0-1.0**. See
`assets/body/base_body.manifest.json` and `assets/body/base_body_proxies.index.json`.
