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
	public class WebsocketEntity : Entity {
		public signal void incoming(IOStream connection, Session? session);

		public override async Http.ConnectionAction handle_request() {
			try {
				transfer_encoding = Http.TransferEncoding.NONE;
				content_encoding = Http.ContentEncoding.NONE;

				var upgrade = request.get_header_var("upgrade");
				var ws_key_arr = request.get_header_var("sec-websocket-key");
				if(ws_key_arr == null || upgrade == null || upgrade[0].down() != "websocket") {
					yield send_status(400);
					return Http.ConnectionAction.CLOSE;
				}


				string ws_key = "%s258EAFA5-E914-47DA-95CA-C5AB0DC85B11".printf(ws_key_arr[0]);

				var checksum = new Checksum(ChecksumType.SHA1);
				checksum.update((uchar[]) ws_key.to_utf8(), ws_key.length);
				uint8[] checksumbuffer = new uint8[20];
				size_t dig_len = 20;
				checksum.get_digest(checksumbuffer, ref dig_len);
				assert(dig_len == 20);

				var acceptstring = Base64.encode((uchar[]) checksumbuffer);

				yield send_status(101);
				yield send_header("Upgrade", "websocket");
				yield send_header("Sec-WebSocket-Accept", acceptstring);
				yield end_headers();

				incoming(io_stream, request.session);
				
				return Http.ConnectionAction.RELEASE;
			} catch(Error e) {
				return Http.ConnectionAction.CLOSE;
			}
		}
	}
}
