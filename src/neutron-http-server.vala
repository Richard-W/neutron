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

	private SocketService? listener = null;
	private uint16 _port;
	/**
	 * The port the Http-Server is currently listening on
	 */
	public uint16 port {
		get {
			return this._port;
		}
		set {
			this._port = value;
			if(listener != null) {
				listener.stop();
			}
			this.listener = new SocketService();
			try {
				this.listener.add_inet_port(this._port, null);
				this.listener.incoming.connect(this.on_incoming);
				this.listener.start();
			} catch(Error e) {
				_port = 0;
				warning(e.message);
				this.listener = null;
			}
		}
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
	 * Maximum size of requests.
	 */
	public int request_max_size {
		get;
		set;
		default = 1048576;
	}


	public Server() {
		#if VERBOSE
			message("constructor called");
		#endif
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
	 * Handle the incoming connection asynchronously 
	 */
	private async void handle_connection(IOStream conn) {
		#if VERBOSE
			message("handle_connection called");
		#endif

		var parser = new Parser(conn, timeout, request_max_size);
		RequestImpl req;

		while((req = yield parser.run()) != null) {
			/* cleanup sessions */
			Session.cleanup();

			/* Add session to request */
			string? session_id = req.get_cookie_var("neutron_session_id");
			Session? session = null;
			if(session_id != null && (session = Session.get_by_id(session_id)) != null) {
				/* Reset last_request-DateTime so the session does not get cleaned up */
				session.reset_last_request_time();

				/* Add the session to the request-object */
				req.set_session(session);
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

