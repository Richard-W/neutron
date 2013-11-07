/*
 * This file is part of the neutron project.
 * 
 * Copyright 2013 Richard Wiedenhöft <richard.wiedenhoeft@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Neutron {
	/**
	 * Represents a unique client-session which can store data between requests
	 *
	 * To use it to store your data you have to derive from it and add
	 * properties. I strongly recommend you derive only once per project.
	 */	 
	public class Session : Object {
		public string session_id {
			get;
			private set;
		}

		public DateTime last_request_time {
			get;
			private set;
		}

		public DateTime creation_time {
			get;
			private set;
		}

		public Session() {
			session_id = generate_session_id();
			creation_time = new DateTime.now_local();
			last_request_time = new DateTime.now_local();
		}

		public void reset_last_request_time() {
			last_request_time = new DateTime.now_local();
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
