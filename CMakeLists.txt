cmake_minimum_required(VERSION 2.6)
project(neutron)

option(INSTALL_HEADERS "Install header, vapi and pkgconfig files" ON)
option(INSTALL_LIBRARY "Install shared library" ON)

set(VERSION_MAJOR 0)
set(VERSION_MINOR 1)
set(VERSION_PATCH 0)

set(VERSION_STRING "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
find_package(Vala REQUIRED)
include(UseVala)

find_package(PkgConfig REQUIRED)

pkg_check_modules(GLIB glib-2.0 REQUIRED)
include_directories(${GLIB_INCLUDE_DIRS})
link_directories(${GLIB_LIBRARY_DIRS})

pkg_check_modules(GOBJECT gobject-2.0 REQUIRED)
include_directories(${GOBJECT_INCLUDE_DIRS})
link_directories(${GOBJECT_LIBRARY_DIRS})

pkg_check_modules(GIO gio-2.0 REQUIRED)
include_directories(${GIO_INCLUDE_DIRS})
link_directories(${GIO_LIBRARY_DIRS})

pkg_check_modules(GEE gee-0.8 REQUIRED)
include_directories(${GEE_INCLUDE_DIRS})
link_directories(${GEE_LIBRARY_DIRS})

vala_precompile(C_SOURCES
		src/neutron-application.vala
		src/neutron-configuration.vala
		src/neutron-errors.vala
		src/neutron-http-server.vala
		src/neutron-http-parser.vala
		src/neutron-http-session.vala
		src/neutron-http-request.vala
		src/neutron-http-requestimpl.vala
		src/neutron-http-sessionprovider.vala
		src/neutron-threadcontroller.vala
		src/neutron-http-entity.vala
		src/neutron-http-staticentity.vala
		src/neutron-http-fileentity.vala
		src/neutron-http-chunkconverter.vala
		src/neutron-http-notfoundentity.vala
	PACKAGES
		gio-2.0
		gee-0.8
		posix
	GENERATE_VAPI
		neutron
	CUSTOM_VAPIS
		vapi/http_parser.vapi
	OPTIONS
		--target-glib=2.32
		--thread
)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/external/http_parser)
list(APPEND C_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/external/http_parser/http_parser.c)

add_library(neutron SHARED ${C_SOURCES})
target_link_libraries(neutron
	${GLIB_LIBRARIES}
	${GOBJECT_LIBRARIES}
	${GIO_LIBRARIES}
	${GEE_LIBRARIES}
)

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
			${CMAKE_CURRENT_SOURCE_DIR}/vapi/neutron.deps
			${CMAKE_CURRENT_BINARY_DIR}/neutron.vapi
		DESTINATION
			share/vala/vapi/
	)

	install(
		FILES
			${CMAKE_CURRENT_BINARY_DIR}/neutron.h
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
