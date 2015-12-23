{is_empty} = require('./helper')


class Registry

  constructor: (server) ->
    @namespaces = {}

    # TODO: verification of incoming package

    server.command 'register', {
      namespace: 'string'
    }, (user, msg) =>
      return @register(user, msg.namespace)

    server.command 'unregister', {
      namespace: 'string'
    }, (user, msg) =>
      return @unregister(user, msg.namespace)

    server.command 'subscribe', {
      namespace: 'string'
    }, (user, msg) =>
      return @subscribe(user, msg.namespace)

    server.command 'unsubscribe', {
      namespace: 'string'
    }, (user, msg) =>
      return @unsubscribe(user, msg.namespace)

    return


  get_namespace: (ns_id, create=false) ->
    namespace = @namespaces[ns_id]

    if not namespace?
      if create
        namespace = @namespaces[ns_id] = {
          subscribed: {}
          registered: {}
        }
      else
        throw new Error("Namespace does not exist")

    return namespace


  subscribe: (user, ns_id) ->
    # prepare cleanup

    # TODO: cleanup cleanup after unsubscribe?
    user.on 'left', () ->
      delete @namespaces[ns_id][user.id]

    # get namespace users

    namespace = @get_namespace(ns_id, true)
    users = namespace.subscribed

    # sanity check

    if users[user.id]?
      throw new Error("User was already subscribed to that namespace")

    # actually subscribe

    users[user.id] = user

    # return list of registered users

    users = {}

    for _, user_entry of namespace.registered
      user = user_entry.user
      users[user.id] = user.status

    return users



  unsubscribe: (user, ns_id) ->
    # get namespace users

    users = @get_namespace(ns_id).subscribed

    # sanity check

    if not users[user.id]?
      throw new Error("User was not subscribed to namespace")

    # actually remove user from namespace

    delete users[user.id]

    # clean up namespace if empty

    @empty_check_namespace(ns_id)

    return


  register: (user, ns_id) ->
    # get namespace

    namespace = @get_namespace(ns_id, true)
    register = namespace.registered

    # already registered?

    if register[user.id]?
      throw new Error("User was already registered to that namespace")

    # notify subscribers

    msg = {
      type: 'user_registered'
      user: user.id
      status: user.status
      namespace: ns_id
    }

    for _, user of namespace.subscribed
      user.send(msg)

    # register user callbacks

    status_change = () ->
      msg = {
        type: 'user_status'
        user: user.id
        namespace: ns_id
        status: user.status
      }

      for _, user of namespace.subscribed
        user.send(msg)

    left = () =>
      @unregister(user, ns_id)

    user.on('status_change', status_change)
    user.on('left', left)

    # register

    register[user.id] = {
      user: user
      cleanup: () ->
        user.removeListener('status_change', status_change)
        user.removeListener('left', left)
    }

    return


  unregister: (user, ns_id) ->
    # get namespace

    namespace = @get_namespace(ns_id)
    register = namespace.registered

    user_entry = register[user.id]

    if not user_entry?
      throw new Error("User was not registered to namespace")

    # tell subscribers

    msg = {
      type: 'user_left'
      user: user.id
      namespaces: ns_id
    }

    for _, user of namespace.subscribed
      user.send(msg)

    # unregister

    user_entry.cleanup()
    delete register[user.id]

    # clean up namespace if empty

    @empty_check_namespace(ns_id)

    return


  empty_check_namespace: (ns_id) ->
    # get namespace

    namespace = @namespaces[ns_id]

    # already cleaned up

    if not namespace?
      return

    # check if vacant

    if is_empty(namespace.subscribed) and is_empty(namespace.registered)
      delete @namespaces[ns_id]


exports.Registry = Registry
