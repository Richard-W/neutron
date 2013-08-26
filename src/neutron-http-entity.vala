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
	public abstract class Entity : Object {
		private IOStream client;
		private Session? session_set = null;
		private Session? session_delete = null;
		private bool status_sent = false;
		private bool headers_sent = false;
		
		private Request _request;
		protected Request request {
			get { return _request; }
		}

		public async ServerAction server_callback(Request request, IOStream client) {
			this._request = request;
			this.client = client;
			var action = yield handle_request();
			return new ServerAction(action, session_set, session_delete);
		}

		protected async void raw_send(string str) throws Error {
			var data = (uint8[]) str.to_utf8();
			yield client.output_stream.write_async(data);
		}

		protected async void send_bytes(uint8[] buffer) throws Error {
			yield client.output_stream.write_async(buffer);
		}

		protected async void send_status(int code, string? description = null) throws Error {
			if(status_sent) throw new HttpError.STATUS_ALREADY_SENT("You can not send the status twice");

			string desc = "";
			/* Just a few common codes. Contribute more if you like */
			switch(code) {
			case 100:
				desc = "Continue";
				break;
			case 101:
				desc = "Switching Protocols";
				break;
			case 102:
				desc = "Processing";
				break;
			case 200:
				desc = "OK";
				break;
			case 301:
				desc = "Moved Permanently";
				break;
			case 302:
				desc = "Found";
				break;
			case 400:
				desc = "Bad Request";
				break;
			case 401:
				desc = "Unauthorized";
				break;
			case 403:
				desc = "Forbidden";
				break;
			case 404:
				desc = "Not Found";
				break;
			case 500:
				desc = "Internal Server Error";
				break;
			}

			if(description != null) desc = description;
			yield raw_send("HTTP/1.1 %d %s\r\n".printf(code, desc));
			status_sent = true;
		}

		protected async void send_header(string key, string val) throws Error {
			if(!status_sent) throw new HttpError.STATUS_NOT_SENT("You have to send the status first");
			if(headers_sent) throw new HttpError.HEADERS_ALREADY_SENT("Already in body of message");
			yield raw_send("%s: %s\r\n".printf(key, val));
		}

		protected async void send_default_headers() throws Error {
			yield send_header("Server", "neutron");
		}

		protected async void end_headers() throws Error {
			yield raw_send("\r\n");
			headers_sent = true;
		}

		protected async void set_cookie(string key,
						string val,
						int lifetime,
						string path = "/",
						bool http_only = false,
						bool secure = false) throws Error {

			var cookie = new StringBuilder();

			cookie.append("%s=%s".printf(key, val));
			cookie.append("; Max-Age=%d".printf(lifetime));
			cookie.append("; Path=%s".printf(path));

			if(http_only) cookie.append("; HttpOnly");
			if(secure) cookie.append("; Secure");

			yield send_header("Set-Cookie", cookie.str);
		}

		protected async void set_session(Session? session) throws Error {
			if(session != null) {
				yield set_cookie("neutron_session_id", session.session_id, 24*3600, "/", true);
				session_set = session;
			} else {
				yield set_cookie("neutron_session_id", "deleted", -1);
			}

			if(request.session != null) session_delete = request.session;
		}

		public abstract async ConnectionAction handle_request();
	}

	public abstract class EntityFactory : Object {
		public abstract Entity create_entity();
	}
}
