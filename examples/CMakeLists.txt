function(add_neutron_example example sources)
	file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../neutron.deps" packages)

	vala_precompile(c_sources
		SOURCES
			${sources}
		PACKAGES
			${packages}
		CUSTOM_VAPIS
			${CMAKE_CURRENT_BINARY_DIR}/../src/neutron.vapi
		OPTIONS
			--thread
			--target-glib=${GLIB_VERSION}
	)

	add_executable(${example} ${c_sources})
	target_link_libraries(${example}
		${GLIB_LIBRARIES}
		${GOBJECT_LIBRARIES}
		${GIO_LIBRARIES}
		neutron
	)
endfunction(add_neutron_example)

add_neutron_example(display_request display_request.vala)
add_neutron_example(websocket websocket.vala)
