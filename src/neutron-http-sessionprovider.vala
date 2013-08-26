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

using Gee;

namespace Neutron.Http {
	private class SessionProvider : Object {
		public int lifetime;
		public int max_lifetime;

		private HashMap<string, Session> stored_sessions;

		public SessionProvider(int lifetime, int max_lifetime) {
			this.lifetime = lifetime;
			this.max_lifetime = max_lifetime;
			stored_sessions = new HashMap<string, Session>();
		}

		public void cleanup() {
			var now = new DateTime.now_local();
			var to_delete = new HashSet<string>();

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

		/**
		 * This reads the session-id from the request and adds the corresponding Session-Object 
		 */
		public void pre_callback(RequestImpl req) {
			//TODO: Do not clean up before every request */
			cleanup();

			string? session_id = req.get_cookie_var("neutron_session_id");
			Session? session = null;

			if(session_id != null) {
				if(stored_sessions.has_key(session_id)) {
					session = stored_sessions.get(session_id);

					/* Reset last_request-DateTime so the session does not get cleaned up */
					session.set_last_request_time();

					/* Add the session to the request-object */
					req._session = session;
				}
			}
		}

		/**
		 * This checks if the Session-object of a Request was replaced or set and sets the cookies 
		 */
		public void post_callback(Session? set_session, Session? deleted_session) {
			if(set_session != null) {
				stored_sessions.set(set_session.session_id, set_session);
			}

			if(deleted_session != null) {
				stored_sessions.unset(deleted_session.session_id);
			}
		}
	}
}
