function(add_neutron_example example sources)
	file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/neutron.deps" packages)

	vala_precompile(c_sources
		SOURCES
			${sources}
		SOURCE_DIRECTORY
			examples
		PACKAGES
			${packages}
		CUSTOM_VAPIS
			${CMAKE_CURRENT_BINARY_DIR}/src/neutron.vapi
			${CMAKE_CURRENT_BINARY_DIR}/examples/example_vars.vala
		OPTIONS
			--thread
			--target-glib=${GLIB_VERSION}
	)

	add_executable(examples/${example} ${c_sources})
	target_link_libraries(examples/${example}
		${GLIB_LIBRARIES}
		${GOBJECT_LIBRARIES}
		${GIO_LIBRARIES}
		neutron
	)
endfunction(add_neutron_example)

