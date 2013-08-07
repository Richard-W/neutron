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
	private class HttpServer : Object {
		private uint16 _port;
		public uint16 port { get { return _port; } set { } }

		private bool _use_tls;
		public bool use_tls { get { return _use_tls; } set { } }

		private TlsCertificate? tls_cert;
		private SocketService listener;

		public HttpServer(uint16 port, bool use_tls, TlsCertificate? tls_cert = null) throws Error {
			assert(port != 0);

			this._port = port;
			this._use_tls = use_tls;
			this.tls_cert = tls_cert;

			listener = new SocketService();
			listener.add_inet_port(port, null);
			listener.incoming.connect(on_incoming);
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
			Request req;

			while((req = yield parser.run()) != null) {
				try {
					yield conn.output_stream.write_async((uint8[]) "Got Request\n".to_utf8());
				} catch(Error e) { }
			}

			try {
				yield conn.close_async();
			} catch(Error e) {
				return;
			}
		}
	}
}
