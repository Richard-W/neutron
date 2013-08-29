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

using Native.HttpParser;
using Gee;

namespace Neutron.Http {
	private class Parser : Object {
		private HashMap<string, HashSet<string>> headers;
		private HashMap<string, string> body;
		private HashMap<string, string> gets;
		private HashMap<string, string> cookies;

		private string? header_field = null;
		private string? header_value = null;
		private string? url = null;
		private string? path = null;
		private bool message_complete = false;
		private int timeout;

		private IOStream stream;

		private http_parser parser;
		private http_parser_settings parser_settings;

		public signal void closed(Parser parser);
		public signal void request(Request request);

		/**
		 * Instantiates a Parser that reads from the supplied IOStream 
		 */
		public Parser(IOStream stream, int timeout) {
			parser = http_parser();
			http_parser_init(&parser, http_parser_type.HTTP_REQUEST);
			parser.data = (void*) this;

			this.stream = stream;
			this.timeout = timeout;

			parser_settings = http_parser_settings();
			parser_settings.on_message_begin = (void*) on_message_begin_cb;
			parser_settings.on_url = (void*) on_url_cb;
			parser_settings.on_status_complete = (void*) on_status_complete_cb;
			parser_settings.on_header_field = (void*) on_header_field_cb;
			parser_settings.on_header_value = (void*) on_header_value_cb;
			parser_settings.on_headers_complete = (void*) on_headers_complete_cb;
			parser_settings.on_body = (void*) on_body_cb;
			parser_settings.on_message_complete = (void*) on_message_complete_cb;
		}

		/**
		 * Get the next request 
		 */
		public async RequestImpl? run() {
			uint8[] buffer = new uint8[80*1024];
			ssize_t recved = 0;
			
			try {
				Cancellable? timeout_provider = null;
				if(timeout > 0) {
					timeout_provider = new Cancellable();
					Timeout.add_seconds((uint) timeout, () => {
						timeout_provider.cancel();
						return true;
					});
				}

				while(!message_complete && (recved = yield stream.input_stream.read_async(buffer, Priority.DEFAULT, timeout_provider)) != 0) {
					var nparsed = http_parser_execute(&parser, &parser_settings, (char*) buffer, recved);
					if((bool)parser.upgrade) {
						yield stream.output_stream.write_async((uint8[]) "HTTP/1.1 501 Not implemented\r\n\r\n".to_utf8());
						closed(this);
						return null;
					} else if(parser.http_errno != 0 || nparsed != recved) {
						yield stream.output_stream.write_async((uint8[]) "HTTP/1.1 400 Bad Request\r\n\r\n".to_utf8());
						closed(this);
						return null;
					}
					buffer = new uint8[80*1024];

					if(timeout > 0) {
						timeout_provider = new Cancellable();
						Timeout.add_seconds((uint) timeout, () => {
							timeout_provider.cancel();
							return true;
						});
					}
				}
			} catch(Error e) {
				closed(this);
				return null;
			}

			if(!message_complete) {
				closed(this);
			}

			message_complete = false;
			return new RequestImpl(path, gets, body, cookies, headers);
		}

		public int on_message_begin(http_parser *parser) {
			headers = new HashMap<string,HashSet<string>>();
			body = new HashMap<string,string>();
			gets = new HashMap<string,string>();
			cookies = new HashMap<string,string>();

			url = null;
			path = null;
			header_field = null;
			header_value = null;
			return 0;
		}

		public int on_url(http_parser *parser, char *data, size_t length) {
			url = ((string) data).substring(0, (long) length);
			var urlarr = url.split("?",2);
			if(urlarr[0][urlarr[0].length-1] == '/' && urlarr[0].length > 1) {
				path = urlarr[0].substring(0, urlarr[0].length-1);
			} else path = urlarr[0];
			if(urlarr.length == 1) return 0;

			parse_varstring(gets, urlarr[1]);

			return 0;
		}

		public int on_status_complete(http_parser *parser) {
			return 0;
		}

		public int on_header_field(http_parser *parser, char *data, size_t length) {
			if(header_field != null) {
				header_set(header_field, "");
			}

			header_field = ((string) data).substring(0, (long) length);
			return 0;
		}

		public int on_header_value(http_parser *parser, char *data, size_t length) {
			if(header_field == null) return 1;
			header_value = ((string) data).substring(0, (long) length);

			header_set(header_field, header_value);
			header_field = null;
			header_value = null;
			return 0;
		}

		private void header_set(string key, string val) {
			var dkey = key.down();
			if(!headers.has_key(dkey)) headers.set(dkey,new HashSet<string>());
			headers.get(dkey).add(val);
		}

		public int on_headers_complete(http_parser *parser) {
			return 0;
		}

		public int on_body(http_parser *parser, char *data, size_t length) {
			var bodystr = ((string) data).substring(0, (long) length);
			parse_varstring(body, bodystr);
			return 0;
		}

		public int on_message_complete(http_parser *parser) {
			message_complete = true;

			/* Parse cookies */
			if(headers.has_key("cookie")) {
				var cookieset = headers.get("cookie");
				foreach(string cookiestring in cookieset) {
					var cookiearr = cookiestring.split(";");
					foreach(string cookie in cookiearr) {
						var cookiesplit = cookie.split("=", 2);
						if(cookiesplit.length != 2) continue;
						else cookies.set(cookiesplit[0].strip(), cookiesplit[1].strip());
					}
				}
			}
			return 0;
		}

		private void parse_varstring(HashMap<string, string> map, string varstring) {
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
			}
		}
	}

	/* The following part is not really good practice, but it was the easiest way to
	 * make vala leave the function-signatures alone.
	 *
	 * This needs some further thought, but i do not think that it is critical
	 * to make this beautiful. It works.
	 */

	private int on_message_begin_cb(http_parser *parser) {
		var parser_obj = (Parser) parser->data;
		return parser_obj.on_message_begin(parser);
	}
	private int on_status_complete_cb(http_parser *parser) {
		var parser_obj = (Parser) parser->data;
		return parser_obj.on_status_complete(parser);
	}
	private int on_headers_complete_cb(http_parser *parser) {
		var parser_obj = (Parser) parser->data;
		return parser_obj.on_headers_complete(parser);
	}
	private int on_message_complete_cb(http_parser *parser) {
		var parser_obj = (Parser) parser->data;
		return parser_obj.on_message_complete(parser);
	}
	private int on_url_cb(http_parser *parser, char *data, size_t length) {
		var parser_obj = (Parser) parser->data;
		return parser_obj.on_url(parser, data, length);
	}
	private int on_header_field_cb(http_parser *parser, char *data, size_t length) {
		var parser_obj = (Parser) parser->data;
		return parser_obj.on_header_field(parser, data, length);
	}
	private int on_header_value_cb(http_parser *parser, char *data, size_t length) {
		var parser_obj = (Parser) parser->data;
		return parser_obj.on_header_value(parser, data, length);
	}
	private int on_body_cb(http_parser *parser, char *data, size_t length) {
		var parser_obj = (Parser) parser->data;
		return parser_obj.on_body(parser, data, length);
	}
}
