status_handler = (server) ->
  server.user_init (user) ->
    user.set_userdata('status', {})

  server.command 'status', {
    status: 'object'
  }, (user, msg) ->
    user.set_userdata('status', msg.status)


exports.status_handler = status_handler

