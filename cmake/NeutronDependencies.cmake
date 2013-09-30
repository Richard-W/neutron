####Vala####

find_package(Vala REQUIRED)

#check if vala-version is ok
set(NEEDED_VALA_VERSION 0.18)
if(VALA_VERSION VERSION_LESS NEEDED_VALA_VERSION)
	message(FATAL_ERROR "Need vala >= ${NEEDED_VALA_VERSION} Found version ${VALA_VERSION}")
else(VALA_VERSION VERSION_LESS NEEDED_VALA_VERSION)
	include(UseVala)
endif(VALA_VERSION VERSION_LESS NEEDED_VALA_VERSION)

####PkgConfig####

find_package(PkgConfig REQUIRED)

####GLib####

pkg_check_modules(GLIB glib-2.0 REQUIRED)
include_directories(${GLIB_INCLUDE_DIRS})
link_directories(${GLIB_LIBRARY_DIRS})
set(LIBRARIES ${GLIB_LIBRARIES})

if(GLIB_VERSION VERSION_LESS 2.32)
	message(FATAL_ERROR "Glib version 2.32 required. Found version ${GLIB_VERSION}")
endif(GLIB_VERSION VERSION_LESS 2.32)

####GObject####

pkg_check_modules(GOBJECT gobject-2.0 REQUIRED)
include_directories(${GOBJECT_INCLUDE_DIRS})
link_directories(${GOBJECT_LIBRARY_DIRS})
set(LIBRARIES ${LIBRARIES} ${GOBJECT_LIBRARIES})

####GIO####

pkg_check_modules(GIO gio-2.0 REQUIRED)
include_directories(${GIO_INCLUDE_DIRS})
link_directories(${GIO_LIBRARY_DIRS})
set(LIBRARIES ${LIBRARIES} ${GIO_LIBRARIES})

####Gee####

#debian and ubuntu ship only ship gee-1.0 pc files
if(DEBIAN)
	pkg_check_modules(GEE gee-1.0 REQUIRED)
else(DEBIAN)
	pkg_check_modules(GEE gee-0.8 REQUIRED)
endif(DEBIAN)
include_directories(${GEE_INCLUDE_DIRS})
link_directories(${GEE_LIBRARY_DIRS})
set(LIBRARIES ${LIBRARIES} ${GEE_LIBRARIES})
