#include "register_types.h"

#include "editor/build_lime_btn.hpp"
#include "gdexample.h"


#include <gdextension_interface.h>
#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_lime_module(ModuleInitializationLevel p_level)
{
	if ( p_level != MODULE_INITIALIZATION_LEVEL_SCENE ) {
		GDREGISTER_CLASS(GDExample);
	}


	if ( p_level == MODULE_INITIALIZATION_LEVEL_EDITOR ) {
		GDREGISTER_INTERNAL_CLASS(LimeToolbarPlugin);
		EditorPlugins::add_by_type<LimeToolbarPlugin>();
	}
}

void uninitialize_lime_module(ModuleInitializationLevel p_level)
{
	if ( p_level == MODULE_INITIALIZATION_LEVEL_EDITOR ) {
		EditorPlugins::remove_by_type<LimeToolbarPlugin>();
	}

	if ( p_level != MODULE_INITIALIZATION_LEVEL_SCENE ) {
		return;
	}
}

extern "C" {
// Initialization.
GDExtensionBool GDE_EXPORT example_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization* r_initialization
)
{
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_lime_module);
	init_obj.register_terminator(uninitialize_lime_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
