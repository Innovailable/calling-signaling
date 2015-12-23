hello_handler = (server, server_id) ->
  server.user_init (user) ->
    user.send({
      type: 'hello'
      id: user.id
      server: server_id
    })


exports.hello_handler = hello_handler

