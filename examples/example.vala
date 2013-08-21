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
		http.set_handler("/", root);
		http.set_handler("/variables", variables);
		http.set_handler("/create_session", create_session);
		http.set_handler("/display_session", display_session);
		http.set_handler("/destroy_session", destroy_session);
	} catch(Error e) {
		stderr.printf("Error: %s\n", e.message);
		return 1;
	}

	return app.run();
}

void root(Neutron.Http.Request req) {
	var page = new StringBuilder();
	page.append("""<!DOCTYPE html>
	<html>
	<head>
		<meta charset="utf-8" />
		<title>Topsite</title>
	</head>
	<body>
		<h1>Neutron Testpage</h1>
		<a href="/create_session">Create session</a><br />
		<a href="/destroy_session">Destroy session</a><br />
		<a href="/display_session">Display session</a><br />
		<a href="/variables">Variables</a><br />
	</body>
	</html>
	""");
	req.set_response_body(page.str);
	req.finish();
}

void variables(Neutron.Http.Request req) {
	var page = new StringBuilder();
	page.append("""<!DOCTYPE html>
	<html>
	<head>
		<meta charset="utf-8" />
		<title>Variables</title>
	</head>
	<body>
	<h1>Request</h1>
	""");
	foreach(string key in req.get_request_vars()) {
		page.append("%s: %s<br />\n".printf(key, req.get_request_var(key)));
	}
	page.append("<h1>Post</h1>\n");
	foreach(string key in req.get_post_vars()) {
		page.append("%s: %s<br />\n".printf(key, req.get_post_var(key)));
	}
	page.append("<h1>Cookies</h1>\n");
	foreach(string key in req.get_cookie_vars()) {
		page.append("%s: %s<br />\n".printf(key, req.get_cookie_var(key)));
	}
	page.append("<h1>Headers</h1>\n");
	foreach(string key in req.get_header_vars()) {
		foreach(string val in req.get_header_var(key)) {
			page.append("%s: %s<br />\n".printf(key, val));
		}
	}
	page.append("</body>\n</html>");
	req.set_response_body(page.str);
	req.finish();
}

void create_session(Neutron.Http.Request req) {
	var page = new StringBuilder();
	page.append("""<!DOCTYPE html>
	<html>
	<head>
		<meta charset="utf-8" />
		<title>Create session</title>
	</head>
	<body>
	<h1>Session creation</h1>
	</body>
	</html>""");
	req.set_session(new Neutron.Http.Session());
	req.set_response_body(page.str);
	req.finish();
}

void display_session(Neutron.Http.Request req) {
	var page = new StringBuilder();
	page.append("""<!DOCTYPE html>
	<html>
	<head>
		<meta charset="utf-8" />
		<title>Display session</title>
	</head>
	<body>
	<h1>Session display</h1>
	""");
	if(req.get_session() == null)
		page.append("<p>Session is not set</p>\n");
	else
		page.append("<p>Session is set</p>\n");
	page.append("</body>\n</html>");
	req.set_response_body(page.str);
	req.finish();
}

void destroy_session(Neutron.Http.Request req) {
	var page = new StringBuilder();
	page.append("""<!DOCTYPE html>
	<html>
	<head>
		<meta charset="utf-8" />
		<title>Destroy session</title>
	</head>
	<body>
	<h1>Session destroy</h1>
	""");
	req.set_session(null);
	page.append("</body>\n</html>");
	req.set_response_body(page.str);
	req.finish();
}
