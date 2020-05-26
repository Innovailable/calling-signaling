{EventEmitter} = require('events')
{is_empty} = require('./helper')
equal = require('deep-equal')
{ v4: uuidv4 } = require('uuid')

class RoomUser extends EventEmitter

  constructor: (@user, @peer_status, @pending=false) ->
    super()

    @active = true

    @leave_cb = () =>
      @emit('left')

    @user.on('left', @leave_cb)

    @status_cb = () =>
      @update_status()

    @user.on('status_changed', @status_cb)

    @update_status()

    return


  accept: () ->
    @pending = false
    @emit('accepted')


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
    super()

    @peers = {}
    @status = {}

    return


  close: () ->
    @emit('closed')


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

    room_user.on 'status_changed', () =>
      @broadcast({
        type: 'room_peer_update'
        room: @id
        user: user.id
        status: room_user.status
      }, user.id)

    @broadcast({
      type: 'room_peer_add'
      room: @id
      pending: pending
      user: user.id
      status: room_user.status
    }, user.id)

    @peers[user.id] = room_user

    @emit('new_peer', room_user)
    @emit('peers_changed', @peers)

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

    for user_id, user of @peers
      if user_id == exclude
        continue

      peers[user_id] = {
        pending: user.pending
        status: user.status
      }

    return peers


  leave: (user) ->
    room_user = @user_check(user)
    @remove(room_user)


  remove: (room_user) ->
    user_id = room_user.user.id

    room_user.destroy()
    delete @peers[user_id]

    @emit('peers_changed', @peers)

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


class RoomManager extends EventEmitter

  constructor: (server, @rm_delay=0) ->
    super()

    @rooms = {}

    server.command 'room_join', {
      room: ['string', 'undefined']
      status: ['object', 'undefined']
    }, (user, msg) =>
      if msg.room?
        room = msg.room
      else
        room = uuidv4()

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

        @emit('new_room', room)
        @emit('rooms_changed', @rooms)

        room.on 'empty', () =>
          rm_room = () =>
            @rooms[room_id].close()
            delete @rooms[room_id]
            @emit('rooms_changed', @rooms)

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
