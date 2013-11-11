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
 * Parses http-request and body
 */
private class Neutron.Http.Parser : Object {
	private int timeout;
	private IOStream stream;
	private uint8[] buf;
	private int bufpos = -1;
	private const int buflen = 80*1024;
	private size_t reclen;
	private uint max_size;
	private bool uses_tls;

	/**
	 * Instantiates a Parser that reads from the supplied IOStream 
	 */
	public Parser(IOStream stream, int timeout, uint max_size, bool uses_tls) {
		this.stream = stream;
		this.timeout = timeout;
		this.max_size = max_size;
		this.uses_tls = uses_tls;
	}

	/**
	 * Get the next request 
	 */
	public async RequestImpl? run() {
		var headers = new HashMap<string, string>();
		var body = new HashMap<string, string>();
		var gets = new HashMap<string, string>();
		var cookies = new HashMap<string, string>();
		string path;
		uint size = 0;

		int state = -1;

		var method = new StringBuilder();
		var url = new StringBuilder();
		var httpver = new StringBuilder();
		StringBuilder? header_key = null;
		StringBuilder header_val = null;
		
		try {
			while(state < 9) {
				if(bufpos == -1) {
					buf = new uint8[buflen];
					Cancellable? timeout_provider = null;
					if(timeout > 0) {
						timeout_provider = new Cancellable();
						Timeout.add_seconds((uint) timeout, () => {
							timeout_provider.cancel();
							return true;
						});
					}
					reclen = yield stream.input_stream.read_async(buf, Priority.DEFAULT, timeout_provider);
					size += (uint) reclen;
					/* Connection closed */
					if(reclen == 0 || size > max_size) return null;
					bufpos = 0;
				}

				while(bufpos < reclen && state < 9) {
					char nextchar = (char) buf[bufpos];
					#if VERBOSE
						if(nextchar != '\r' && nextchar != '\n') message("nextchar = %c".printf(nextchar));
						else message("nextchar = %d".printf((int) nextchar));
					#endif

					switch(state) {
					case -1:
						if(nextchar != '\r' && nextchar != '\n') {
							#if VERBOSE
								message("state -1: switching state, char=%c".printf(nextchar));
							#endif
							state = 0;
							continue;
						}
						break;
					case 0:
						if(nextchar == ' ') {
							state = 1;
							bufpos++;
							continue;
						}
						if(nextchar == '\r' || nextchar == '\n') {
							#if VERBOSE
								message("state 0: unexpected char: %d".printf((int) nextchar));
							#endif
							return null;
						}

						method.append_c(nextchar);
						break;
					case 1:
						if(nextchar == ' ') {
							state = 2;
							bufpos++;
							continue;
						}
						if(nextchar == '\r' || nextchar == '\n') {
							#if VERBOSE
								message("state 1: unexpected char: %d".printf((int) nextchar));
							#endif
							return null;
						}

						url.append_c(nextchar);
						break;
					case 2:
						if(nextchar == '\r') {
							state = 3;
							bufpos++;
							continue;
						}
						if(nextchar == '\n') {
							state = 4;
							header_key = new StringBuilder();
							bufpos++;
							continue;
						}
						if(nextchar == ' ') {
							#if VERBOSE
								message("state 2: unexpected char: %d".printf((int) nextchar));
							#endif
							return null;
						}

						httpver.append_c(nextchar);
						break;
					case 3:
						if(nextchar != '\n') {
							#if VERBOSE
								message("state 3: unexpected char: %d".printf((int) nextchar));
							#endif
							return null;
						} else {
							state = 4;
							header_key = new StringBuilder();
						}
						break;
					case 4:
						if(nextchar == ':') {
							state = 5;
							bufpos++;
							continue;
						}
						if(nextchar == ' ') {
							#if VERBOSE
								message("state 4: unexpected char: %d".printf((int) nextchar));
							#endif
							return null;
						}
						if(nextchar == '\r') {
							state = 8;
							bufpos++;
							continue;
						}
						if(nextchar == '\n') {
							state = 9;
							bufpos++;
							continue;
						}

						header_key.append_c(nextchar);
						break;
					case 5:
						if(nextchar == ' ') {
							state = 6;
							header_val = new StringBuilder();
							bufpos++;
							continue;
						} else {
							#if VERBOSE
								message("state 5: unexpected char: %d".printf((int) nextchar));
							#endif
							return null;
						}
					case 6:
						if(nextchar == '\r') {
							state = 7;
							bufpos++;
							var key_str = header_key.str.down();
							headers.set(key_str, header_val.str);
							header_key = new StringBuilder();
							continue;
						}
						if(nextchar == '\n') {
							state = 4;
							var key_str = header_key.str.down();
							headers.set(key_str, header_val.str);
							header_key = new StringBuilder();
							bufpos++;
							continue;
						}

						header_val.append_c(nextchar);
						break;
					case 7:
						if(nextchar == '\n') state = 4;
						else {
							#if VERBOSE
								message("state 7: unexpected char: %d".printf((int) nextchar));
							#endif
							return null;
						}
						break;
					case 8:
						if(nextchar == '\n') state = 9;
						else {
							#if VERBOSE
								message("state 8: unexpected char: %d".printf((int) nextchar));
							#endif
							return null;
						}
						break;
					}
					bufpos++;
				}

				assert(reclen >= bufpos);
				if(bufpos == reclen) bufpos = -1;
			}

			var urlarr = url.str.split("?",2);
			if(urlarr[0][urlarr[0].length-1] == '/' && urlarr[0].length > 1) {
				path = urlarr[0].substring(0, urlarr[0].length-1);
			} else path = urlarr[0];
			if(urlarr.length == 2) parse_varstring(gets, urlarr[1]);

			if(headers.has_key("cookie")) {
				var cookiearr = headers.get("cookie").split(";");
				foreach(string cookie in cookiearr) {
					var cookiesplit = cookie.split("=", 2);
					if(cookiesplit.length != 2) continue;
					else cookies.set(cookiesplit[0].strip(), cookiesplit[1].strip());
				}
			}

			if(headers.has_key("content-length") && method.str == "POST") {
				#if VERBOSE
					message("content-length > 0");
				#endif
				var clen = uint64.parse(headers.get("content-length"));
				uint8[] bodybuffer;
				var bodybuilder = new StringBuilder();
				uint64 already_received = 0;
				size_t recved;

				if(bufpos != -1) {
					while(bufpos < reclen && already_received < reclen) {
						bodybuilder.append_c((char) buf[bufpos]);
						bufpos++;
						already_received++;
					}
					if(bufpos >= reclen) bufpos = -1;
				}

				if(already_received < clen) {
					Cancellable? timeout_provider = null;
					if(timeout > 0) {
						timeout_provider = new Cancellable();
						Timeout.add_seconds((uint) timeout, () => {
							timeout_provider.cancel();
							return true;
						});
					}
					while(clen > already_received) {
						bodybuffer = new uint8[clen - already_received];
						recved = yield stream.input_stream.read_async(bodybuffer, Priority.DEFAULT, timeout_provider);
						if(recved == 0) return null;
						already_received += recved;
						bodybuilder.append((string) bodybuffer);
						if(timeout > 0) {
							timeout_provider = new Cancellable();
							Timeout.add_seconds((uint) timeout, () => {
								timeout_provider.cancel();
								return true;
							});
						}
					}
				}
				parse_varstring(body, bodybuilder.str);
			}
		} catch(Error e) {
			return null;
		}

		return new RequestImpl(method.str, path, gets, body, cookies, headers, uses_tls);
	}

	private void parse_varstring(HashMap<string, string> map, string varstring) {
		#if VERBOSE
			message("parse_varstring called");
		#endif
		var reqarr = varstring.split("&");
		foreach(string reqpair in reqarr) {
			var reqparr = reqpair.split("=", 2);
			string key = reqparr[0];
			string val;
			if(reqparr.length == 1) val = "";
			else val = reqparr[1];
			var ue_key = Uri.unescape_string(key);
			var ue_val = Uri.unescape_string(val);
			if(ue_key == null) return;
			if(ue_val == null) ue_val = "";
			map.set(ue_key, ue_val);
			#if VERBOSE
				message("map.set(%s, %s)".printf(ue_key, ue_val));
			#endif
		}
	}
}

