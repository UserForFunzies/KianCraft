// The sky: a color gradient that follows the sun (blue days, warm sunsets,
// deep blue nights), a glowing sun and a moon, twinkling stars, and soft
// drifting clouds whose amount and darkness the weather sets. An aurora
// shimmers on cold nights.
shader_type sky;

uniform vec3 day_top : source_color = vec3(0.24, 0.47, 0.92);
uniform vec3 day_horizon : source_color = vec3(0.68, 0.82, 0.98);
uniform vec3 sunset : source_color = vec3(1.0, 0.5, 0.25);
uniform vec3 night_top : source_color = vec3(0.01, 0.015, 0.05);
uniform vec3 night_horizon : source_color = vec3(0.04, 0.06, 0.14);
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);   // a biome's own sky (pink candy, gold fall...)
uniform float cloud_cover = 0.35;        // 0 clear .. 1 overcast
uniform float cloud_dark = 0.0;          // rain clouds are grey
uniform float cloud_quality = 2.0;       // 0 off, 1 simple, 2 detailed
uniform float stars = 1.0;
uniform float aurora = 0.0;
uniform float flash = 0.0;               // lightning
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);   // (the light points at the moon at night, so it's passed in)
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p, int oct) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < oct; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 sun = normalize(sun_dir);
	float sun_up = sun.y;
	float day = smoothstep(-0.18, 0.2, sun_up);
	float h = clamp(d.y, -0.2, 1.0);
	float up = pow(clamp(h, 0.0, 1.0), 0.55);
	vec3 top = mix(night_top, day_top, day);
	vec3 hor = mix(night_horizon, day_horizon, day);
	vec3 col = mix(hor, top, up);
	// Sunrise and sunset: warm near the horizon on the sun's side.
	float twilight = 1.0 - smoothstep(0.0, 0.35, abs(sun_up));
	float toward = pow(clamp(dot(normalize(vec3(d.x, 0.0, d.z)), normalize(vec3(sun.x, 0.0, sun.z))) * 0.5 + 0.5, 0.0, 1.0), 3.0);
	col = mix(col, sunset, twilight * (1.0 - up) * (0.35 + 0.65 * toward));
	col *= tint;
	// Storm clouds grey out the whole sky.
	col = mix(col, vec3(0.42, 0.45, 0.5) * mix(0.08, 1.0, day), cloud_dark * cloud_cover * 0.85);
	// Below the horizon: a darker ground haze.
	if (d.y < 0.0) {
		col = mix(col, hor * 0.55, smoothstep(0.0, -0.2, d.y));
	}
	// The sun: a bright disc with a soft glow.
	float sd = dot(d, sun);
	col += vec3(1.0, 0.85, 0.6) * pow(max(sd, 0.0), 300.0) * 12.0 * smoothstep(-0.1, 0.05, sun_up);
	col += vec3(1.0, 0.7, 0.45) * pow(max(sd, 0.0), 8.0) * 0.35 * day;
	// Stars and the moon at night.
	float night = 1.0 - day;
	if (night > 0.01 && d.y > 0.0) {
		vec3 sp = d * 220.0;
		vec3 cell = floor(sp);
		float st = hash3(cell);
		if (st > 0.996) {
			float tw = 0.6 + 0.4 * sin(TIME * (2.0 + st * 6.0) + st * 40.0);
			float dist = length(fract(sp) - 0.5);
			col += vec3(0.9, 0.92, 1.0) * smoothstep(0.35, 0.0, dist) * tw * night * stars * (1.0 - cloud_cover);
		}
		float md = dot(d, normalize(moon_dir));
		col += vec3(0.85, 0.88, 1.0) * smoothstep(0.9993, 0.9997, md) * 1.8 * night;
		col += vec3(0.4, 0.45, 0.6) * pow(max(md, 0.0), 30.0) * 0.25 * night;
		// Aurora: wavy green-violet curtains.
		if (aurora > 0.0) {
			float band = fbm(vec2(d.x * 3.0 + TIME * 0.03, d.z * 3.0), 3);
			float curtain = smoothstep(0.15, 0.45, d.y) * (1.0 - smoothstep(0.45, 0.85, d.y));
			col += mix(vec3(0.1, 0.9, 0.5), vec3(0.6, 0.2, 0.9), band) * curtain * pow(band, 2.0) * aurora * night * 1.6;
		}
	}
	// Clouds: soft noise on a flat layer high up, drifting with the wind.
	if (cloud_quality > 0.0 && d.y > 0.02) {
		vec2 cp = d.xz / (d.y + 0.08) * 1.6 + vec2(TIME * 0.006, TIME * 0.003);
		int oct = cloud_quality > 1.5 ? 5 : 3;
		float n = fbm(cp, oct);
		float cov = mix(0.62, 0.18, cloud_cover);
		float c = smoothstep(cov, cov + 0.25, n);
		float lit = mix(0.95, 0.38, cloud_dark) * mix(0.05, 1.0, day);
		vec3 ccol = mix(vec3(lit), sunset * lit * 1.1, twilight * 0.6) * tint;
		// Silver edges facing the sun.
		ccol += vec3(1.0, 0.9, 0.75) * pow(max(sd, 0.0), 6.0) * (1.0 - c) * 0.5 * day;
		col = mix(col, ccol, c * smoothstep(0.02, 0.2, d.y));
	}
	col += vec3(0.85, 0.9, 1.0) * flash;
	COLOR = col;
}
