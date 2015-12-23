{EventEmitter} = require('events')

class TestUser extends EventEmitter

  constructor: (@id) ->
    @sent = []
    @status = {}

  send: (msg) ->
    @sent.push(msg)
    return


class TestServer

  constructor: () ->
    @commands = {}
    @inits = []
    @users = {}

  add_user: (user) ->
    @users[user.id] = user

    for init in @inits
      init(user)

  user_init: (fun) ->
    @inits.push(fun)

  command: (id, format, fun) ->
    @commands[id] = fun
    return

  trigger: (user, msg) ->
    return @commands[msg.type](user, msg)

  get_user: (id) ->
    return @users[id]


module.exports = {
  TestUser: TestUser
  TestServer: TestServer
}
