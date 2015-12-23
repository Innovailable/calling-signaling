BIND_PORT = process.env.BIND_PORT ? 8080
BIND_HOST = process.env.BIND_HOST ? "0.0.0.0"

WebSocketServer = require('ws').Server
Server = require('./server').Server
WebsocketChannel = require('./websocket_channel').WebsocketChannel

# start doing stuff ...
server = new Server()

wss = new WebSocketServer({port: BIND_PORT, host: BIND_HOST})

console.log("Starting server on '" + BIND_HOST + ":" + BIND_PORT + "'")

wss.on 'connection', (ws) ->
  console.log("Accepting connection")
  channel = new WebsocketChannel(ws)
  hotel.create_user(channel)
