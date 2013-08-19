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
	public class Application : Object {
		/* General */
		private Configuration config;
		private MainLoop mainloop;

		public Application(string[] argv, string? configfile = null) throws Error {
			config = new Configuration(argv, configfile);
			mainloop = new MainLoop();
		}

		public int run() {
			if(config.general_daemon) {
				var pid = Posix.fork();
				if(pid != 0) Posix.exit(0);
				Posix.setsid();
			}

			if(http_enabled) http_server.start();
			mainloop.run();
			return 0;
		}

		/* Http */
		private Http.Server? http_server;
		private bool http_enabled = false;

		public void enable_http() throws Error {
			http_enabled = true;
			http_server = new Http.Server(config.http_port, config.http_use_tls, config.http_tls_certificate, config.http_session_lifetime, config.http_session_max_lifetime);
		}

		public Http.Server? get_http_server() {
			if(http_enabled) return http_server;
			else return null;
		}
	}
}
