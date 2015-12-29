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


class TestRoom extends EventEmitter

  constructor: (@id, @status={}) ->
    @peers = {}

  invite: (user, promise) ->
    @peers[user.id] = promise
    return

  add_peer: (user_id, status={}, pending=false) ->
    return @peers[user_id] = new TestPeer(user_id, status, pending)

  peers_object: () ->
    return {}


class TestRooms

  constructor: () ->
    @rooms = {}

  get_room: (id) ->
    room = @rooms[id]

    if not room?
      room = @rooms[id] = new TestRoom(id)

    return room


class TestPeer extends EventEmitter

  constructor: (id, @status={}, @pending=false) ->
    @user = {
      id: id
    }


module.exports = {
  TestUser: TestUser
  TestServer: TestServer
  TestRooms: TestRooms
  TestRoom: TestRoom
  TestPeer: TestPeer
}
