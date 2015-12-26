{Server} = require('./server')
{status_handler} = require('./status')
{hello_handler} = require('./hello')
{ping_handler} = require('./ping')
{Registry} = require('./registry')
{RoomManager} = require('./rooms')
{InvitationManager} = require('./invitations')
{WebsocketChannel} = require('./websocket_channel')

WebSocketServer = require('ws').Server


SERVER_ID = 'calling-signaling 1.0'

class CallingServer extends Server

  constructor: () ->
    super()

    hello_handler(@, SERVER_ID)
    status_handler(@)
    ping_handler(@)

    @rooms = new RoomManager(@)
    @registry = new Registry(@, @rooms)
    @invitations = new InvitationManager(@, @rooms)


class CallingWebsocketServer extends CallingServer

  constructor: (port=8080, host='0.0.0.0') ->
    super()

    @wss = new WebSocketServer({port: port, host: host})

    @wss.on 'connection', (ws) =>
      channel = new WebsocketChannel(ws)
      @create_user(channel)


  close: () ->
    @wss.close()


module.exports = {
  CallingServer: CallingServer
  CallingWebsocketServer: CallingWebsocketServer
}
