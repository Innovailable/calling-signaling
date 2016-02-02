{Server} = require('./server')
{status_handler} = require('./status')
{hello_handler} = require('./hello')
{ping_handler} = require('./ping')
{Registry} = require('./registry')
{RoomManager} = require('./rooms')
{InvitationManager} = require('./invitations')
{WebsocketChannel} = require('./websocket_channel')
{Promise} = require('bluebird')

WebSocketServer = require('ws').Server


SERVER_ID = 'calling-signaling 1.0'

class CallingServer extends Server

  constructor: () ->
    super()

    hello_handler(@, SERVER_ID)
    status_handler(@)
    ping_handler(@)

    @rooms = new RoomManager(@, 10 * 60 * 1000)
    @registry = new Registry(@, @rooms)
    @invitations = new InvitationManager(@, @rooms)


class CallingWebsocketServer extends CallingServer

  constructor: () ->
    super()


  listen: (port=8080, host='0.0.0.0') ->
    return new Promise (resolve, reject) =>
      @wss = new WebSocketServer({port: port, host: host}, resolve)

      @wss.on 'error', (err) ->
        reject(err)

      @wss.on 'connection', (ws) =>
        channel = new WebsocketChannel(ws)
        @create_user(channel)


  close: () ->
    @wss.close()


module.exports = {
  CallingServer: CallingServer
  CallingWebsocketServer: CallingWebsocketServer
}
