include(CMakeParseArguments)
include(ValaCreateFastVapi)
include(ValaCreateCFile)
include(ValaCreateVapi)

function(vala_precompile output)
	cmake_parse_arguments(
		ARGS
		""
		"GENERATE_VAPI"
		"SOURCES;CONFIGURED_SOURCES;PACKAGES;OPTIONS;CUSTOM_VAPIS"
		${ARGN}
	)

	set(fast_vapis "")
	foreach(source_file ${ARGS_SOURCES})
		vala_create_fast_vapi(fast_vapi "${CMAKE_CURRENT_SOURCE_DIR}/${source_file}")
		list(APPEND fast_vapis ${fast_vapi})
	endforeach(source_file ${ARGS_SOURCES})

	foreach(source_file ${ARGS_CONFIGURED_SOURCES})
		vala_create_fast_vapi(fast_vapi ${source_file})
		list(APPEND fast_vapis ${fast_vapi})
	endforeach(source_file ${ARGS_CONFIGURED_SOURCES})

	if(ARGS_GENERATE_VAPI)
		vala_create_vapi(vapi header
			NAME ${ARGS_GENERATE_VAPI}
			FAST_VAPIS ${fast_vapis}
			PACKAGES ${ARGS_PACKAGES}
			OPTIONS ${ARGS_OPTIONS}
		)
		set(c_depends "")
		list(APPEND c_depends ${vapi})
		list(APPEND c_depends ${header})
	endif(ARGS_GENERATE_VAPI)

	set(c_files "")
	foreach(source_file ${ARGS_SOURCES})
		vala_create_c_file(c_file
			SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/${source_file}"
			FAST_VAPIS ${fast_vapis}
			CUSTOM_VAPIS ${ARGS_CUSTOM_VAPIS}
			PACKAGES ${ARGS_PACKAGES}
			OPTIONS ${ARGS_OPTIONS}
			DEPENDS ${c_depends}
		)
		list(APPEND c_files ${c_file})
	endforeach(source_file ${ARGS_SOURCES})
	
	foreach(source_file ${ARGS_CONFIGURED_SOURCES})
		vala_create_c_file(c_file
			SOURCE ${source_file}
			FAST_VAPIS ${fast_vapis}
			CUSTOM_VAPIS ${ARGS_CUSTOM_VAPIS}
			PACKAGES ${ARGS_PACKAGES}
			OPTIONS ${ARGS_OPTIONS}
			DEPENDS ${c_depends}
		)
		list(APPEND c_files ${c_file})
	endforeach(source_file ${ARGS_CONFIGURED_SOURCES})

	set(${output} ${c_files} PARENT_SCOPE)
endfunction(vala_precompile)
