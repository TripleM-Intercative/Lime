shader_type canvas_item;

uniform vec2 size;

uniform float cell_size = 20.0;
uniform vec2 cell_offset = vec2(0.0);
uniform vec4 cell_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 effect_origin = vec2(0.5);

uniform float effect_value : hint_range(0.0, 1.0, 0.001);
uniform vec2 effect_length = vec2(50.0, 100.0);
uniform float effect_delay = 0.05;

uniform float target_rotation = 0.05;

uniform float effect_value_offset = 80.0;
uniform float effect_length_offset : hint_range(0.0, 1.0) = 0.4;

uniform float effect_rotation_offset : hint_range(0.0, 1.0) = 0.6;

uniform vec3 light_direction = vec3(1.0, 0.0, 0.0);
uniform vec4 light_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float gradient_scale = 2.0;
uniform bool dobble_light = false;

vec3 random(vec3 value, vec3 seed) {
	vec3 seed_value = value + seed;

	vec3 return_value = vec3(
		dot(seed_value, vec3(127.1,311.7, 201.9) ),
		dot(seed_value, vec3(269.5,183.3, 367.7) ),
		dot(seed_value, vec3(245.1,367.7, 105.6) ) 
	);

	return fract(sin(return_value) * 43758.5453123);
}

float offset_mix(float offset, float alpha) {
	return mix(1.0 - offset, 1.0 + offset, alpha);
}

void fragment() {
	vec2 coord = UV * size - cell_offset;
	vec2 origin_pos = effect_origin * size - cell_offset;

	vec2 cell_index = floor(coord / cell_size);
	vec2 cell_center = (cell_index + vec2(0.5)) * cell_size;
	vec2 cell_uv = fract(coord / cell_size);
	float cell_dist = distance(origin_pos, cell_center);

	vec3 rng = random(vec3(cell_index, 0.0), vec3(0.0));
	
	vec2 dist_point = vec2(
		effect_origin.x < 0.5 ? size.x : 0.0,
		effect_origin.y < 0.5 ? size.y : 0.0
	);
	dist_point -= cell_offset;
	
	float max_dist = distance(origin_pos, dist_point);
	max_dist += max(effect_length.x, effect_length.y) * (1.0 + effect_length_offset);
	max_dist += effect_value_offset;
	max_dist += cell_size * 0.71;

	// Apply random values for Transfomations
	float cell_dist_rot = cell_dist + effect_value_offset * rng.x;
	float cell_dist_scale = cell_dist + effect_value_offset * rng.y;

	float effect_lenght_rot = effect_length.x * offset_mix(effect_length_offset, rng.z);
	float effect_lenght_scale = effect_length.y * offset_mix(effect_length_offset, rng.x);

	// Map effect value to Transformation value
	float duration = max(1.0 - effect_delay, 0.001);
	float rotation_value = clamp(effect_value / duration, 0.0, 1.0) * max_dist;
	float scale_value = clamp((effect_value - effect_delay) / duration, 0.0, 1.0) * max_dist;

	// Rotation
	float rotation = clamp((rotation_value - cell_dist_rot) / effect_lenght_rot, 0.0, 1.0);
	rotation *= target_rotation * offset_mix(effect_rotation_offset, rng.y);

	// Scale
	float scale = clamp((scale_value - cell_dist_scale) / effect_lenght_scale, 0.0, 1.0);

	if (scale >= 1.0) {
		discard;
	}

	float direction = cell_center.x < origin_pos.x ? -1.0 : 1.0;

	// Calculate Rotation Matrix
	float angle = rotation * PI * 2.0 * direction;
	float sin_angle = sin(angle);
	float cos_angle = cos(angle);
	mat2 rot_mat = mat2(vec2(cos_angle, - sin_angle), vec2(sin_angle, cos_angle));

	// Apply Transformations
	vec2 local_uv = cell_uv - 0.5;
	local_uv.x /= cos(scale * PI * 0.5);
	local_uv = rot_mat * local_uv;

	if (abs(local_uv.x) > 0.5 || abs(local_uv.y) > 0.5) {
		discard;
	}

	// Light
	vec3 normal = vec3(sin(scale * PI * 0.5) * -direction, 0.0, cos(scale * PI * 0.5));

	vec3 cell_light_direction = light_direction;

	if (dobble_light) {
		cell_light_direction.x *= direction;
	}

	float light = clamp(-dot(normal, normalize(cell_light_direction)), 0.0, 1.0);

	float gardient_value = smoothstep(0.0, 1.0, scale * gradient_scale);
	float gradient = mix(0.0, (local_uv.x * -direction + 0.5), gardient_value);

	COLOR = vec4(mix(cell_color.rgb, light_color.rgb * gradient, light), 1.0);
}