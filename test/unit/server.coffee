{Server, User, msg_integrity} = require('../../src/server')
{EventEmitter} = require('events')
{Promise} = require('bluebird')


class TestChannel extends EventEmitter

  constructor: () ->
    @sent = []

  receive: (msg) ->
    @emit('message', msg)

  send: (msg) ->
    @sent.push(msg)


describe 'Server', () ->

  channel = null
  server = null

  beforeEach () ->
    channel = new TestChannel()
    server = new Server()

  describe 'Server', () ->

    it 'should register multiple inits', () ->
      init_a = () ->
      init_b = () ->

      server.user_init(init_a)
      server.user_init(init_b)

      server.inits.should.deep.equal([init_a, init_b])


    it 'should run all inits on new users', () ->
      a = new Promise (resolve) ->
        server.user_init(resolve)

      b = new Promise (resolve) ->
        server.user_init(resolve)

      user = server.create_user(channel)

      return Promise.all([a, b]).then (users) ->
        for i in users
          i.should.equal(user)


    it 'should register multiple commands', () ->
      server.command('a', {}, () ->)
      server.command('b', {}, () ->)

      server.commands.should.have.keys('a', 'b')


    it 'should remove users after they left', () ->
      user = server.create_user(channel)

      server.users.should.have.key(user.id)

      user.emit('left')

      server.users.should.be.empty


  describe 'User', () ->

    test_user = null

    beforeEach () ->
      test_user = server.create_user(channel)

    it 'should run registered command', () ->
      return new Promise (resolve) ->
        test_msg = {
          type: 'test'
          tid: 0
        }

        server.command 'test', {}, (user, msg) ->
          user.should.equal(test_user)
          msg.should.equal(msg)
          resolve()

        channel.receive(test_msg)


    it 'should reject messages not conforming to format', () ->
      return new Promise (resolve, reject) ->
        test_msg = {
          type: 'test'
          tid: 0
        }

        server.command 'test', {a: 'string'}, (user, msg) ->
          reject()

        channel.receive(test_msg)

        setTimeout () ->
          channel.sent[0].should.deep.equal({
            type: 'answer'
            tid: 0
            error: 'Missing element in message'
          })
          resolve()
        , 10


    it 'should reject messages without type', () ->
      channel.receive({tid: 0})

      channel.sent[0].should.deep.equal({
        type: 'answer'
        tid: 0
        error: 'Missing type in message'
      })


    it 'should reject messages without tid', () ->
      channel.receive({})

      channel.sent[0].should.deep.equal({
        type: 'error'
        error: 'Missing tid in message'
      })


    it 'should reject messages with unknown command', () ->
      channel.receive({type: 'a', tid: 0})

      channel.sent[0].should.deep.equal({
        type: 'answer'
        tid: 0
        error: 'Unknown command'
      })


    it 'should emit `left` when channel closes', () ->
      return new Promise (resolve) ->
        test_user.on('left', resolve)

        channel.emit('closed')


    it 'should send with `send()`', () ->
      msg = {type: 'test'}

      channel.sent.should.be.empty
      test_user.send(msg)
      channel.sent.should.deep.equal([msg])


    it 'should answer on messages without payload', () ->
      server.command('test', {}, () ->)

      channel.receive({type: 'test', tid: 42})
      channel.sent.should.deep.equal([{type: 'answer', tid: 42}])


    it 'should answer on messages with payload', () ->
      server.command('test', {}, () -> 23)

      channel.receive({type: 'test', tid: 42})
      channel.sent.should.deep.equal([{type: 'answer', tid: 42, data: 23}])


    it 'should send exception message in answer error', () ->
      error_msg = 'Some error occured'

      server.command('test', {}, () -> throw new Error(error_msg))
      channel.receive({type: 'test', tid: 0})

      channel.sent.should.deep.equal([{
        type: 'answer'
        tid: 0
        error: error_msg
      }])


  describe 'msg_integrity', () ->

    it 'should let through valid messages', () ->
      msg_integrity({
        a: 'number'
        b: 'string'
        c: 'object'
      },{
        a: 1
        b: 'hello'
        c: {}
      })


    it 'should reject missing fields', () ->
      expect(() -> msg_integrity({
        a: 'number'
      },{
      })).to.throw("Missing element in message")


    it 'should reject wrong types', () ->
      expect(() -> msg_integrity({
        a: 'number'
      },{
        a: 'test'
      })).to.throw("Type mismatch in message")


    it 'should reject unknown fields', () ->
      expect(() -> msg_integrity({
      },{
        a: 'test'
      })).to.throw("Unexpected field in message")


    it 'should verify with multiple types', () ->
      desc = {
        a: ['number', 'string']
      }

      msg_integrity(desc, {
        a: 1
      })

      msg_integrity(desc, {
        a: 'test'
      })

      expect(() -> msg_integrity(desc,{
        a: true
      })).to.throw("Type mismatch in message")


    it 'should allow undefined type', () ->
      msg_integrity({
        a: 'undefined'
      }, {})
