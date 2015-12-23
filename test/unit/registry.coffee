{TestUser, TestServer} = require('./helper')

{Registry} = require('../../src/registry')

describe 'Registry', () ->
  server = null
  registry = null

  user_a = null
  user_b = null
  user_c = null

  ns_msg = (user, type, ns='a') ->
    server.trigger(user, {
      type: type
      namespace: ns
    })

  beforeEach () ->
    server = new TestServer()
    registry = new Registry(server)

    user_a = new TestUser('a')
    user_b = new TestUser('b')
    user_c = new TestUser('c')


  it 'should not allow subscribing twice on same namespace', () ->
    subscribe = () ->
      ns_msg(user_a, 'subscribe')

    subscribe()
    expect(subscribe).to.throw("User was already subscribed to that namespace")


  it 'should not allow registering twice on same namespace', () ->
    register = () ->
      ns_msg(user_a, 'register')

    register()
    expect(register).to.throw("User was already registered to that namespace")


  it 'should not allow to unregister without registering', () ->
    expect(() -> ns_msg(user_a, 'unregister')).to.throw()


  it 'should not allow to unsubscribe without subscribing', () ->
    expect(() -> ns_msg(user_a, 'unsubscribe')).to.throw()


  it 'should give subscriber previously registered user', () ->
    ns_msg(user_a, 'register')
    res = ns_msg(user_b, 'subscribe')

    res.should.deep.equal({a: {}})


  it 'should notify subscriber of new registered user', () ->
    res = ns_msg(user_a, 'subscribe')
    res.should.deep.equal({})

    ns_msg(user_b, 'register')

    msg = user_a.sent[0]
    msg.type.should.equal("user_registered")
    msg.user.should.equal("b")


  it 'should notify subscribed user of unregistering user', () ->
    ns_msg(user_b, 'register')

    res = ns_msg(user_a, 'subscribe')
    res.should.deep.equal({b: {}})

    ns_msg(user_b, 'unregister')

    msg = user_a.sent[0]
    msg.type.should.equal("user_left")
    msg.user.should.equal("b")


  it 'should notify subscribed user of leaving user', () ->
    ns_msg(user_b, 'register')

    res = ns_msg(user_a, 'subscribe')
    res.should.deep.equal({b: {}})

    user_b.emit('left')

    msg = user_a.sent[0]
    msg.type.should.deep.equal('user_left')
    msg.user.should.deep.equal('b')


  it 'should not send message after unsubscribing', () ->
    ns_msg(user_a, 'subscribe')
    ns_msg(user_a, 'unsubscribe')

    ns_msg(user_b, 'register')

    user_a.sent.length.should.equal(0)


  it 'should not have unregistered user in registered list', () ->
    ns_msg(user_a, 'register')
    ns_msg(user_a, 'unregister')

    res = ns_msg(user_b, 'subscribe')

    res.should.deep.equal({})


  it 'should clean up after last unsubscribe', () ->
    ns_msg(user_a, 'subscribe')
    ns_msg(user_a, 'unsubscribe')

    registry.namespaces.should.deep.equal({})


  it 'should clean up after last unregister', () ->
    ns_msg(user_a, 'register')
    ns_msg(user_a, 'unregister')

    registry.namespaces.should.deep.equal({})


  it 'should notify of status changes', () ->
    status = {name: 'test'}

    ns_msg(user_a, 'register')
    ns_msg(user_b, 'subscribe')

    user_a.status = status
    user_a.emit('status_change')

    msg = user_b.sent[0]
    msg.type.should.equal("user_status")
    msg.user.should.equal('a')
    msg.status.should.deep.equal(status)

