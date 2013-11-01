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

public interface Neutron.Serializable : Object {
	private static Gee.HashMap<Type, SerializeFunctionContainer> serialize_functions;
	private static Gee.HashMap<Type, UnserializeFunctionContainer> unserialize_functions;
	private static bool type_maps_initialized = false;

	private static void init_type_maps() {
		if(type_maps_initialized) return;

		serialize_functions = new Gee.HashMap<Type, SerializeFunctionContainer>();
		unserialize_functions = new Gee.HashMap<Type, UnserializeFunctionContainer>();

		type_maps_initialized = true;

		register_property_type(typeof(string), serialize_string, unserialize_string);
		register_property_type(typeof(int), serialize_int, unserialize_int);
		register_property_type(typeof(bool), serialize_bool, unserialize_bool);
	}

	/**
	 * Serializes the properties of this object so it can be stored in a file.
	 */
	public uint8[] serialize() throws SerializeError {
		if(!type_maps_initialized) init_type_maps();
		var serial = new ByteArray();
		serial.append(serializable_get_class_identifier());

		var object_type = this.get_type();
		var class_name = (uint8[]) object_type.name().to_utf8();
		var class_name_len = new uint8[sizeof(int)];
		var intptr = &class_name.length;
		Memory.copy((void*) class_name_len, (void*) intptr, sizeof(int));

		serial.append(class_name_len);
		serial.append(class_name);

		var spec_list = this.get_class().list_properties();
		var excluded_properties = serializable_exclude_properties();

		foreach(ParamSpec spec in spec_list) {
			var specname = spec.get_name();
			var typename = spec.value_type.name();

			if(serializable_string_array_contains(excluded_properties, specname))
				continue;
			if(!serialize_functions.has_key(spec.value_type)) {
				throw new SerializeError.NOT_SERIALIZABLE("No serialize function defined for type %s\n".printf(typename));
			}

			uint8[] property_name = (uint8[]) specname.to_utf8();
			intptr = &property_name.length;
			uint8[] property_name_len = new uint8[sizeof(int)];
			Memory.copy((void*) property_name_len, (void*) intptr, sizeof(int));

			serial.append(property_name_len);
			serial.append(property_name);

			var type = (uint8[]) typename.to_utf8();
			var type_len = new uint8[sizeof(int)];
			intptr = &type.length;
			Memory.copy((void*) type_len, (void*) intptr, sizeof(int));

			serial.append(type_len);
			serial.append(type);

			var val = Value(spec.value_type);
			this.get_property(specname, ref val);

			var serialize_function = serialize_functions.get(spec.value_type);
			var data = serialize_function.func(val);
			intptr = &data.length;
			uint8[] data_len = new uint8[sizeof(int)];
			Memory.copy((void*) data_len, (void*) intptr, sizeof(int));

			serial.append(data_len);
			serial.append(data);
		}
		
		return serial.data;
	}
	
	/**
	 * Creates a new Serializable from a serial created with the serialize-method
	 */
	public void unserialize(uint8[] serial) throws SerializeError {
		if(!type_maps_initialized) init_type_maps();

		int current = 0;
		int len = 32;
		uint8[] class_ident = new uint8[32];

		for(int start = current; (current - start) < len && current < serial.length; current++) {
			class_ident[current-start] = serial[current];
		}

		uint8[] class_ident2 = this.serializable_get_class_identifier();
		for(int c = 0; c < 32; c++) {
			if(class_ident[c] != class_ident2[c])
				throw new SerializeError.NOT_UNSERIALIZABLE("Class identifiers do not match");
		}

		len = *((int*) ((char*) serial + current));
		current += (len+4);

		while(current < serial.length) {
			len = *((int*) ((char*) serial + current));
			var strb = new StringBuilder();
			current += 4;

			for(int start = current; (current - start) < len && current < serial.length; current++) {
				strb.append_c((char) serial[current]);
			}
			string property_name = strb.str;

			len = *((int*) ((char*) serial + current));
			strb = new StringBuilder();
			current += 4;

			for(int start = current; (current - start) < len && current < serial.length; current++) {
				strb.append_c((char) serial[current]);
			}
			string property_type_name = strb.str;
			var property_type = Type.from_name(property_type_name);

			len = *((int*) ((char*) serial + current));
			current += 4;
			uint8[] data = new uint8[len];
			for(int start = current; (current - start) < len && current < serial.length; current++) {
				data[current - start] = serial[current];
			}

			if(!unserialize_functions.has_key(property_type)) {
				throw new SerializeError.NOT_UNSERIALIZABLE("Unserialize-function not defined for property-type %s".printf(property_type_name));
			}

			var unserialize_function = unserialize_functions.get(property_type);

			Value val = unserialize_function.func(data);

			this.set_property(property_name, val);
		}
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
		string[]? optional_properties;

		object_type = this.get_type();
		spec_list = this.get_class().list_properties();
		property_list = new Gee.ArrayList<string>();
		identsumb = new Checksum(ChecksumType.SHA256);
		identsum_len = 32;
		excluded_properties = serializable_exclude_properties();
		optional_properties = serializable_optional_properties();

		foreach(ParamSpec spec in spec_list) {
			var specname = spec.get_name();
			if(serializable_string_array_contains(excluded_properties, specname))
				continue;
			if(serializable_string_array_contains(optional_properties, specname))
				continue;
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

	public virtual string[]? serializable_optional_properties() {
		return null;
	}

	public static void register_property_type(Type type, owned SerializeFunction serialize_func, owned UnserializeFunction unserialize_func) {
		if(!type_maps_initialized) init_type_maps();
		serialize_functions.set(type, new SerializeFunctionContainer((owned) serialize_func));
		unserialize_functions.set(type, new UnserializeFunctionContainer((owned) unserialize_func));
	}

	private static bool serializable_string_array_contains(string[]? arr, string str) {
		if(arr == null) return false;

		foreach(string str2 in arr) {
			if(str == str2)
				return true;
		}

		return false;
	}

	private class SerializeFunctionContainer {
		public SerializeFunction func;

		public SerializeFunctionContainer(owned SerializeFunction func) {
			this.func = (owned) func;
		}
	}

	private class UnserializeFunctionContainer {
		public UnserializeFunction func;

		public UnserializeFunctionContainer(owned UnserializeFunction func) {
			this.func = (owned) func;
		}
	}

	private static uint8[] serialize_string(Value val) {
		return (uint8[]) val.get_string().to_utf8();
	}

	private static Value unserialize_string(uint8[] serial) {
		Value val = Value(typeof(string));
		val.set_string((string) serial);

		return val;
	}

	private static uint8[] serialize_int(Value val) {
		var data = new uint8[sizeof(int)];
		var integer = val.get_int();
		int *intptr = &integer;

		Memory.copy((void*) data, (void*) intptr, sizeof(int));

		return data;
	}

	private static Value unserialize_int(uint8[] serial) {
		Value val = Value(typeof(int));
		int integer = 0;
		int *intptr = &integer;

		Memory.copy((void*) intptr, (void*) serial, sizeof(int));

		val.set_int(integer);

		return val;
	}

	private static uint8[] serialize_bool(Value val) {
		var data = new uint8[1];

		if(val.get_boolean())
			data[0] = 1;
		else
			data[0] = 0;

		return data;
	}

	private static Value unserialize_bool(uint8[] serial) {
		Value val = Value(typeof(bool));

		if(serial[0] == 1)
			val.set_boolean(true);
		else
			val.set_boolean(false);

		return val;
	}
}

public delegate uint8[] Neutron.SerializeFunction(Value val);
public delegate Value Neutron.UnserializeFunction(uint8[] serial);
