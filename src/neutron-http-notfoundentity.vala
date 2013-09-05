/*
 * This file is part of the neutron project.
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

namespace Neutron.Http {
	public class NotFoundEntity : Entity {
		public async override ConnectionAction handle_request() {
			try {
				yield send_status(404);
				yield send_header("Content-type", "text/html");
				yield end_headers();
				yield send("""
				<!DOCTYPE html>
				<html>
				<head>
					<meta charset="utf-8" />
				</head>
				<body>
					<h1>404 - Not Found</h1>
				</body>
				</html>
				""");
				yield end_body();
				return ConnectionAction.KEEP_ALIVE;
			} catch(Error e) {
				return ConnectionAction.CLOSE;
			}
		}
	}
}
