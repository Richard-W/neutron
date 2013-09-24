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

/**
 * Serves just a simple string. Useful for static html-sites.
 *
 * Comparison to FileEntity: Pro: Uses RAM, Con: Uses RAM.
 *
 * Seriously... this is intended for small html-files, that are
 * always the same for everyone. Do not uses this for anything
 * with more than 1-2 kB
 */
public class Neutron.Http.StaticEntity : Entity {
	private string mime_type;
	private string content;

	public StaticEntity(string mime_type, string content) {
		this.mime_type = mime_type;
		this.content = content;
	}

	protected override async ConnectionAction handle_request() {
		try {
			yield send_status(200);
			yield send_header("Content-Type", mime_type);
			yield end_headers();
			yield send(content);
			yield end_body();
		} catch(Error e) {
			return ConnectionAction.CLOSE;
		}
		return ConnectionAction.KEEP_ALIVE;
	}
}

