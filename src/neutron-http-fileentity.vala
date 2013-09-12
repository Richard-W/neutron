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

namespace Neutron.Http {
	/**
	 * Entity that is only able to supply a simple file from the filesystem.
	 *
	 * If you seek access-control this entity is not for you.
	 */
	public class FileEntity : Entity {
		private string mime_type;
		private string filename;

		public FileEntity(string mime_type, string filename) {
			this.mime_type = mime_type;
			this.filename = filename;
		}

		protected override async ConnectionAction handle_request() {
			try {
				var file = File.new_for_path(filename);
				if(!file.query_exists()) {
					yield send_status(500);
					yield end_headers();
					return ConnectionAction.CLOSE;
				}
				yield send_status(200);
				yield send_header("Content-Type", mime_type);

				//var info = yield file.query_info_async("*", FileQueryInfoFlags.NONE);
				//var size = info.get_size();

				yield end_headers();

				var fstream = yield file.read_async();

				ssize_t bytes_read;
				uint8[] buffer = new uint8[10240];
				
				while((bytes_read = yield fstream.read_async(buffer)) != 0) {
					buffer.length = (int) bytes_read;
					yield send_bytes(buffer);
					buffer = new uint8[10240];
				}

				yield end_body();
			} catch(Error e) {
				return ConnectionAction.CLOSE;
			}
			return ConnectionAction.KEEP_ALIVE;
		}
	}
}
