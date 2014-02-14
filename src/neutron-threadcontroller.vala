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
	 * Starts a certain number of thread and can be supplied with Source-object,
	 * which get executed in one of the threads.
	 */
	public class ThreadController : Object {
		private static Gee.ArrayList<ThreadController>? default_stack = null;
		/**
		 * The top element of the default-stack.
		 */
		public static ThreadController? default {
			owned get {
				if(default_stack == null || default_stack.is_empty) return null;
				return default_stack.last();
			}
		}

		public static ThreadController? pop_default() {
			var result = default;
			if(!default_stack.is_empty) {
				default_stack.remove_at(default_stack.size - 1);
			}
			return result;
		}

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

		/**
		 * Invoke a source in one of the worker-threads.
		 */
		public void invoke(Source isource) {
			isource.attach(thread_contexts[next]);
			next++;
			if(next >= num_threads) next = 0;
		}

		/**
		 * Sets this as the application default thread-controller.
		 */
		public void push_default() {
			if(default_stack == null) {
				default_stack = new Gee.ArrayList<ThreadController>();
			}
			default_stack.add(this);
		}
	}
}
