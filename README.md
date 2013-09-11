Neutron
=======

A library for developing web-applications using the GObject-System.

Installation instructions
-------------------------

<dl>
<dt>Debian</dt>
<dd>
Inside the source-directory:
```bash
./configure --prefix=/usr --enable-debian
make
make package
```
Now you have a .deb-file, which you can install using "dpkg -i"
Currently the package compiled on debian segfaults, when worker_threads
is set to a number greater than 0. This seems to be a bug in valac-0.16.
</dd>
<dt>Arch</dt>
<dd>
If you did not do it already install yaourt. Instructions for installing yaourt
can be found here: https://wiki.archlinux.de/title/Yaourt.
Now you can just install the package "neutron-git" from AUR.
</dd>
<dt>Ubuntu</dt>
<dd>
Just like Debian. Note that i have not tested anything on Ubuntu.
</dd>

Usage
-----

We'll start with a simple hello-world-application.

hello.vala:
```vala
int main(string[] argv) {
	Neutron.Application app;
	try {
		app = new Neutron.Application(argv);

		//Enable the http-server
		app.enable_http();

		var http = app.get_http_server();
		http.select_entity.connect(on_select_entity);
	} catch(Error e) {
		stderr.printf("Caught error: %s\n", e.message);
		return 1;
	}

	return app.run();
}

void on_select_entity(Neutron.Http.Request request, Neutron.Http.EntitySelectContainer container) {
	switch(request.path) {
	case "/":
		container.set_entity(new Neutron.Http.StaticEntity("text/html", """
		<!DOCTYPE html>
		<html>
		<head>
			<meta charset="utf-8" />
		</head>
		<body>
			<h1>Hello World!</h1>
		</body>
		</html>
		"""));
		break;
	}
}
//Compile with "valac hello.vala --pkg neutron" if you installed the library
```

Well... where is the port-number and all the other stuff? If you run the program without
any changes now it will just bind to port 80 and use unencrypted http.

If you want to use your own settings just create a file named hello.conf:
```
[Http]
port = 8080
```
and start the above example with
    ./hello -c hello.conf

Note: If you really want to hardcode your settings just instantiate a Neutron.Http.Server-Object manually
and enter a GLib.MainLoop.

Now the application binds to port 8080. It is also possible to use TLS and other stuff.
See examples/example.conf in the repository. Note that you also can hardcode a config-file
in your application by giving the constructor of the Application class it's second argument.
The -c option will still be first choice.

Also note, that the user of your application can set worker_threads in the config-file to a value > 0 which
will distribute the execution over several threads. You still need to use asynchronous operations because every
thread is able to handle several connections. Also i strongly advise you to use the AsyncQueue-class to share
data between requests.
