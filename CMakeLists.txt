cmake_minimum_required(VERSION 2.6)
project(webcon)

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
		src/webcon-errors.vala
		src/webcon-configuration.vala
		src/webcon-session.vala
		src/webcon-request.vala
		src/webcon-response.vala
		src/webcon-requestimpl.vala
		src/webcon-httpserver.vala
		src/webcon-application.vala
		src/webcon-httpparser.vala
	PACKAGES
		gio-2.0
		gee-0.8
	GENERATE_VAPI
		webcon
	CUSTOM_VAPIS
		vapi/http_parser.vapi
	OPTIONS
		-g
)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/external/http_parser)
list(APPEND C_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/external/http_parser/http_parser.c)

add_library(webcon SHARED ${C_SOURCES})
target_link_libraries(webcon
	${GLIB_LIBRARIES}
	${GOBJECT_LIBRARIES}
	${GIO_LIBRARIES}
	${GEE_LIBRARIES}
)
