using Neutron;

class TestSession : Session {
	public string? some_value {
		get;
		set;
		default = null;
	}
}

class TestEntity : Http.Entity {
	public override async Http.ConnectionAction handle_request() {
		try {
			yield send_status(200);

			if(request.session == null) {
				var test_session = new TestSession();
				test_session.some_value="teststring";
				yield set_session(test_session);
			}

			yield end_headers();

			if(request.session == null) yield send("dummy");
			else yield send(((TestSession)request.session).some_value);

			yield end_body();

			return Http.ConnectionAction.CLOSE;
		} catch(Error e) {
			return Http.ConnectionAction.CLOSE;
		}
	}
}

int main() {
	var config = new Configuration();
	config.push_default();

	var http_server = new Http.Server();
	http_server.select_entity.connect(on_select_entity);
	http_server.session_lifetime = 1;
	http_server.session_max_lifetime = 2000;
	http_server.port = 8080;
	if(http_server.port == 0) {
		return 1;
	}

	var loop = new MainLoop();
	var retval = 1;
	
	test.begin(http_server, (obj, res) => {
		retval = test.end(res);
		loop.quit();
	});

	loop.run();

	return retval;
}

void on_select_entity(Http.Request req, Http.EntitySelectContainer cont) {
	if(req.path == "/") {
		cont.set_entity(new TestEntity());
	}
}

async int test(Http.Server server) {
	try {
		var sock_addr = new InetSocketAddress(new InetAddress.from_string("127.0.0.1"), 8080);
		var client = new SocketClient();
		var conn = yield client.connect_async(sock_addr);

		var message = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
		stdout.printf(message);
		yield conn.output_stream.write_async(message.data);

		var dis = new DataInputStream(conn.input_stream);

		string line;
		bool failed = true;
		string session_id = "";
		stdout.printf("------- Response 1 -------\n");
		while((line = yield dis.read_line_async()) != null) {
			stdout.printf("%s\n", line);
			var line_arr = line.split(":", 2);
			if(line_arr.length == 2) {
				var key = line_arr[0].strip().down();
				var val = line_arr[1].strip();

				if(key == "set-cookie") {
					var sc_arr = val.split(";");
					var cookie = sc_arr[0].strip();

					var cookie_arr = cookie.split("=", 2);
					if(cookie_arr.length == 2 && cookie_arr[0].strip() == "neutron_session_id") {
						session_id = cookie_arr[1].strip();
						failed = false;
						break;
					}
				}
			}
		}
		stdout.printf("------- End Response 1 -------\n");

		conn.close();

		if(failed) return 1;
		stdout.printf("\n\n");
		
		var session_delete_time = new DateTime.now_local();
		session_delete_time = session_delete_time.add_seconds(2);
		while(session_delete_time.compare(new DateTime.now_local()) >= 0) {
			Idle.add(test.callback);
			yield;
		}

		conn = yield client.connect_async(sock_addr);
		dis = new DataInputStream(conn.input_stream);

		message = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nCookie: neutron_session_id=%s\r\n\r\n".printf(session_id);
		stdout.printf(message);
		yield conn.output_stream.write_async(message.data);

		failed = false;
		stdout.printf("------- Response 2 -------\n");
		while((line = yield dis.read_line_async()) != null) {
			stdout.printf("%s\n", line);
			if(line == "teststring\r") failed = true;
		}
		stdout.printf("------- End Response 2 -------\n");
	
		conn.close();
		if(failed) return 1;

		server.session_lifetime = 2;
		server.session_max_lifetime = 3;

		message = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
		stdout.printf(message);
		conn = yield client.connect_async(sock_addr);
		yield conn.output_stream.write_async(message.data);

		dis = new DataInputStream(conn.input_stream);

		failed = true;
		session_id = "";
		stdout.printf("------- Response 3 -------\n");
		while((line = yield dis.read_line_async()) != null) {
			stdout.printf("%s\n", line);
			var line_arr = line.split(":", 2);
			if(line_arr.length == 2) {
				var key = line_arr[0].strip().down();
				var val = line_arr[1].strip();

				if(key == "set-cookie") {
					var sc_arr = val.split(";");
					var cookie = sc_arr[0].strip();

					var cookie_arr = cookie.split("=", 2);
					if(cookie_arr.length == 2 && cookie_arr[0].strip() == "neutron_session_id") {
						session_id = cookie_arr[1].strip();
						failed = false;
						break;
					}
				}
			}
		}
		stdout.printf("------- End Response 3 -------\n");

		if(failed) return 1;
		stdout.printf("\n\n");

		conn.close();

		session_delete_time = new DateTime.now_local();
		session_delete_time = session_delete_time.add_seconds(2);
		while(session_delete_time.compare(new DateTime.now_local()) >= 0) {
			Idle.add(test.callback);
			yield;
		}

		conn = yield client.connect_async(sock_addr);
		dis = new DataInputStream(conn.input_stream);

		message = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nCookie: neutron_session_id=%s\r\n\r\n".printf(session_id);
		stdout.printf(message);
		yield conn.output_stream.write_async(message.data);

		failed = true;
		stdout.printf("------- Response 4 -------\n");
		while((line = yield dis.read_line_async()) != null) {
			stdout.printf("%s\n", line);
			if(line == "teststring\r") failed = false;
		}
		stdout.printf("------- End Response 4 -------\n");
	
		if(failed) return 1;
		
		session_delete_time = new DateTime.now_local();
		session_delete_time = session_delete_time.add_seconds(2);
		while(session_delete_time.compare(new DateTime.now_local()) >= 0) {
			Idle.add(test.callback);
			yield;
		}

		conn = yield client.connect_async(sock_addr);
		dis = new DataInputStream(conn.input_stream);

		message = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nCookie: neutron_session_id=%s\r\n\r\n".printf(session_id);
		stdout.printf(message);
		yield conn.output_stream.write_async(message.data);

		failed = false;
		stdout.printf("------- Response 5 -------\n");
		while((line = yield dis.read_line_async()) != null) {
			stdout.printf("%s\n", line);
			if(line == "teststring\r") failed = true;
		}
		stdout.printf("------- End Response 5 -------\n");
	
		if(failed) return 1;
		else return 0;

	}
	catch(Error e) {
		stderr.printf("%s\n", e.message);
		return 1;
	}
}
