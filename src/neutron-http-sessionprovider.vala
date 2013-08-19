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

		public void pre_callback(RequestImpl req) {
			string? session_id = req.get_cookie_var("neutron_session_id");
			Session? session = null;

			if(session_id != null) {
				if(stored_sessions.has_key(session_id)) {
					session = stored_sessions.get(session_id);

					/* Reset last_request-DateTime so the session does not get cleaned up */
					session.set_last_request_time();

					/* Add the session to the request-object */
					req.session = session;
				} else {
					req.set_session(null);
				}
			}
		}

		public void post_callback(RequestImpl req) {
			string? cookie_session_id = req.get_cookie_var("neutron_session_id");
			string? prop_session_id = null;

			if(req.session != null) prop_session_id = req.session.get_session_id();

			bool set_sessioncookie = true;

			if(req.session_changed) {
				if(cookie_session_id != null && prop_session_id == null) {
					set_sessioncookie = false;
					req.set_cookie("neutron_session_id", "deleted", -1, "/", true, false);
					stored_sessions.unset(cookie_session_id);
				} else if(cookie_session_id == null && prop_session_id != null) {
					stored_sessions.set(prop_session_id, req.session);
				} else if(cookie_session_id != prop_session_id) {
					stored_sessions.unset(cookie_session_id);
					stored_sessions.set(prop_session_id, req.session);
				} else if(cookie_session_id == null && prop_session_id == null) {
					set_sessioncookie = false;
				} else {
					assert_not_reached();
				}
			}

			if(set_sessioncookie && prop_session_id != null) {
				req.set_cookie("neutron_session_id", prop_session_id, lifetime, "/", true, false);
			}
		}
	}
}
