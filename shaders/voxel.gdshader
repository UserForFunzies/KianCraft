// Terrain shader, lit by the real sun, moon and torches (with shadows), plus
// the game's own block light so caves stay dark and lamps glow.
//
// Vertex color from the chunk mesher:
//   COLOR.r = sunlight level reaching this spot (0-1; caves are low)
//   COLOR.g = lamp light level (0-1)
//   COLOR.b = ambient occlusion in corners (0-1)
//   COLOR.a = how much it sways in the wind (1 = not at all, 0.7 leaves, 0.3 plant tops)
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_nearest_mipmap_anisotropic;
uniform float daylight = 1.0;            // (kept for the old look and the menus)
uniform float min_light = 0.015;   // (caves with no light are very dark)
uniform float lamp_glow = 1.0;           // block-light glow (lower when real torch lights are on)
uniform float wind = 1.0;                // 0 = no swaying
uniform float wetness = 0.0;             // rain: darker, shinier
uniform float snow_cover = 0.0;          // snow storms dust the tops of blocks white
uniform vec3 lamp_color : source_color = vec3(1.0, 0.78, 0.48);
uniform float surface = 0.0;             // bumpy, shiny surfaces (High/Ultra)
uniform float variety = 0.0;             // natural blocks vary in color across the world
uniform float tile_count = 160.0;
// One pixel per tile. Row 0: bumpiness, roughness, metal, ore glints. Row 1: color variety.
uniform sampler2D materials : filter_nearest;

varying float v_sky;
varying float v_lamp;
varying float v_ao;
varying vec3 v_world;
varying flat float v_plant;   // grass and flowers (no snow on them)

void vertex() {
	v_sky = COLOR.r;
	v_lamp = COLOR.g;
	v_ao = COLOR.b;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world = w;
	v_plant = (COLOR.a < 0.99 && abs(COLOR.a - 0.7) > 0.02) ? 1.0 : 0.0;
	float sway = 1.0 - COLOR.a;
	if (sway > 0.08 && wind > 0.0) {
		float t = TIME * 1.6;
		float gust = 0.6 + 0.4 * sin(t * 0.37 + w.x * 0.05 + w.z * 0.03);
		vec2 off = vec2(sin(t + w.x * 0.9 + w.z * 0.4), cos(t * 0.8 + w.z * 0.8 + w.x * 0.3)) * 0.06 * sway * wind * gust;
		VERTEX.xz += off;
		VERTEX.y += sin(t * 1.3 + w.x + w.z) * 0.015 * sway * wind;
	}
}

float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }
float vhash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(vhash(i), vhash(i + vec2(1, 0)), u.x), mix(vhash(i + vec2(0, 1)), vhash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec4 tex = texture(atlas, UV);
	if (tex.a < 0.5) {
		discard;  // see-through pixels in leaves and glass
	}
	vec3 albedo = tex.rgb;
	float tile = floor(UV.x * tile_count);
	vec2 muv = vec2((tile + 0.5) / tile_count, 0.25);
	vec4 mat = texture(materials, muv);
	float rough = 0.92;
	float metal = 0.0;
	if (variety > 0.0) {
		// Big soft patches: meadows go a little more golden here, greener there;
		// stone a bit warmer or cooler. (Stops the world looking stamped out.)
		float amt = texture(materials, vec2(muv.x, 0.75)).r * variety;
		vec2 wp = v_world.xz + v_world.y * 0.3;
		float n1 = vnoise(wp * 0.035) * 0.65 + vnoise(wp * 0.11) * 0.35;
		vec3 warm = albedo * vec3(1.06, 1.02, 0.9);
		vec3 cool = albedo * vec3(0.9, 0.98, 1.02);
		albedo = mix(albedo, mix(cool, warm, n1), amt * 0.6);
		albedo *= 1.0 + (vnoise(wp * 0.6) - 0.5) * 0.08 * amt;
	}
	if (surface > 0.0) {
		float fade = 1.0 - smoothstep(18.0, 46.0, -VERTEX.z);
		// Bumps from the picture itself (lighter = raised), lit by the real sun.
		vec2 tsz = vec2(textureSize(atlas, 0));
		vec2 texel = 1.0 / tsz;
		vec2 tile_w = vec2(1.0 / tile_count, 1.0);
		vec2 local = vec2(UV.x * tile_count - tile, UV.y);
		vec2 dx = dFdx(UV);
		vec2 dy = dFdy(UV);
		vec2 step_l = vec2(texel.x * tile_count, texel.y);
		vec2 lx0 = vec2(fract(local.x - step_l.x), local.y);
		vec2 lx1 = vec2(fract(local.x + step_l.x), local.y);
		vec2 ly0 = vec2(local.x, fract(local.y - step_l.y));
		vec2 ly1 = vec2(local.x, fract(local.y + step_l.y));
		float hx0 = lum(textureGrad(atlas, vec2((tile + lx0.x) / tile_count, lx0.y), dx, dy).rgb);
		float hx1 = lum(textureGrad(atlas, vec2((tile + lx1.x) / tile_count, lx1.y), dx, dy).rgb);
		float hy0 = lum(textureGrad(atlas, vec2((tile + ly0.x) / tile_count, ly0.y), dx, dy).rgb);
		float hy1 = lum(textureGrad(atlas, vec2((tile + ly1.x) / tile_count, ly1.y), dx, dy).rgb);
		vec2 grad = vec2(hx1 - hx0, hy1 - hy0) * mat.r * surface * fade * 1.6;
		vec3 tn = normalize(vec3(-grad.x, -grad.y, 1.0));
		// A tangent frame from screen-space derivatives (the mesh has no tangents).
		vec3 dp1 = dFdx(VERTEX);
		vec3 dp2 = dFdy(VERTEX);
		vec3 N = normalize(NORMAL);
		vec3 dp2perp = cross(dp2, N);
		vec3 dp1perp = cross(N, dp1);
		vec3 T = dp2perp * dx.x + dp1perp * dy.x;
		vec3 B = dp2perp * dx.y + dp1perp * dy.y;
		float invmax = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-12));
		NORMAL = normalize(mat3(T * invmax, B * invmax, N) * tn);
		rough = mix(0.92, mat.g, surface);
		metal = mat.b * surface;
		// Ore specks glint like real metal in your torchlight.
		float sat = max(albedo.r, max(albedo.g, albedo.b)) - min(albedo.r, min(albedo.g, albedo.b));
		float glint = mat.a * smoothstep(0.14, 0.32, sat) * surface;
		metal = max(metal, glint * 0.85);
		rough = mix(rough, 0.28, glint);
	}
	// Snow settles on top faces in the open.
	float up = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0);
	float snow = snow_cover * smoothstep(0.6, 0.9, up) * smoothstep(0.85, 1.0, v_sky) * (1.0 - v_plant);
	albedo = mix(albedo, vec3(0.92, 0.95, 1.0), snow * 0.85);
	// Wet ground in the rain: darker, with shiny highlights.
	float wet = wetness * smoothstep(0.85, 1.0, v_sky) * (1.0 - snow) * (1.0 - v_plant);
	albedo *= 1.0 - wet * 0.35;
	ALBEDO = albedo;
	ROUGHNESS = mix(rough, 0.25, wet * (0.4 + 0.6 * up));
	METALLIC = metal;
	SPECULAR = mix(0.2 + (0.92 - rough) * 0.4, 0.6, wet);
	// Light from the sky (ambient) only reaches where the sky does, and corners are darker.
	float sky = pow(0.8, 15.0 - v_sky * 15.0);
	AO = clamp(sky * v_ao, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.25;
	// Block light (torches, lamps, lava, glowing plants) as a warm glow, so it
	// works even with real lights turned off.
	float lamp = pow(0.8, 15.0 - v_lamp * 15.0);
	EMISSION = albedo * (lamp_color * lamp * lamp_glow + vec3(min_light)) * v_ao;
}

void light() {
	// The sun and moon can't reach into caves: scale them by how much sky
	// light gets here (shadows on top of that when they're turned on).
	// Torch lights only reach where the game's own block light spreads, so
	// they never shine through walls.
	float reach = LIGHT_IS_DIRECTIONAL ? smoothstep(0.55, 0.95, v_sky) : smoothstep(0.0, 0.3, v_lamp);
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	// A little wrap so shaded sides aren't flat black (like shader packs).
	float wrap = clamp((dot(NORMAL, LIGHT) + 0.25) / 1.25, 0.0, 1.0);
	DIFFUSE_LIGHT += mix(ndl, wrap, 0.35) * ATTENUATION * LIGHT_COLOR * reach / PI * (1.0 - METALLIC * 0.6);
	vec3 h = normalize(VIEW + LIGHT);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), mix(8.0, 120.0, 1.0 - ROUGHNESS)) * (1.0 - ROUGHNESS);
	vec3 tint = mix(vec3(1.0), ALBEDO * 1.6, METALLIC);   // metal shines in its own color
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR * reach * (SPECULAR_AMOUNT * 0.5 + METALLIC * 1.5) * tint;
}
