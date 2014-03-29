include(CMakeParseArguments)

function(vala_create_c_file output)
	cmake_parse_arguments(
		ARGS
		""
		"SOURCE"
		"FAST_VAPIS;PACKAGES;OPTIONS;CUSTOM_VAPIS;DEPENDS"
		${ARGN}
	)
	get_filename_component(c_file ${ARGS_SOURCE} NAME)
	string(REPLACE ".vala" ".c" c_file ${c_file})
	set(c_file "${CMAKE_CURRENT_BINARY_DIR}/${c_file}")

	set(vala_local_args "")
	list(APPEND vala_local_args ${ARGS_OPTIONS})

	foreach(package ${ARGS_PACKAGES})
		list(APPEND vala_local_args "--pkg=${package}")
	endforeach(package ${ARGS_PACKAGES})

	get_filename_component(c_file_name ${c_file} NAME_WE)
	set(fast_vapis_used "")
	foreach(fast_vapi ${ARGS_FAST_VAPIS})
		#remove .fast.vapi from vapiname
		get_filename_component(vapi_file_name ${fast_vapi} NAME_WE)
		get_filename_component(vapi_file_name ${vapi_file_name} NAME_WE)

		if(NOT c_file_name STREQUAL vapi_file_name)
			list(APPEND vala_local_args "--use-fast-vapi=${fast_vapi}")
			list(APPEND fast_vapis_used ${fast_vapi})
		endif(NOT c_file_name STREQUAL vapi_file_name)
	endforeach(fast_vapi ${ARGS_FAST_VAPIS})

	foreach(custom_vapi ${ARGS_CUSTOM_VAPIS})
		list(APPEND vala_local_args ${custom_vapi})
	endforeach(custom_vapi ${ARGS_CUSTOM_VAPIS})

	add_custom_command(
		OUTPUT
			${c_file}
		COMMAND
			${VALA_COMPILER}
		ARGS
			"-C"
			${ARGS_SOURCE}
			${vala_local_args}
		MAIN_DEPENDENCY
			${ARGS_SOURCE}
		DEPENDS
			${fast_vapis_used}
			${ARGS_CUSTOM_VAPIS}
			${ARGS_DEPENDS}
	)

	set(${output} ${c_file} PARENT_SCOPE)
endfunction(vala_create_c_file)
