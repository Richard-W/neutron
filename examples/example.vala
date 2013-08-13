/*
 * This file is part of the webcon project.
 * 
 * Copyright 2013 Richard Wiedenhöft <richard.wiedenhoeft@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

int main(string[] argv) {
	Neutron.Application app;
	Neutron.Http.Server http;

	try {
		app = new Neutron.Application(argv);
		app.enable_http();

		http = app.get_http_server();
		http.set_handler("/example", request_handler);
	} catch(Error e) {
		stderr.printf("Error: %s\n", e.message);
		return 1;
	}

	return app.run();
}

void request_handler(Neutron.Http.Request req) {
	req.set_cookie("testcookie", "testvalue", 3600);
	req.set_cookie("ütf-8-test", "testvalüe", 3600);
	req.add_header_line("content-type: text/html");
	if(req.get_session_vars() == null) {
		req.set_session_var("testkey", "testval");
	}
	var contentb = new StringBuilder();
	contentb.append("""
	<!DOCTYPE html>
	<html>
		<head>
			<title>Testsite</title>
			<meta charset="utf-8" />
		</head>
		<body>
			<h3>Request-vars</h3>
	""");
	foreach(string key in req.get_request_vars()) {
		contentb.append("%s: %s<br />".printf(key, req.get_request_var(key)));
	}
	contentb.append("<h3>Headers</h3>");
	foreach(string key in req.get_header_vars()) {
		foreach(string val in req.get_header_var(key)) {
			contentb.append("%s: %s<br />".printf(key, val));
		}
	}
	contentb.append("<h3>Post</h3>");
	foreach(string key in req.get_post_vars()) {
		contentb.append("%s: %s<br />".printf(key, req.get_post_var(key)));
	}
	contentb.append("<h3>Cookies</h3>");
	foreach(string key in req.get_cookie_vars()) {
		contentb.append("%s: %s<br />".printf(key, req.get_cookie_var(key)));
	}
	contentb.append("<h3>Session</h3>");
	foreach(string key in req.get_session_vars()) {
		contentb.append("%s: %s<br />".printf(key, req.get_session_var(key)));
	}
	contentb.append("<h3>Path</h3>");
	contentb.append("%s<br />".printf(req.path));
	contentb.append("""
	<h3>Form</h3>
	<form method="POST" action = "#">
	<input type="text" name="field1">
	<input type="text" name="field2">
	<input type="submit" value="submit">
	</form>
	</body>
	</html>
	""");
	req.set_response_body(contentb.str);
	req.finish();
}
