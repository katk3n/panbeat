shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1600.0, 900.0);
uniform float glow_energy : hint_range(0.0, 1.5) = 1.0;
uniform bool monochrome = false;
uniform bool high_contrast = false;
uniform bool decoration_enabled = true;
uniform float pulse_phase = 0.0;
uniform int background_preset = 2;
uniform int note_bloom_count = 0;
uniform vec4 note_bloom_geometry_0; uniform vec4 note_bloom_color_0;
uniform vec4 note_bloom_geometry_1; uniform vec4 note_bloom_color_1;
uniform vec4 note_bloom_geometry_2; uniform vec4 note_bloom_color_2;
uniform vec4 note_bloom_geometry_3; uniform vec4 note_bloom_color_3;
uniform vec4 note_bloom_geometry_4; uniform vec4 note_bloom_color_4;
uniform vec4 note_bloom_geometry_5; uniform vec4 note_bloom_color_5;
uniform vec4 note_bloom_geometry_6; uniform vec4 note_bloom_color_6;
uniform vec4 note_bloom_geometry_7; uniform vec4 note_bloom_color_7;
uniform vec4 note_bloom_geometry_8; uniform vec4 note_bloom_color_8;
uniform vec4 note_bloom_geometry_9; uniform vec4 note_bloom_color_9;
uniform vec4 note_bloom_geometry_10; uniform vec4 note_bloom_color_10;
uniform vec4 note_bloom_geometry_11; uniform vec4 note_bloom_color_11;
uniform vec4 note_bloom_geometry_12; uniform vec4 note_bloom_color_12;
uniform vec4 note_bloom_geometry_13; uniform vec4 note_bloom_color_13;
uniform vec4 note_bloom_geometry_14; uniform vec4 note_bloom_color_14;
uniform vec4 note_bloom_geometry_15; uniform vec4 note_bloom_color_15;

float ring(float value, float radius, float width) {
	return 1.0 - smoothstep(width, width + 0.0025, abs(value - radius));
}

vec3 note_bloom(vec2 pixel, vec4 geometry, vec4 color_energy) {
	bool orb = geometry.z < 0.0;
	float source_radius = abs(geometry.z);
	float radial_distance = length(pixel - geometry.xy);
	float distance_to_ring = abs(radial_distance - source_radius);
	float sigma = max(geometry.w, 1.0);
	if (orb) {
		float normalized_radius = radial_distance / max(source_radius, 1.0);
		float body_mask = 1.0 - smoothstep(0.94, 1.02, normalized_radius);
		float sphere_depth = sqrt(max(0.0, 1.0 - normalized_radius * normalized_radius));
		vec3 hot_core = mix(color_energy.rgb, vec3(1.0), 0.30);
		vec3 body = mix(color_energy.rgb * 0.34, hot_core, pow(sphere_depth, 0.72)) * body_mask;
		float outside_distance = max(radial_distance - source_radius, 0.0);
		float halo_gate = smoothstep(0.64, 1.0, normalized_radius);
		float luminous_edge = exp(-pow(outside_distance / sigma, 2.0) * 1.15) * 0.42;
		float diffused_mist = exp(-pow(outside_distance / (sigma * 3.6), 2.0) * 0.85) * 0.42;
		float atmospheric_spill = exp(-outside_distance / (sigma * 7.5)) * 0.12;
		vec3 halo = color_energy.rgb * (luminous_edge + diffused_mist + atmospheric_spill) * halo_gate * color_energy.a;
		return body * (0.68 + color_energy.a * 0.62) + halo;
	}
	float luminous_core = exp(-pow(distance_to_ring / sigma, 2.0) * 1.15) * 0.65;
	float diffused_mist = exp(-pow(distance_to_ring / (sigma * 3.6), 2.0) * 0.85) * 0.42;
	float atmospheric_spill = exp(-distance_to_ring / (sigma * 7.5)) * 0.12;
	return color_energy.rgb * (luminous_core + diffused_mist + atmospheric_spill) * color_energy.a;
}

float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}

float noise21(vec2 value) {
	vec2 cell = floor(value);
	vec2 local = fract(value);
	local = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x), mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), local.x), local.y);
}

float soft_fbm(vec2 value) {
	float total = 0.0;
	float amplitude = 0.55;
	for (int octave = 0; octave < 4; octave++) {
		total += noise21(value) * amplitude;
		value = value * 2.03 + vec2(7.1, 3.7);
		amplitude *= 0.48;
	}
	return total;
}

vec3 silent_resonance(vec2 p, vec2 uv, float radius, float time, float energy) {
	vec3 indigo = vec3(0.022, 0.038, 0.085);
	vec3 mineral = vec3(0.13, 0.22, 0.25);
	vec3 gold = vec3(0.88, 0.58, 0.24);
	float mist = soft_fbm(p * 2.4 + vec2(time * 0.24, -time * 0.12));
	float edge_mist = smoothstep(0.38, 0.92, radius) * smoothstep(1.28, 0.56, radius);
	float warped_radius = radius + (mist - 0.5) * 0.052;
	float ripple = pow(0.5 + 0.5 * cos(warped_radius * 54.0 - time * 1.55), 11.0) * edge_mist;
	float aurora = exp(-abs(p.y - sin(p.x * 2.8 + time * 0.95) * 0.20 - sin(time * 0.62) * 0.23) * 7.5);
	float wandering_light = exp(-length(p - vec2(sin(time * 0.48) * 0.82, cos(time * 0.37) * 0.48)) * 3.6);
	float dawn = exp(-length(p - vec2(-0.78, -0.42)) * 4.8);
	vec3 color = mix(indigo, mineral, mist * 0.72 * edge_mist);
	color += gold * ripple * 0.22 * energy;
	color += mix(mineral, vec3(0.20, 0.56, 0.62), 0.58) * aurora * 0.22 * energy;
	color += gold * wandering_light * 0.20 * energy;
	color += gold * dawn * 0.28 * energy;
	color += vec3(0.20, 0.42, 0.48) * exp(-length(p - vec2(0.82, 0.36)) * 5.6) * 0.16 * energy;
	return color;
}

vec3 breath_of_dawn(vec2 p, vec2 uv, float radius, float time, float energy) {
	vec3 midnight = vec3(0.030, 0.062, 0.115);
	vec3 pearl = vec3(0.78, 0.83, 0.80);
	vec3 lavender = vec3(0.29, 0.20, 0.38);
	vec3 antique_gold = vec3(0.92, 0.67, 0.35);
	float fog = soft_fbm(p * 1.9 + vec2(time * 0.16, -time * 0.085) + 5.0);
	float edge = smoothstep(0.36, 0.88, radius);
	float breathing_radius = 0.64 + sin(time * 0.88) * 0.055;
	float halo = exp(-abs(radius - breathing_radius) * 10.0) * edge;
	float veil = smoothstep(0.44, 0.76, fog) * edge;
	vec2 dawn_center = vec2(sin(time * 0.42) * 0.46, -0.60 + cos(time * 0.31) * 0.20);
	float upper_glow = exp(-length(p - dawn_center) * 2.8);
	float silk = exp(-abs(p.y + sin(p.x * 2.2 - time * 0.82) * 0.24 - cos(time * 0.44) * 0.16) * 6.0);
	vec3 color = mix(midnight, lavender, veil * 0.56);
	color += mix(pearl, antique_gold, 0.28) * halo * 0.46 * energy;
	color += pearl * upper_glow * 0.30 * energy;
	color += mix(lavender, antique_gold, 0.52) * silk * 0.18 * energy;
	return color;
}

vec3 deep_resonance(vec2 p, vec2 uv, float radius, float time, float energy) {
	vec3 abyss = vec3(0.006, 0.038, 0.045);
	vec3 jade = vec3(0.055, 0.27, 0.25);
	vec3 moonstone = vec3(0.24, 0.46, 0.48);
	vec3 bronze = vec3(0.62, 0.42, 0.21);
	vec2 drift = vec2(time * 0.12, -time * 0.070);
	float field = soft_fbm(p * 2.1 + drift);
	float folds = soft_fbm(vec2(p.x * 1.2 - p.y * 0.65, p.y * 2.6 + p.x * 0.25) - drift * 0.7 + 4.0);
	float edge = smoothstep(0.34, 0.86, radius);
	float veil = smoothstep(0.50, 0.80, field) * edge;
	float caustic = pow(max(0.0, sin((folds + p.x * 0.16) * 18.0 + time * 0.72)), 10.0) * edge;
	float resonance = exp(-abs(radius + (field - 0.5) * 0.070 - (0.66 + sin(time * 0.64) * 0.042)) * 26.0);
	vec2 moon_center = vec2(sin(time * 0.38) * 0.62, cos(time * 0.31) * 0.36);
	float moon_pool = exp(-length(p - moon_center) * 4.4) * edge;
	vec3 color = abyss + jade * veil * 0.42;
	color += moonstone * caustic * 0.15 * energy;
	color += bronze * resonance * 0.11 * energy;
	color += moonstone * moon_pool * 0.10 * energy;
	return color;
}

void fragment() {
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float time = pulse_phase;
	float pulse = 0.5 + 0.5 * sin(time * 0.72);

	vec3 background;
	if (background_preset == 0) {
		background = silent_resonance(p, UV, radius, time, glow_energy);
	} else if (background_preset == 1) {
		background = breath_of_dawn(p, UV, radius, time, glow_energy);
	} else {
		background = deep_resonance(p, UV, radius, time, glow_energy);
	}
	float vignette = smoothstep(0.34, 1.12, radius);
	background *= 1.0 - vignette * 0.25;
	if (high_contrast) background = vec3(0.0);
	if (monochrome) background = vec3(dot(background, vec3(0.299, 0.587, 0.114)));

	float disc = decoration_enabled ? 1.0 - smoothstep(0.466, 0.476, radius) : 0.0;
	float dome = sqrt(max(0.0, 1.0 - pow(radius / 0.48, 2.0)));
	float brushed = sin(radius * 720.0 + sin(angle * 9.0) * 2.0) * 0.5 + 0.5;
	float forged = sin(angle * 34.0 + radius * 155.0) * 0.5 + 0.5;
	float directional_light = clamp(0.25 + dome * 0.38 - p.x * 0.24 - p.y * 0.34, 0.0, 1.0);
	vec3 copper_shadow = vec3(0.070, 0.031, 0.020);
	vec3 forged_copper = vec3(0.46, 0.205, 0.105);
	vec3 warm_highlight = vec3(0.88, 0.46, 0.22);
	vec3 patina = vec3(0.045, 0.205, 0.168);
	vec3 metal = mix(copper_shadow, forged_copper, directional_light);
	float soft_reflection = exp(-pow((p.x + p.y + 0.22) * 2.7, 2.0)) * smoothstep(0.48, 0.04, radius);
	metal += warm_highlight * pow(directional_light, 3.2) * (0.20 + brushed * 0.050);
	metal += warm_highlight * soft_reflection * 0.095;
	metal += patina * forged * (1.0 - directional_light) * 0.028;
	metal += vec3(0.080, 0.038, 0.022) * brushed * 0.035;
	metal *= 0.72 + dome * 0.38;

	vec3 amber = monochrome || high_contrast ? vec3(0.86) : vec3(1.0, 0.61, 0.18);
	vec3 cyan = monochrome || high_contrast ? vec3(0.74) : vec3(0.15, 0.72, 1.0);
	vec3 magenta = monochrome || high_contrast ? vec3(0.64) : vec3(0.60, 0.20, 0.68);
	float inner_resonance = decoration_enabled ? ring(radius, 0.345, 0.0025) + ring(radius, 0.225, 0.0020) + ring(radius, 0.108, 0.0020) : 0.0;
	metal += mix(patina, warm_highlight, 0.18) * inner_resonance * (0.045 + pulse * 0.025) * glow_energy;
	metal += mix(patina, magenta, forged * 0.28) * pow(max(dome, 0.0), 3.0) * 0.018 * glow_energy;

	float glass_veil = soft_fbm(p * 3.1 + vec2(time * 0.025, -time * 0.018) + 11.0);
	vec3 transmitted_background = background;
	float inner_breath = exp(-abs(radius + (glass_veil - 0.5) * 0.026 - (0.29 + sin(time * 0.30) * 0.012)) * 18.0);
	transmitted_background += mix(patina, vec3(0.30, 0.38, 0.46), 0.42) * (glass_veil - 0.38) * 0.115 * glow_energy;
	transmitted_background += mix(patina, vec3(0.42, 0.58, 0.54), 0.46) * inner_breath * 0.045 * glow_energy;
	transmitted_background += warm_highlight * soft_reflection * 0.032;
	transmitted_background += forged_copper * dome * 0.022;
	float edge_density = smoothstep(0.16, 0.47, radius) * 0.10;
	float copper_opacity = high_contrast ? 0.90 : (monochrome ? 0.60 : 0.24 + edge_density);
	vec3 translucent_copper = mix(transmitted_background, metal, copper_opacity);
	vec3 color = mix(background, translucent_copper, disc);
	vec2 pixel = UV * viewport_size;
	if (note_bloom_count > 0) color += note_bloom(pixel, note_bloom_geometry_0, note_bloom_color_0);
	if (note_bloom_count > 1) color += note_bloom(pixel, note_bloom_geometry_1, note_bloom_color_1);
	if (note_bloom_count > 2) color += note_bloom(pixel, note_bloom_geometry_2, note_bloom_color_2);
	if (note_bloom_count > 3) color += note_bloom(pixel, note_bloom_geometry_3, note_bloom_color_3);
	if (note_bloom_count > 4) color += note_bloom(pixel, note_bloom_geometry_4, note_bloom_color_4);
	if (note_bloom_count > 5) color += note_bloom(pixel, note_bloom_geometry_5, note_bloom_color_5);
	if (note_bloom_count > 6) color += note_bloom(pixel, note_bloom_geometry_6, note_bloom_color_6);
	if (note_bloom_count > 7) color += note_bloom(pixel, note_bloom_geometry_7, note_bloom_color_7);
	if (note_bloom_count > 8) color += note_bloom(pixel, note_bloom_geometry_8, note_bloom_color_8);
	if (note_bloom_count > 9) color += note_bloom(pixel, note_bloom_geometry_9, note_bloom_color_9);
	if (note_bloom_count > 10) color += note_bloom(pixel, note_bloom_geometry_10, note_bloom_color_10);
	if (note_bloom_count > 11) color += note_bloom(pixel, note_bloom_geometry_11, note_bloom_color_11);
	if (note_bloom_count > 12) color += note_bloom(pixel, note_bloom_geometry_12, note_bloom_color_12);
	if (note_bloom_count > 13) color += note_bloom(pixel, note_bloom_geometry_13, note_bloom_color_13);
	if (note_bloom_count > 14) color += note_bloom(pixel, note_bloom_geometry_14, note_bloom_color_14);
	if (note_bloom_count > 15) color += note_bloom(pixel, note_bloom_geometry_15, note_bloom_color_15);
	COLOR = vec4(color, 1.0);
}
