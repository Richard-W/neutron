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
	private class RequestImpl : Request {
		private HashMap<string,string>? gets;
		private HashMap<string,string>? posts;
		private HashMap<string,string>? cookies;
		private HashMap<string,HashSet<string>>? headers;
		private Session? session;

		public RequestImpl(HashMap<string,string>? gets, HashMap<string,string>? posts, HashMap<string,string>? cookies, HashMap<string,HashSet<string>> headers) {
			this.gets = gets;
			this.posts = posts;
			this.cookies = cookies;
			this.headers = headers;
		}

		public void set_session(Session session) {
			this.session = session;
		}

		private string? get_var(HashMap<string,string> map, string key) {
			if(!map.has_key(key)) return null;
			else return map.get(key);
		}

		public override string? get_request_var(string key) {
			return get_var(gets, key);
		}

		public override string? get_post_var(string key) {
			return get_var(posts, key);
		}

		public override string? get_cookie_var(string key) {
			return get_var(cookies, key);
		}

		public override string[]? get_header_var(string key) {
			if(headers.has_key(key)) return headers.get(key).to_array();
			else return null;
		}

		public override string? get_session_var(string key) {
			if(session != null) return session.get_var(key);
			else return null;
		}

		public override string[]? get_post_vars() {
			if(posts == null) return null;
			if(posts.size == 0) return null;
			return posts.keys.to_array();
		}

		public override string[]? get_cookie_vars() {
			if(cookies == null) return null;
			if(cookies.size == 0) return null;
			return cookies.keys.to_array();
		}

		public override string[]? get_request_vars() {
			if(gets == null) return null;
			if(gets.size == 0) return null;
			return gets.keys.to_array();
		}

		public override string[]? get_header_vars() {
			if(headers == null) return null;
			if(headers.size == 0) return null;
			return headers.keys.to_array();
		}

		public override string[]? get_session_vars() {
			if(session == null) return null;
			return session.get_vars();
		}
	}
}
