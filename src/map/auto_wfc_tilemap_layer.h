#pragma once

#include <godot_cpp/classes/tile_map_layer.hpp>
#include <godot_cpp/classes/wrapped.hpp>

namespace lime {

	class LAutoWFCTilemapLayer : public godot::TileMapLayer
	{
		GDCLASS(LAutoWFCTilemapLayer, godot::TileMapLayer)

		public:
		LAutoWFCTilemapLayer();
		~LAutoWFCTilemapLayer();

		void generate();

		private:



	};


}; // namespace lime
