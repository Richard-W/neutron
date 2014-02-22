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

using Gee;

/**
 * Represents a unique client-session which can store data between requests
 *
 * To use it to store your data you have to derive from it and add
 * properties. I strongly recommend you derive only once per project.
 */
public class Neutron.Session : Object {
	/**
	 * The time a session is stored when no new request claim it
	 */
	public static int lifetime {
		get;
		set;
		default = 3600;
	}

	/**
	 * The time after which a session is deleted unconditionally.
	 */
	public static int max_lifetime {
		get;
		set;
		default = -1;
	}

	private static HashMap<string, Session>? stored_sessions = null;
	public static Session? get_by_id(string id) {
		if(stored_sessions == null) stored_sessions = new HashMap<string, Session>();
		if(stored_sessions.has_key(id)) {
			return stored_sessions.get(id);
		} else {
			return null;
		}
	}

	public static void delete_by_id(string id) {
		if(stored_sessions == null) stored_sessions = new HashMap<string, Session>();
		stored_sessions.unset(id);
	}

	public static void cleanup() {
		if(stored_sessions == null) stored_sessions = new HashMap<string, Session>();
		var now = new DateTime.now_local();
		var to_delete = new Gee.HashSet<string>();

		foreach(string key in stored_sessions.keys) {
			var session = stored_sessions.get(key);
			var req_diff = now.difference(session.last_request_time) / TimeSpan.SECOND;
			var creation_diff = now.difference(session.creation_time) / TimeSpan.SECOND;

			if(req_diff > lifetime && lifetime > 0) {
				to_delete.add(key);
			} else if(creation_diff > max_lifetime && max_lifetime > 0) {
				to_delete.add(key);
			}
		}

		foreach(string key in to_delete) {
			stored_sessions.unset(key);
		}
	}

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
		stored_sessions.set(this.session_id, this);
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
