if(INSTALL_LIBRARY)
	install(
		TARGETS
			neutron
		LIBRARY DESTINATION lib
	)
endif(INSTALL_LIBRARY)

if(INSTALL_HEADERS)
	install(
		FILES
			${CMAKE_CURRENT_SOURCE_DIR}/neutron.deps
			${CMAKE_CURRENT_BINARY_DIR}/src/neutron.vapi
		DESTINATION
			share/vala/vapi/
	)

	install(
		FILES
			${CMAKE_CURRENT_BINARY_DIR}/src/neutron.h
		DESTINATION
			include/
	)

	configure_file(
		"${CMAKE_CURRENT_SOURCE_DIR}/neutron.pc.in"
		"${CMAKE_CURRENT_BINARY_DIR}/neutron.pc"
		@ONLY
	)

	install(
		FILES
			${CMAKE_CURRENT_BINARY_DIR}/neutron.pc
		DESTINATION
			lib/pkgconfig/
	)
endif(INSTALL_HEADERS)
