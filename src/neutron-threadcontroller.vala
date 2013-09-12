
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
	public class ThreadController : Object {
		private Thread<bool>[] threads;
		private MainContext[] thread_contexts;
		private MainLoop[] thread_loops;
		private int num_threads;
		private int next = 0;
		private int i;

		public ThreadController(int num_threads) {
			assert(num_threads > 0);
			this.num_threads = num_threads;

			threads = new Thread<bool>[num_threads];
			thread_contexts = new MainContext[num_threads];
			thread_loops = new MainLoop[num_threads];

			for(int i = 0; i < num_threads; i++) {
				this.i = i;
				var thread = new Thread<bool>(null, this.thread_function);
				threads[i] = thread;
			}
		}

		~ThreadController() {
			for(int i = 0; i < num_threads; i++) {
				thread_loops[i].quit();
				threads[i].join();
			}
		}

		private bool thread_function() {
			var context = new MainContext();
			context.push_thread_default();
			thread_contexts[i] = context;

			var loop = new MainLoop(context);
			thread_loops[i] = loop;
			loop.run();
			return true;
		}

		public void invoke(IdleSource isource) {
			isource.attach(thread_contexts[next]);
			next++;
			if(next >= num_threads) next = 0;
		}
	}
}
