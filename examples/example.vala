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

		var root = new Neutron.Http.StaticEntityFactory("text/html", """<!DOCTYPE html>
		<html>
		<head>
			<meta charset="utf-8" />
		</head>
		<body>
			<h1>Neutron testpage</h1>
			<br><a href="/request">Request</a>
			<br><a href="/file">Filetest</a>
		</body>
		</html>""");
		http.set_handler("/", root);

		var file = new Neutron.Http.FileEntityFactory("text/html", "./file.html");
		http.set_handler("/file", file);

		var request = new DisplayRequestEntityFactory();
		http.set_handler("/request", request);
	} catch(Error e) {
		stderr.printf("Error: %s\n", e.message);
		return 1;
	}

	return app.run();
}

class DisplayRequestEntity : Neutron.Http.Entity {
	protected override async Neutron.Http.ConnectionAction handle_request() {
		try {
			yield send_status(200);
			yield send_header("Content-Type", "text/html");

			if(request.session == null) yield set_session(new Neutron.Http.Session());

			yield end_headers();

			yield send("""
			<!DOCTYPE html>
			<html>
			<head>
				<title>Display Request</title>
			</head>
			<body>
				<h1>Display Request</h1>
				<h2>Headers</h2>
			""");

			foreach(string header_key in request.get_header_vars()) {
				foreach(string header_field in request.get_header_var(header_key)) {
					yield send("%s: %s<br />\n".printf(header_key, header_field));
				}
			}

			yield send("<h2>Request</h2>");
			foreach(string request_key in request.get_request_vars()) {
				yield send("%s: %s<br />\n".printf(request_key, request.get_request_var(request_key)));
			}

			yield send("<h2>Post</h2>");
			foreach(string post_key in request.get_post_vars()) {
				yield send("%s: %s<br />\n".printf(post_key, request.get_post_var(post_key)));
			}

			yield send("<h2>Cookies</h2>");
			foreach(string cookie_key in request.get_cookie_vars()) {
				yield send("%s: %s<br />\n".printf(cookie_key, request.get_cookie_var(cookie_key)));
			}

			yield send("""
			<h2>Form</h2>
			<form method="post" action="/request">
			<table border=0>
			<tr>
				<td>input1</td>
				<td><input type="text" name="input1"></td>
			</tr><tr>
				<td>input2</td>
				<td><input type="text" name="input2"></td>
			</tr><tr>
				<td colspan=2><input type="submit" value="Send"></td>
			</tr>
			</table>
			""");

			yield send("""
			</body>
			</html>
			""");
			yield end_body();
			return Neutron.Http.ConnectionAction.KEEP_ALIVE;
		} catch(Error e) {
			return Neutron.Http.ConnectionAction.CLOSE;
		}
	}
}

class DisplayRequestEntityFactory : Neutron.Http.EntityFactory {
	public override Neutron.Http.Entity create_entity() {
		return (Neutron.Http.Entity) new DisplayRequestEntity();
	}
}
