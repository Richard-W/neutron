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

namespace Neutron {
	/**
	 * Controls the global values of the application
	 */
	public class Application : Object {
		/* General */
		private Configuration config;
		private MainLoop mainloop;

		private ThreadController? _thread_controller;
		/**
		 * Default thread controller of this application
		 */
		public ThreadController? thread_controller {
			get { return _thread_controller; }
		}

		/**
		 * Takes the argv and an alternative configfile, to instantiate the
		 * default Configuration-object
		 */
		public Application(string[] argv, string? configfile = null, MainLoop? custom_mainloop = null) throws Error {
			config = new Configuration(argv, configfile);

			if(custom_mainloop == null)
				mainloop = new MainLoop();
			else
				mainloop = custom_mainloop;

			if(config.general_worker_threads > 0)
				_thread_controller = new ThreadController(config.general_worker_threads);
			else
				_thread_controller = null;
		}

		/**
		 * This runs the GLib.MainLoop and daemonizes the process if it is specified in the config 
		 */
		public int run() {
			if(config.general_daemon) {
				var pid = Posix.fork();
				if(pid != 0) Posix.exit(0);
				Posix.setsid();
			}

			if(Posix.getuid() == 0) {
				if(config.general_gid != 0)
					Posix.setgid(config.general_gid);
				else
					Posix.setgid(Posix.getgrnam("nobody").gr_gid);

				if(config.general_uid != 0)
					Posix.setuid(config.general_uid);
				else
					Posix.setuid(Posix.getpwnam("nobody").pw_uid);
			}

			mainloop.run();
			return 0;
		}
	}
}
