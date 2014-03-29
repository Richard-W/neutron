include(CMakeParseArguments)

function(vala_create_vapi vapi_output header_output)
	cmake_parse_arguments(
		ARGS
		""
		"NAME"
		"FAST_VAPIS;PACKAGES;OPTIONS"
		${ARGN}
	)

	set(vala_args "")
	list(APPEND vala_args ${ARGS_OPTIONS})

	foreach(fast_vapi ${ARGS_FAST_VAPIS})
		list(APPEND vala_args "--use-fast-vapi=${fast_vapi}")
	endforeach(fast_vapi ${ARGS_FAST_VAPIS})

	foreach(package ${ARGS_PACKAGES})
		list(APPEND vala_args "--pkg=${package}")
	endforeach(package ${ARGS_PACKAGES})

	set(vapi_file "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_NAME}.vapi")
	set(header_file "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_NAME}.h")

	add_custom_command(
		OUTPUT
			${vapi_file}
			${header_file}
		COMMAND
			${VALA_COMPILER}
		ARGS
			${vala_args}
			"--library=${ARGS_NAME}"
			"--header=${ARGS_NAME}.h"
			"-C"
		DEPENDS
			${ARGS_FAST_VAPIS}
	)

	set(${vapi_output} ${vapi_file} PARENT_SCOPE)
	set(${header_output} ${header_file} PARENT_SCOPE)
endfunction(vala_create_vapi)
