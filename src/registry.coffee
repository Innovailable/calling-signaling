{is_empty} = require('./helper')
{EventEmitter} = require('events')


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

    user.on('left', left_cb)

    # actually subscribe

    @subscribed[user.id] = {
      user: user
      cleanup: () ->
        user.removeListener('left', left_cb)
    }

    # return list of registered users

    users = {}

    for _, entry of @registered
      user = entry.user
      users[user.id] = user.status

    return users


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


  register: (user) ->
    # already registered?

    if @registered[user.id]?
      throw new Error("User was already registered to that namespace")

    # notify subscribers

    @broadcast({
      type: 'user_registered'
      user: user.id
      status: user.status
      namespace: @id
    })

    # register user callbacks

    status_change = () =>
      @broadcast({
        type: 'user_status'
        user: user.id
        namespace: @id
        status: user.status
      })

    left = () =>
      @unregister(user)

    user.on('status_change', status_change)
    user.on('left', left)

    # register

    @registered[user.id] = {
      user: user
      cleanup: () ->
        user.removeListener('status_change', status_change)
        user.removeListener('left', left)
    }

    return


  unregister: (user) ->

    entry = @registered[user.id]

    if not entry?
      throw new Error("User was not registered to namespace")

    # tell subscribers

    @broadcast({
      type: 'user_left'
      user: user.id
      namespaces: @id
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

    # notify subscribers

    @broadcast({
      type: 'room_registered'
      room: room.id
      status: room.status
      namespace: @id
    })

    # register callbacks

    empty_cb = () =>
      @unregister(room)

    status_cb = (status) ->
      @broadcast({
        type: 'room_status'
        room: room.id
      })

    room.on('empty', empty_cb)
    room.on('status_changed', status_cb)

    # add to room list

    @rooms[room.id] = {
      room: room
      cleanup: () ->
        room.removeListener('empty', empty_cb)
        room.removeListnere('status_changed', status_cb)
    }

    return


  unregister_room: (room) ->

    entry = @rooms[room.id]

    if not entry?
      throw new Error("Room was not registered to namespace")

    # tell subscribers

    @broadcast({
      type: 'room_closed'
      room: room.id
      namespaces: @id
    })

    # unregister

    entry.cleanup()
    delete @rooms[user.id]

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

    server.command 'register', {
      namespace: 'string'
    }, (user, msg) =>
      return @get_namespace(msg.namespace, true).register(user)

    server.command 'unregister', {
      namespace: 'string'
    }, (user, msg) =>
      return @get_namespace(msg.namespace, false).unregister(user)

    server.command 'register_room', {
      namespace: 'string'
      room: 'room'
    }, (user, msg) =>
      namespace = @get_namespace(msg.namespace, true)
      room = @rooms.get_room(msg.room)
      return namespace.register_room(room)

    server.command 'unregister_room', {
      namespace: 'string'
    }, (user, msg) =>
      namespace = @get_namespace(msg.namespace, false)
      room = @rooms.get_room(msg.room)
      return namespace.unregister_room(room)

    server.command 'subscribe', {
      namespace: 'string'
    }, (user, msg) =>
      return @get_namespace(msg.namespace, true).subscribe(user)

    server.command 'unsubscribe', {
      namespace: 'string'
    }, (user, msg) =>
      return @get_namespace(msg.namespace, false).unsubscribe(user)

    return


  get_namespace: (ns_id, create=false) ->
    namespace = @namespaces[ns_id]

    if not namespace?
      if create
        namespace = @namespaces[ns_id] = new Namespace()

        namespace.on 'empty', () =>
          delete @namespaces[ns_id]
      else
        throw new Error("Namespace does not exist")

    return namespace


exports.Registry = Registry
