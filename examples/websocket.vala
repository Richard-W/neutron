/*
 * This file is part of the webcon project.
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

int main(string[] argv) {
	Neutron.Application app;
	Neutron.Http.Server http;

	try {
		app = new Neutron.Application(argv, "%s/examples/example.conf".printf(cmake_current_binary_dir));

		http = new Neutron.Http.Server();

		http.select_entity.connect(on_select_entity);
		http.start();
	} catch(Error e) {
		stderr.printf("Error: %s\n", e.message);
		return 1;
	}

	return app.run();
}

void on_select_entity(Neutron.Http.Request request, Neutron.Http.EntitySelectContainer container) {
	switch(request.path) {
	case "/":
		string protocol = null;
		if(Neutron.Configuration.default.http_use_tls)
			protocol = "wss";
		else
			protocol = "ws";

		container.set_entity(new Neutron.Http.StaticEntity("text/html", """
<!DOCTYPE html>
<html>
<head>
        <meta charset="utf-8" />
        <script src="https://code.jquery.com/jquery-2.0.3.min.js"></script>
        <style>
                .connected {
                        visibility: hidden;
                }
                .disconnected {
                        visibility: visible;
                }
        </style>
        <script>
                var socket;
                function ws_connect() {
                        socket = new WebSocket("%s://%s/socket");
                        socket.onopen = function() {
                                $(".disconnected").css("visibility", "hidden");
                                $(".connected").css("visibility", "visible");
                        }
                        socket.onclose = function() {
                                $(".disconnected").css("visibility", "visible");
                                $(".connected").css("visibility", "hidden");
                        }
                        socket.onerror = function() {
                                alert("ERROR!!!");
                                socket.close();
                        }
                        socket.onmessage = function(msg) {
                                alert(msg.data);
                        }
                }

                function ws_send() {
                        socket.send($("#input").val());
                }

                function ws_disconnect() {
                        socket.close();
                }
        </script>
</head>
<body>
        <h1>WS Test</h1>
        <button type="button" class="disconnected" onclick="ws_connect()">Connect</button><br />
        <button type="button" class="connected" onclick="ws_disconnect()">Disconnect</button><br />
        <input type="text" id="input" class="connected"><button type="button" class="connected" onclick="ws_send()">Send</button><br />
</body>
</html>
""".printf(protocol, request.get_header_var("host"))));
		break;
	case "/socket":
		var entity = new Neutron.Websocket.HttpUpgradeEntity();
		entity.incoming.connect(on_incoming_ws);
		container.set_entity(entity);
		break;
	}
}

void on_incoming_ws(Neutron.Websocket.Connection conn) {
	conn.ref();

	conn.on_message.connect(on_message);
	conn.on_close.connect(on_close);
	conn.start();
}

void on_message(string message, Neutron.Websocket.Connection conn) {
	conn.send.begin("Got line: %s".printf(message));
}

void on_close(Neutron.Websocket.Connection conn) {
	conn.unref();
}
