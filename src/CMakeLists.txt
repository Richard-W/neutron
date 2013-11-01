set(VALA_PACKAGES gio-2.0 posix)
if(DEBIAN)
	list(APPEND VALA_PACKAGES gee-1.0)
else(DEBIAN)
	list(APPEND VALA_PACKAGES gee-0.8)
endif(DEBIAN)

vala_precompile(C_SOURCES
	SOURCES
		neutron-application.vala
		neutron-configuration.vala
		neutron-errors.vala
		neutron-http-server.vala
		neutron-http-parser.vala
		neutron-session.vala
		neutron-http-request.vala
		neutron-http-requestimpl.vala
		neutron-threadcontroller.vala
		neutron-http-entity.vala
		neutron-http-staticentity.vala
		neutron-http-fileentity.vala
		neutron-http-chunkconverter.vala
		neutron-http-notfoundentity.vala
		neutron-websocket-httpupgradeentity.vala
		neutron-websocket-connection.vala
		neutron-serializable.vala
	PACKAGES
		${VALA_PACKAGES}
	GENERATE_VAPI
		neutron
	OPTIONS
		--target-glib=${GLIB_VERSION}
		--thread
)

add_library(neutron SHARED ${C_SOURCES})
target_link_libraries(neutron ${LIBRARIES})

install(
	TARGETS
		neutron
	LIBRARY DESTINATION lib
)

install(
	FILES
		${CMAKE_CURRENT_BINARY_DIR}/neutron.h
	DESTINATION
		include/
)

install(
	FILES
		${CMAKE_CURRENT_BINARY_DIR}/neutron.vapi
	DESTINATION
		share/vala/vapi/
)


