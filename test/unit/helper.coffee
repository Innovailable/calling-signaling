{EventEmitter} = require('events')

class TestUser extends EventEmitter

  constructor: (@id) ->
    @sent = []
    @userdata = {}

  send: (msg) ->
    @sent.push(msg)
    return

  get_userdata: (obj={}) ->
    for key, value of @userdata
      obj[key] = value
    return obj

  set_userdata: (key, value) ->
    @userdata[key] = value
    @emit('userdata_changed', key, value)


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
    @user = new TestUser(id)

  get_userdata: (obj={}) ->
    if not obj.status?
      obj.status = {}
    for key, value of @status
      obj.status[key] = value
    return obj


module.exports = {
  TestUser: TestUser
  TestServer: TestServer
  TestRooms: TestRooms
  TestRoom: TestRoom
  TestPeer: TestPeer
}
