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
	/**
	 * Main class for Http-communication.
	 *
	 * To use it you have to connect to the select_entity-event and supply an Entity-object for
	 * Requests you feel responsible for.
	 *
	 * If two handlers of select_entity feel responsible for one Request, the behaviour is determined,
	 * by the order in which the signal-handlers are processed.
	 */
	public class Server : Object {
		/**
		 * Fired when a new Request comes in and used for selecting an appropriate Entity
		 */
		public signal void select_entity(Request request, EntitySelectContainer container);

		private uint16 _port;
		/**
		 * The port the Http-Server is currently listening on
		 */
		public uint16 port {
			get { return _port; }
		}

		private TlsCertificate? _tls_certificate = null;
		/**
		 * Certificate used when use_tls == true. You can only set this.
		 */
		public TlsCertificate? tls_certificate {
			set { _tls_certificate = value; }
		}

		/**
		 * Whether the server uses TLS
		 */
		public bool use_tls = false;

		/**
		 * Used to distribute requests over threads
		 */
		public ThreadController? thread_controller = null;

		/**
		 * The time in seconds the server will wait for new requests before it
		 * disconnects from the client
		 */
		public int timeout = -1;

		/**
		 * The time a session is stored when no new request claim it
		 */
		public int session_lifetime = 3600;

		/**
		 * The time after which a session is deleted unconditionally.
		 */
		public int session_max_lifetime = -1;

		/**
		 * Maximum size of requests.
		 */
		public uint request_max_size = 1048576;

		private SocketService listener;
		private HashMap<string, Session> stored_sessions;

		public Server(uint16 port) throws Error {
			assert(port != 0);
			this._port = port;

			/* Define listener */
			listener = new SocketService();
			listener.add_inet_port(port, null);
			listener.incoming.connect(on_incoming);

			stored_sessions = new HashMap<string, Session>();
		}

		/**
		 * Sets certain parameters of this server according to the Configuration-object
		 */
		public void apply_config(Configuration config) {
			this.use_tls = config.http_use_tls;
			this.tls_certificate = config.http_tls_certificate;
			this.timeout = config.http_timeout;
			this.session_lifetime = config.http_session_lifetime;
			this.session_max_lifetime = config.http_session_max_lifetime;
			this.request_max_size = config.http_request_max_size;
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
			if(thread_controller == null)
				handle_connection.begin((IOStream) conn);
			else {
				var isource = new IdleSource();
				isource.set_callback(() => {
					this.handle_connection.begin((IOStream) conn);
					isource.destroy();
					return true;
				});
				thread_controller.invoke(isource);
			}
			return true;
		}

		/**
		 * Handle the incoming connection asynchronously 
		 */
		private async void handle_connection(IOStream conn) {
			if(use_tls) {
				try {
					/* Wrap the connection in a TlsServerConnection */
					var tlsconn = TlsServerConnection.new(conn, _tls_certificate);
					yield tlsconn.handshake_async();
					conn = (IOStream) tlsconn;
				} catch(Error e) {
					return;
				}
			}

			/* Parser takes an IOStream-Object, so it does not care whether connection
			 * is encrypted or not */
			var parser = new Parser(conn, timeout, request_max_size, use_tls);
			RequestImpl req;

			bool keep_running = true;
			while((req = yield parser.run()) != null && keep_running) {
				/* cleanup sessions */
				cleanup_sessions();

				/* Add session to request */
				string? session_id = req.get_cookie_var("neutron_session_id");
				if(session_id != null) {
					if(stored_sessions.has_key(session_id)) {
						var session = stored_sessions.get(session_id);

						/* Reset last_request-DateTime so the session does not get cleaned up */
						session.set_last_request_time();

						/* Add the session to the request-object */
						req._session = session;
					}
				}

				/* Let the user choose the entity */
				Entity? entity;
				var container = new EntitySelectContainer();
				select_entity(req, container);
				entity = container.get_entity();

				/* If no entity was chosen return 404 */
				if(entity == null)
					entity = new NotFoundEntity();

				/* Call handler */
				var server_action = yield entity.server_callback(req, conn);

				/* Store new session */
				if(server_action.new_session != null) {
					stored_sessions.set(server_action.new_session.session_id, server_action.new_session);
				}

				/* Delete old session */
				if(server_action.old_session != null) {
					stored_sessions.unset(server_action.old_session.session_id);
				}

				if(server_action.connection_action == ConnectionAction.CLOSE)
					break;
				else if(server_action.connection_action == ConnectionAction.RELEASE)
					return;
				else if(server_action.connection_action != ConnectionAction.KEEP_ALIVE)
					assert_not_reached();
			}

			try {
				/* Close connection */
				yield conn.close_async();
			} catch(Error e) {
				return;
			}
		}

		private void cleanup_sessions() {
			var now = new DateTime.now_local();
			var to_delete = new HashSet<string>();

			foreach(string key in stored_sessions.keys) {
				var session = stored_sessions.get(key);
				var req_diff = now.difference(session.last_request_time) / TimeSpan.SECOND;
				var creation_diff = now.difference(session.creation_time) / TimeSpan.SECOND;

				if(req_diff > session_lifetime && session_lifetime > 0) {
					to_delete.add(key);
				} else if(creation_diff > session_max_lifetime && session_max_lifetime > 0) {
					to_delete.add(key);
				}
			}

			foreach(string key in to_delete) {
				stored_sessions.unset(key);
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

	public class EntitySelectContainer : Object {
		private Entity? entity=null;

		public void set_entity(Entity entity) {
			if(this.entity == null)
				this.entity = entity;
		}

		public Entity get_entity() {
			return this.entity;
		}
	}
}
