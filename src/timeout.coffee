class TimeoutHandler

  constructor: (@user, @time) ->
    @reset_cb = () =>
      @reset()

    @user.on('received', @reset_cb)

    @user.once 'left', () =>
      clearTimeout(@timeout)
      delete @timeout
      @user.removeListener('received', @reset_cb)

    @reset()

  reset: () ->
    console.log('resetting timeout')

    if @timeout
      clearTimeout(@timeout)

    @timeout = setTimeout () =>
      console.log('timeout triggered')
      @user.leave()
    , @time

timeout_handler = (server) ->
  server.command 'remote_timeout', {time: 'number'}, (user, msg) ->
    handler = new TimeoutHandler(user, msg.time)
    return


exports.timeout_handler = timeout_handler
