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

/* This code will only work on little-endian-architectures. */

public class Neutron.Websocket.Connection : Object {
	public signal void message(string message, Connection conn);
	public signal void binary_message(uint8[] message, Connection conn);
	public signal void close(Connection conn);
	public signal void error(string errstr, Connection conn);

	private Session? _session;
	public Session? session {
		get { return _session; }
	}

	private bool _started = false;
	public bool started {
		get { return _started; }
	}

	private bool _closed = false;
	public bool closed {
		get { return _closed; }
	}

	private bool _has_error = false;
	public bool has_error {
		get { return _has_error; }
	}

	private string? _error_string = null;
	public string? error_string {
		get { return _error_string; }
	}

	private IOStream stream;
	private Cancellable cancellable;

	public Connection(IOStream stream, Session? session) {
		this.stream = stream;
		this._session = session;

		cancellable = new Cancellable();

		this.close.connect(this.on_close);
		this.error.connect(this.on_error);
	}

	public void start() {
		if(_started) return;
		read_message.begin();
		_started = true;
	}

	public async void send(string message) {
		var payload = (uint8[]) message.to_utf8();
		try {
			yield send_frame(payload, true, 0x1);
		} catch(Error e) {
			error(e.message, this);
			return;
		}
	}

	private void on_error(string errstr, Connection conn) {
		_has_error = true;
		_error_string = errstr;
	}

	private void on_close(Connection conn) {
		_closed = true;
	}

	private async uint8[] read_bytes(uint len) throws WebsocketError {
		try {
			ByteArray result = new ByteArray();

			while(result.len < len) {
				var buf = new uint8[len - result.len];
				if((yield stream.input_stream.read_async(buf, Priority.DEFAULT, cancellable)) == 0)
					throw new WebsocketError.CONNECTION_CLOSED_UNEXPECTEDLY("Connection closed during read_frame");
				result.append(buf);
			}

			return result.data;
		} catch(IOError e) {
			throw new WebsocketError.CONNECTION_CLOSED_UNEXPECTEDLY(e.message);
		}
	}

	public async uint8[]? read_frame(out bool fin, out uint8 opcode) throws WebsocketError {
		var frame_header = yield read_bytes(2);

		fin = ((frame_header[0] & 0x80) == 0x80);
		/* Maybe we need this code in the future
		bool rsv1 = ((frame_header[0] & 0x40) == 0x40);
		bool rsv2 = ((frame_header[0] & 0x20) == 0x20);
		bool rsv3 = ((frame_header[0] & 0x10) == 0x10);
		*/
		opcode = (frame_header[0] & 0xF);

		bool masked = ((frame_header[1] & 0x80) == 0x80);
		uint payload_len = (uint) (frame_header[1] & 0x7F);

		/*
		if(fin)
			stdout.printf("Fin: true\n");
		else 
			stdout.printf("Fin: false\n");
		stdout.printf("Opcode: %u\n", opcode);
		if(masked)
			stdout.printf("Masked: true\n");
		else 
			stdout.printf("Masked: false\n");
		stdout.printf("Len: %llu\n", payload_len);
		stdout.printf("---------\n");
		*/

		uint8[] mask;
		uint8 mask_next = 0;
		if(masked) {
			mask = yield read_bytes(4);
		} else {
			mask = new uint8[4];
			mask[0] = 0;
			mask[1] = 0;
			mask[2] = 0;
			mask[3] = 0;
		}

		if(payload_len == 126) {
			var payload_len_ext = yield read_bytes(2);
			payload_len = Posix.htons(*((uint16*) payload_len_ext));
		} else if(payload_len == 127) {
			var payload_len_ext = yield read_bytes(8);
			for(int i = 0; i < 4; i++) {
				if(payload_len_ext[i] != 0)
					throw new WebsocketError.MAX_FRAME_SIZE_EXCEEDED("uint32 should really be enough to address a single frame");
			}
			payload_len = Posix.htonl( *((uint32*) ((uint8*) payload_len_ext) + 4));
		} else if(payload_len == 0) {
			return null;
		}

		uint8[] payload = yield read_bytes(payload_len);
		for(int i = 0; i < payload.length; i++) {
			payload[i] ^= mask[mask_next];
			mask_next++;
			if(mask_next == 4) mask_next = 0;
		}

		/* stdout.printf("Payload: %s\n", (string) payload); */
		return payload;
	}

	private async void send_frame(uint8[]? payload, bool fin, uint8 opcode) throws WebsocketError {
		try {
			var frame_header = new uint8[2];
			uint8[]? pl_ext = null;

			frame_header[0] = opcode;
			frame_header[0] &= 0xF;

			if(fin)	frame_header[0] |= 0x80;

			if(payload != null) {
				if(payload.length < 126) {
					frame_header[1] = (uint8) payload.length;
				} else if(payload.length > 125 && payload.length < 0x10000) {
					frame_header[1] = 126;
					pl_ext = new uint8[2];
					*((uint16*)pl_ext) = Posix.htons((uint16) payload.length);
				} else {
					frame_header[1] = 127;
					pl_ext = new uint8[8];
					*((uint32*)pl_ext) = Posix.htonl(payload.length);
				}
			} else {
				frame_header[1] = 0;
			}

			frame_header[1] &= 0x7F;

			var frame = new ByteArray();

			frame.append(frame_header);
			if(pl_ext != null) frame.append(pl_ext);
			if(payload != null) frame.append(payload);

			if((yield stream.output_stream.write_async(frame.data, Priority.DEFAULT, cancellable)) == 0) {
				throw new WebsocketError.CONNECTION_CLOSED_UNEXPECTEDLY("Connection closed during write");
			}
		} catch(IOError e) {
			throw new WebsocketError.CONNECTION_CLOSED_UNEXPECTEDLY(e.message);
		}
	}

	private async void read_message() {
		try {
			var _message = new ByteArray();
			bool fin = false;
			uint8 opcode = 0;

			while(!fin) {
				uint8[] frame;
				uint8 current_opcode;
				frame = yield read_frame(out fin, out current_opcode);

				if(opcode == 0) {
					opcode = current_opcode;
				} else if(current_opcode != 0) {
					error("Expected opcode 0", this);
					return;
				}

				_message.append(frame);
			}

			switch(opcode) {
			case 0:
				error("Expected opcode != 0", this);
				return;
			case 1:
				var sb = new StringBuilder();
				sb.append((string) _message.data);
				message(sb.str, this);
				break;
			case 2:
				binary_message(_message.data, this);
				break;
			case 8:
				close(this);
				return;
			case 9:
				yield send_frame(_message.data, true, 0xA);
				break;
			case 0xA:
				break;
			default:
				error("Unknown opcode", this);
				return;
			}

			read_message.begin();
		} catch(Error e) {
			error(e.message, this);
			return;
		}
	}
}
