// Water: gently waving, see-through near the shore and deep blue further
// down, reflecting the sky (fresnel), with sparkles from the sun and foam
// where it meets the ground. Caves keep their darkness (block sky light).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_nearest_mipmap_anisotropic;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float daylight = 1.0;
uniform float min_light = 0.015;   // (caves with no light are very dark)
uniform float waves = 1.0;               // 0 = flat (low settings)
uniform float fancy = 1.0;               // 0 = plain (no depth tint, foam, refraction)
uniform vec3 shallow : source_color = vec3(0.2, 0.62, 0.66);
uniform vec3 deep : source_color = vec3(0.03, 0.16, 0.32);
uniform vec3 sky_color : source_color = vec3(0.55, 0.72, 0.95);
uniform float rain = 0.0;

varying float v_sky;
varying float v_lamp;
varying vec3 v_world;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float height(vec2 p, float t) {
	return noise(p * 0.35 + vec2(t * 0.25, t * 0.18)) * 0.6 + noise(p * 0.9 - vec2(t * 0.4, -t * 0.3)) * 0.4;
}

void vertex() {
	v_sky = COLOR.r;
	v_lamp = COLOR.g;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world = w;
	if (NORMAL.y > 0.5 && waves > 0.0) {
		VERTEX.y += (height(w.xz, TIME) - 0.5) * 0.08 * waves;
	}
}

void fragment() {
	vec4 tex = texture(atlas, UV);
	float t = TIME;
	// Ripples: bend the normal using the wave height (plus rain drops).
	vec2 p = v_world.xz;
	float e = 0.15;
	float h0 = height(p, t);
	vec3 n = normalize(vec3((h0 - height(p + vec2(e, 0.0), t)) * 2.2, 1.0, (h0 - height(p + vec2(0.0, e), t)) * 2.2));
	if (rain > 0.0) {
		vec2 cell = floor(p * 3.0);
		float ph = fract(t * 1.3 + hash(cell));
		float ring = 1.0 - smoothstep(0.0, 0.08, abs(length(fract(p * 3.0) - 0.5) - ph * 0.5));
		n.xz += ring * (1.0 - ph) * rain * 0.6;
		n = normalize(n);
	}
	NORMAL = mix(NORMAL, normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz), waves * 0.8);
	float sky = pow(0.8, 15.0 - v_sky * 15.0);
	// How deep the water is behind this pixel (soft shores, deeper = bluer).
	float depth_amount = 0.5;
	float foam = 0.0;
	if (fancy > 0.5) {
		float d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
		vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
		float scene = -vp.z / vp.w;
		float water_d = -VERTEX.z;
		float through = max(scene - water_d, 0.0);
		if (d > 0.0) {   // (no depth with some edge smoothing modes: just look medium-deep)
			depth_amount = 1.0 - exp(-through / 5.0);
			foam = (1.0 - smoothstep(0.0, 0.4, through)) * smoothstep(0.85, 1.0, v_sky);
			foam *= 0.5 + 0.5 * noise(p * 4.0 + t * 0.5);
		}
	}
	vec3 body = mix(shallow, deep, depth_amount) * (0.35 + 0.65 * sky);
	// The sky's reflection, stronger at low angles (fresnel).
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 refl = sky_color * sky;
	vec3 col = mix(body, refl, clamp(fres * 0.85 + 0.08, 0.0, 0.9));
	col = mix(col, vec3(0.95, 0.98, 1.0), foam * 0.7);
	col *= 0.85 + 0.3 * dot(tex.rgb, vec3(0.333));   // a hint of the water picture's pattern
	float lamp = pow(0.8, 15.0 - v_lamp * 15.0);
	vec3 glow = col * (vec3(1.0, 0.8, 0.5) * lamp * 0.5 + vec3(min_light));
	if (fancy > 0.5) {
		// See-through: what's under the water (wobbling a little) shows in the
		// shallows, fading to the water's own color where it's deep.
		vec3 under = textureLod(screen_tex, SCREEN_UV + n.xz * 0.015 * (1.0 - fres), 0.0).rgb;
		float cov = clamp(0.18 + depth_amount * 0.8 + fres * 0.45 + foam * 0.6, 0.0, 1.0);
		ALBEDO = col * cov;
		EMISSION = under * mix(vec3(1.0), shallow * 1.5, 0.35 + depth_amount * 0.4) * (1.0 - cov) + glow * cov;
		ALPHA = 1.0;
	} else {
		ALBEDO = col;
		EMISSION = glow;
		ALPHA = tex.a * 0.85;
	}
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}

void light() {
	float reach = LIGHT_IS_DIRECTIONAL ? smoothstep(0.55, 0.95, v_sky) : smoothstep(0.0, 0.3, v_lamp);
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR * reach / PI * 0.6;
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(clamp(dot(NORMAL, h), 0.0, 1.0), 220.0) * ATTENUATION * LIGHT_COLOR * reach * 4.0;   // sun sparkles
}
