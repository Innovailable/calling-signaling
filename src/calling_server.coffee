{Server} = require('./server')
{status_handler} = require('./status')
{hello_handler} = require('./hello')
{ping_handler} = require('./ping')
{Registry} = require('./registry')
{RoomManager} = require('./rooms')
{InvitationManager} = require('./invitations')
{WebsocketChannel} = require('./websocket_channel')
{WebsocketHeartbeat} = require('./websocket_heartbeat')
{Promise} = require('bluebird')

WebSocketServer = require('ws').Server


SERVER_ID = 'calling-signaling 1.0'

default_options = {
  hello: true
  status: true
  ping: true
  rooms: true
  registry: true
  invitations: true
}

resolve_option = (sub_config, key, dfl) ->
  if sub_config == null or typeof sub_config != 'object'
    return dfl

  return sub_config[key] ? dfl

class CallingServer extends Server

  constructor: (user_options) ->
    super()

    options = Object.assign({}, default_options, user_options)

    if options.hello
      server_id = resolve_option(options.hello, 'server_id', SERVER_ID)
      hello_handler(@, server_id)

    if options.status
      status_handler(@)

    if options.ping
      ping_handler(@)

    if options.rooms
      timeout = resolve_option(options.rooms, 'timeout', 10*60*1000)
      @rooms = new RoomManager(@, timeout)

    if options.registry
      @registry = new Registry(@, @rooms)

    if options.invitations
      if not @rooms?
        throw new Error("'invitations' cannot be used without 'rooms'")

      @invitations = new InvitationManager(@, @rooms)


class CallingWebsocketServer extends CallingServer

  constructor: (user_options) ->
    super(user_options)


  listen: (port=8080, host='0.0.0.0') ->
    return new Promise (resolve, reject) =>
      @wss = new WebSocketServer({port: port, host: host}, resolve)

      @wss.on 'error', (err) ->
        reject(err)

      @wss.on 'connection', (ws) =>
        channel = new WebsocketChannel(ws)
        new WebsocketHeartbeat(ws)
        @create_user(channel)


  close: () ->
    @wss.close()


module.exports = {
  CallingServer: CallingServer
  CallingWebsocketServer: CallingWebsocketServer
}
