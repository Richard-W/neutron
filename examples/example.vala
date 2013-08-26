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

		var root = new Neutron.Http.StaticEntityFactory("text/html", """
		<!DOCTYPE html>
		<html>
		<head>
			<meta charset="utf-8" />
		</head>
		<body>
			<h1>Neutron testpage</h1>
			<br><a href="/variables">Variables</a>
		</body>
		</html>
		""");
		http.set_handler("/", root);
	} catch(Error e) {
		stderr.printf("Error: %s\n", e.message);
		return 1;
	}

	return app.run();
}
