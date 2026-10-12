shader_type sky;

// Day and night sky: color gradient, sun and moon disks, and twinkling stars.
// Every uniform is driven by DayNight according to the hour.

uniform vec3 top_color : source_color = vec3(0.36, 0.55, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.76, 0.7);
uniform vec3 ground_horizon_color : source_color = vec3(0.7, 0.68, 0.62);
uniform vec3 ground_bottom_color : source_color = vec3(0.25, 0.27, 0.22);
uniform float horizon_softness = 0.35;

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0); // Toward the sun.
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_intensity = 1.0;
uniform float sun_size_deg = 2.2;

uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0); // Toward the moon.
uniform vec3 moon_color : source_color = vec3(0.85, 0.9, 1.0);
uniform float moon_intensity = 0.0;
uniform float moon_size_deg = 1.6;

uniform float star_visibility : hint_range(0.0, 1.0) = 0.0;
uniform float star_density = 0.004; // Share of sky cells holding a star.
uniform float star_scale = 260.0;   // Number of cells across the sky; higher gives smaller stars.
uniform float twinkle_time = 0.0;   // Driven by script, so the sky does not redraw every frame on its own.

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float disk(vec3 dir, vec3 center, float size_deg) {
	float d = dot(dir, normalize(center));
	return smoothstep(cos(radians(size_deg)), cos(radians(size_deg * 0.7)), d);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 color;
	if (dir.y >= 0.0) {
		color = mix(horizon_color, top_color, smoothstep(0.0, horizon_softness, dir.y));
	} else {
		color = mix(ground_horizon_color, ground_bottom_color, smoothstep(0.0, 0.3, -dir.y));
	}

	// Stars, only above the horizon and not in the low-resolution reflection pass.
	if (star_visibility > 0.0 && dir.y > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 grid = dir * star_scale;
		vec3 cell = floor(grid);
		float h = hash(cell);
		if (h < star_density) {
			float twinkle = 0.65 + 0.35 * sin(twinkle_time * (1.5 + h * 400.0) + h * 1000.0);
			float star = smoothstep(0.45, 0.0, length(grid - cell - 0.5));
			color += vec3(star * twinkle * star_visibility) * smoothstep(0.0, 0.15, dir.y);
		}
	}

	// Sun: a disk and a soft glow around it.
	float sun_dot = max(dot(dir, normalize(sun_direction)), 0.0);
	color += sun_color * sun_intensity * (disk(dir, sun_direction, sun_size_deg) * 4.0 + pow(sun_dot, 48.0) * 0.35);

	// Moon: a pale disk with a faint halo.
	float moon_dot = max(dot(dir, normalize(moon_direction)), 0.0);
	color += moon_color * moon_intensity * (disk(dir, moon_direction, moon_size_deg) * 1.6 + pow(moon_dot, 64.0) * 0.15);

	COLOR = color;
}
