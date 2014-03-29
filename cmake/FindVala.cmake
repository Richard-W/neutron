include(FindPackageHandleStandardArgs)

#find valac executable
find_program(VALA_COMPILER NAMES valac)
mark_as_advanced(VALA_COMPILER)

#get version of vala
if(VALA_COMPILER)
	execute_process(
		COMMAND
			${VALA_COMPILER}
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
endif(VALA_COMPILER)

#handle standard args like REQUIRED
find_package_handle_standard_args(
		Vala
	REQUIRED_VARS
		VALA_COMPILER
	VERSION_VAR
		VALA_VERSION
)
