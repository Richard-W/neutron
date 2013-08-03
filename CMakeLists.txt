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

vala_precompile(C_SOURCES
		src/webcon-errors.vala
		src/webcon-configuration.vala
	PACKAGES
		gio-2.0
	GENERATE_VAPI
		webcon
	OPTIONS
		-g
)

add_library(webcon SHARED ${C_SOURCES})
target_link_libraries(webcon
	${GLIB_LIBRARIES}
	${GOBJECT_LIBRARIES}
	${GIO_LIBRARIES}
)
