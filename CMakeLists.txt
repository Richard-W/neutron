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

find_package(Vala REQUIRED)
include(UseVala)

find_package(PkgConfig REQUIRED)

pkg_check_modules(GLIB glib-2.0 REQUIRED)
include_directories(${GLIB_INCLUDE_DIRS})
link_directories(${GLIB_LIBRARY_DIRS})

if(GLIB_VERSION VERSION_LESS 2.32)
	message(FATAL_ERROR "Glib version 2.32 required. Found version ${GLIB_VERSION}")
endif(GLIB_VERSION VERSION_LESS 2.32)

pkg_check_modules(GOBJECT gobject-2.0 REQUIRED)
include_directories(${GOBJECT_INCLUDE_DIRS})
link_directories(${GOBJECT_LIBRARY_DIRS})

pkg_check_modules(GIO gio-2.0 REQUIRED)
include_directories(${GIO_INCLUDE_DIRS})
link_directories(${GIO_LIBRARY_DIRS})

#debian and ubuntu ship only ship gee-1.0 pc files
if(DEBIAN)
	pkg_check_modules(GEE gee-1.0 REQUIRED)
else(DEBIAN)
	pkg_check_modules(GEE gee-0.8 REQUIRED)
endif(DEBIAN)
include_directories(${GEE_INCLUDE_DIRS})
link_directories(${GEE_LIBRARY_DIRS})

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
target_link_libraries(neutron
	${GLIB_LIBRARIES}
	${GOBJECT_LIBRARIES}
	${GIO_LIBRARIES}
	${GEE_LIBRARIES}
)

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
endif(EXAMPLES)

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

set(CPACK_GENERATOR "DEB")
set(CPACK_PACKAGE_VERSION_MAJOR ${VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${VERSION_PATCH})
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libglib2.0-0,libgee2,glib-networking")
set(CPACK_PACKAGE_DESCRIPTION "Web-development library using the GObject-system")
set(CPACK_PACKAGE_CONTACT "Richard Wiedenhöft <richard.wiedenhoeft@gmail.com>")
include(CPack)
