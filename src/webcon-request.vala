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

namespace Webcon {
	public abstract class Request : Object {
		/** The requested path */
		public string path;

		/** Get string from POST-body */
		public abstract string get_post_var(string key);
		/** Get string from Request (e.g. /index.html?foo=bar) */
		public abstract string get_request_var(string key);
		/** Get string from Cookie */
		public abstract string get_cookie_var(string key);
		/** Get string from Session */
		public abstract string get_session_var(string key);
	}
}
