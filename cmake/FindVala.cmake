# Copyright 2013 Richard Wiedenhöft

# Inspired by Vala_CMake written by Jakob Westhoff (https://github.com/jakobwesthoff/Vala_CMake)
# This module makes it possible to do parallel builds of vala-programs in cmake
#
# Copy this file to a subdirectory in your project-dir (e.g. ./cmake)
# and add the following line to your CMakeLists.txt:
# list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
#
# You can now use the macro find_package to enable Vala:
# find_package(Vala REQUIRED)
#
# Now you can use the function vala_precompile. for example:
# vala_precompile(C_FILES
#	SOURCES
#		source1.vala
#		source2.vala
#		source3.vala
#	PACKAGES
#		gio-2.0
#		posix
#	GENERATE_VAPI
#		somelibrary
#	OPTIONS
#		-g
#		--thread
# )
#
# Now the variable C_FILES contains the precompiled c-files
#
# Reference of the options that vala_precompile supports:
#
# SOURCES:
#	A list of vala source files
#
# CONFIGURED_SOURCES:
#	A list of vala source files that are not in the
#	projects source-dir but in CMAKE_CURRENT_BINARY_DIR.
#	This is useful when you want to configure a file before
#	you precompile it.
#
# CUSTOM_VAPIS:
#	A list of full-path vapi-files that you want to include
#	in the precompilation process
#
# PACKAGES:
#	A list of vala-packages to be used.
#
# OPTIONS:
#	Additional options that are supplied to valac.
#
# GENERATE_VAPI:
#	Creates a vapi-file from the sources. Useful
#	when you are creating a library. (Do not append .vapi)

include(FindPackageHandleStandardArgs)
include(CMakeParseArguments)

#find valac executable
find_program(VALAC NAMES valac)
mark_as_advanced(VALAC)

#get version of vala
if(VALAC)
	execute_process(
		COMMAND
			${VALAC}
		ARGS
			"--version"
		OUTPUT_VARIABLE
			VALA_VERSION
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)

	string(
		REPLACE
			"Vala "
			""
		VALA_VERSION
		"${VALA_VERSION}"
	)
endif(VALAC)

#handle standard args like REQUIRED
find_package_handle_standard_args(
		Vala
	REQUIRED_VARS
		VALAC
	VERSION_VAR
		VALA_VERSION
)

#vala precompile-function
function(vala_precompile output)
	cmake_parse_arguments(
		ARGS
		""
		"GENERATE_VAPI"
		"SOURCES;CONFIGURED_SOURCES;PACKAGES;OPTIONS;CUSTOM_VAPIS"
		${ARGN}
	)

	#initialize variables
	set(fast_vapis "")
	set(out_files "")

	#create fast vapis
	foreach(source_file ${ARGS_SOURCES})
		string(REPLACE ".vala" ".fast.vapi" fast_vapi ${source_file})
		list(APPEND fast_vapis ${fast_vapi})

		add_custom_command(
			OUTPUT
				"${CMAKE_CURRENT_BINARY_DIR}/${fast_vapi}"
			COMMAND
				${VALAC}
			ARGS
				"--fast-vapi=${CMAKE_CURRENT_BINARY_DIR}/${fast_vapi}"
				"${CMAKE_CURRENT_SOURCE_DIR}/${source_file}"
			DEPENDS
				"${CMAKE_CURRENT_SOURCE_DIR}/${source_file}"
		)
	endforeach(source_file ${ARGS_SOURCES})

	#create fast vapis for configured sources
	foreach(source_file ${ARGS_CONFIGURED_SOURCES})
		string(REPLACE ".vala" ".fast.vapi" fast_vapi ${source_file})
		list(APPEND fast_vapis ${fast_vapi})

		add_custom_command(
			OUTPUT
				"${CMAKE_CURRENT_BINARY_DIR}/${fast_vapi}"
			COMMAND
				${VALAC}
			ARGS
				"--fast-vapi=${CMAKE_CURRENT_BINARY_DIR}/${fast_vapi}"
				"${CMAKE_CURRENT_BINARY_DIR}/${source_file}"
			DEPENDS
				"${CMAKE_CURRENT_BINARY_DIR}/${source_file}"
		)
	endforeach(source_file ${ARGS_ABSOLUTE_SOURCES})

	#set arguments that are common for every vala-file to be compiled
	set(vala_global_args ${ARGS_OPTIONS})
	list(APPEND vala_global_args ${ARGS_CUSTOM_VAPIS})
	foreach(pkg ${ARGS_PACKAGES})
		list(APPEND vala_global_args "--pkg=${pkg}")
	endforeach(pkg ${ARGS_PACKAGES})

	#create array with full path of fast vapis to use as a dependency
	set(fast_vapis_abs "")
	foreach(fast_vapi ${fast_vapis})
		list(APPEND fast_vapis_abs "${CMAKE_CURRENT_BINARY_DIR}/${fast_vapi}")
	endforeach(fast_vapi ${fast_vapis})

	#used to generate the vapi
	set(first_source_file TRUE)

	#create c-files
	foreach(source_file ${ARGS_SOURCES})
		if(first_source_file AND ARGS_GENERATE_VAPI)
			vala_add_c_command(out_file
				SOURCE_FILE
					${source_file}
				GENERATE_VAPI
					${ARGS_GENERATE_VAPI}
				IN_BINARY_DIR
					FALSE
				GLOBAL_ARGS
					${vala_global_args}
				FAST_VAPIS
					${fast_vapis}
			)
			set(first_source_file FALSE)
		else(first_source_file AND ARGS_GENERATE_VAPI)
			vala_add_c_command(out_file
				SOURCE_FILE
					${source_file}
				IN_BINARY_DIR
					FALSE
				GLOBAL_ARGS
					${vala_global_args}
				FAST_VAPIS
					${fast_vapis}
			)
		endif(first_source_file AND ARGS_GENERATE_VAPI)
		list(APPEND out_files ${out_file})
	endforeach(source_file ${ARGS_SOURCES})

	foreach(source_file ${ARGS_CONFIGURED_SOURCES})
		if(first_source_file AND ARGS_GENERATE_VAPI)
			vala_add_c_command(out_file
				SOURCE_FILE
					${source_file}
				GENERATE_VAPI
					${ARGS_GENERATE_VAPI}
				IN_BINARY_DIR
					TRUE
				GLOBAL_ARGS
					${vala_global_args}
				FAST_VAPIS
					${fast_vapis}
			)
			set(first_source_file FALSE)
		else(first_source_file AND ARGS_GENERATE_VAPI)
			vala_add_c_command(out_file
				SOURCE_FILE
					${source_file}
				IN_BINARY_DIR
					TRUE
				GLOBAL_ARGS
					${vala_global_args}
				FAST_VAPIS
					${fast_vapis}
			)
		endif(first_source_file AND ARGS_GENERATE_VAPI)
		list(APPEND out_files ${out_file})
	endforeach(source_file ${ARGS_CONFIGURED_SOURCES})


	#create a list that contains the absolute path of all generated c files
	set(out_files_abs "")
	foreach(out_file ${out_files})
		list(APPEND out_files_abs "${CMAKE_CURRENT_BINARY_DIR}/${out_file}")
	endforeach(out_file ${out_files})

	#write the path of all created c files to the parent scope
	set(${output} ${out_files_abs} PARENT_SCOPE)
endfunction(vala_precompile output)

function(vala_add_c_command output)
	cmake_parse_arguments(
		ARGS
		""
		"SOURCE_FILE;GENERATE_VAPI;IN_BINARY_DIR"
		"GLOBAL_ARGS;FAST_VAPIS"
		${ARGN}
	)

	set(vala_local_args "")
	set(command_output_files "")

	#generate the vapi- and the header-file if necessary
	if(ARGS_GENERATE_VAPI)
		list(APPEND vala_local_args "--vapi=${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_VAPI}.vapi")
		list(APPEND vala_local_args "--header=${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_VAPI}.h")
		list(APPEND command_output_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_VAPI}.vapi")
		list(APPEND command_output_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_VAPI}.h")
	endif(ARGS_GENERATE_VAPI)

	#include all fast-vapis except for the one generated by the source_file itself
	foreach(fast_vapi ${ARGS_FAST_VAPIS})
		string(REPLACE ".fast.vapi" ".vala" tmp ${fast_vapi})
		if(NOT ${ARGS_SOURCE_FILE} STREQUAL ${tmp})
			list(APPEND vala_local_args "--use-fast-vapi=${CMAKE_CURRENT_BINARY_DIR}/${fast_vapi}")
		endif(NOT ${ARGS_SOURCE_FILE} STREQUAL ${tmp})
	endforeach(fast_vapi ${ARGS_FAST_VAPIS})

	string(REPLACE ".vala" ".c" out_file ${ARGS_SOURCE_FILE})

	if(ARGS_IN_BINARY_DIR)
		set(source_file_abs "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_SOURCE_FILE}")
	else(ARGS_IN_BINARY_DIR)
		set(source_file_abs "${CMAKE_CURRENT_SOURCE_DIR}/${ARGS_SOURCE_FILE}")
	endif(ARGS_IN_BINARY_DIR)

	list(APPEND command_output_files "${CMAKE_CURRENT_BINARY_DIR}/${out_file}")

	add_custom_command(
		OUTPUT
			${command_output_files}
		COMMAND
			${VALAC}
		ARGS
			${vala_global_args}
			${vala_local_args}
			${source_file_abs}
			"-C"
		DEPENDS
			${fast_vapis_abs}
			${source_file_abs}
	)

	set(${output} ${out_file} PARENT_SCOPE)
endfunction(vala_add_c_command)

