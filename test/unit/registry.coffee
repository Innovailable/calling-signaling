{TestUser, TestServer, TestRooms} = require('./helper')

{Registry} = require('../../src/registry')

describe 'Registry', () ->
  server = null
  registry = null
  rooms = null

  user_a = null
  user_b = null
  user_c = null

  ns_msg = (user, type, ns='a') ->
    server.trigger(user, {
      type: type
      namespace: ns
    })

  room_msg = (user, type, ns='a', room_id='r') ->
    server.trigger(user, {
      type: type
      room: room_id
      namespace: ns
    })

  beforeEach () ->
    server = new TestServer()
    rooms = new TestRooms()
    registry = new Registry(server, rooms)

    user_a = new TestUser('a')
    user_b = new TestUser('b')
    user_c = new TestUser('c')


  describe 'Sanity checks', () ->

    it 'should not allow subscribing twice on same namespace', () ->
      subscribe = () ->
        ns_msg(user_a, 'ns_subscribe')

      subscribe()
      expect(subscribe).to.throw("User was already subscribed to that namespace")


    it 'should not allow registering twice on same namespace', () ->
      register = () ->
        ns_msg(user_a, 'ns_user_register')

      register()
      expect(register).to.throw("User was already registered to that namespace")


    it 'should not allow registering room twice on same namespace', () ->
      register = () ->
        room_msg(user_a, 'ns_room_register')

      register()
      expect(register).to.throw("Room was already registered to that namespace")


    it 'should not allow to unregister without registering', () ->
      ns_msg(user_b, 'ns_subscribe')
      expect(() -> ns_msg(user_a, 'ns_user_unregister')).to.throw("User was not registered to namespace")


    it 'should not allow to unsubscribe without subscribing', () ->
      ns_msg(user_b, 'ns_subscribe')
      expect(() -> ns_msg(user_a, 'ns_unsubscribe')).to.throw("User was not subscribed to namespace")


    it 'should not allow unregistering room without registering', () ->
      ns_msg(user_b, 'ns_subscribe')
      expect(() -> ns_msg(user_a, 'ns_room_unregister')).to.throw("Room was not registered to namespace")


  describe 'Notifications', () ->

    it 'should give subscriber previously registered user', () ->
      ns_msg(user_a, 'ns_user_register')
      res = ns_msg(user_b, 'ns_subscribe')

      res.should.deep.equal({a: {}})


    it 'should notify subscriber of new registered user', () ->
      res = ns_msg(user_a, 'ns_subscribe')
      res.should.deep.equal({})

      ns_msg(user_b, 'ns_user_register')

      msg = user_a.sent[0]
      msg.type.should.equal("ns_user_add")
      msg.user.should.equal("b")


    it 'should notify subscribed user of unregistering user', () ->
      ns_msg(user_b, 'ns_user_register')

      res = ns_msg(user_a, 'ns_subscribe')
      res.should.deep.equal({b: {}})

      ns_msg(user_b, 'ns_user_unregister')

      msg = user_a.sent[0]
      msg.type.should.equal("ns_user_rm")
      msg.user.should.equal("b")


    it 'should notify subscribed user of leaving user', () ->
      ns_msg(user_b, 'ns_user_register')

      res = ns_msg(user_a, 'ns_subscribe')
      res.should.deep.equal({b: {}})

      user_b.emit('left')

      msg = user_a.sent[0]
      msg.type.should.deep.equal('ns_user_rm')
      msg.user.should.deep.equal('b')


    it 'should not send message after unsubscribing', () ->
      ns_msg(user_a, 'ns_subscribe')
      ns_msg(user_a, 'ns_unsubscribe')

      ns_msg(user_b, 'ns_user_register')

      user_a.sent.length.should.equal(0)


    it 'should not have unregistered user in registered list', () ->
      ns_msg(user_a, 'ns_user_register')
      ns_msg(user_a, 'ns_user_unregister')

      res = ns_msg(user_b, 'ns_subscribe')

      res.should.deep.equal({})


  describe 'Cleanup', () ->

    it 'should clean up after last unsubscribe', () ->
      ns_msg(user_a, 'ns_subscribe')
      ns_msg(user_a, 'ns_unsubscribe')

      registry.namespaces.should.deep.equal({})


    it 'should clean up after last unregister', () ->
      ns_msg(user_a, 'ns_user_register')
      ns_msg(user_a, 'ns_user_unregister')

      registry.namespaces.should.deep.equal({})


    it 'should notify of status changes', () ->
      status = {name: 'test'}

      ns_msg(user_a, 'ns_user_register')
      ns_msg(user_b, 'ns_subscribe')

      user_a.status = status
      user_a.emit('status_change')

      msg = user_b.sent[0]
      msg.type.should.equal("ns_user_update")
      msg.user.should.equal('a')
      msg.status.should.deep.equal(status)

