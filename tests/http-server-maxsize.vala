using Neutron;

const string request_string = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";

int main() {
	var config = new Configuration();
	config.push_default();


	var http_server = new Http.Server();
	http_server.select_entity.connect(on_select_entity);
	http_server.request_max_size = request_string.length;
	http_server.port = 8080;

	var loop = new MainLoop();
	var retval1 = 1;
	
	test.begin(8080, (obj, res) => {
		retval1 = test.end(res);
		loop.quit();
	});

	loop.run();

	http_server = new Http.Server();
	http_server.select_entity.connect(on_select_entity);
	http_server.request_max_size = request_string.length - 1;
	http_server.port = 8081;

	loop = new MainLoop();
	var retval2 = 1;

	test.begin(8081, (obj, res) => {
		retval2 = test.end(res);
		if(retval2 == 1) retval2 = 0;
		else retval2 = 2;
		loop.quit();
	});

	loop.run();

	return retval1+retval2;
}

void on_select_entity(Http.Request req, Http.EntitySelectContainer cont) {
	if(req.path == "/") {
		cont.set_entity(new Http.StaticEntity("text/html", "teststring"));
	}
}

async int test(uint16 port) {
	try {
		var sock_addr = new InetSocketAddress(new InetAddress.from_string("127.0.0.1"), port);
		var client = new SocketClient();
		var conn = yield client.connect_async(sock_addr);

		yield conn.output_stream.write_async(request_string.data);

		var dis = new DataInputStream(conn.input_stream);

		string line;
		line = yield dis.read_line_async();
		stdout.printf("%s\n", line);

		if(line != "HTTP/1.1 200 OK\r") return 1;

		conn.close();

		return 0;
	}
	catch(Error e) {
		stderr.printf("%s\n", e.message);
		return 1;
	}
}
