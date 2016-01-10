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
 * Http-Entity which upgrades the connection to the websocket-protocol
 */
public class Neutron.Websocket.HttpUpgradeEntity : Http.Entity {
	public bool check_origin { get; construct; }

	public signal void incoming(Websocket.Connection conn);

	public HttpUpgradeEntity (bool check_origin = true) {
		Object (check_origin : check_origin);
	}

	/**
	 * Maximum size of a websocket message
	 */
	public uint message_max_size {
		get;
		set;
		default = 1048576;
	}

	public override async Http.ConnectionAction handle_request() {
		/* Unset transfer- and content-encoding */
		transfer_encoding = Http.TransferEncoding.NONE;
		content_encoding = Http.ContentEncoding.NONE;

		/* Check headers */
		bool headers_ok = true;
		if(request.get_header_var("upgrade").down() != "websocket") {
			headers_ok = false;
		}
		string? ws_key_raw = request.get_header_var("sec-websocket-key");
		if(ws_key_raw == null) {
			headers_ok = false;
		}
		string? host = request.get_header_var("host");
		if(host == null) {
			headers_ok = false;
		}
		string? origin = request.get_header_var("origin");
		if(origin == null) {
			headers_ok = false;
		}
		if(!headers_ok) {
			/* Upgrade required */
			try {
				yield send_status(426);
				yield send_header("Upgrade", "websocket");
				yield send_header("Connection", "close");
				yield send_header("Sec-WebSocket-Version", "13");
			} catch(Error e) { }
			return Http.ConnectionAction.CLOSE;
		}

		/* Check if origin matches allowed_origin */
		string allowed_origin;
		if(request.get_header_var("x-forwarded-proto") == "https") {
			allowed_origin = "https://%s".printf(host);
		} else {
			allowed_origin = "http://%s".printf(host);
		}
		if(check_origin && allowed_origin != origin) {
			try {
				yield send_status(403);
			} catch(Error e) { }
			return Http.ConnectionAction.CLOSE;
		}

		/* Compute checksum for the Sec-WebSocket-Accept header */
		string ws_key = "%s258EAFA5-E914-47DA-95CA-C5AB0DC85B11".printf(ws_key_raw);
		var checksum = new Checksum(ChecksumType.SHA1);
		checksum.update((uchar[]) ws_key.data, ws_key.length);
		uint8[] checksumbuffer = new uint8[20];
		size_t dig_len = 20;
		checksum.get_digest(checksumbuffer, ref dig_len);
		var acceptstring = Base64.encode((uchar[]) checksumbuffer);

		/* Send status "Switching protocols" and release connection */
		try {
			yield send_status(101);
			yield send_header("Upgrade", "websocket");
			yield send_header("Connection", "Upgrade");
			yield send_header("Sec-WebSocket-Accept", acceptstring);
			yield end_headers();
		} catch(Error e) {
			return Http.ConnectionAction.CLOSE;
		}
		incoming(new Websocket.Connection(io_stream, request.session, message_max_size));
		return Http.ConnectionAction.RELEASE;
	}
}
