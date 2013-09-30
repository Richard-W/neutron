cmake_minimum_required(VERSION 2.6)
project(neutron)

option(INSTALL_HEADERS "Install header, vapi and pkgconfig files" ON)
option(INSTALL_LIBRARY "Install shared library" ON)
option(DEBIAN "Compile on debian" OFF)
option(EXAMPLES "Build examples" OFF)

set(VERSION_MAJOR "0")
set(VERSION_MINOR "1")
set(VERSION_PATCH "0")

#needed for example for pkgconfig
set(VERSION_STRING "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

#include project-specific cmake-files
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

include(NeutronDependencies)

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
		neutron-edb-serializable.vala
	SOURCE_DIRECTORY
		src
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

if(EXAMPLES)
	configure_file(
		"${CMAKE_CURRENT_SOURCE_DIR}/examples/example.conf.in"
		"${CMAKE_CURRENT_BINARY_DIR}/examples/example.conf"
		@ONLY
	)

	configure_file(
		"${CMAKE_CURRENT_SOURCE_DIR}/examples/example_vars.vala.in"
		"${CMAKE_CURRENT_BINARY_DIR}/examples/example_vars.vala"
		@ONLY
	)

	include(NeutronExample)

	add_neutron_example(display_request display_request.vala)
	add_neutron_example(websocket websocket.vala)
	add_neutron_example(serial serial.vala)
endif(EXAMPLES)

include(NeutronInstall)

## Uncomment this if you wish to build a debian-package using "make package"
#include(NeutronCPack)
