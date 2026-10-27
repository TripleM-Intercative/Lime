shader_type canvas_item;

// Sphere radius
uniform float planet_radius = 0.4;
uniform float cloud_radius = 0.45;
uniform float atmosphere_radius = 0.5;

// Cells for Noice
uniform int planet_cell_amount = 10;
uniform int cloud_cell_amount = 10;

// Noice wrapping period
uniform vec3 planet_period = vec3(9.5);
uniform vec3 cloud_period = vec3(9.5);

// Noice Seed
uniform vec3 planet_seed = vec3(0.0);
uniform vec3 cloud_seed = vec3(2.0);

// Rotation Vector
uniform vec3 rotation = vec3(1.0, 1.0, 0.0);

// Speed scalar
uniform float planet_rotation_speed = 0.1;
uniform float cloud_rotation_speed = 0.12;
uniform float cloud_morphing_speed = 10;

// Light
uniform vec3 sun_direction = vec3(1.0, 0.0, 1.0);
uniform vec2 planet_shadow_transition = vec2(-0.15, 0.15);
uniform vec2 cloud_shadow_transition = vec2(-0.15, 0.15);
uniform vec2 atmosphere_shadow_transition = vec2(-0.2, 0.3);
uniform float max_shadow = 0.05;
uniform float cloud_shadow_offset = 0.05;
uniform float cloud_shadow_intensity = 0.7;

// colors and thresholds
uniform float planet_threshold_0_ = 0.44;
uniform vec4 planet_color_0_ : source_color = vec4(.114, .306, .537, 1.);
uniform float planet_threshold_1_ = 0.5;
uniform vec4 planet_color_1_ : source_color = vec4(0., .698, .792, 1.);
uniform float planet_threshold_2_ = 0.54;
uniform vec4 planet_color_2_ : source_color = vec4(.984, .82, .635, 1.);
uniform float planet_threshold_3_ = 0.58;
uniform vec4 planet_color_3_ : source_color = vec4(.968, .573, .337, 1.);
uniform float planet_threshold_4_ = 0.69;
uniform vec4 planet_color_4_ : source_color = vec4(.2, .792, .498, 1.);
uniform float planet_threshold_5_ = 1.0;
uniform vec4 planet_color_5_ : source_color = vec4(.078, .349, .114, 1.);

uniform float cloud_threshold_0_ = 0.5;
uniform vec4 cloud_color_0_ : source_color = vec4(0.0);
uniform float cloud_threshold_1_ = 0.6;
uniform vec4 cloud_color_1_ : source_color = vec4(0.5);
uniform float cloud_threshold_2_ = 0.62;
uniform vec4 cloud_color_2_ : source_color = vec4(0.8);
uniform float cloud_threshold_3_ = 1.0;
uniform vec4 cloud_color_3_ : source_color = vec4(1.0);

uniform vec4 atmosphere_color : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform float atmosphere_intensity = 1.5;
uniform float atmosphere_density = 2.0;

// modulo function with wrapping
vec3 modulo(vec3 divident, vec3 divisor){
	vec3 positiveDivident = mod(divident, divisor) + divisor;
	return mod(positiveDivident, divisor);
}

// 3 dimensional pseudo random number generator
vec3 random(vec3 value, vec3 seed){
	vec3 seed_value = value + seed;

	vec3 return_value = vec3(
		dot(seed_value, vec3(127.1,311.7, 201.9) ),
		dot(seed_value, vec3(269.5,183.3, 367.7) ),
		dot(seed_value, vec3(245.1,367.7, 105.6) ) 
	);

	return -1.0 + 2.0 * fract(sin(return_value) * 43758.5453123);
}

// Rodrigues-Formula
mat3 rotation_from_axis(vec3 axis, float angle) {
	vec3 normalized_axis = normalize(axis);
	float sin_angle = sin(angle);
	float cos_angle = cos(angle);
    
	mat3 K = mat3(
		vec3(0.0, normalized_axis.z, -normalized_axis.y),
		vec3(-normalized_axis.z, 0.0, normalized_axis.x),
		vec3(normalized_axis.y, -normalized_axis.x, 0.0)
	);
    
	mat3 I = mat3(1.0);
	return I + sin_angle * K + ((1.0 - cos_angle) * (K * K));
}

float planet_noise(vec2 uv, mat3 rot) {
	vec2 centered_uv = uv - vec2(0.5);

	float depth_squared = 
		(planet_radius * planet_radius) - 
		(centered_uv.x * centered_uv.x) - 
		(centered_uv.y * centered_uv.y);

	if (depth_squared < 0.0) return 0.0;

	float depth = sqrt(depth_squared);

	vec3 xyz = rot * vec3(centered_uv, depth); // rotate pixel
	xyz = vec3(xyz * float(planet_cell_amount)); // calculate discrete cells

	vec3 cell_min = floor(xyz);
	vec3 cell_max = ceil(xyz);
	vec3 xyz_fract = fract(xyz);
	
	// wrap Cell around Sphere after period
	cell_min = modulo(cell_min, planet_period);
	cell_max = modulo(cell_max, planet_period);
	
	// calculate Blur for lerp
	vec3 blur = smoothstep(0.0, 1.0, xyz_fract);
	
	// generate points for a cube of random values for every pixel
	vec3 p_min_min_min = random(vec3(cell_min.x, cell_min.y, cell_min.z), planet_seed);
	vec3 p_max_min_min = random(vec3(cell_max.x, cell_min.y, cell_min.z), planet_seed);
	vec3 p_min_max_min = random(vec3(cell_min.x, cell_max.y, cell_min.z), planet_seed);
	vec3 p_max_max_min = random(vec3(cell_max.x, cell_max.y, cell_min.z), planet_seed);
	vec3 p_min_min_max = random(vec3(cell_min.x, cell_min.y, cell_max.z), planet_seed);
	vec3 p_max_min_max = random(vec3(cell_max.x, cell_min.y, cell_max.z), planet_seed);
	vec3 p_min_max_max = random(vec3(cell_min.x, cell_max.y, cell_max.z), planet_seed);
	vec3 p_max_max_max = random(vec3(cell_max.x, cell_max.y, cell_max.z), planet_seed);
	
	// Trilinear Interpolation
    float x_front_bottom = mix(
		dot(p_min_min_min, xyz_fract - vec3(0,0,0)), 
		dot(p_max_min_min, xyz_fract - vec3(1,0,0)), 
		blur.x);
    float x_back_bottom = mix(
		dot(p_min_max_min, xyz_fract - vec3(0,1,0)), 
		dot(p_max_max_min, xyz_fract - vec3(1,1,0)), 
		blur.x);
	float xy_bottom = mix(x_front_bottom, x_back_bottom, blur.y);
    
    float x_front_top = mix(
		dot(p_min_min_max, xyz_fract - vec3(0,0,1)), 
		dot(p_max_min_max, xyz_fract - vec3(1,0,1)), 
		blur.x);
    float x_back_top = mix(
		dot(p_min_max_max, xyz_fract - vec3(0,1,1)), 
		dot(p_max_max_max, xyz_fract - vec3(1,1,1)), 
		blur.x);
	float xy_top = mix(x_front_top, x_back_top, blur.y);
    
	return mix(xy_bottom, xy_top, blur.z) * 0.8 + 0.5; // clamp values beteen 0.1 and 0.9
}

float cloud_noice(vec2 uv, mat3 rot){
	vec2 centered_uv = uv - vec2(0.5);

	float depth_squared = 
		(cloud_radius * cloud_radius) - 
		(centered_uv.x * centered_uv.x) - 
		(centered_uv.y * centered_uv.y);

	if (depth_squared < 0.0) return 0.0;

	float depth = sqrt(depth_squared);

	vec3 xyz = rot * vec3(centered_uv, depth); // rotate pixel
	xyz += vec3(0.0, 0.0, TIME * cloud_morphing_speed / 1000.0); // cloud morphing
	xyz = vec3(xyz * float(cloud_cell_amount)); // calculate discrete cells

	vec3 cell_min = floor(xyz);
	vec3 cell_max = ceil(xyz);
	vec3 xyz_fract = fract(xyz);
	
	// wrap Cell around Sphere after period
	cell_min = modulo(cell_min, cloud_period);
	cell_max = modulo(cell_max, cloud_period);
	
	// calculate Blur for lerp
	vec3 blur = smoothstep(0.0, 1.0, xyz_fract);
	
	// generate points for a cube of random values for every pixel
	vec3 p_min_min_min = random(vec3(cell_min.x, cell_min.y, cell_min.z), cloud_seed);
	vec3 p_max_min_min = random(vec3(cell_max.x, cell_min.y, cell_min.z), cloud_seed);
	vec3 p_min_max_min = random(vec3(cell_min.x, cell_max.y, cell_min.z), cloud_seed);
	vec3 p_max_max_min = random(vec3(cell_max.x, cell_max.y, cell_min.z), cloud_seed);
	vec3 p_min_min_max = random(vec3(cell_min.x, cell_min.y, cell_max.z), cloud_seed);
	vec3 p_max_min_max = random(vec3(cell_max.x, cell_min.y, cell_max.z), cloud_seed);
	vec3 p_min_max_max = random(vec3(cell_min.x, cell_max.y, cell_max.z), cloud_seed);
	vec3 p_max_max_max = random(vec3(cell_max.x, cell_max.y, cell_max.z), cloud_seed);
	
	// Trilinear Interpolation
    float x_front_bottom = mix(
		dot(p_min_min_min, xyz_fract - vec3(0,0,0)), 
		dot(p_max_min_min, xyz_fract - vec3(1,0,0)), 
		blur.x);
    float x_back_bottom = mix(
		dot(p_min_max_min, xyz_fract - vec3(0,1,0)), 
		dot(p_max_max_min, xyz_fract - vec3(1,1,0)), 
		blur.x);
	float xy_bottom = mix(x_front_bottom, x_back_bottom, blur.y);
    
    float x_front_top = mix(
		dot(p_min_min_max, xyz_fract - vec3(0,0,1)), 
		dot(p_max_min_max, xyz_fract - vec3(1,0,1)), 
		blur.x);
    float x_back_top = mix(
		dot(p_min_max_max, xyz_fract - vec3(0,1,1)), 
		dot(p_max_max_max, xyz_fract - vec3(1,1,1)), 
		blur.x);
	float xy_top = mix(x_front_top, x_back_top, blur.y);
    
	return mix(xy_bottom, xy_top, blur.z) * 0.8 + 0.5; // clamp values beteen 0.1 and 0.9
}

vec4 color_planet(vec2 uv, mat3 rot) {
	float value = planet_noise(uv, rot);
	vec4 color = vec4(0.0);

	if (value < planet_threshold_0_){
		color = planet_color_0_;
	}else if (value < planet_threshold_1_){
		color = planet_color_1_;
	}else if (value < planet_threshold_2_){
		color = planet_color_2_;
	}else if (value < planet_threshold_3_){
		color = planet_color_3_;
	}else if (value < planet_threshold_4_){
		color = planet_color_4_;
	}else if (value < planet_threshold_5_){
		color = planet_color_5_;
	}

	return color;
}

vec4 color_cloud(vec2 uv, mat3 rot) {
	float value = cloud_noice(uv, rot);
	vec4 color = vec4(0.0);

	if (value < cloud_threshold_0_){
		color = cloud_color_0_;
	}else if (value < cloud_threshold_1_){
		color = cloud_color_1_;
	}else if (value < cloud_threshold_2_){
		color = cloud_color_2_;
	}else if (value < cloud_threshold_3_){
		color = cloud_color_3_;
	}
	return color;
}

void fragment() {
	// calculate Rotation matrix
	float planet_angle = float(-TIME * planet_rotation_speed);
	float cloud_angle = float(-TIME * cloud_rotation_speed);
	mat3 planet_rot = rotation_from_axis(rotation, planet_angle);
	mat3 cloud_rot = rotation_from_axis(rotation, cloud_angle);

	// calculate Colors
	COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	vec4 planet_color = color_planet(UV, planet_rot);
	vec4 cloud_color = color_cloud(UV, cloud_rot);

	vec2 centered_uv = UV - vec2(0.5);
	float dist = distance(UV, vec2(0.5));

	// PLanet Color
	if (dist < planet_radius) {
		float depth_squared = 
		(planet_radius * planet_radius) - 
		(centered_uv.x * centered_uv.x) - 
		(centered_uv.y * centered_uv.y);
	
		float depth = (depth_squared < 0.0) ? 0.0 : sqrt(depth_squared);
	
		vec3 surface_normal = normalize(vec3(centered_uv, depth));
		float light = dot(surface_normal, normalize(sun_direction));
		light = smoothstep(planet_shadow_transition.x, planet_shadow_transition.y, light);

		// Cloud shadow calculation
		vec2 uv_offset = sun_direction.xy * cloud_shadow_offset;
		float cloud_shadow_noice = cloud_noice(UV + uv_offset, cloud_rot);
		float cloud_shadow = smoothstep(cloud_threshold_1_, cloud_threshold_2_, cloud_shadow_noice);

		light = light * mix(1.0, 1.0 - cloud_shadow_intensity, cloud_shadow);

		COLOR = vec4(planet_color.rgb * max(light, max_shadow), planet_color.a);
	}

	// Cloud Color
	if (dist < cloud_radius) {
		float depth_squared = 
		(cloud_radius * cloud_radius) - 
		(centered_uv.x * centered_uv.x) - 
		(centered_uv.y * centered_uv.y);
	
		float depth = (depth_squared < 0.0) ? 0.0 : sqrt(depth_squared);
	
		vec3 surface_normal = normalize(vec3(centered_uv, depth));
		float light = dot(surface_normal, normalize(sun_direction));
		light = smoothstep(cloud_shadow_transition.x, cloud_shadow_transition.y, light);

		COLOR.rgb = mix(COLOR.rgb, cloud_color.rgb * max(light, max_shadow), cloud_color.a);
	}

	// Atmosphere Color
	if (dist >= planet_radius && dist < atmosphere_radius){
		vec3 surface_normal = normalize(vec3(centered_uv, 0.0));
		float light = dot(surface_normal, normalize(sun_direction));
		light = smoothstep(atmosphere_shadow_transition.x, atmosphere_shadow_transition.y, light);

		float alpha = (dist - planet_radius) / (atmosphere_radius - planet_radius);
		float atmosphere = smoothstep(0.0, 1.0, alpha);
		atmosphere = 1.0 - pow(atmosphere, atmosphere_density);

		COLOR += atmosphere_color * atmosphere * atmosphere_intensity * max(light, max_shadow);
	}
}
