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
 * Main class for Http-communication.
 *
 * To use it you have to connect to the select_entity-event and supply an Entity-object for
 * Requests you feel responsible for.
 *
 * If two handlers of select_entity feel responsible for one Request, the behaviour is determined,
 * by the order in which the signal-handlers are processed.
 */
public class Neutron.Http.Server : Object {
	/**
	 * Fired when a new Request comes in and used for selecting an appropriate Entity
	 */
	public signal void select_entity(Request request, EntitySelectContainer container);

	/**
	 * The port the Http-Server is currently listening on
	 */
	public uint16 port {
		get;
		private set;
	}

	/**
	 * Certificate used when use_tls == true. You can only set this.
	 */
	public TlsCertificate? tls_certificate {
		get;
		set;
		default = null;
	}

	/**
	 * Whether the server uses TLS
	 */
	public bool use_tls { 
		get;
		set;
		default = false;
	}

	/**
	 * Used to distribute requests over threads
	 */
	public ThreadController? thread_controller {
		get;
		set;
		default = ThreadController.default;
	}

	/**
	 * The time in seconds the server will wait for new requests before it
	 * disconnects from the client
	 */
	public int timeout {
		get;
		set;
		default = -1;
	}

	/**
	 * The time a session is stored when no new request claim it
	 */
	public int session_lifetime {
		get;
		set;
		default = 3600;
	}

	/**
	 * The time after which a session is deleted unconditionally.
	 */
	public int session_max_lifetime {
		get;
		set;
		default = -1;
	}

	/**
	 * Maximum size of requests.
	 */
	public int request_max_size {
		get;
		set;
		default = 1048576;
	}

	private SocketService listener;
	private HashMap<string, Session> stored_sessions;

	public Server(uint16 port = 0) throws Error {
		#if VERBOSE
			message("constructor called");
		#endif
		if(port == 0) {
			if(Configuration.default == null || !Configuration.default.has("http", "port"))
				throw new HttpError.INVALID_PORT("Port is missing");

			var port_raw = uint64.parse(Configuration.default.get("http", "port"));
			if(port_raw > 0xFFFF) throw new HttpError.INVALID_PORT("Port number too high");

			this.port = (uint16) port_raw;
		}
		else {
			this.port = port;
		}

		/* Define listener */
		listener = new SocketService();
		listener.add_inet_port(this.port, null);
		listener.incoming.connect(on_incoming);

		stored_sessions = new HashMap<string, Session>();
		apply_config(Configuration.default);
	}

	/**
	 * Sets certain parameters of this server according to the Configuration-object
	 */
	private void apply_config(Configuration? config) throws Error {
		#if VERBOSE
			message("apply_config called");
		#endif
		if(config == null) return;

		this.use_tls = config.get_bool("http", "use_tls", false);

		var cert_file = config.get("http", "tls_cert_file");
		var key_file = config.get("http", "tls_key_file");
		if(cert_file != null && key_file != null) {
			this.tls_certificate = new TlsCertificate.from_files(cert_file, key_file);
		}

		this.timeout = config.get_int("http", "timeout", -1);

		this.session_lifetime = config.get_int("http", "session_lifetime", 3600);

		this.session_max_lifetime = config.get_int("http", "session_max_lifetime", -1);

		this.request_max_size = config.get_int("http", "request_max_size", 1048576);
	}

	/**
	 * Start handling connections 
	 */
	public void start() {
		#if VERBOSE
			message("start called");
		#endif
		listener.start();
	}

	/**
	 * Stop handling connections 
	 */
	public void stop() {
		#if VERBOSE
			message("stop called");
		#endif
		listener.stop();
	}

	/**
	 * Gets the connections from listener 
	 */
	private bool on_incoming(SocketConnection conn, Object? source_object) {
		#if VERBOSE
			message("on_incoming called");
		#endif
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
	 * Stores a session in this server
	 */
	public void store_session(Session session) {
		#if VERBOSE
			message("store_session called");
		#endif
		stored_sessions.set(session.session_id, session);
	}

	/**
	 * Deletes a session from this server
	 */
	public void delete_session(Session session) {
		#if VERBOSE
			message("delete_session called");
		#endif
		stored_sessions.unset(session.session_id);
	}

	/**
	 * Handle the incoming connection asynchronously 
	 */
	private async void handle_connection(IOStream conn) {
		#if VERBOSE
			message("handle_connection called");
		#endif
		if(use_tls) {
			try {
				/* Wrap the connection in a TlsServerConnection */
				var tlsconn = TlsServerConnection.new(conn, tls_certificate);
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

		while((req = yield parser.run()) != null) {
			/* cleanup sessions */
			cleanup_sessions();

			/* Add session to request */
			string? session_id = req.get_cookie_var("neutron_session_id");
			if(session_id != null) {
				if(stored_sessions.has_key(session_id)) {
					var session = stored_sessions.get(session_id);

					/* Reset last_request-DateTime so the session does not get cleaned up */
					session.reset_last_request_time();

					/* Add the session to the request-object */
					req.set_session(session);
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
			var connection_action = yield entity.server_callback(this, req, conn);

			var connection_header = req.get_header_var("connection");
			if(connection_header != null)
				connection_header = connection_header.down();

			if(connection_action == ConnectionAction.CLOSE || connection_header == "close") {
				#if VERBOSE
					if(connection_action == ConnectionAction.CLOSE) message("connection_action is CLOSE");
					else message("connection_header is close");
				#endif
				break;
			}
			else if(connection_action == ConnectionAction.RELEASE)
				return;
			else if(connection_action != ConnectionAction.KEEP_ALIVE)
				assert_not_reached();
		}

		try {
			#if VERBOSE
				if(req == null) message("req is null");
				message("handle_connection: closed connection");
			#endif
			/* Close connection */
			yield conn.close_async();
		} catch(Error e) {
			return;
		}
	}

	private void cleanup_sessions() {
		#if VERBOSE
			message("cleanup_sessions called");
		#endif
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

public enum Neutron.Http.ConnectionAction {
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

public class Neutron.Http.EntitySelectContainer : Object {
	private Entity? entity=null;

	public void set_entity(Entity entity) {
		if(this.entity == null)
			this.entity = entity;
	}

	public Entity get_entity() {
		return this.entity;
	}
}

