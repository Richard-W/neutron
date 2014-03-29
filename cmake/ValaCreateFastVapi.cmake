function(vala_create_fast_vapi output source_file)
	get_filename_component(vapi_file ${source_file} NAME)
	string(REPLACE ".vala" ".fast.vapi" vapi_file ${vapi_file})
	set(vapi_file "${CMAKE_CURRENT_BINARY_DIR}/${vapi_file}")

	add_custom_command(
		OUTPUT
			${vapi_file}
		COMMAND
			${VALA_COMPILER}
		ARGS
			"--fast-vapi=${vapi_file}"
			${source_file}
		DEPENDS
			${source_file}
	)

	set(${output} ${vapi_file} PARENT_SCOPE)
endfunction(vala_create_fast_vapi)
