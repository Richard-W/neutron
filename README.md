Neutron
=======

A library for developing web-applications using the GObject-System.

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
		http.set_handler("/", page_hello_world);
	} catch(Error e) {
		stderr.printf("Caught error: %s\n", e.message);
		return 1;
	}

	return app.run();
}

void page_hello_world(Neutron.Http.Request req) {
	req.set_response_body("Hello World!");
	req.finish();
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

Well, the hello application is really simple and fits nicely into one function, but what if
you want to build bigger applications?

The RequestHandlerFunc (in the above case page_hello_world) is only a receiver. The library does not care
when the function returns. What matters is the finish-method. It MUST be called eventually (because if it
is not you got yourself a nice memory-leak), but you can do it whenever or whereever you want.

Also note that Neutron is single-threaded. This might change in the future, but until then you do not want
to use blocking operations. This is not really a problem though, because vala provides asynchronous methods
for almost everything that matters.
