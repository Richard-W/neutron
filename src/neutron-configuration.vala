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

namespace Neutron {
	private class Configuration : Object {
		/* General */

		private bool _general_daemon;
		/**
		 * Fork and detach from tty 
		 */
		public bool general_daemon {
			get { return _general_daemon; }
		}

		private int _general_worker_threads;
		/**
		 * Number of worker threads running
		 */
		public int general_worker_threads {
			get { return _general_worker_threads; }
		}

		/* Http */

		private uint16 _http_port;
		/**
		 * The port the http-server will bind to 
		 */
		public uint16 http_port {
			get { return _http_port; }
		}

		private bool _http_use_tls;
		/**
		 * Makes the http-server use https 
		 */
		public bool http_use_tls {
			get { return _http_use_tls; }
		}

		private TlsCertificate? _http_tls_certificate;
		/**
		 * The certificate and private key used for https 
		 */
		public TlsCertificate? http_tls_certificate {
			get { return _http_tls_certificate; }
		}

		private int _http_session_lifetime;
		/**
		 * Maximum time sessions stays stored between requests 
		 */
		public int http_session_lifetime {
			get { return _http_session_lifetime; }
		}

		private int _http_session_max_lifetime;
		/**
		 * Maximum time sessions stays stored at all 
		 */
		public int http_session_max_lifetime {
			get { return _http_session_max_lifetime; }
		}

		private int _http_timeout;
		/**
		 * The timeout of the connection
		 */
		public int http_timeout {
			get { return _http_timeout; }
		}

		/* Websocket */

		private uint _websocket_message_max_size;
		/**
		 * Maximum size of websocket-message
		 */
		public uint websocket_message_max_size {
			get { return _websocket_message_max_size; }
		}

		/* Internal */

		private string _internal_config_file;
		/**
		 * Configuration-file that is parsed when reload() is called without arguments 
		 */
		public string internal_config_file {
			get { return _internal_config_file; }
		}

		/**
		 * Should be given the argv-array, to determine the location of the config-file. 
		 */
		public Configuration(string[] argv, string? alternative = null) throws Error {
			string? config_file = null;
			OptionEntry[] options = new OptionEntry[1];
			options[0] = { "config", 'c', 0, OptionArg.FILENAME, ref config_file, "Configuration-file", "CONFIG" };

			var opt_context = new OptionContext("");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse(ref argv);

			if(config_file == null) config_file = alternative;
			_internal_config_file = config_file;

			reload();
		}

		/**
		 * Parses the config-file again. You can also specify a new config-file 
		 */
		public void reload(string? new_config = null) throws Error {
			if(new_config != null) _internal_config_file = new_config;
			if(_internal_config_file == null) {
				set_defaults();
				return;
			}

			var kf = new KeyFile();
			kf.set_list_separator(',');
			kf.load_from_file(_internal_config_file, KeyFileFlags.NONE);

			parse_bool(kf, out _general_daemon, "General", "daemon", false, false);
			parse_int(kf, out _general_worker_threads, "General", "worker_threads", false, 0);
			parse_port(kf, out _http_port, "Http", "port", false, 80);
			parse_bool(kf, out _http_use_tls, "Http", "use_tls", false, false);
			parse_int(kf, out _http_session_lifetime, "Http", "session_lifetime", false, 3600);
			parse_int(kf, out _http_session_max_lifetime, "Http", "session_max_lifetime", false, -1);
			parse_certificate(kf, out _http_tls_certificate, "Http", "tls_cert_file", "Http", "tls_key_file", _http_use_tls);
			parse_int(kf, out _http_timeout, "Http", "timeout", false, -1);
			parse_uint(kf, out _websocket_message_max_size, "Websocket", "message_max_size", false, 1048576);

			Websocket.Connection.message_max_size = _websocket_message_max_size;
		}

		/**
		 * Set the default values 
		 */
		public void set_defaults() {
			_general_daemon = false;
			_http_port = 80;
			_http_use_tls = false;
		}

		/**
		 * This basically just parses a uint16 
		 */
		private void parse_port(KeyFile kf, out uint16 dest, string group, string key, bool required, uint16 default_value) throws Error {
			if(!check_option(kf, group, key, required)) {
				dest = default_value;
				return;
			}
			uint64 port_proto = kf.get_uint64(group, key);
			if(port_proto > 65535) throw new ConfigurationError.INVALID_OPTION("Portnumber too high");
			dest = (uint16) port_proto;
		}

		/**
		 * Parse a uint from the config-file
		 */
		private void parse_uint(KeyFile kf, out uint dest, string group, string key, bool required, uint default_value) throws Error {
			if(!check_option(kf, group, key, required)) {
				dest = default_value;
				return;
			}
			uint64 port_proto = kf.get_uint64(group, key);
			if(port_proto > 0xFFFFFFFF) throw new ConfigurationError.INVALID_OPTION("number too high");
			dest = (uint) port_proto;
		}

		/**
		 * Parses a boolean from the config-file 
		 */
		private void parse_bool(KeyFile kf, out bool dest, string group, string key, bool required, bool default_value) throws Error {
			if(!check_option(kf, group, key, required)) {
				dest = default_value;
				return;
			}
			dest = kf.get_boolean(group, key);
		}

		/**
		 * Parses an integer from the config-file 
		 */
		private void parse_int(KeyFile kf, out int dest, string group, string key, bool required, int default_value) throws Error {
			if(!check_option(kf, group, key, required)) {
				dest = default_value;
				return;
			}
			dest = (int) kf.get_int64(group, key);
		}

		/**
		 * Parses a TlsCertificate from the config-file 
		 */
		private void parse_certificate(KeyFile kf, out TlsCertificate cert, string cert_group, string cert_key, string key_group, string key_key, bool required) throws Error {
			if((!check_option(kf, cert_group, cert_key, required)) || (!check_option(kf, key_group, key_key, required))) {
				cert = null;
				return;
			}

			string cert_file = kf.get_string(cert_group, cert_key);
			string key_file = kf.get_string(key_group, key_key);

			cert = new TlsCertificate.from_files(cert_file, key_file);
		}

		/**
		 * Checks if option is set in the config-file. Throws an error if it is not set, but required 
		 */
		private bool check_option(KeyFile kf, string group, string key, bool required) throws Error {
			if(!kf.has_group(group) || !kf.has_key(group, key)) {
				if(required)
					throw new ConfigurationError.REQUIRED_OPTION_MISSING("Required option missing");
				return false;
			}
			return true;
		}
	}
}
