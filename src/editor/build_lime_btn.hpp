#pragma once

#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/thread.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

class LimeToolbarPlugin : public EditorPlugin
{
	GDCLASS(LimeToolbarPlugin, EditorPlugin)

	String source_dir = ProjectSettings::get_singleton()->globalize_path("res://");
	String build_dir  = source_dir;

	Button* button = nullptr;
	Ref<FileAccess> m_stdio;
	int m_process_pid = -1;

	enum class CMakePass { NONE = 0, MAKEFILE, BUILD };

	CMakePass m_current_pass = CMakePass::NONE;

protected:
	static void _bind_methods()
	{
		ClassDB::bind_method(D_METHOD("_on_build_lime_button_pressed"), &LimeToolbarPlugin::_on_build_lime_button_pressed);
		ClassDB::bind_method(D_METHOD("_build_log", "line"), &LimeToolbarPlugin::_build_log);
		ClassDB::bind_method(D_METHOD("_build_finished", "exit_code"), &LimeToolbarPlugin::_build_finished);
	}

public:
	void _enter_tree() override
	{
		button = memnew(Button);
		button->set_text("Build Lime Extension");
		button->connect("pressed", Callable(this, "_on_build_lime_button_pressed"));
		add_control_to_container(CONTAINER_TOOLBAR, button);
	}

	void _exit_tree() override
	{
		if ( button ) {
			remove_control_from_container(CONTAINER_TOOLBAR, button);
			button->queue_free();
			button = nullptr;
		}
	}

	void _on_build_lime_button_pressed()
	{
		if ( source_dir.is_empty() || build_dir.is_empty() ) {
			UtilityFunctions::push_error("[Lime] source_dir and build_dir must be set before building.");
			return;
		}

		button->set_disabled(true);
		_make_worker();
	}

	void _process(double delta) override
	{
		if ( m_process_pid != -1 && m_stdio.is_valid() ) {
			if ( String output = m_stdio->get_line(); !output.is_empty() )
				call_deferred("_build_log", "[Lime] " + output);

			if ( !OS::get_singleton()->is_process_running(m_process_pid) ) {
				switch ( m_current_pass ) {
					case CMakePass::NONE:
						break;
					case CMakePass::MAKEFILE:
						_build_worker();
						break;
					case CMakePass::BUILD:
						_build_finished(OS::get_singleton()->get_process_exit_code(m_process_pid));
						break;
				};
			}
		}
	}

private:
	void _make_worker()
	{
		_run_and_log("cmake", PackedStringArray{build_dir});
		m_current_pass = CMakePass::MAKEFILE;
	}

	void _build_worker()
	{
		_run_and_log("cmake", PackedStringArray{"--build", build_dir});
		m_current_pass = CMakePass::BUILD;
	}

	void _run_and_log(const String& exe, const PackedStringArray& args)
	{
		call_deferred("_build_log", "[Lime] " + exe + " " + String(" ").join(args));

		Dictionary info = OS::get_singleton()->execute_with_pipe(exe, args, false);
		m_stdio			= Ref<FileAccess>(Object::cast_to<FileAccess>(info.get("stdio", Variant())));
		m_process_pid	= info.get("pid", -1);
	}

	void _build_log(const String& line)
	{
		UtilityFunctions::print(line);
	}

	void _build_finished(int exit_code)
	{
		m_process_pid = -1;
		m_current_pass = CMakePass::NONE;
		button->set_disabled(false);

		if ( exit_code == 0 ) {
			UtilityFunctions::print("[Lime] Build succeeded.");
		} else {
			UtilityFunctions::push_error("[Lime] Build failed.");
		}
	}
};
