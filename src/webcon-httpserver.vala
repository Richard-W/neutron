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
	private class HttpServer : Object {
		private uint16 _port;
		public uint16 port { get { return _port; } set { } }

		private bool _use_tls;
		public bool use_tls { get { return _use_tls; } set { } }

		private TlsCertificate? tls_cert;
		private SocketService listener;

		private HashMap<string, Session> stored_sessions;
		private HashMap<string, RequestHandlerWrapper> request_handlers;

		public HttpServer(uint16 port, bool use_tls, TlsCertificate? tls_cert = null) throws Error {
			assert(port != 0);

			this._port = port;
			this._use_tls = use_tls;
			this.tls_cert = tls_cert;

			listener = new SocketService();
			listener.add_inet_port(port, null);
			listener.incoming.connect(on_incoming);

			stored_sessions = new HashMap<string, Session>();
			request_handlers = new HashMap<string, RequestHandlerWrapper>();
		}

		public void set_handler(string path, RequestHandlerFunc handler) {
			request_handlers.set(path, new RequestHandlerWrapper(handler));
		}

		public void start() {
			listener.start();
		}

		public void stop() {
			listener.stop();
		}

		private bool on_incoming(SocketConnection conn, Object? source_object) {
			handle_connection.begin((IOStream) conn);
			return true;
		}

		private async void handle_connection(IOStream conn) {
			if(_use_tls) {
				try {
					var tlsconn = TlsServerConnection.new(conn, tls_cert);
					yield tlsconn.handshake_async();
					conn = (IOStream) tlsconn;
				} catch(Error e) {
					return;
				}
			}

			var parser = new HttpParser(conn);
			RequestImpl req;

			while((req = yield parser.run()) != null) {
				try {
					string? session_id = req.get_cookie_var("webcon_session_id");
					Session? session = null;
					if(session_id == null) {
						session = new Session();
						session_id = session.get_session_id();
						stored_sessions.set(session_id, session);
					}
					else if(!stored_sessions.has_key(session_id)) {
						session = new Session();
						session_id = session.get_session_id();
						stored_sessions.set(session_id, session);
					}
					/* if(session_id == null || stored_sessions.has_key(session_id)
					 * would have been better practice, but triggers a bug in valac.
					 * https://bugzilla.gnome.org/show_bug.cgi?id=703666
					 */
					else {
						session = stored_sessions.get(session_id);
					}
					req.set_session(session);
					req.set_cookie("webcon_session_id", session_id, 3600, "/", true, use_tls);

					if(request_handlers.has_key(req.path)) {
						var wrapper = request_handlers.get(req.path);
						wrapper.handler(req);
					} else {
						req.set_response_http_status(404);
						req.set_response_body("<!DOCTYPE html><html><head><meta charset=\"utf-8\" /><title>404 - Page not found</title></head><body><h1>404 - Page not found</h1></body></html>");
					}

					var respb = new StringBuilder();
					respb.append("HTTP/1.1 %d\r\n".printf(req.response_http_status));
					respb.append("Connection: keep-alive\r\n");

					foreach(string header_line in req.response_headers) {
						respb.append("%s\r\n".printf(header_line));
					}

					respb.append("Content-Length: %ld\r\n".printf(req.response_body.length));
					respb.append("\r\n");
					respb.append(req.response_body);
					yield conn.output_stream.write_async((uint8[]) respb.str.to_utf8());
				} catch(Error e) { }
			}

			try {
				yield conn.close_async();
			} catch(Error e) {
				return;
			}
		}
	}

	private class RequestHandlerWrapper : Object {
		public RequestHandlerFunc handler;

		public RequestHandlerWrapper(RequestHandlerFunc handler) {
			this.handler = handler;
		}
	}

	public delegate void RequestHandlerFunc(Request request);
}
