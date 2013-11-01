public class Foo : Object, Neutron.Serializable {
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
}

void main() {
	Foo foo1 = new Foo();
	Foo foo2;
	
	foo1.bar = 5;
	foo1.baz = "Hello World!";
	foo1.bay = true;

	try {
		var serial = foo1.serialize();
		stdout.printf("Serial: %s\n\n", Base64.encode((uchar[]) serial));
		foo2 = new Foo();
		foo2.unserialize(serial);
	} catch(Error e) {
		stderr.printf("Caught error: %s\n", e.message);
		return;
	}
	stdout.printf("Bar: %d\nBaz: %s\n", foo2.bar, foo2.baz);
	if(foo2.bay)
		stdout.printf("Bay: true\n");
	else
		stdout.printf("Bay: false\n");
}