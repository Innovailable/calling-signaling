{is_empty} = require('./helper')
{EventEmitter} = require('events')


class NamespaceRoom extends EventEmitter

  constructor: (room, namespace) ->
    # initialization

    @room = room
    @namespace = namespace

    # peer callbacks

    ns_room = @

    @peer_left_cb = () ->
      namespace.broadcast({
        type: 'ns_room_peer_rm'
        namespace: namespace.id
        room: room.id
        user: @user.id
      })

      ns_room.peer_cleanup(@)

    @peer_status_cb = (status) ->
      namespace.broadcast({
        type: 'ns_room_peer_update'
        namespace: namespace.id
        room: room.id
        user: @user.id
        status: @status
      })

    @peer_accept_cb = () ->
      namespace.broadcast({
        type: 'ns_room_peer_update'
        namespace: namespace.id
        room: room.id
        user: @user.id
        pending: false
      })

    # add current users

    for _, peer of @room.peers
      @peer_setup(peer)

    # register callbacks

    @empty_cb = () =>
      @emit('empty')

    @status_cb = () =>
      @namespace.broadcast({
        type: 'ns_room_update'
        namespace: @namespace.id
        room: @room.id
        status: @room.status
      })

    @peer_cb = (peer) =>
      @namespace.broadcast({
        type: 'ns_room_peer_add'
        namespace: @namespace.id
        room: @room.id
        user: peer.user.id
        status: peer.status
        pending: peer.pending
      })

      @peer_setup(peer)

    @room.on('empty', @empty_cb)
    @room.on('status_changed', @status_cb)
    @room.on('new_peer', @peer_cb)

    # announce room

    @namespace.broadcast({
      type: 'ns_room_add'
      namespace: @namespace.id
      room: @room.id
      status: @room.status
      peers: @peer_description()
    })

    return


  peer_setup: (peer) ->
    peer.on('left', @peer_left_cb)
    peer.on('status_changed', @peer_status_cb)
    peer.on('accepted', @peer_accept_cb)


  peer_cleanup: (peer) ->
    peer.removeListener('left', @peer_left_cb)
    peer.removeListener('status_changed', @peer_status_cb)
    peer.removeListener('accepted', @peer_accept_cb)


  unregister: () ->
    # tell subscribers

    @namespace.broadcast({
      type: 'ns_room_rm'
      room: @room.id
      namespace: @namespace.id
    })

    # cleanup

    @room.removeListener('empty', @empty_cb)
    @room.removeListener('status_changed', @status_cb)
    @room.removeListener('new_peer', @peer_cb)

    for _, peer of @room.peers
      @peer_cleanup(peer)

    return


  peer_description: () ->
    res = {}

    for peer_id, peer of @room.peers
      res[peer_id] = {
        status: peer.status
        pending: peer.pending
      }

    return res


  description: () ->
    return {
      status: @room.status
      peers: @peer_description()
    }


class Namespace extends EventEmitter

  constructor: (@id) ->
    @subscribed = {}
    @registered = {}
    @rooms = {}


  broadcast: (msg) ->
    for _, entry of @subscribed
      entry.user.send(msg)


  subscribe: (user) ->
    # sanity check

    if @subscribed[user.id]?
      throw new Error("User was already subscribed to that namespace")

    # cleanup on leaving

    left_cb = () =>
      @unsubscribe(user)

    user.once('left', left_cb)

    # actually subscribe

    @subscribed[user.id] = {
      user: user
      cleanup: () ->
        user.removeListener('left', left_cb)
    }

    # list of registered users

    users = {}

    for user_id, entry of @registered
      cur = entry.user
      users[user_id] = cur.status

    # list of registered rooms

    rooms = {}

    for room_id, room of @rooms
      rooms[room_id] = room.description()

    # return answer

    return {
      users: users
      rooms: rooms
    }


  unsubscribe: (user) ->
    entry = @subscribed[user.id]

    # sanity check

    if not entry?
      throw new Error("User was not subscribed to namespace")

    # do cleanup

    entry.cleanup()

    # actually remove user from namespace

    delete @subscribed[user.id]

    # clean up namespace if empty

    @empty_check()

    return


  register_user: (user) ->
    # already registered?

    if @registered[user.id]?
      throw new Error("User was already registered to that namespace")

    # notify subscribers

    @broadcast({
      type: 'ns_user_add'
      user: user.id
      status: user.status
      namespace: @id
    })

    # register user callbacks

    status_change = () =>
      @broadcast({
        type: 'ns_user_update'
        user: user.id
        namespace: @id
        status: user.status
      })

    left = () =>
      @unregister_user(user)

    user.on('status_changed', status_change)
    user.once('left', left)

    # register

    @registered[user.id] = {
      user: user
      cleanup: () ->
        user.removeListener('status_changed', status_change)
        user.removeListener('left', left)
    }

    return


  unregister_user: (user) ->

    entry = @registered[user.id]

    if not entry?
      throw new Error("User was not registered to namespace")

    # tell subscribers

    @broadcast({
      type: 'ns_user_rm'
      user: user.id
      namespace: @id
    })

    # unregister

    entry.cleanup()
    delete @registered[user.id]

    # clean up namespace if empty

    @empty_check()

    return


  register_room: (room) ->
    # already registered

    if @rooms[room.id]?
      throw new Error("Room was already registered to that namespace")

    # create room

    ns_room = new NamespaceRoom(room, @)
    @rooms[room.id] = ns_room

    # unregister when empty

    ns_room.on 'empty', () =>
      @unregister_room(room)

    return


  unregister_room: (room) ->

    ns_room = @rooms[room.id]

    if not ns_room?
      throw new Error("Room was not registered to namespace")

    # tell subscribers

    # unregister

    ns_room.unregister()
    delete @rooms[room.id]

    # clean up namespace if empty

    @empty_check()

    return


  empty_check: () ->
    if is_empty(@subscribed) and is_empty(@registered) and is_empty(@rooms)
      @emit('empty')


class Registry

  constructor: (server, @rooms) ->
    @namespaces = {}

    # TODO: verification of incoming package

    server.command 'ns_user_register', {
      namespace: 'string'
    }, (user, msg) =>
      return @get_namespace(msg.namespace, true).register_user(user)

    server.command 'ns_user_unregister', {
      namespace: 'string'
    }, (user, msg) =>
      return @get_namespace(msg.namespace, false).unregister_user(user)

    server.command 'ns_room_register', {
      namespace: 'string'
      room: 'string'
    }, (user, msg) =>
      namespace = @get_namespace(msg.namespace, true)
      room = @rooms.get_room(msg.room)
      return namespace.register_room(room)

    server.command 'ns_room_unregister', {
      namespace: 'string'
      room: 'string'
    }, (user, msg) =>
      namespace = @get_namespace(msg.namespace, false)
      room = @rooms.get_room(msg.room)
      return namespace.unregister_room(room)

    server.command 'ns_subscribe', {
      namespace: 'string'
    }, (user, msg) =>
      return @get_namespace(msg.namespace, true).subscribe(user)

    server.command 'ns_unsubscribe', {
      namespace: 'string'
    }, (user, msg) =>
      return @get_namespace(msg.namespace, false).unsubscribe(user)

    return


  get_namespace: (ns_id, create=false) ->
    namespace = @namespaces[ns_id]

    if not namespace?
      if create
        namespace = @namespaces[ns_id] = new Namespace(ns_id)

        namespace.on 'empty', () =>
          delete @namespaces[ns_id]
      else
        throw new Error("Namespace does not exist")

    return namespace


module.exports = {
  Registry: Registry
  Namespace: Namespace
  NamespaceRoom: NamespaceRoom
}
