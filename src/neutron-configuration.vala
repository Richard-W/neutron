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

using Gee;

/**
 * Easy access to values specified by the user of the application
 */
public class Neutron.Configuration : Object {
	public static Configuration? default {
		get;
		private set;
		default = null;
	}

	public static Configuration? pop_default() {
		var result = Configuration.default;
		Configuration.default = null;
		return result;
	}

	private HashMap<string, HashMap<string, string>> conf_map;

	public Configuration() {
		conf_map = new HashMap<string, HashMap<string, string>>();
	}

	public void push_default() {
		Configuration.default = this;
	}

	public new void set(string group, string key, string? val) {
		var _group = group.down();
		var _key = key.down();

		if(!conf_map.has_key(_group)) {
			conf_map.set(_group, new HashMap<string, string>());
		}

		var group_map = conf_map.get(_group);

		if(group_map.has_key(_key) && val == null) {
			group_map.unset(_key);
		}
		else {
			group_map.set(_key, val);
		}
	}

	public new string? get(string group, string key) {
		var _group = group.down();
		var _key = key.down();

		if(!conf_map.has_key(_group)) return null;

		var group_map = conf_map.get(_group);

		if(!group_map.has_key(_key)) return null;

		return group_map.get(_key);
	}

	public bool has(string group, string key) {
		var _group = group.down();
		var _key = key.down();

		if(!conf_map.has_key(_group)) return false;
		else if(!conf_map.get(_group).has_key(_key)) return false;
		else return true;
	}

	public virtual void load_file(string file) throws Error {
		var kf = new KeyFile();
		kf.load_from_file(file, KeyFileFlags.NONE);

		var groups = kf.get_groups();
		foreach(string group in groups) {
			var keys = kf.get_keys(group);
			foreach(string key in keys) {
				this.set(group, key, kf.get_string(group, key));
			}
		}
	}

	public bool get_bool(string group, string key, bool default_val = false) {
		var val = this.get(group, key);

		if(val == null)
			return default_val;

		val = val.down();

		if(val == "true" || val == "yes")
			return true;
		else if(val == "false" || val == "no")
			return false;
		else {
			message("Neutron.Configuration.get_bool: Expected true|yes|false|no, got %s for %s/%s".printf(val, group, key));
			return default_val;
		}
	}

	public int get_int(string group, string key, int default_val = 0) {
		var val = this.get(group, key);

		if(val == null)
			return default_val;

		return int.parse(val);
	}
}
