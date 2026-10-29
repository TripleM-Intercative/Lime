#include <map/ruinedcitytilemaplayer.h>

#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/tile_set.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cmath>

namespace {

	// Distinct salts so every pass gets its own random stream from the same seed.
	constexpr uint64_t SALT_CITY		= 0xA1B2C3D4E5F60718ull;
	constexpr uint64_t SALT_DESTRUCTION = 0x5EED0F1A2B3C4D5Eull;
	constexpr uint64_t SALT_OVERGROWTH	= 0x7F6E5D4C3B2A1908ull;

	// Absolute z of the debug overlay. 4096 is the engine's maximum canvas z.
	constexpr int DEBUG_Z_INDEX = 4096;

	inline float clamp01(float v)
	{
		return std::min(std::max(v, 0.0f), 1.0f);
	}

	inline float lerpf(float a, float b, float t)
	{
		return a + (b - a) * t;
	}

	// Small deterministic PRNG (splitmix64) so results do not depend on engine RNG.
	struct Rng
	{
		uint64_t state;

		explicit Rng(uint64_t p_seed) : state(p_seed)
		{
		}

		uint32_t next_u32()
		{
			state += 0x9E3779B97F4A7C15ull;
			uint64_t z = state;
			z		   = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
			z		   = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
			return static_cast<uint32_t>((z ^ (z >> 31)) >> 32);
		}

		// [0, 1)
		float randf()
		{
			return (next_u32() >> 8) * (1.0f / 16777216.0f);
		}

		// Inclusive on both ends.
		int randi_range(int p_lo, int p_hi)
		{
			if ( p_hi <= p_lo ) {
				return p_lo;
			}
			return p_lo + static_cast<int>(next_u32() % static_cast<uint32_t>(p_hi - p_lo + 1));
		}
	};

	inline uint32_t hash_cell(int x, int y, uint32_t seed)
	{
		uint32_t h = (static_cast<uint32_t>(x) * 0x8DA6B343u) ^ (static_cast<uint32_t>(y) * 0xD8163841u) ^ (seed * 0xCB1AB31Fu);
		h ^= h >> 15;
		h *= 0x2C1B3C6Du;
		h ^= h >> 12;
		h *= 0x297A2D39u;
		h ^= h >> 15;
		return h;
	}

	inline float lattice(int x, int y, uint32_t seed)
	{
		return (hash_cell(x, y, seed) >> 8) * (1.0f / 16777216.0f);
	}

	// Smoothly interpolated lattice noise in [0, 1].
	float value_noise(float x, float y, uint32_t seed)
	{
		const float fx = std::floor(x);
		const float fy = std::floor(y);
		const int ix   = static_cast<int>(fx);
		const int iy   = static_cast<int>(fy);
		float tx	   = x - fx;
		float ty	   = y - fy;
		tx			   = tx * tx * (3.0f - 2.0f * tx);
		ty			   = ty * ty * (3.0f - 2.0f * ty);

		const float a = lattice(ix, iy, seed);
		const float b = lattice(ix + 1, iy, seed);
		const float c = lattice(ix, iy + 1, seed);
		const float d = lattice(ix + 1, iy + 1, seed);
		return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty);
	}

	// Fractal sum of value noise, normalised to [0, 1].
	float fbm(float x, float y, int octaves, float persistence, uint32_t seed)
	{
		float sum		= 0.0f;
		float amplitude = 1.0f;
		float norm		= 0.0f;
		float frequency = 1.0f;
		for ( int o = 0; o < octaves; o++ ) {
			sum += amplitude * value_noise(x * frequency, y * frequency, seed + static_cast<uint32_t>(o) * 0x9E3779B9u);
			norm += amplitude;
			amplitude *= persistence;
			frequency *= 2.0f;
		}
		return norm > 0.0f ? sum / norm : 0.0f;
	}

	void fill_rect(std::vector<uint8_t>& grid, int W, int H, int x, int y, int w, int h, uint8_t value)
	{
		const int x0 = std::max(x, 0);
		const int y0 = std::max(y, 0);
		const int x1 = std::min(x + w, W);
		const int y1 = std::min(y + h, H);
		for ( int yy = y0; yy < y1; yy++ ) {
			for ( int xx = x0; xx < x1; xx++ ) {
				grid[static_cast<size_t>(yy) * W + xx] = value;
			}
		}
	}

	// Used for the debug view when no Gradient is assigned: blue -> cyan -> green -> yellow -> red.
	Color default_ramp_color(float t)
	{
		static const Color stops[] = {
				Color(0.05f, 0.10f, 0.45f), Color(0.00f, 0.60f, 0.80f), Color(0.20f, 0.75f, 0.30f),
				Color(0.95f, 0.85f, 0.20f), Color(0.85f, 0.15f, 0.10f),
		};
		constexpr int segments = 4;
		const float scaled	   = clamp01(t) * segments;
		const int i			   = std::min(static_cast<int>(scaled), segments - 1);
		const float f		   = scaled - i;
		return stops[i].lerp(stops[i + 1], f);
	}

} // namespace

// Registration -----------------------------------------------------------

#define RMC_BIND(m_name, m_info)                                                                                                                     \
	ClassDB::bind_method(D_METHOD("set_" #m_name, "value"), &RuinedCityTileMapLayer::set_##m_name);                                                  \
	ClassDB::bind_method(D_METHOD("get_" #m_name), &RuinedCityTileMapLayer::get_##m_name);                                                           \
	ADD_PROPERTY(m_info, "set_" #m_name, "get_" #m_name)

void RuinedCityTileMapLayer::_bind_methods()
{
	ClassDB::bind_method(D_METHOD("generate"), &RuinedCityTileMapLayer::generate);
	ClassDB::bind_method(D_METHOD("get_generate_button"), &RuinedCityTileMapLayer::get_generate_button);
	ClassDB::bind_method(D_METHOD("queue_debug_rebuild"), &RuinedCityTileMapLayer::queue_debug_rebuild);
	ClassDB::bind_method(D_METHOD("rebuild_debug_view"), &RuinedCityTileMapLayer::rebuild_debug_view);

	BIND_ENUM_CONSTANT(PASS_CITY);
	BIND_ENUM_CONSTANT(PASS_DESTRUCTION);
	BIND_ENUM_CONSTANT(PASS_OVERGROWTH);
	BIND_ENUM_CONSTANT(PASS_FINAL);

	// Map.
	RMC_BIND(map_width, PropertyInfo(Variant::INT, "map_width", PROPERTY_HINT_RANGE, "1,1024,1,or_greater"));
	RMC_BIND(map_height, PropertyInfo(Variant::INT, "map_height", PROPERTY_HINT_RANGE, "1,1024,1,or_greater"));
	RMC_BIND(generation_seed, PropertyInfo(Variant::INT, "generation_seed"));

	// Inspector button. The property is a Callable that is never stored.
	ADD_PROPERTY(
			PropertyInfo(Variant::CALLABLE, "generate_button", PROPERTY_HINT_TOOL_BUTTON, "Generate,Reload", PROPERTY_USAGE_EDITOR), "",
			"get_generate_button"
	);

	// Debug view.
	ADD_GROUP("Debug View", "debug_");
	ClassDB::bind_method(D_METHOD("set_debug_view", "enabled"), &RuinedCityTileMapLayer::set_debug_view);
	ClassDB::bind_method(D_METHOD("get_debug_view"), &RuinedCityTileMapLayer::get_debug_view);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "debug_view"), "set_debug_view", "get_debug_view");
	ClassDB::bind_method(D_METHOD("set_debug_pass", "pass"), &RuinedCityTileMapLayer::set_debug_pass);
	ClassDB::bind_method(D_METHOD("get_debug_pass"), &RuinedCityTileMapLayer::get_debug_pass);
	ADD_PROPERTY(
			PropertyInfo(Variant::INT, "debug_pass", PROPERTY_HINT_ENUM, "City,Destruction,Overgrowth,Final"), "set_debug_pass", "get_debug_pass"
	);
	ClassDB::bind_method(D_METHOD("set_debug_ramp", "ramp"), &RuinedCityTileMapLayer::set_debug_ramp);
	ClassDB::bind_method(D_METHOD("get_debug_ramp"), &RuinedCityTileMapLayer::get_debug_ramp);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "debug_ramp", PROPERTY_HINT_RESOURCE_TYPE, "Gradient"), "set_debug_ramp", "get_debug_ramp");

	// Pass 1.
	ADD_GROUP("City Pass", "city_");
	RMC_BIND(city_min_block_size, PropertyInfo(Variant::INT, "city_min_block_size", PROPERTY_HINT_RANGE, "1,64,1,or_greater"));
	RMC_BIND(city_max_block_size, PropertyInfo(Variant::INT, "city_max_block_size", PROPERTY_HINT_RANGE, "1,128,1,or_greater"));
	RMC_BIND(city_road_width, PropertyInfo(Variant::INT, "city_road_width", PROPERTY_HINT_RANGE, "0,16,1,or_greater"));
	RMC_BIND(city_building_margin, PropertyInfo(Variant::INT, "city_building_margin", PROPERTY_HINT_RANGE, "0,16,1,or_greater"));
	RMC_BIND(city_building_chance, PropertyInfo(Variant::FLOAT, "city_building_chance", PROPERTY_HINT_RANGE, "0,1,0.01"));

	// Pass 2.
	ADD_GROUP("Destruction Pass", "destruction_");
	RMC_BIND(destruction_crater_count, PropertyInfo(Variant::INT, "destruction_crater_count", PROPERTY_HINT_RANGE, "0,256,1,or_greater"));
	RMC_BIND(destruction_min_radius, PropertyInfo(Variant::FLOAT, "destruction_min_radius", PROPERTY_HINT_RANGE, "0.5,64,0.1,or_greater"));
	RMC_BIND(destruction_max_radius, PropertyInfo(Variant::FLOAT, "destruction_max_radius", PROPERTY_HINT_RANGE, "0.5,64,0.1,or_greater"));
	RMC_BIND(destruction_falloff, PropertyInfo(Variant::FLOAT, "destruction_falloff", PROPERTY_HINT_RANGE, "0.1,4,0.01,or_greater"));
	RMC_BIND(destruction_roughness, PropertyInfo(Variant::FLOAT, "destruction_roughness", PROPERTY_HINT_RANGE, "0,1,0.01"));

	// Pass 3.
	ADD_GROUP("Overgrowth Pass", "overgrowth_");
	RMC_BIND(overgrowth_scale, PropertyInfo(Variant::FLOAT, "overgrowth_scale", PROPERTY_HINT_RANGE, "0.5,128,0.1,or_greater"));
	RMC_BIND(overgrowth_octaves, PropertyInfo(Variant::INT, "overgrowth_octaves", PROPERTY_HINT_RANGE, "1,8,1"));
	RMC_BIND(overgrowth_persistence, PropertyInfo(Variant::FLOAT, "overgrowth_persistence", PROPERTY_HINT_RANGE, "0,1,0.01"));
	RMC_BIND(overgrowth_warp, PropertyInfo(Variant::FLOAT, "overgrowth_warp", PROPERTY_HINT_RANGE, "0,4,0.01,or_greater"));

	// Combine.
	ADD_GROUP("Final Map", "final_");
	RMC_BIND(final_use_city, PropertyInfo(Variant::BOOL, "final_use_city"));
	RMC_BIND(final_use_destruction, PropertyInfo(Variant::BOOL, "final_use_destruction"));
	RMC_BIND(final_use_overgrowth, PropertyInfo(Variant::BOOL, "final_use_overgrowth"));
	RMC_BIND(final_destruction_threshold, PropertyInfo(Variant::FLOAT, "final_destruction_threshold", PROPERTY_HINT_RANGE, "0,1,0.01"));
	RMC_BIND(final_overgrowth_threshold, PropertyInfo(Variant::FLOAT, "final_overgrowth_threshold", PROPERTY_HINT_RANGE, "0,1,0.01"));
	RMC_BIND(final_overgrowth_covers_buildings, PropertyInfo(Variant::BOOL, "final_overgrowth_covers_buildings"));

	// Tile output.
	ADD_GROUP("Tiles", "tiles_");
	RMC_BIND(tiles_source_id, PropertyInfo(Variant::INT, "tiles_source_id"));
	RMC_BIND(tiles_ground, PropertyInfo(Variant::VECTOR2I, "tiles_ground"));
	RMC_BIND(tiles_road, PropertyInfo(Variant::VECTOR2I, "tiles_road"));
	RMC_BIND(tiles_building, PropertyInfo(Variant::VECTOR2I, "tiles_building"));
	RMC_BIND(tiles_rubble, PropertyInfo(Variant::VECTOR2I, "tiles_rubble"));
	RMC_BIND(tiles_overgrown, PropertyInfo(Variant::VECTOR2I, "tiles_overgrown"));
}

#undef RMC_BIND

RuinedCityTileMapLayer::~RuinedCityTileMapLayer()
{
	if ( debug_item.is_valid() ) {
		RenderingServer* rs = RenderingServer::get_singleton();
		if ( rs != nullptr ) {
			rs->free_rid(debug_item);
		}
	}
}

void RuinedCityTileMapLayer::_notification(int p_what)
{
	if ( p_what == NOTIFICATION_ENTER_TREE ) {
		queue_debug_rebuild();
	}
}

// Helpers ----------------------------------------------------------------

int RuinedCityTileMapLayer::_width() const
{
	return std::max(map_width, 1);
}

int RuinedCityTileMapLayer::_height() const
{
	return std::max(map_height, 1);
}

uint64_t RuinedCityTileMapLayer::_pass_seed(uint64_t p_salt) const
{
	return static_cast<uint64_t>(generation_seed) * 0x9E3779B97F4A7C15ull + p_salt;
}

void RuinedCityTileMapLayer::_mark_dirty(uint32_t p_flags)
{
	dirty |= p_flags | DIRTY_FINAL;
	queue_debug_rebuild();
}

// Recomputes whatever the requested pass needs and is out of date.
// PASS_FINAL needs every pass.
void RuinedCityTileMapLayer::_ensure_pass(Pass p_pass)
{
	const bool all = p_pass == PASS_FINAL;

	if ( (all || p_pass == PASS_CITY) && (dirty & DIRTY_CITY) ) {
		_run_city_pass();
		dirty &= ~DIRTY_CITY;
	}
	if ( (all || p_pass == PASS_DESTRUCTION) && (dirty & DIRTY_DESTRUCTION) ) {
		_run_destruction_pass();
		dirty &= ~DIRTY_DESTRUCTION;
	}
	if ( (all || p_pass == PASS_OVERGROWTH) && (dirty & DIRTY_OVERGROWTH) ) {
		_run_overgrowth_pass();
		dirty &= ~DIRTY_OVERGROWTH;
	}
	if ( all && (dirty & DIRTY_FINAL) ) {
		_combine_passes();
		dirty &= ~DIRTY_FINAL;
	}
}

// Pass 1: city layout -----------------------------------------------------
//
// Recursive binary space partitioning. A rectangle that is larger than
// city_max_block_size is split by a road at a random position that keeps both
// halves at least city_min_block_size wide. Every remaining block receives a
// building (inset by city_building_margin) with probability
// city_building_chance. max_block_size is a soft limit: a rectangle that is too
// small to be split with the given min size and road width is kept as is.
//
// Random numbers are always consumed in the same pattern, so changing e.g. the
// building chance does not move the roads.
void RuinedCityTileMapLayer::_run_city_pass()
{
	const int W = _width();
	const int H = _height();
	city.assign(static_cast<size_t>(W) * H, KIND_GROUND);

	const int road_w = std::max(city_road_width, 0);
	const int min_b	 = std::max(city_min_block_size, 1);
	const int max_b	 = std::max(city_max_block_size, min_b);
	const int margin = std::max(city_building_margin, 0);

	Rng rng(_pass_seed(SALT_CITY));

	struct Rect
	{
		int x, y, w, h;
	};
	std::vector<Rect> pending;
	std::vector<Rect> blocks;
	pending.push_back({0, 0, W, H});

	while ( !pending.empty() ) {
		const Rect r = pending.back();
		pending.pop_back();

		const bool want_x = r.w > max_b && r.w >= 2 * min_b + road_w;
		const bool want_y = r.h > max_b && r.h >= 2 * min_b + road_w;

		if ( !want_x && !want_y ) {
			blocks.push_back(r);
			continue;
		}

		bool split_x = want_x;
		if ( want_x && want_y ) {
			split_x = (r.w == r.h) ? (rng.randf() < 0.5f) : (r.w > r.h);
		}

		if ( split_x ) {
			const int s = rng.randi_range(min_b, r.w - min_b - road_w);
			fill_rect(city, W, H, r.x + s, r.y, road_w, r.h, KIND_ROAD);
			pending.push_back({r.x, r.y, s, r.h});
			pending.push_back({r.x + s + road_w, r.y, r.w - s - road_w, r.h});
		} else {
			const int s = rng.randi_range(min_b, r.h - min_b - road_w);
			fill_rect(city, W, H, r.x, r.y + s, r.w, road_w, KIND_ROAD);
			pending.push_back({r.x, r.y, r.w, s});
			pending.push_back({r.x, r.y + s + road_w, r.w, r.h - s - road_w});
		}
	}

	for ( const Rect& b: blocks ) {
		const float roll = rng.randf();
		if ( roll >= city_building_chance ) {
			continue;
		}
		fill_rect(city, W, H, b.x + margin, b.y + margin, b.w - 2 * margin, b.h - 2 * margin, KIND_BUILDING);
	}
}

// Pass 2: artificial destruction --------------------------------------------
//
// A damage field in [0, 1]: 0 untouched, 1 fully destroyed. Each crater has a
// random centre and radius; damage falls off from its centre with the power
// destruction_falloff, and the crater edge is made irregular by
// destruction_roughness. Overlapping craters keep the larger value.
// The field does not look at the city, so it can be tuned on its own.
void RuinedCityTileMapLayer::_run_destruction_pass()
{
	const int W = _width();
	const int H = _height();
	destruction.assign(static_cast<size_t>(W) * H, 0.0f);

	const int count		  = std::max(destruction_crater_count, 0);
	const float r_min	  = std::max(destruction_min_radius, 0.0f);
	const float r_max	  = std::max(destruction_max_radius, r_min);
	const float roughness = clamp01(destruction_roughness);
	const float falloff	  = std::max(destruction_falloff, 0.01f);

	Rng rng(_pass_seed(SALT_DESTRUCTION));

	for ( int c = 0; c < count; c++ ) {
		// Always four draws per crater, so parameters never shift other craters.
		const float cx			  = rng.randf() * W;
		const float cy			  = rng.randf() * H;
		const float radius		  = lerpf(r_min, r_max, rng.randf());
		const uint32_t noise_seed = rng.next_u32();

		const float reach = radius * (1.0f + roughness);
		const int x0	  = std::max(static_cast<int>(std::floor(cx - reach)), 0);
		const int x1	  = std::min(static_cast<int>(std::ceil(cx + reach)), W - 1);
		const int y0	  = std::max(static_cast<int>(std::floor(cy - reach)), 0);
		const int y1	  = std::min(static_cast<int>(std::ceil(cy + reach)), H - 1);

		for ( int y = y0; y <= y1; y++ ) {
			for ( int x = x0; x <= x1; x++ ) {
				const float dx = (x + 0.5f) - cx;
				const float dy = (y + 0.5f) - cy;
				// The edge noise has a fixed feature size of roughly 3 tiles.
				const float n				 = value_noise(x * 0.35f, y * 0.35f, noise_seed);
				const float effective_radius = radius * (1.0f + roughness * (n * 2.0f - 1.0f));
				if ( effective_radius <= 0.0f ) {
					continue;
				}
				const float d = std::sqrt(dx * dx + dy * dy) / effective_radius;
				if ( d >= 1.0f ) {
					continue;
				}
				float& cell = destruction[static_cast<size_t>(y) * W + x];
				cell		= std::max(cell, std::pow(1.0f - d, falloff));
			}
		}
	}
}

// Pass 3: organic overgrowth ----------------------------------------------
//
// A growth field in [0, 1] from fractal value noise. overgrowth_scale is the
// feature size in tiles; overgrowth_warp bends the sample position with a second
// noise field, which turns blobs into winding, vine-like shapes.
// The field does not look at the city, so it can be tuned on its own.
void RuinedCityTileMapLayer::_run_overgrowth_pass()
{
	const int W = _width();
	const int H = _height();
	overgrowth.assign(static_cast<size_t>(W) * H, 0.0f);

	const int octaves		= std::min(std::max(overgrowth_octaves, 1), 8);
	const float persistence = clamp01(overgrowth_persistence);
	const float warp		= std::max(overgrowth_warp, 0.0f);
	const float inv_scale	= 1.0f / std::max(overgrowth_scale, 0.001f);

	Rng rng(_pass_seed(SALT_OVERGROWTH));
	const uint32_t seed_main   = rng.next_u32();
	const uint32_t seed_warp_x = rng.next_u32();
	const uint32_t seed_warp_y = rng.next_u32();

	for ( int y = 0; y < H; y++ ) {
		for ( int x = 0; x < W; x++ ) {
			float fx = (x + 0.5f) * inv_scale;
			float fy = (y + 0.5f) * inv_scale;
			if ( warp > 0.0f ) {
				const float wx = fbm(fx, fy, 2, 0.5f, seed_warp_x) - 0.5f;
				const float wy = fbm(fx, fy, 2, 0.5f, seed_warp_y) - 0.5f;
				fx += wx * 2.0f * warp;
				fy += wy * 2.0f * warp;
			}
			overgrowth[static_cast<size_t>(y) * W + x] = clamp01(fbm(fx, fy, octaves, persistence, seed_main));
		}
	}
}

// Combine ----------------------------------------------------------------
//
// Applied per cell, in this order (each step can be switched off with the
// final_use_* properties):
//   city:        start from the city kind (ground if the city pass is off)
//   destruction: damage >= final_destruction_threshold turns buildings and
//                roads into rubble; ground is left unchanged
//   overgrowth:  growth >= final_overgrowth_threshold turns the cell into
//                overgrown, except intact buildings unless
//                final_overgrowth_covers_buildings is set
void RuinedCityTileMapLayer::_combine_passes()
{
	const size_t count = static_cast<size_t>(_width()) * _height();
	final_map.assign(count, KIND_GROUND);

	for ( size_t i = 0; i < count; i++ ) {
		uint8_t kind = final_use_city ? city[i] : static_cast<uint8_t>(KIND_GROUND);

		if ( final_use_destruction && destruction[i] >= final_destruction_threshold ) {
			if ( kind == KIND_BUILDING || kind == KIND_ROAD ) {
				kind = KIND_RUBBLE;
			}
		}

		if ( final_use_overgrowth && overgrowth[i] >= final_overgrowth_threshold ) {
			if ( kind != KIND_BUILDING || final_overgrowth_covers_buildings ) {
				kind = KIND_OVERGROWN;
			}
		}

		final_map[i] = kind;
	}
}

// Output -----------------------------------------------------------------

Callable RuinedCityTileMapLayer::get_generate_button()
{
	return Callable(this, "generate");
}

void RuinedCityTileMapLayer::generate()
{
	_ensure_pass(PASS_FINAL);
	_write_tiles();
	queue_debug_rebuild();

	// Tile edits made from code do not mark the scene as modified on their own.
	Engine* engine = Engine::get_singleton();
	if ( engine != nullptr && engine->is_editor_hint() ) {
		EditorInterface* editor = EditorInterface::get_singleton();
		if ( editor != nullptr ) {
			editor->mark_scene_as_unsaved();
		}
	}
}

// Replaces the layer's contents with the final map. The map occupies cells
// (0, 0) to (map_width - 1, map_height - 1).
void RuinedCityTileMapLayer::_write_tiles()
{
	if ( get_tile_set().is_null() ) {
		UtilityFunctions::push_warning("RuinedCityTileMapLayer: no TileSet is assigned, nothing was written.");
		return;
	}

	const Vector2i atlas_for_kind[KIND_COUNT] = {tiles_ground, tiles_road, tiles_building, tiles_rubble, tiles_overgrown};

	bool any_mapped = false;
	for ( const Vector2i& coords: atlas_for_kind ) {
		any_mapped = any_mapped || (coords.x >= 0 && coords.y >= 0);
	}
	if ( !any_mapped ) {
		UtilityFunctions::push_warning(
				"RuinedCityTileMapLayer: all tiles_* atlas coords are (-1, -1), nothing was written. Set them in the 'Tiles' group."
		);
		return;
	}

	const int W = _width();
	const int H = _height();

	clear();
	for ( int y = 0; y < H; y++ ) {
		for ( int x = 0; x < W; x++ ) {
			const Vector2i coords = atlas_for_kind[final_map[static_cast<size_t>(y) * W + x]];
			if ( coords.x < 0 || coords.y < 0 ) {
				continue;
			}
			set_cell(Vector2i(x, y), tiles_source_id, coords);
		}
	}
}

// Debug view ---------------------------------------------------------------
//
// The overlay is a separate canvas item that is a child of this layer's canvas
// item and is drawn on top of the tiles. Every cell becomes one rectangle at
// map_to_local(cell), sized like a tile of the TileSet, coloured by sampling
// the ramp at the cell's value in [0, 1].

float RuinedCityTileMapLayer::_debug_value(Pass p_pass, size_t p_index) const
{
	switch ( p_pass ) {
		case PASS_CITY:
			return city[p_index] / static_cast<float>(KIND_BUILDING);
		case PASS_DESTRUCTION:
			return destruction[p_index];
		case PASS_OVERGROWTH:
			return overgrowth[p_index];
		case PASS_FINAL:
			return final_map[p_index] / static_cast<float>(KIND_COUNT - 1);
	}
	return 0.0f;
}

void RuinedCityTileMapLayer::queue_debug_rebuild()
{
	if ( debug_rebuild_queued ) {
		return;
	}
	if ( !debug_view && !debug_item.is_valid() ) {
		return;
	}
	debug_rebuild_queued = true;
	call_deferred("rebuild_debug_view");
}

void RuinedCityTileMapLayer::rebuild_debug_view()
{
	debug_rebuild_queued = false;

	RenderingServer* rs = RenderingServer::get_singleton();
	if ( rs == nullptr ) {
		return;
	}

	if ( !debug_view || !is_inside_tree() ) {
		if ( debug_item.is_valid() ) {
			rs->canvas_item_clear(debug_item);
		}
		return;
	}

	Ref<TileSet> tile_set = get_tile_set();
	if ( tile_set.is_null() ) {
		if ( debug_item.is_valid() ) {
			rs->canvas_item_clear(debug_item);
		}
		if ( !warned_missing_tile_set ) {
			warned_missing_tile_set = true;
			UtilityFunctions::push_warning("RuinedCityTileMapLayer: the debug view needs a TileSet to know the cell size.");
		}
		return;
	}
	warned_missing_tile_set = false;

	if ( !debug_item.is_valid() ) {
		debug_item = rs->canvas_item_create();
		rs->canvas_item_set_parent(debug_item, get_canvas_item());
		rs->canvas_item_set_z_as_relative_to_parent(debug_item, false);
		rs->canvas_item_set_z_index(debug_item, DEBUG_Z_INDEX);
	}
	rs->canvas_item_clear(debug_item);

	_ensure_pass(debug_pass);

	std::vector<Color> lut(256);
	for ( int i = 0; i < 256; i++ ) {
		const float t = i / 255.0f;
		lut[i]		  = debug_ramp.is_valid() ? debug_ramp->sample(t) : default_ramp_color(t);
	}

	const Vector2i tile_size = tile_set->get_tile_size();
	const Vector2 size(tile_size.x, tile_size.y);
	const int W = _width();
	const int H = _height();

	for ( int y = 0; y < H; y++ ) {
		for ( int x = 0; x < W; x++ ) {
			const float value	 = clamp01(_debug_value(debug_pass, static_cast<size_t>(y) * W + x));
			const Color& color	 = lut[static_cast<size_t>(std::lround(value * 255.0f))];
			const Vector2 centre = map_to_local(Vector2i(x, y));
			rs->canvas_item_add_rect(debug_item, Rect2(centre - size * 0.5f, size), color);
		}
	}
}

void RuinedCityTileMapLayer::set_debug_view(bool p_enabled)
{
	if ( debug_view == p_enabled ) {
		return;
	}
	debug_view = p_enabled;
	queue_debug_rebuild();
}

bool RuinedCityTileMapLayer::get_debug_view() const
{
	return debug_view;
}

void RuinedCityTileMapLayer::set_debug_pass(Pass p_pass)
{
	if ( debug_pass == p_pass ) {
		return;
	}
	debug_pass = p_pass;
	queue_debug_rebuild();
}

RuinedCityTileMapLayer::Pass RuinedCityTileMapLayer::get_debug_pass() const
{
	return debug_pass;
}

void RuinedCityTileMapLayer::set_debug_ramp(const Ref<Gradient>& p_ramp)
{
	if ( debug_ramp == p_ramp ) {
		return;
	}
	const Callable on_changed(this, "queue_debug_rebuild");
	if ( debug_ramp.is_valid() && debug_ramp->is_connected("changed", on_changed) ) {
		debug_ramp->disconnect("changed", on_changed);
	}
	debug_ramp = p_ramp;
	if ( debug_ramp.is_valid() && !debug_ramp->is_connected("changed", on_changed) ) {
		debug_ramp->connect("changed", on_changed);
	}
	queue_debug_rebuild();
}

Ref<Gradient> RuinedCityTileMapLayer::get_debug_ramp() const
{
	return debug_ramp;
}
