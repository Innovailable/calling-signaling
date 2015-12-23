status_handler = (server) ->
  server.user_init (user) ->
    user.status = {}

  server.command 'status', {
    status: 'object'
  }, (user, msg) ->
    user.status = msg.status
    user.emit('status_changed', user.status)


exports.status_handler = status_handler

