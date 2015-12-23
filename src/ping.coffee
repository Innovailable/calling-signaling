ping_handler = (server) ->
  server.command 'ping', {}, (user, msg) ->
    return


exports.ping_handler = ping_handler
