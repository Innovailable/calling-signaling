uuid = require('node-uuid')
{EventEmitter} = require('events')

type_check = (desc, obj) ->
  if typeof(desc) == 'string'
    return typeof(obj) == desc
  else
    for type in desc
      if type_check(type, obj)
        return true
    return false

msg_integrity = (types, msg) ->
  for id, type of types
    if not type_check(type, msg[id])
      if msg[id]?
        throw new Error("Type mismatch in message")
      else
        throw new Error("Missing element in message")

  for id of msg
    if not types[id]?
      throw new Error("Unexpected field in message")


class User extends EventEmitter

  constructor: (@id, @channel, @server) ->
    @channel.on 'message', (msg) =>
      @receive(msg)

    @channel.on 'closed', () =>
      @leave()

    @channel.on 'error', (error) =>
      try
        @channel.send({
          type: 'error'
          error: error
        })
      catch
      @channel.close()


  receive: (msg) ->
    error = (reason) =>
      @send({
        type: 'answer'
        tid: msg.tid
        error: reason
      })

    if not msg.tid?
      @send({
        type: 'error'
        error: 'Missing tid in message'
      })
      return

    if not msg.type?
      error("Missing type in message")
      return

    cmd = @server.commands[msg.type]

    if not cmd?
      error("Unknown command")
      return

    try
      res = cmd(@, msg)
    catch err
      error(err.message)
      return

    if res?
      @send({
        type: 'answer'
        tid: msg.tid
        data: res
      })
    else
      @send({
        type: 'answer'
        tid: msg.tid
      })


  send: (msg) ->
    @channel.send(msg)


  leave: () ->
    @emit('left')
    @channel.close()


class Server

  constructor: () ->
    @users = {}
    @commands = {}
    @inits = []


  command: (id, format, fun) ->
    # inject common message items

    format.type = 'string'
    format.tid = 'number'

    # wrap in message integrity test

    wrapped_fun = (user, msg) ->
      msg_integrity(format, msg)
      fun(user, msg)

    # add into command registry

    @commands[id] = wrapped_fun


  user_init: (fun) ->
    @inits.push(fun)


  create_user: (channel) ->
    id = uuid.v4()

    user = new User(id, channel, @)
    @users[id] = user

    user.on 'left', () =>
      delete @users[id]

    for init in @inits
      init(user)

    return user


exports.msg_integrity = msg_integrity
exports.Server = Server
exports.User = User
