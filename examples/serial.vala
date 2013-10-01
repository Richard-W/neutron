public class Foo : Object, Neutron.EDB.Serializable {
	public int bar {
		get;
		set;
	}

	public string baz {
		get;
		set;
	}

	public bool bay {
		get;
		set;
	}

	public Bar foobar {
		get;
		set;
	}

	public string[]? serializable_exclude_properties() {
		return { "bar" };
	}
}

public class Bar : Object, Neutron.EDB.Serializable{
	public string foobar {
		get;
		set;
	}
}

void main() {
	Foo foo1 = new Foo();
	Foo foo2;
	
	foo1.bar = 5;
	foo1.baz = "Hello World!";
	foo1.bay = true;

	Bar bar = new Bar();
	bar.foobar = "Goodbye World!";

	foo1.foobar = bar;
	
	try {
		var serial = foo1.serialize();
		stdout.printf("Serial: %s\n\n", Base64.encode((uchar[]) serial));
		foo2 = (Foo) Neutron.EDB.Serializable.unserialize(serial);
	} catch(Error e) {
		stderr.printf("Caught error: %s\n", e.message);
		return;
	}
	stdout.printf("Bar: %d\nBaz: %s\n", foo2.bar, foo2.baz);
	if(foo2.bay)
		stdout.printf("Bay: true\n");
	else
		stdout.printf("Bay: false\n");
	stdout.printf("Foobar: %s\n", foo2.foobar.foobar);
}
