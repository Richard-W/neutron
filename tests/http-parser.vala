using Neutron;

class Globals {
	public static Http.Request request;
}

int main() {
	try {
		var config = new Configuration();
		config.push_default();

		config.set("http", "port", "8080");

		var http_server = new Http.Server();
		http_server.select_entity.connect(on_select_entity);
		http_server.start();

		var loop = new MainLoop();
		var retval = 1;
		
		test.begin((obj, res) => {
			retval = test.end(res);
			loop.quit();
		});

		loop.run();

		return retval;
	}
	catch(Error e) {
		stderr.printf("%s\n", e.message);
		return 1;
	}
}

void on_select_entity(Http.Request req, Http.EntitySelectContainer cont) {
	Globals.request = req;
}

async int test() {
	try {
		var sock_addr = new InetSocketAddress(new InetAddress.from_string("127.0.0.1"), 8080);
		var client = new SocketClient();
		var conn = yield client.connect_async(sock_addr);
		var dis = new DataInputStream(conn.input_stream);

		string message = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n";
		stdout.printf(message);
		yield conn.output_stream.write_async(message.data);
		int retval = yield read_response(dis);
		if(retval != 0) return 1;

		var req = Globals.request;
		if(req.path != "/") return 1;
		if(req.method != "GET") return 1;
		if(req.uses_tls) return 1;
		if(req.get_header_var("host") != "localhost") return 1;
		if(req.get_header_var("connection") != "keep-alive") return 1;
		if(req.get_request_vars() != null) return 1;
		if(req.get_post_vars() != null) return 1;
		if(!conn.is_connected()) return 1;

		conn.close();

		return 0;
	}
	catch(Error e) {
		stderr.printf("%s\n", e.message);
		return 1;
	}
}

async int read_response(DataInputStream dis) {
	var cancel = new Cancellable();
	stdout.printf("---- Response start ----\n");
	try {
		var timeout_thread = new Thread<void*>(null, () => {
			Thread.usleep(200000);
			cancel.cancel();
			return null;
		});
		while(true) {
			var line = yield dis.read_line_async(Priority.DEFAULT, cancel);
			stdout.printf("%s\n", line);
		}
	}
	catch(IOError.CANCELLED e) {
		stdout.printf("\n---- Response end ----\n");
		return 0;
	}
	catch(Error e) {
		return 1;
	}
}
