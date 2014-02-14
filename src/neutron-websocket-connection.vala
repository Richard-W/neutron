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

/* This code will only work on little-endian-architectures. */

/**
 * Represents a connection to a websocket-client (Typically JS)
 *
 * Gets emitted and constructed by a Websocket.HttpUpgradeEntity which one of your
 * select_entity-handlers should supply.
 */
public class Neutron.Websocket.Connection : Object {
	public signal void on_message(string message, Connection conn);
	public signal void on_binary_message(uint8[] message, Connection conn);
	public signal void on_close(Connection conn);
	public signal void on_error(string errstr, Connection conn);

	public Session? session {
		get;
		private set;
	}
	
	public bool alive {
		get;
		private set;
		default = false;
	}

	public uint32 message_max_size {
		get;
		set;
	}

	private bool started = false;
	private IOStream stream;
	private Cancellable cancellable;

	public Connection(IOStream stream, Session? session, uint32 message_max_size) {
		#if VERBOSE
			message("constructor called");
		#endif
		this.stream = stream;
		this.session = session;
		this.message_max_size = message_max_size;

		cancellable = new Cancellable();
	}

	public void start() {
		#if VERBOSE
			message("start called");
		#endif
		if(started) return;
		alive = true;
		read_message.begin();
	}

	private void close_internal() {
		#if VERBOSE
			message("close_internal called");
		#endif
		alive = false;
		on_close(this);
		stream.close_async.begin();
	}

	private void error_internal(string errstr) {
		#if VERBOSE
			message("error_internal called");
		#endif
		alive = false;
		on_error(errstr, this);
		close_internal();
	}

	public async void close() {
		#if VERBOSE
			message("close called");
		#endif
		try {
			yield send_frame(null, true, 0x8);
			bool fin;
			uint8 opcode;
			yield read_frame(out fin, out opcode);

			if(fin && opcode == 8) {
				close_internal();
			} else {
				error_internal("Closing handshake failed");
			}
		} catch(Error e) {
			error_internal(e.message);
		}
	}

	public async void send(string msg) {
		#if VERBOSE
			message("send called");
		#endif
		if(!alive) return;
		var payload = (uint8[]) msg.to_utf8();
		try {
			yield send_frame(payload, true, 0x1);
		} catch(Error e) {
			error_internal(e.message);
		}
	}

	public async void send_binary(uint8[] msg) {
		#if VERBOSE
			message("send_binary called");
		#endif
		if(!alive) return;
		try {
			yield send_frame(msg, true, 0x2);
		} catch(Error e) {
			error_internal(e.message);
			return;
		}
	}

	private async uint8[] read_all_async(uint len) throws WebsocketError {
		#if VERBOSE
			message("read_all_async called");
		#endif
		try {
			ByteArray result = new ByteArray();

			while(result.len < len) {
				var buf = new uint8[len - result.len];
				if((yield stream.input_stream.read_async(buf, Priority.DEFAULT, cancellable)) == 0)
					throw new WebsocketError.CONNECTION_CLOSED_UNEXPECTEDLY("Connection closed during read_frame");
				result.append(buf);
			}

			return result.data;
		} catch(Error e) {
			throw new WebsocketError.CONNECTION_CLOSED_UNEXPECTEDLY(e.message);
		}
	}

	private async uint8[]? read_frame(out bool fin, out uint8 opcode, uint max_size = 1048576) throws WebsocketError {
		#if VERBOSE
			message("read_frame called");
		#endif
		var frame_header = yield read_all_async(2);

		fin = ((frame_header[0] & 0x80) == 0x80);
		bool rsv1 = ((frame_header[0] & 0x40) == 0x40);
		bool rsv2 = ((frame_header[0] & 0x20) == 0x20);
		bool rsv3 = ((frame_header[0] & 0x10) == 0x10);
		if(rsv1 || rsv2 || rsv3) throw new WebsocketError.PROTOCOL_ERROR("unexpected positive rsv-flag in frame-header");

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
			mask = yield read_all_async(4);
		} else {
			mask = new uint8[4];
			mask[0] = 0;
			mask[1] = 0;
			mask[2] = 0;
			mask[3] = 0;
		}

		if(payload_len == 126) {
			var payload_len_ext = yield read_all_async(2);
			payload_len = Posix.htons(*((uint16*) payload_len_ext));
		} else if(payload_len == 127) {
			var payload_len_ext = yield read_all_async(8);
			for(int i = 0; i < 4; i++) {
				if(payload_len_ext[i] != 0)
					throw new WebsocketError.MAX_FRAME_SIZE_EXCEEDED("uint32 should really be enough to address a single frame");
			}
			payload_len = Posix.htonl( *((uint32*) ((uint8*) payload_len_ext) + 4));
		} else if(payload_len == 0) {
			return null;
		}

		if(payload_len > max_size)
			throw new WebsocketError.MAX_FRAME_SIZE_EXCEEDED("you need to specify a higher max_size for websocket-messages");

		uint8[] payload = yield read_all_async(payload_len);
		for(int i = 0; i < payload.length; i++) {
			payload[i] ^= mask[mask_next];
			mask_next++;
			if(mask_next == 4) mask_next = 0;
		}

		/* stdout.printf("Payload: %s\n", (string) payload); */
		return payload;
	}

	private async void send_frame(uint8[]? payload, bool fin, uint8 opcode) throws WebsocketError {
		#if VERBOSE
			message("send_frame called");
		#endif
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
		} catch(Error e) {
			throw new WebsocketError.CONNECTION_CLOSED_UNEXPECTEDLY(e.message);
		}
	}

	private async void read_message() {
		#if VERBOSE
			message("read_message called");
		#endif
		try {
			var _message = new ByteArray();
			bool fin = false;
			uint8 opcode = 0;

			while(!fin) {
				uint8[] frame;
				uint8 current_opcode;
				frame = yield read_frame(out fin, out current_opcode, (message_max_size - _message.len));

				if(opcode == 0) {
					opcode = current_opcode;
				} else if(current_opcode != 0) {
					error_internal("Expected opcode 0");
					return;
				}

				_message.append(frame);
			}

			#if VERBOSE
				message("message opcode: %d".printf(opcode));
			#endif
			switch(opcode) {
			case 0:
				error_internal("Expected opcode != 0");
				return;
			case 1:
				var sb = new StringBuilder();
				_message.append({0});
				sb.append((string) _message.data);
				#if VERBOSE
					message("signal on_message emitted");
				#endif
				on_message(sb.str, this);
				break;
			case 2:
				#if VERBOSE
					message("signal on_binary_message emitted");
				#endif
				on_binary_message(_message.data, this);
				break;
			case 8:
				yield send_frame(null, true, 0x8);
				close_internal();
				return;
			case 9:
				yield send_frame(_message.data, true, 0xA);
				break;
			case 0xA:
				break;
			default:
				error_internal("Unknown opcode");
				return;
			}

			read_message.begin();
		} catch(Error e) {
			error_internal(e.message);
		}
	}
}
