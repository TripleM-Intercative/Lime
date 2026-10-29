#pragma once

#define L_PROPERTY(m_type, m_name)                                                                                                                   \
	void set_##m_name(m_type p_value)                                                                                                                \
	{                                                                                                                                                \
		if ( m_name == p_value ) {                                                                                                                   \
			return;                                                                                                                                  \
		}                                                                                                                                            \
		m_name = p_value;                                                                                                                            \
	}                                                                                                                                                \
	m_type get_##m_name() const                                                                                                                      \
	{                                                                                                                                                \
		return m_name;                                                                                                                               \
	}
