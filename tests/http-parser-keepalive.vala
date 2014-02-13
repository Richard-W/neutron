using Neutron;

class Globals {
	public static Http.Request request;
}

int main() {
	var http_server = new Http.Server();
	http_server.select_entity.connect(on_select_entity);
	http_server.port = 8080;

	var loop = new MainLoop();
	var retval = 1;
	test.begin((obj, res) => {
		retval = test.end(res);
		loop.quit();
	});
	loop.run();
	return retval;
}

void on_select_entity(Http.Request req, Http.EntitySelectContainer cont) {
	Globals.request = req;
	cont.set_entity(new Http.StaticEntity("text/html", "empty"));
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
		if(req.method != "GET") return 2;
		if(req.get_header_var("host") != "localhost") return 4;
		if(req.get_header_var("connection") != "keep-alive") return 5;
		if(req.get_request_vars() != null) return 6;
		if(req.get_post_vars() != null) return 7;

		message = "POST /?key=value HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\nContent-Length: 19\r\n\r\nkey1=val1&key2=val2\r\n";
		stdout.printf(message);
		yield conn.output_stream.write_async(message.data);
		retval = yield read_response(dis);
		if(retval != 0) return 1;

		req = Globals.request;
		if(req.path != "/") return 1;
		if(req.method != "POST") return 2;
		if(req.get_header_var("host") != "localhost") return 4;
		if(req.get_header_var("connection") != "keep-alive") return 5;
		if(req.get_request_var("key") != "value") return 6;
		if(req.get_post_var("key1") != "val1") return 7;
		if(req.get_post_var("key2") != "val2") return 8;

		message = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
		stdout.printf(message);
		yield conn.output_stream.write_async(message.data);
		retval = yield read_response(dis);
		if(retval != 0) return 1;

		req = Globals.request;
		if(req.path != "/") return 1;
		if(req.method != "GET") return 2;
		if(req.get_header_var("host") != "localhost") return 4;
		if(req.get_header_var("connection") != "close") return 5;
		if(req.get_request_vars() != null) return 6;
		if(req.get_post_vars() != null) return 7;

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
	Thread<void*> timeout_thread;
	stdout.printf("---- Response start ----\n");
	try {
		timeout_thread = new Thread<void*>(null, () => {
			Thread.usleep(200000);
			cancel.cancel();
			return null;
		});
		while(true) {
			var line = yield dis.read_line_async(Priority.DEFAULT, cancel);
			if(line != null) stdout.printf("%s\n", line);
			else break;
		}
	}
	catch(IOError.CANCELLED e) {
		stdout.printf("\n---- Response end ----\n");
		timeout_thread.join();
		return 0;
	}
	catch(Error e) {
		timeout_thread.join();
		return 1;
	}
	timeout_thread.join();
	return 0;
}
