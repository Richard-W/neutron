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

public interface Neutron.EDB.Serializable : Object {
	/**
	 * Serializes the properties of this object so it can be stored in a file.
	 */
	public uint8[] serialize() throws EDBError {
		ParamSpec[] spec_list;
		ByteArray serial;
		Type object_type;
		uint8[] class_name;
		uint8[] class_name_len;
		int *intptr;
		string[]? excluded_properties;

		serial = new ByteArray();
		object_type = this.get_type();
		excluded_properties = serializable_exclude_properties();

		class_name = (uint8[]) object_type.name().to_utf8();
		intptr = &class_name.length;
		class_name_len = new uint8[sizeof(int)];
		Memory.copy((void*) class_name_len, (void*) intptr, sizeof(int));
		
		serial.append(serializable_get_class_identifier());

		serial.append(class_name_len);
		serial.append(class_name);

		spec_list = this.get_class().list_properties();
		foreach(ParamSpec spec in spec_list) {
			var specname = spec.get_name();
			if(excluded_properties != null) {
				var cont = false;
				foreach(string excluded_property in excluded_properties) {
					if(specname == excluded_property) {
						cont = true;
						break;
					}
				}
				if(cont)
					continue;
			}

			Value val;
			uint8[] data;
			uint8[] type = new uint8[1];
			
			val = Value(spec.value_type);
			this.get_property(spec.get_name(), ref val);

			if(spec.value_type.is_a(typeof(string))) {
				data = (uint8[]) val.get_string().to_utf8();
				type[0] = 0;
			}
			else if(spec.value_type.is_a(typeof(int))) {
				var intval = val.get_int();
				var tmp = &intval;
				data = new uint8[sizeof(int)];
				Memory.copy((void*) data, tmp, sizeof(int));
				type[0] = 1;
			}
			else if(spec.value_type.is_a(typeof(uint))) {
				var uintval = val.get_uint();
				var tmp = &uintval;
				data = new uint8[sizeof(uint)];
				Memory.copy((void*) data, tmp, sizeof(uint));
				type[0] = 2;
			}
			else if(spec.value_type.is_a(typeof(bool))) {
				data = new uint8[1];
				type[0] = 3;
				if(val.get_boolean())
					data[0] = 1;
				else
					data[0] = 0;
			}
			else if(spec.value_type.is_a(typeof(Serializable))) {
				data = ((Serializable) val.get_object()).serialize();
				type[0] = 4;
			}
			else {
				throw new EDBError.NOT_SERIALIZABLE("Type %s is not supported".printf(spec.value_type.name()));
			}

			uint8[] property_name = (uint8[]) specname.to_utf8();
			intptr = &property_name.length;
			uint8[] property_name_len = new uint8[sizeof(int)];
			Memory.copy((void*) property_name_len, (void*) intptr, sizeof(int));

			intptr = &data.length;
			uint8[] datalen = new uint8[sizeof(int)];
			Memory.copy((void*) datalen, (void*) intptr, sizeof(int));

			serial.append(property_name_len);
			serial.append(property_name);

			serial.append(type);

			serial.append(datalen);
			serial.append(data);
		}
		
		return serial.data;
	}
	
	/**
	 * Creates a new Serializable from a serial created with the serialize-method
	 */
	public static Serializable unserialize(uint8[] serial) throws EDBError {
		int current = 0;
		int len = 32;
		uint8[] class_ident = new uint8[32];

		for(int start = current; (current - start) < len && current < serial.length; current++) {
			class_ident[current-start] = serial[current];
		}

		len = *((int*) ((char*) serial + current));
		current += 4;
		StringBuilder strb = new StringBuilder();
		for(int start = current; (current - start) < len && current < serial.length; current++) {
			strb.append_c((char) serial[current]);
		}

		string typename = strb.str;
		Serializable obj = (Serializable) Object.new(Type.from_name(typename));

		uint8[] class_ident2 = obj.serializable_get_class_identifier();

		for(int c = 0; c < 32; c++) {
			if(class_ident[c] != class_ident2[c])
				throw new EDBError.NOT_UNSERIALIZABLE("Class identifiers do not match");
		}

		while(current < serial.length) {
			Value val;

			len = *((int*) ((char*) serial + current));
			strb = new StringBuilder();
			current += 4;

			for(int start = current; (current - start) < len && current < serial.length; current++) {
				strb.append_c((char) serial[current]);
			}
			string property_name = strb.str;

			uint8 type = serial[current];
			current++;

			len = *((int*) ((char*) serial + current));
			current += 4;
			uint8[] data = new uint8[len];
			for(int start = current; (current - start) < len && current < serial.length; current++) {
				data[current - start] = serial[current];
			}

			switch(type) {
			case 0:
				val = Value(typeof(string));
				val.set_string((string) data);
				break;
			case 1:
				val = Value(typeof(int));
				val.set_int(*((int*) data));
				break;
			case 2:
				val = Value(typeof(uint));
				val.set_uint(*((uint*) data));
				break;
			case 3:
				val = Value(typeof(bool));
				if(data[0] == 1)
					val.set_boolean(true);
				else
					val.set_boolean(false);
				break;
			case 4:
				var inline_obj = unserialize(data);
				val = Value(typeof(Object));
				val.set_object(inline_obj);
				break;
			default:
				throw new EDBError.NOT_UNSERIALIZABLE("unknown type");
			}

			obj.set_property(property_name, val);
		}

		return obj;
	}

	/**
	 * Returns an identifier which is unique to the class which implements this interface
	 *
	 * The identifier depends on
	 * 	-Name of class
	 *	-Name of properties
	 *	-Type of properties
	 *
	 * This is used to ensure that a given serial is compatible with the running software
	 */
	public uint8[] serializable_get_class_identifier() {
		Type object_type;
		Gee.ArrayList<string> property_list;
		ParamSpec[] spec_list;
		uchar[] identstring;
		Checksum identsumb;
		uint8[] identsum;
		size_t identsum_len;
		string[]? excluded_properties;

		object_type = this.get_type();
		spec_list = this.get_class().list_properties();
		property_list = new Gee.ArrayList<string>();
		identsumb = new Checksum(ChecksumType.SHA256);
		identsum_len = 32;
		excluded_properties = serializable_exclude_properties();

		foreach(ParamSpec spec in spec_list) {
			var specname = spec.get_name();
			if(excluded_properties != null) {
				var cont = false;
				foreach(string excluded_property in excluded_properties) {
					if(specname == excluded_property) {
						cont = true;
						break;
					}
				}
				if(cont)
					continue;
			}
			property_list.add("%s:%s".printf(specname, spec.value_type.name()));
		}
		property_list.sort();

		var identstringb = new StringBuilder();
		identstringb.append("%s".printf(object_type.name()));
		foreach(string property in property_list) {
			identstringb.append(";%s".printf(property));
		}

		identstring = (uchar[]) identstringb.str.to_utf8();
		identsumb.update(identstring, identstring.length);
		identsum = new uint8[32];
		identsumb.get_digest(identsum, ref identsum_len);
		assert(identsum_len == 32);

		return identsum;
	}

	public virtual string[]? serializable_exclude_properties() {
		return null;
	}
}
