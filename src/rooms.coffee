{EventEmitter} = require('events')
{is_empty} = require('./helper')
equal = require('deep-equal')
uuid = require('node-uuid')

class RoomUser extends EventEmitter

  constructor: (@user, @peer_status, @pending=false) ->
    @active = true

    @leave_cb = () =>
      @emit('left')

    @user.on('left', @leave_cb)

    @userdata_cb = (key, value) =>
      if key == 'status'
        @emit('userdata_changed', 'status', @merged_status())
      else
        @emit('userdata_changed', key, value)

    @user.on('userdata_changed', @userdata_cb)

    return


  accept: () ->
    @pending = false
    @emit('accepted')


  merged_status: () ->
    res = {}

    for status in [@user.userdata.status, @peer_status]
      for key, value of status
        res[key] = value

    return res


  set_status: (status) ->
    @peer_status = status
    @emit('userdata_changed', 'status', @merged_status())


  get_userdata: (obj={}) ->
    @user.get_userdata(obj)
    obj.status = @merged_status()
    return obj


  destroy: () ->
    @active = false
    @user.removeListener('left', @leave_cb)
    @user.removeListener('userdata_changed', @userdata_cb)
    return


class Room extends EventEmitter

  constructor: (@id) ->
    @peers = {}
    @status = {}

    return


  user_check: (user) ->
    room_user = @peers[user.id]

    if not room_user?
      throw new Error("You are not in the room")

    if room_user.pending
      throw new Error("You are only invited to the room")

    return room_user


  add_user: (user, status, pending) ->
    if @peers[user.id]?
      throw new Error("User is already in room")

    room_user = new RoomUser(user, status, pending)

    room_user.on 'left', () =>
      @remove(room_user)

    room_user.on 'userdata_changed', (key, value) =>
      msg = {
        type: 'room_peer_update'
        room: @id
        user: user.id
      }

      room_user.get_userdata(msg)

      @broadcast(msg, user.id)

    msg = {
      type: 'room_peer_add'
      room: @id
      pending: pending
      user: user.id
    }

    room_user.get_userdata(msg)

    @broadcast(msg, user.id)

    @peers[user.id] = room_user

    @emit('new_peer', room_user)

    return room_user


  join: (user, status={}) ->
    @add_user(user, status, false)

    return {
      room: @id
      peers: @peers_object(user.id)
      status: @status
    }


  invite: (user, promise) ->
    room_user = @add_user(user, {}, true)

    promise.then (status) =>
      if not room_user.active
        return

      if status?
        @broadcast({
          type: 'room_peer_update'
          room: @id
          user: user.id
          pending: false
        }, user.id)

        room_user.set_status(status)
        room_user.accept()

      else
        @remove(room_user)

    .catch () =>
      if room_user.active
        @remove(room_user)

    return


  peers_object: (exclude) ->
    peers = {}

    for user_id, peer of @peers
      if user_id == exclude
        continue

      peers[user_id] = {
        pending: peer.pending
      }

      peer.get_userdata(peers[user_id])

    return peers


  leave: (user) ->
    room_user = @user_check(user)
    @remove(room_user)


  remove: (room_user) ->
    user_id = room_user.user.id

    room_user.destroy()
    delete @peers[user_id]

    @broadcast({
      type: 'room_peer_rm'
      room: @id
      user: user_id
    })

    if is_empty(@peers)
      @emit('empty')

    return


  broadcast: (msg, exclude) ->
    for user_id, user of @peers
      if user_id == exclude
        continue

      user.user.send(msg)

    return


  message: (user, to_id, event, data) ->
    @user_check(user)

    to_user = @peers[to_id]

    if not to_user?
      throw new Error("Unknown recipient")

    if to_user.pending
      throw new Error("Recipient is pending")

    to_user.user.send({
      type: 'room_peer_from'
      room: @id
      user: user.id
      event: event
      data: data
    })

    return


  room_status: (user, key, value, check, previous) ->
    @user_check(user)

    if check and not equal(@status[key], previous)
      throw new Error("Status not in expected state")

    @status[key] = value

    @broadcast({
      type: 'room_update'
      room: @id
      status: @status
    }, user.id)

    return


  peer_status: (user, status) ->
    room_user = @user_check(user)

    room_user.set_status(status)

    return


class RoomManager

  constructor: (server, @rm_delay=0) ->
    @rooms = {}

    server.command 'room_join', {
      room: ['string', 'undefined']
      status: ['object', 'undefined']
    }, (user, msg) =>
      if msg.room?
        room = msg.room
      else
        room = uuid.v4()

      if msg.status?
        status = msg.status
      else
        status = {}

      room = @get_room(room, true)
      return room.join(user, status)

    server.command 'room_leave', {
      room: 'string'
    }, (user, msg) =>
      room = @get_room(msg.room)
      return room.leave(user)

    server.command 'room_peer_status', {
      room: 'string'
      status: 'object'
    }, (user, msg) =>
      room = @get_room(msg.room)
      return room.peer_status(user, msg.status)

    server.command 'room_status', {
      room: 'string'
      key: 'string'
      value: ['string', 'number', 'boolean', 'undefined', 'null', 'object']
      check: ['boolean', 'undefined']
      previous: ['string', 'number', 'boolean', 'undefined', 'null', 'object']
    }, (user, msg) =>
      room = @get_room(msg.room)
      return room.room_status(user, msg.key, msg.value, msg.check, msg.previous)

    server.command 'room_peer_to', {
      room: 'string'
      user: 'string'
      event: 'string'
      data: 'object'
    }, (user, msg) =>
      room = @get_room(msg.room)
      return room.message(user, msg.user, msg.event, msg.data)

    return


  get_room: (room_id, create=false) ->
    room = @rooms[room_id]

    if not room?
      if create
        room = @rooms[room_id] = new Room(room_id)

        room.on 'empty', () =>
          rm_room = () =>
            delete @rooms[room_id]

          if @rm_delay <= 0
            rm_room()
          else
            timeout = setTimeout(rm_room, @rm_delay)
            room.once 'new_peer', () ->
              clearTimeout(timeout)
      else
        throw new Error("Room does not exist")

    return room


module.exports = {
  Room: Room
  RoomUser: RoomUser
  RoomManager: RoomManager
}
