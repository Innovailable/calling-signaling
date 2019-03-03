class ServerPingHandler

  constructor: (@user, @time) ->
    @reset_cb = () =>
      @reset()

    @user.on('sent', @reset_cb)
    @user.on('received', @reset_cb)

    @user.once 'left', () =>
      clearTimeout(@timeout)
      delete @timeout
      @user.removeListener('sent', @reset_cb)
      @user.removeListener('received', @reset_cb)

    @reset()

  reset: () ->
    if @timeout
      clearTimeout(@timeout)

    @timeout = setTimeout () =>
      @ping()
      @reset()
    , @time

  ping: () ->
    @user.send({type: 'ping'})

ping_handler = (server) ->
  server.command 'ping', {}, (user, msg) ->
    return

  server.command 'remote_ping', {time: 'number'}, (user, msg) ->
    handler = new ServerPingHandler(user, msg.time)
    return


exports.ping_handler = ping_handler
