shader_type spatial;

// Simple stylized river water: tinted, slightly transparent, with ripples flowing along Z.
uniform vec4 water_color : source_color = vec4(0.18, 0.42, 0.45, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.82;
uniform float flow_speed = 0.6;
uniform float ripple_scale = 0.8;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.15;

// Highlight halo where the player can draw water (driven by RiverWaterSource).
uniform vec3 highlight_position = vec3(0.0);
uniform float highlight_amount : hint_range(0.0, 1.0) = 0.0;
uniform float highlight_radius = 2.2;
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.92, 0.7);
uniform float highlight_pulse_speed = 3.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * ripple_scale;
	float t = TIME * flow_speed;
	// Analytic slopes of a few overlapping sine waves, all drifting downstream (+Z).
	vec2 slope = vec2(
		cos(p.x * 2.1 + (p.y - t) * 0.7) + cos(-p.x * 1.3 + (p.y - t * 1.4) * 2.4),
		cos(p.x * 0.4 + (p.y - t) * 1.7) + cos(p.x * 1.1 - (p.y - t * 1.2) * 2.2)
	) * 0.5;
	NORMAL_MAP = normalize(vec3(slope * ripple_strength, 1.0)) * 0.5 + 0.5;
	float halo = 1.0 - smoothstep(highlight_radius * 0.4, highlight_radius, distance(world_pos.xz, highlight_position.xz));
	halo *= highlight_amount * (0.75 + 0.25 * sin(TIME * highlight_pulse_speed));
	ALBEDO = mix(water_color.rgb, water_color.rgb * 2.2 * highlight_tint, halo);
	EMISSION = highlight_tint * halo * 0.3;
	ALPHA = opacity;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
