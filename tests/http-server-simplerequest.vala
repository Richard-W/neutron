using Neutron;

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
	if(req.path == "/") {
		cont.set_entity(new Http.StaticEntity("text/html", "teststring"));
	}
}

async int test() {
	try {
		var sock_addr = new InetSocketAddress(new InetAddress.from_string("127.0.0.1"), 8080);
		var client = new SocketClient();
		var conn = yield client.connect_async(sock_addr);

		var message = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
		yield conn.output_stream.write_async(message.data);

		var dis = new DataInputStream(conn.input_stream);

		string line;
		int count = 1;
		while((line = yield dis.read_line_async()) != null) {
			stdout.printf("%s\n", line);
			if(count == 1 && line != "HTTP/1.1 200 OK\r") return 1;

			if(line == "teststring\r") {
				conn.close();
				return 0;
			}

			count++;
		}
		
		return 1;
	}
	catch(Error e) {
		stderr.printf("%s\n", e.message);
		return 1;
	}
}
