// Procedural eye material for the low-poly eye proxy (eyes/teeth/tongue/genitals
// multi-surface mesh — eye surface only). RESOLUTION-INDEPENDENT: the iris, pupil,
// limbal ring and sclera are computed analytically in the fragment shader, so there
// is no baked texture and no fixed pixel resolution.
//
// We key off the MODEL-SPACE SURFACE NORMAL rather than UVs: an eyeball is a sphere,
// and its visible front (where the iris/pupil belong) is the cap whose outward normal
// points along the eye's gaze. Both eyeballs share one mesh, but both gaze the same
// way (forward, +Z in head-local space), so a single gaze axis selects the iris cap on
// each eye independently — no per-eye UV-island bookkeeping, robust to the proxy's
// sphere-unwrap seams. The angle from the gaze axis drives concentric rings:
// sclera -> limbal ring -> iris (radial fibre striation) -> pupil. Glossy/wet via low
// roughness + strong specular.
//
// Defaults reproduce a natural warm-brown eye (the prior baked brown_eye.png look).
// All visual knobs are uniforms (see EYE_PARAMS_DEFAULT in body_rig.gd).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// --- gaze / framing ---------------------------------------------------------------
// Model-space direction the eyes look (the iris cap centre). +Z is the head's forward.
uniform vec3  gaze_dir = vec3(0.0, 0.0, 1.0);
// --- iris / pupil -----------------------------------------------------------------
uniform vec3  iris_color : source_color = vec3(0.36, 0.20, 0.09);  // warm brown
uniform vec3  iris_inner : source_color = vec3(0.20, 0.10, 0.04);  // darker toward pupil
uniform float iris_radius   = 0.62;   // iris half-angle (radians) from the gaze axis
uniform float pattern_strength = 0.55; // radial fibre/striation contrast
uniform float pattern_scale    = 64.0; // number of angular fibres
// --- pupil ------------------------------------------------------------------------
uniform vec3  pupil_color : source_color = vec3(0.02, 0.02, 0.02);
uniform float pupil_size  = 0.34;   // pupil radius as a fraction of iris radius
// pupil_aspect: 1.0 = round; <1 narrows horizontally => vertical slit (cat/reptile);
// >1 = horizontal slit (goat). The pupil is an ellipse in the gaze-tangent plane.
uniform float pupil_aspect = 1.0;
// --- limbal ring (dark rim at the iris/sclera boundary) ---------------------------
uniform vec3  limbal_color : source_color = vec3(0.06, 0.03, 0.02);
uniform float limbal_width = 0.14;  // fraction of iris radius occupied by the ring
// --- sclera -----------------------------------------------------------------------
uniform vec3  sclera_color : source_color = vec3(0.93, 0.90, 0.88);
uniform vec3  vein_color   : source_color = vec3(0.78, 0.45, 0.42);
uniform float vein_strength = 0.12;  // subtle red veining toward the sclera rim
// --- material / wetness -----------------------------------------------------------
uniform float eye_roughness = 0.06;  // wet, glossy cornea
uniform float eye_specular  = 0.9;
// --- catch-light (procedural corneal highlight) -----------------------------------
// A small bright glint baked into the albedo so the eye reads "wet/alive" even under
// flat preview lighting (the engine specular needs a light to glint; this does not).
// Placed up-and-temporal of the iris centre, in the gaze-tangent plane. It is a LOOK
// cue, not a physical reflection — kept subtle so it doesn't fight engine specular.
uniform vec3  catchlight_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float catchlight_strength = 0.55;  // 0 = off
uniform float catchlight_size     = 0.10;  // angular radius (fraction of iris_radius)
uniform vec2  catchlight_offset   = vec2(-0.35, 0.42); // tangent-plane (x=temporal, y=up)

varying vec3 v_model_normal;   // outward surface normal in MODEL space

// cheap value-noise hash for veins / iris break-up (deterministic; no texture)
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 2D value noise (smoothed hash) for the iris crypt/furrow break-up — still texture-free.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_model_normal = normalize(NORMAL);   // object/model-space normal (pre view xform)
}

void fragment() {
	vec3 n = normalize(v_model_normal);
	vec3 g = normalize(gaze_dir);

	// angle of this fragment's normal from the gaze axis: 0 at the iris centre.
	float ndg = clamp(dot(n, g), -1.0, 1.0);
	float theta = acos(ndg);                       // 0 .. PI

	// tangent-plane coordinate for angular fibres + slit pupil orientation.
	vec3 up = abs(g.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 tx = normalize(cross(up, g));             // local "horizontal"
	vec3 ty = cross(g, tx);                        // local "vertical"
	vec2 local = vec2(dot(n, tx), dot(n, ty));     // direction within the tangent plane
	float ang = atan(local.y, local.x);

	vec3 col = sclera_color;

	// subtle veining on the sclera (radial streaks, stronger away from the iris)
	float scl_t = smoothstep(iris_radius, 1.4, theta);
	float vein = scl_t * pow(max(0.0, sin(ang * 9.0 + hash21(local * 7.0) * 6.28)), 8.0);
	col = mix(col, vein_color, vein * vein_strength);

	// iris band: theta in [0, iris_radius]
	float in_iris = 1.0 - smoothstep(iris_radius, iris_radius + 0.06, theta);
	if (in_iris > 0.0) {
		float t = clamp(theta / iris_radius, 0.0, 1.0);   // 0 centre .. 1 at limbus
		// base radial gradient: darker (iris_inner) toward the pupil, brighter (iris_color)
		// toward the limbus, with a gentle gamma so the mid-iris carries the most colour.
		vec3 iris = mix(iris_inner, iris_color, pow(t, 0.7));

		// FIBRES — two angular octaves: fine radial striations + a coarser furrow set,
		// both jittered per-spoke so they don't read as a clean comb. Modulated by t so
		// they fade out at the pupil edge and intensify toward the collarette/limbus.
		float spoke_jit = hash21(vec2(floor(ang * pattern_scale), 3.0));
		float fine = sin(ang * pattern_scale + spoke_jit * 6.28) * 0.5 + 0.5;
		float coarse = sin(ang * (pattern_scale * 0.28) + 1.3) * 0.5 + 0.5;
		float fibres = mix(fine, coarse, 0.4);
		fibres = mix(fibres, hash21(vec2(ang * 17.0, 1.0)), 0.25);
		// radial weight: weakest near the pupil, a bright collarette ring at ~0.4t.
		float collarette = exp(-pow((t - 0.42) * 4.5, 2.0));
		float fweight = (0.30 + 0.70 * t) + 0.5 * collarette;
		iris *= 1.0 - pattern_strength * (fibres - 0.5) * fweight;

		// CRYPTS — soft cellular dark pits (Fuchs' crypts) via value noise in (ang, t),
		// strongest in the mid-iris, giving the surface depth instead of a flat disc.
		float crypt = vnoise(vec2(ang * 9.0, t * 6.0));
		crypt = smoothstep(0.55, 0.95, crypt) * (0.6 + 0.4 * collarette);
		iris *= 1.0 - 0.30 * crypt;

		col = mix(col, iris, in_iris);

		// limbal ring: a defined dark rim at the iris/sclera boundary (sharper inner edge,
		// soft outer falloff into the sclera) so the iris reads as a crisp disc.
		float lim_in = smoothstep(iris_radius * (1.0 - limbal_width), iris_radius * (1.0 - limbal_width * 0.4), theta);
		float lim = lim_in * in_iris;
		col = mix(col, limbal_color, lim);
	}

	// pupil: an ellipse in the tangent plane (aspect<1 => vertical slit). A soft dark
	// halo just outside the hard pupil edge gives it a defined, set-in look.
	float pupil_r = pupil_size * iris_radius;       // pupil half-angle
	vec2 pl = vec2(local.x / max(pupil_aspect, 0.001), local.y);
	float pr = asin(clamp(length(pl), 0.0, 1.0));   // angular radius of this fragment
	float pupil_halo = (1.0 - smoothstep(pupil_r, pupil_r + 0.10 * iris_radius, pr)) * in_iris;
	col = mix(col, pupil_color * 0.5, pupil_halo * 0.5);
	float in_pupil = (1.0 - smoothstep(pupil_r, pupil_r + 0.015, pr)) * in_iris;
	col = mix(col, pupil_color, in_pupil);

	// CATCH-LIGHT — a small bright corneal glint baked into albedo (reads "wet/alive"
	// without depending on a scene light). Positioned in the gaze-tangent plane.
	vec2 cl = local - catchlight_offset * iris_radius;
	float cl_r = length(cl);
	float clr = catchlight_size * iris_radius;
	float glint = (1.0 - smoothstep(clr * 0.4, clr, cl_r)) * catchlight_strength;
	col = mix(col, catchlight_color, clamp(glint, 0.0, 1.0));

	ALBEDO = col;
	ROUGHNESS = eye_roughness;
	SPECULAR = eye_specular;
	METALLIC = 0.0;
}
