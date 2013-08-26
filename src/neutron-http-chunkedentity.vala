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
	public abstract class ChunkedEntity : Entity {
		protected override async void send_default_headers() throws Error {
			yield base.send_default_headers();
			yield send_header("Transfer-Encoding", "chunked");
		}

		protected async void send_chunk(string str) throws Error {
			yield send_byte_chunk((uint8[]) str.to_utf8());
		}

		protected async void send_byte_chunk(uint8[] data) throws Error {
			yield raw_send("%x\r\n".printf((int) data.length));
			yield send_bytes(data);
			yield raw_send("\r\n");
		}

		protected async void send_end_chunk() throws Error {
			yield raw_send("0\r\n\r\n");
		}
	}
}
