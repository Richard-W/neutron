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
	public class Application : Object {
		private Configuration config;
		private HttpServer http_server;
		private MainLoop mainloop;

		public Application(string[] argv, string? configfile = null) throws Error {
			var config_from_argv = true;
			try {
				config = new Configuration.from_argv(argv);
			} catch(ConfigurationError.NO_CONFIGURATION e) { 
				config_from_argv = false;
			}

			if(!config_from_argv) {
				if(configfile == null) throw new ConfigurationError.NO_CONFIGURATION("Hardcoded configuration-file is null and no arguments given to select another");
				config = new Configuration.from_file(configfile);
			}

			http_server = new HttpServer(config.http_port, config.http_use_tls, config.http_tls_certificate);

			mainloop = new MainLoop();
		}

		public void set_handler(string path, RequestHandlerFunc handler) {
			http_server.set_handler(path, handler);
		}

		public int run() {
			if(config.general_daemon) {
				var pid = Posix.fork();
				if(pid != 0) Posix.exit(0);
				Posix.setsid();
			}

			http_server.start();
			mainloop.run();
			return 0;
		}
	}
}
