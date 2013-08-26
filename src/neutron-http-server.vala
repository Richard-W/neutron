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
	public class Server : Object {
		private uint16 _port;
		public uint16 port { get { return _port; } set { } }

		private bool _use_tls;
		public bool use_tls { get { return _use_tls; } set { } }

		private TlsCertificate? tls_cert;
		private SocketService listener;
		private ThreadController? tcontrol;

		private SessionProvider sessionprovider;
		private HashMap<string, EntityFactory> request_handlers;

		public Server(ThreadController? tcontrol, uint16 port, bool use_tls, TlsCertificate? tls_cert = null, int session_lifetime = 3600, int session_max_lifetime = -1) throws Error {
			assert(port != 0);
			this.tcontrol = tcontrol;

			this._port = port;
			this._use_tls = use_tls;
			this.tls_cert = tls_cert;

			/* Define listener */
			listener = new SocketService();
			listener.add_inet_port(port, null);
			listener.incoming.connect(on_incoming);

			request_handlers = new HashMap<string, EntityFactory>();

			sessionprovider = new SessionProvider(session_lifetime, session_max_lifetime);
		}

		//TODO: Regular expressions?
		/**
		 * Adds a handler for a specific http-path 
		 */
		public void set_handler(string path, EntityFactory entfac) {
			request_handlers.set(path, entfac);
		}

		/**
		 * Start handling connections 
		 */
		public void start() {
			listener.start();
		}

		/**
		 * Stop handling connections 
		 */
		public void stop() {
			listener.stop();
		}

		/**
		 * Gets the connections from listener 
		 */
		private bool on_incoming(SocketConnection conn, Object? source_object) {
			if(tcontrol == null)
				handle_connection.begin((IOStream) conn);
			else {
				var isource = new IdleSource();
				isource.set_callback(() => {
					this.handle_connection.begin((IOStream) conn);
					isource.destroy();
					return true;
				});
				tcontrol.invoke(isource);
			}
			return true;
		}

		/**
		 * Handle the incoming connection asynchronously 
		 */
		private async void handle_connection(IOStream conn) {
			if(_use_tls) {
				try {
					/* Wrap the connection in a TlsServerConnection */
					var tlsconn = TlsServerConnection.new(conn, tls_cert);
					yield tlsconn.handshake_async();
					conn = (IOStream) tlsconn;
				} catch(Error e) {
					return;
				}
			}

			/* Parser takes an IOStream-Object, so it does not care whether connection
			 * is encrypted or not */
			var parser = new Parser(conn);
			RequestImpl req;

			bool keep_running = true;
			while((req = yield parser.run()) != null && keep_running) {
				/* Check if a handler is registered for the requested path */
				if(request_handlers.has_key(req.path)) {
					/* Let the sessionprovider add information to the Request */
					sessionprovider.pre_callback(req);

					var entityfac = request_handlers.get(req.path);
					var entity = entityfac.create_entity();

					/* Call handler */
					var server_action = yield entity.server_callback(req, conn);

					sessionprovider.post_callback(server_action.new_session, server_action.old_session);

					if(server_action.connection_action == ConnectionAction.CLOSE)
						break;
					else if(server_action.connection_action == ConnectionAction.RELEASE)
						return;
					else if(server_action.connection_action != ConnectionAction.KEEP_ALIVE)
						assert_not_reached();
				} else {
					//TODO: 404-page
				}
			}

			try {
				/* Close connection */
				yield conn.close_async();
			} catch(Error e) {
				return;
			}
		}
	}

	public enum ConnectionAction {
		/**
		 * Close the connection
		 */
		CLOSE,
		/**
		 * Keep handling the connection
		 */
		KEEP_ALIVE,
		/**
		 * Stop handling the connection but leave it open
		 */
		RELEASE
	}

	public class ServerAction : Object {
		public ConnectionAction connection_action;
		public Session? new_session;
		public Session? old_session;

		public ServerAction(ConnectionAction a, Session? b, Session? c) {
			connection_action = a;
			new_session = b;
			old_session = c;
		}
	}
}
