/*
 * This file is part of the webcon project.
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

namespace Webcon {
	private class Configuration {
		/* General */

		private uint16 _general_http_port;
		/** The port the http-server will bind to */
		public uint16 general_http_port {
			get { return _general_http_port; }
			set { }
		}

		private bool _general_daemon;
		/** Fork and detach from tty */
		public bool general_daemon {
			get { return _general_daemon; }
			set { }
		}

		/* Security */

		private bool _security_use_tls;
		/** Makes the http-server use https */
		public bool security_use_tls {
			get { return _security_use_tls; }
			set { }
		}

		private TlsCertificate? _security_tls_certificate;
		/** The certificate and private key used for https */
		public TlsCertificate? security_tls_certificate {
			get { return _security_tls_certificate; }
			set { }
		}

		/* Internal */

		private string _internal_config_file;
		/** Configuration-file that is parsed when reload() is called without arguments */
		public string internal_config_file {
			get { return _internal_config_file; }
			set { }
		}

		/** Should be given the argv-array, to determine the location of the config-file. */
		public Configuration(string[] args) throws Error {
			string? config_file = null;
			OptionEntry[] options = new OptionEntry[1];
			options[0] = { "config", 'c', 0, OptionArg.FILENAME, ref config_file, "Configuration-file", "CONFIG" };

			var opt_context = new OptionContext("");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse(ref args);

			if(config_file == null) {
				throw new ConfigurationError.NO_CONFIGURATION("No configuration given");
			}

			_internal_config_file = config_file;

			reload();
		}

		/** Parses the config-file again. You can also specify a new config-file */
		public void reload(string? new_config = null) throws Error {
			if(new_config != null) _internal_config_file = new_config;

			var kf = new KeyFile();
			kf.set_list_separator(',');
			kf.load_from_file(_internal_config_file, KeyFileFlags.NONE);

			parse_port(kf, out _general_http_port, "General", "http_port", true, 0);
			parse_bool(kf, out _general_daemon, "General", "daemon", false, false);
			parse_bool(kf, out _security_use_tls, "Security", "use_tls", false, false);
			parse_certificate(kf, out _security_tls_certificate, "Security", "tls_cert_file", "Security", "tls_key_file", _security_use_tls);
		}

		/** This basically just parses a uint16 */
		private void parse_port(KeyFile kf, out uint16 dest, string group, string key, bool required, uint16 default_value) throws Error {
			if(!check_option(kf, group, key, required)) {
				dest = default_value;
				return;
			}
			uint64 port_proto = kf.get_uint64(group, key);
			if(port_proto > 65535) throw new ConfigurationError.INVALID_OPTION("Portnumber too high");
			dest = (uint16) port_proto;
		}

		/** Parses a boolean from the config-file */
		private void parse_bool(KeyFile kf, out bool dest, string group, string key, bool required, bool default_value) throws Error {
			if(!check_option(kf, group, key, required)) {
				dest = default_value;
				return;
			}
			dest = kf.get_boolean(group, key);
		}

		/** Parses a TlsCertificate from the config-file */
		private void parse_certificate(KeyFile kf, out TlsCertificate cert, string cert_group, string cert_key, string key_group, string key_key, bool required) throws Error {
			if((!check_option(kf, cert_group, cert_key, required)) || (!check_option(kf, key_group, key_key, required))) {
				cert = null;
			}

			string cert_file = kf.get_string(cert_group, cert_key);
			string key_file = kf.get_string(key_group, key_key);

			cert = new TlsCertificate.from_files(cert_file, key_file);
		}

		/** Checks if option is set in the config-file. Throws an error if it is not set, but required */
		private bool check_option(KeyFile kf, string group, string key, bool required) throws Error {
			if(!kf.has_key(group, key)) {
				if(required)
					throw new ConfigurationError.REQUIRED_OPTION_MISSING("Required option missing");
				return false;
			}
			return true;
		}
	}
}
