class_name LobberStateMachine
extends StateMachine

var m_current_target: LEntity

func _on_character_cell_changed(_type: LEntity, _old: Vector2i, _new: Vector2i) -> void:
	if _type is LimePlayer:

		if parent.path_manager.is_entity_in_range(parent.path_manager_id, _type, parent.area_of_view_radius):
			if !m_current_target:
				m_current_target = _type
		else:
			m_current_target = null

	elif _type is Lobber:
		#var units = lobber.path_manager.entities_of_type(LimePlayer)
		pass

	pass
