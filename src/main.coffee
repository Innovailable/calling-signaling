BIND_PORT = process.env.BIND_PORT ? 8080
BIND_HOST = process.env.BIND_HOST ? "0.0.0.0"

{CallingWebsocketServer} = require('./calling_server')

server = new CallingWebsocketServer(BIND_PORT, BIND_HOST)

server.listen().then () ->
  console.log("Listening on " + BIND_HOST + ":" + BIND_PORT)
