{get_cli_options} = require('./cli')

BIND_PORT = process.env.BIND_PORT ? 8080
BIND_HOST = process.env.BIND_HOST ? "0.0.0.0"

{CallingWebsocketServer} = require('./calling_server')

server = new CallingWebsocketServer(get_cli_options())

server.listen(BIND_PORT, BIND_HOST).then () ->
  console.log("Listening on " + BIND_HOST + ":" + BIND_PORT)
