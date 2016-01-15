EventEmitter = require('events').EventEmitter
{Promise} = require('bluebird')

###*
# A signaling channel using WebSockets. Wraps around `ws` WebSockets. Reference implementation of a channel.
# @class WebsocketChannel
# @extends events.EventEmitter
#
# @constructor
# @param {WebSocket} ws The websocket connection with the client
###
class exports.WebsocketChannel extends EventEmitter

  ###*
  # A message was received
  # @event message
  # @param {Object} data The decoded message
  ###

  ###*
  # The WebSocket was closed
  # @event closed
  ###

  ###*
  # An error occured with the WebSocket
  # @event error
  # @param {Error} error The error which occured
  ###

  constructor: (@ws) ->
    @ws.on 'message', (msg) =>
      try
        data = JSON.parse(msg)
        @emit('message', data)
      catch err
        @emit('error', "Error processing incoming message: " + err.message)

    @ws.on 'close', () =>
      @emit('closed')

  ###*
  # Send data to the client
  # @method send
  # @param {Object} data The message to be sent
  ###
  send: (data) ->
    msg = JSON.stringify(data)
    return Promise.promisify(@ws.send).call(@ws, msg)

  ###*
  # Close the connection to the client
  # @method close
  ###
  close: () ->
    return Promise.promisify(@ws.close).call(@ws)
