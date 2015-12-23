{EventEmitter} = require('events')
{is_empty} = require('./helper')
equal = require('deep-equal')


class RoomUser extends EventEmitter

  constructor: (@user, @peer_status, @pending=false) ->
    @active = true

    @leave_cb = () =>
      @emit('left')

    @user.on('left', @leave_cb)

    @status_cb = () =>
      @update_status()

    @user.on('status_changed', @status_cb)

    @update_status()

    return


  set_status: (status) ->
    @peer_status = status
    @update_status()


  update_status: () ->
    @status = {}

    for status in [@user.status, @peer_status]
      for key, id of status
        @status[key] = id

    @emit('status_changed', @status)


  destroy: () ->
    @active = false
    @user.removeListener('left', @leave_cb)
    @user.removeListener('status_changed', @status_cb)
    return


class Room extends EventEmitter

  constructor: (@id) ->
    @users = {}
    @status = {}

    return


  add_user: (user, status, pending) ->
    if @users[user.id]?
      throw new Error("User is already in room")

    room_user = new RoomUser(user, status, pending)

    room_user.on 'left', () =>
      @leave(user)

    room_user.on 'status_changed', () =>
      @broadcast({
        type: 'peer_status'
        room: @id
        user: user.id
        status: room_user.status
      })

    @broadcast({
      type: 'peer_joined'
      room: @id
      pending: pending
      user: user.id
      status: room_user.status
    })

    @users[user.id] = room_user

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

    promise.then (accepted) =>
      if not room_user.active
        return

      if accepted
        @broadcast({
          type: 'peer_accepted'
          room: @id
          user: user.id
        })

        room_user.pending = false
      else
        @leave(user)
    .catch () =>
      if room_user.active
        @leave(user)

    return


  peers_object: (exclude) ->
    peers = {}

    for user_id, user of @users
      if user_id == exclude
        continue

      peers[user_id] = {
        pending: user.pending
        status: user.status
      }

    return peers


  leave: (user) ->
    room_user = @users[user.id]

    if not room_user?
      throw new Error("User was not in room")

    room_user.destroy()
    delete @users[user.id]

    @broadcast({
      type: 'peer_left'
      room: @id
      user: user.id
    })

    if is_empty(@users)
      @emit('empty')

    return


  broadcast: (msg, exclude) ->
    for user_id, user of @users
      if user_id == exclude
        continue

      if user.pending
        continue

      user.user.send(msg)

    return


  message: (user, to_id, event, data) ->
    to_user = @users[to_id]

    if not to_user?
      throw new Error("Unknown recipient")

    if to_user.pending
      throw new Error("Recipient is pending")

    to_user.user.send({
      type: 'from'
      room: @id
      user: user.id
      event: event
      data: data
    })

    return


  room_status: (user, key, value, check, previous) ->
    if check and not equal(@status[key], previous)
      throw new Error("Status not in expected state")

    @status[key] = value

    @broadcast({
      type: 'room_status'
      room: @id
      status: @status
    }, user.id)

    return


  peer_status: (user, status) ->
    room_user = @users[user.id]

    if not user?
      throw new Error("User not in room")

    room_user.set_status(status)

    return


class RoomManager

  constructor: (server) ->
    @rooms = {}

    server.command 'join', {
      room: 'string'
      status: ['object', 'undefined']
    }, (user, msg) =>
      if msg.status?
        status = msg.status
      else
        status = {}

      room = @get_room(msg.room, true)
      return room.join(user, status)

    server.command 'leave', {
      room: 'string'
    }, (user, msg) =>
      room = @get_room(msg.room)
      return room.leave(user)

    server.command 'peer_status', {
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

    server.command 'to', {
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
          delete @rooms[room_id]
      else
        throw new Error("Room does not exist")

    return room


module.exports = {
  Room: Room
  RoomUser: RoomUser
  RoomManager: RoomManager
}
