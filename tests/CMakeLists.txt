function(neutron_test test)
	file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../neutron.deps" packages)

	include (ValaPrecompile)
	vala_precompile(${test}_SOURCES
		SOURCES
			${test}.vala
		PACKAGES
			${packages}
		CUSTOM_VAPIS
			${CMAKE_CURRENT_BINARY_DIR}/../src/neutron.vapi
		OPTIONS
			--thread
			--target-glib=${GLIB_VERSION}
	)

	add_executable(${test} ${${test}_SOURCES})
	target_link_libraries(${test}
		${LIBRARIES}
		neutron
	)

	add_test(NAME ${test} COMMAND ${test})
endfunction(neutron_test)

neutron_test(serializable-values)
neutron_test(http-server-simplerequest)
neutron_test(http-server-maxsize)
neutron_test(http-server-session)
neutron_test(http-server-sessioncleanup)
neutron_test(http-parser-keepalive)
