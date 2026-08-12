shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1600.0, 900.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float motion_speed : hint_range(0.0, 1.0) = 0.38;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x), mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), local.x), local.y);
}

float soft_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int octave = 0; octave < 4; octave++) {
		value += noise21(p) * amplitude;
		p = p * 2.03 + vec2(5.7, 2.9);
		amplitude *= 0.48;
	}
	return value;
}

void fragment() {
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float t = TIME * motion_speed;
	float radius = length(p);

	vec3 night_jade = vec3(0.008, 0.030, 0.032);
	vec3 mineral = vec3(0.045, 0.145, 0.135);
	vec3 dusk = vec3(0.115, 0.070, 0.105);
	vec3 copper_light = vec3(0.68, 0.35, 0.16);
	vec3 moonstone = vec3(0.45, 0.64, 0.57);
	float mist = soft_fbm(p * 1.75 + vec2(t * 0.34, -t * 0.18) + 4.0);
	float folded_mist = soft_fbm(vec2(p.x * 1.25 - p.y * 0.42, p.y * 2.15 + p.x * 0.20) - vec2(t * 0.18, t * 0.26));
	float veil = smoothstep(0.43, 0.82, mist) * smoothstep(1.18, 0.22, radius);
	vec3 color = mix(night_jade, dusk, clamp(UV.y * 0.44 + veil * 0.46, 0.0, 1.0));
	color += mineral * veil * 0.46 * intensity;

	float breathing_radius = 0.58 + sin(t * 1.36) * 0.060;
	float breathing_halo = exp(-abs(radius + (mist - 0.5) * 0.035 - breathing_radius) * 11.0);
	float resonance = pow(0.5 + 0.5 * cos((radius + (folded_mist - 0.5) * 0.072) * 30.0 - t * 1.85), 11.0);
	resonance *= smoothstep(0.16, 0.48, radius) * smoothstep(1.16, 0.60, radius);
	float moving_veil = exp(-abs(p.y - sin(p.x * 2.5 + t * 1.35) * 0.22 - sin(t * 0.82) * 0.22) * 6.5);
	color += moonstone * breathing_halo * 0.13 * intensity;
	color += mix(moonstone, copper_light, 0.38) * resonance * 0.075 * intensity;
	color += mix(mineral, moonstone, 0.55) * moving_veil * 0.14 * intensity;

	float dawn_pool = exp(-length(p - vec2(-0.72 + sin(t * 0.64) * 0.42, 0.38 + cos(t * 0.52) * 0.24)) * 3.2);
	float quiet_pool = exp(-length(p - vec2(0.76 + cos(t * 0.58) * 0.36, -0.30 + sin(t * 0.70) * 0.22)) * 3.8);
	color += copper_light * dawn_pool * 0.22 * intensity;
	color += moonstone * quiet_pool * 0.17 * intensity;
	float edge = smoothstep(0.34, 1.18, radius);
	color *= 1.0 - edge * 0.48;
	COLOR = vec4(color, 1.0);
}
