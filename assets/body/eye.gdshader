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

varying vec3 v_model_normal;   // outward surface normal in MODEL space

// cheap value-noise hash for veins / iris break-up (deterministic; no texture)
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
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
		float fibres = sin(ang * pattern_scale) * 0.5 + 0.5;
		fibres = mix(fibres, hash21(vec2(ang * 12.0, 1.0)), 0.35);
		vec3 iris = mix(iris_inner, iris_color, t);
		iris *= 1.0 - pattern_strength * (fibres - 0.5) * (0.4 + 0.6 * t);
		col = mix(col, iris, in_iris);

		// limbal ring: dark rim just inside the iris/sclera boundary
		float lim = smoothstep(iris_radius * (1.0 - limbal_width), iris_radius, theta);
		col = mix(col, limbal_color, lim * in_iris);
	}

	// pupil: an ellipse in the tangent plane (aspect<1 => vertical slit).
	float pupil_r = pupil_size * iris_radius;       // pupil half-angle
	vec2 pl = vec2(local.x / max(pupil_aspect, 0.001), local.y);
	float pr = asin(clamp(length(pl), 0.0, 1.0));   // angular radius of this fragment
	float in_pupil = (1.0 - smoothstep(pupil_r, pupil_r + 0.03, pr)) * in_iris;
	col = mix(col, pupil_color, in_pupil);

	ALBEDO = col;
	ROUGHNESS = eye_roughness;
	SPECULAR = eye_specular;
	METALLIC = 0.0;
}
