shader_type canvas_item;
render_mode blend_add;   // light, not paint: it brightens what is behind it

// Hologram for a sprite: a tinted, see-through projection with fine scanlines that scroll,
// a soft glow on the edges, a light flicker and now and then a sideways glitch.
// Put it on a Sprite2D (or any CanvasItem with a texture). Keeps the node modulate.

group_uniforms Look;
uniform vec4 tint : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.75;
uniform float edge_glow : hint_range(0.0, 3.0) = 1.4;
group_uniforms Scanlines;
uniform float line_count : hint_range(10.0, 400.0) = 10.0;   // lines over the sprite's height
uniform float line_strength : hint_range(0.0, 1.0) = 0.45;
uniform float scroll_speed : hint_range(-4.0, 4.0) = 0.6;
group_uniforms Instability;
uniform float flicker : hint_range(0.0, 1.0) = 0.15;
uniform float glitch : hint_range(0.0, 1.0) = 0.35;          // how often bands slide sideways
uniform float glitch_shift : hint_range(0.0, 0.2) = 0.04;     // how far, in sprite widths

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

// the node's modulate, read in vertex(): in fragment() COLOR already holds the texture
// times modulate, and multiplying by it recoloured the hologram with the sprite's colours
varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	// a glitch: some horizontal bands slide for a short moment
	float slot = floor(TIME * 8.0);
	float band = floor(UV.y * 14.0);
	float on = step(1.0 - glitch * 0.25, hash(slot * 7.0 + band));
	vec2 uv = UV + vec2((hash(slot + band * 3.0) - 0.5) * 2.0 * glitch_shift * on, 0.0);
	vec4 tex = texture(TEXTURE, uv);
	// edges: where the alpha changes, a brighter rim (alpha read around the pixel)
	vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
	float around = texture(TEXTURE, uv + vec2(px.x, 0.0)).a + texture(TEXTURE, uv - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, uv + vec2(0.0, px.y)).a + texture(TEXTURE, uv - vec2(0.0, px.y)).a;
	float rim = clamp(tex.a * 4.0 - around, 0.0, 1.0);
	// scanlines, anti-aliased: a smooth wave whose contrast fades when lines get thinner
	// than a pixel
	float y = UV.y * line_count + TIME * scroll_speed * 4.0;
	float w = fwidth(y);
	float lines = 0.5 + 0.5 * cos(y * 6.2832);
	lines = mix(lines, 0.5, clamp(w * 1.5, 0.0, 1.0));
	float shade = 1.0 - line_strength * lines;
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// every part of the sprite reads, dark colours included (a red cape kept almost no light)
	vec3 col = tint.rgb * (0.55 + 0.75 * lum) * shade + tint.rgb * rim * edge_glow;
	float f = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 37.0)) * hash(floor(TIME * 20.0));
	COLOR = vec4(col * f, tex.a * opacity * f * (0.75 + 0.25 * shade)) * node_tint;
}
