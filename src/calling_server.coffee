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
DEFAULT_TIMEOUT = 10*60*1000

class CallingServer extends Server

  constructor: (room_timeout=DEFAULT_TIMEOUT, server_id=SERVER_ID) ->
    super()

    hello_handler(@, server_id)
    status_handler(@)
    ping_handler(@)

    @rooms = new RoomManager(@, room_timeout)
    @registry = new Registry(@, @rooms)
    @invitations = new InvitationManager(@, @rooms)


class CallingWebsocketServer extends CallingServer

  constructor: (room_timeout=DEFAULT_TIMEOUT, server_id=SERVER_ID) ->
    super(room_timeout, server_id)


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
