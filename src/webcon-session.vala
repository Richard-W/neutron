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

using Gee;

namespace Webcon {
	/** This class represents a unique client-session which can store data between requests */
	public class Session : Object {
		private string sessid;

		public Session() {
			sessid = generate_session_id();
		}

		private string generate_session_id() {
			var strbuilder = new StringBuilder();
			var rand = new Rand();
			for(int i = 0; i < 64; i++) {
				uint8 chr = (uint8) rand.int_range(48, 110);
				if(chr > 57) chr += 7;
				if(chr > 90) chr += 6;
				strbuilder.append_c((char) chr);
			}
			return strbuilder.str;
		}
	}

}
