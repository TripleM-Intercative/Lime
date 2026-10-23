shader_type canvas_item;

// uniform sampler2D screen_texture : hint_screen_texture;
uniform vec2 size;

uniform float cell_size = 20.0;
uniform vec2 effect_origin = vec2(0.5);

uniform float effect_value : hint_range(0.0, 1.0, 0.001);
uniform vec3 effect_duration = vec3(1.0, 2.0, 2.0);
uniform float effect_strength = 200.0;

void fragment() {
	vec2 coord = UV * size;

	vec2 cell_index = floor(coord / cell_size);
	vec2 cell_center = (cell_index + vec2(0.5)) * cell_size;

	vec2 origin_dist = abs(effect_origin * size - cell_center);
	vec2 dist_point = vec2(
		effect_origin.x < 0.5 ? size.x : 0.0, 
		effect_origin.y < 0.5 ? size.y : 0.0
	);
	vec2 dist = abs(effect_origin * size - dist_point) + vec2(effect_strength);

	float duration_sum_xy = effect_duration.x + effect_duration.y;
	float duration_sum_xyz = effect_duration.x + effect_duration.y + effect_duration.z;

	vec3 duration_scale = duration_sum_xyz / effect_duration;

	vec3 mapped_value = vec3(
		effect_value * duration_scale.x,
		(effect_value - (effect_duration.x / duration_sum_xyz)) * duration_scale.y,
		(effect_value - (duration_sum_xy / duration_sum_xyz)) * duration_scale.z
	);

	vec3 interp = vec3(
		mix(0.0, dist.x, clamp(mapped_value.x, 0.0, 1.0)),
		mix(cell_size * 0.5, dist.y, clamp(mapped_value.y, 0.0, 1.0)),
		mix(0.0, dist.y, clamp(mapped_value.z, 0.0, 1.0))
	);
	
	vec2 grid = vec2(
		step(0.1, abs(sin(PI * UV.x * (size.x / cell_size)))), 
		step(0.1, abs(sin(PI * UV.y * (size.y / cell_size))))
	);
	bool is_grid = grid.x * grid.y < 0.5;

	vec3 alpha = (interp - vec3(origin_dist.x, vec2(origin_dist.y))) / effect_strength;

	if (origin_dist.x > interp.x || origin_dist.y > interp.y) {
		COLOR = vec4(vec3(0.0), 1.0);
	} else {
		if (is_grid) {
			COLOR = vec4(vec3(0.0), clamp(1.0 - alpha.z, 0.0, 1.0));
		} else {
			if (alpha.x > 1.0 && origin_dist.y <= cell_size * 0.5) {
				discard;
			} else {
				float beta = alpha.x > 1.0 ? alpha.y : alpha.x;
				COLOR = vec4(vec3(0.0), clamp(1.0 - beta, 0.0, 1.0));
			}
		}
	}
}