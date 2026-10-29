#pragma once

#include <godot_cpp/classes/gradient.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/tile_map_layer.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <cstddef>
#include <cstdint>
#include <vector>

using namespace godot;

// Getter/setter pair for a property that feeds the passes. Changing the value
// marks the given passes (and always the final map) as needing a recompute.
#define RMC_PROPERTY(m_type, m_name, m_dirty_flags) \
	void set_##m_name(m_type p_value) {             \
		if (m_name == p_value) {                    \
			return;                                 \
		}                                           \
		m_name = p_value;                           \
		_mark_dirty(m_dirty_flags);                 \
	}                                               \
	m_type get_##m_name() const {                   \
		return m_name;                              \
	}

// Getter/setter pair for a property that does not affect any pass.
#define RMC_PROPERTY_PLAIN(m_type, m_name) \
	void set_##m_name(m_type p_value) {    \
		m_name = p_value;                  \
	}                                      \
	m_type get_##m_name() const {          \
		return m_name;                     \
	}

/*
 * TileMapLayer that generates a ruined city in three independent passes:
 *
 *   1. City        - BSP blocks separated by roads, a building per block.
 *   2. Destruction - a 0..1 damage field made of irregular craters.
 *   3. Overgrowth  - a 0..1 growth field made of domain-warped fBm noise.
 *
 * Every pass has its own parameters and its own random stream (derived from
 * generation_seed), so tuning one pass never changes the output of another.
 * The final map combines the passes and is what generate() writes to the layer.
 *
 * Pass data lives in memory only and is recomputed on demand, so the debug view
 * follows the inspector live. Tiles are only written when generate() runs.
 */
class RuinedCityTileMapLayer : public TileMapLayer {
	GDCLASS(RuinedCityTileMapLayer, TileMapLayer)

public:
	enum Pass {
		PASS_CITY,
		PASS_DESTRUCTION,
		PASS_OVERGROWTH,
		PASS_FINAL,
	};

	~RuinedCityTileMapLayer();

	// Runs all passes, combines them and writes the result into this layer.
	void generate();
	// Returns a Callable for the inspector button (PROPERTY_HINT_TOOL_BUTTON).
	Callable get_generate_button();

	// Debug view.
	void set_debug_view(bool p_enabled);
	bool get_debug_view() const;
	void set_debug_pass(Pass p_pass);
	Pass get_debug_pass() const;
	void set_debug_ramp(const Ref<Gradient> &p_ramp);
	Ref<Gradient> get_debug_ramp() const;
	void queue_debug_rebuild();
	void rebuild_debug_view();

	// Map.
	RMC_PROPERTY(int, map_width, DIRTY_ALL)
	RMC_PROPERTY(int, map_height, DIRTY_ALL)
	RMC_PROPERTY(int64_t, generation_seed, DIRTY_ALL)

	// City pass.
	RMC_PROPERTY(int, city_min_block_size, DIRTY_CITY)
	RMC_PROPERTY(int, city_max_block_size, DIRTY_CITY)
	RMC_PROPERTY(int, city_road_width, DIRTY_CITY)
	RMC_PROPERTY(int, city_building_margin, DIRTY_CITY)
	RMC_PROPERTY(float, city_building_chance, DIRTY_CITY)

	// Destruction pass.
	RMC_PROPERTY(int, destruction_crater_count, DIRTY_DESTRUCTION)
	RMC_PROPERTY(float, destruction_min_radius, DIRTY_DESTRUCTION)
	RMC_PROPERTY(float, destruction_max_radius, DIRTY_DESTRUCTION)
	RMC_PROPERTY(float, destruction_falloff, DIRTY_DESTRUCTION)
	RMC_PROPERTY(float, destruction_roughness, DIRTY_DESTRUCTION)

	// Overgrowth pass.
	RMC_PROPERTY(float, overgrowth_scale, DIRTY_OVERGROWTH)
	RMC_PROPERTY(int, overgrowth_octaves, DIRTY_OVERGROWTH)
	RMC_PROPERTY(float, overgrowth_persistence, DIRTY_OVERGROWTH)
	RMC_PROPERTY(float, overgrowth_warp, DIRTY_OVERGROWTH)

	// Combine step.
	RMC_PROPERTY(bool, final_use_city, DIRTY_FINAL)
	RMC_PROPERTY(bool, final_use_destruction, DIRTY_FINAL)
	RMC_PROPERTY(bool, final_use_overgrowth, DIRTY_FINAL)
	RMC_PROPERTY(float, final_destruction_threshold, DIRTY_FINAL)
	RMC_PROPERTY(float, final_overgrowth_threshold, DIRTY_FINAL)
	RMC_PROPERTY(bool, final_overgrowth_covers_buildings, DIRTY_FINAL)

	// Tile output. Atlas coords of (-1, -1) mean "leave the cell empty".
	RMC_PROPERTY_PLAIN(int, tiles_source_id)
	RMC_PROPERTY_PLAIN(Vector2i, tiles_ground)
	RMC_PROPERTY_PLAIN(Vector2i, tiles_road)
	RMC_PROPERTY_PLAIN(Vector2i, tiles_building)
	RMC_PROPERTY_PLAIN(Vector2i, tiles_rubble)
	RMC_PROPERTY_PLAIN(Vector2i, tiles_overgrown)

protected:
	static void _bind_methods();
	void _notification(int p_what);

private:
	// Values stored in the final map. The city pass only produces
	// GROUND, ROAD and BUILDING.
	enum Kind : uint8_t {
		KIND_GROUND,
		KIND_ROAD,
		KIND_BUILDING,
		KIND_RUBBLE,
		KIND_OVERGROWN,
		KIND_COUNT,
	};

	static constexpr uint32_t DIRTY_CITY = 1u << 0;
	static constexpr uint32_t DIRTY_DESTRUCTION = 1u << 1;
	static constexpr uint32_t DIRTY_OVERGROWTH = 1u << 2;
	static constexpr uint32_t DIRTY_FINAL = 1u << 3;
	static constexpr uint32_t DIRTY_ALL = DIRTY_CITY | DIRTY_DESTRUCTION | DIRTY_OVERGROWTH | DIRTY_FINAL;

	// Map.
	int map_width = 64;
	int map_height = 64;
	int64_t generation_seed = 0;

	// Debug view.
	bool debug_view = false;
	Pass debug_pass = PASS_FINAL;
	Ref<Gradient> debug_ramp;

	// City pass.
	int city_min_block_size = 6;
	int city_max_block_size = 14;
	int city_road_width = 2;
	int city_building_margin = 1;
	float city_building_chance = 0.85f;

	// Destruction pass.
	int destruction_crater_count = 8;
	float destruction_min_radius = 3.0f;
	float destruction_max_radius = 9.0f;
	float destruction_falloff = 0.75f;
	float destruction_roughness = 0.35f;

	// Overgrowth pass.
	float overgrowth_scale = 10.0f;
	int overgrowth_octaves = 3;
	float overgrowth_persistence = 0.5f;
	float overgrowth_warp = 0.75f;

	// Combine step.
	bool final_use_city = true;
	bool final_use_destruction = true;
	bool final_use_overgrowth = true;
	float final_destruction_threshold = 0.35f;
	float final_overgrowth_threshold = 0.55f;
	bool final_overgrowth_covers_buildings = false;

	// Tile output.
	int tiles_source_id = 0;
	Vector2i tiles_ground = Vector2i(-1, -1);
	Vector2i tiles_road = Vector2i(-1, -1);
	Vector2i tiles_building = Vector2i(-1, -1);
	Vector2i tiles_rubble = Vector2i(-1, -1);
	Vector2i tiles_overgrown = Vector2i(-1, -1);

	// Pass data (row-major, map_width * map_height). Never saved.
	std::vector<uint8_t> city; // Kind values: ground / road / building
	std::vector<float> destruction; // damage 0..1
	std::vector<float> overgrowth; // growth 0..1
	std::vector<uint8_t> final_map; // Kind values

	uint32_t dirty = DIRTY_ALL;
	bool debug_rebuild_queued = false;
	bool warned_missing_tile_set = false;
	RID debug_item;

	int _width() const;
	int _height() const;
	uint64_t _pass_seed(uint64_t p_salt) const;
	void _mark_dirty(uint32_t p_flags);
	void _ensure_pass(Pass p_pass);
	void _run_city_pass();
	void _run_destruction_pass();
	void _run_overgrowth_pass();
	void _combine_passes();
	void _write_tiles();
	float _debug_value(Pass p_pass, size_t p_index) const;
};

VARIANT_ENUM_CAST(RuinedCityTileMapLayer::Pass);

#undef RMC_PROPERTY
#undef RMC_PROPERTY_PLAIN
