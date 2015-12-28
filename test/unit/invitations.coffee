{TestUser, TestServer, TestRooms} = require('./helper')
{InvitationManager} = require('../../src/invitations')
{EventEmitter} = require('events')


describe 'Invitations', () ->
  user_a = null
  user_b = null
  user_c = null

  server = null
  rooms = null
  invites = null

  beforeEach () ->
    server = new TestServer()
    rooms = new TestRooms()
    invites = new InvitationManager(server, rooms)

    user_a = new TestUser('a')
    user_b = new TestUser('b')
    user_c = new TestUser('c')

    server.add_user(user_a)
    server.add_user(user_b)
    server.add_user(user_c)


  it 'should initialize `invites` on users', () ->
    user_a.invites.should.not.be.undefined


  it 'should give different handles for each invitation', () ->
    res = invites.invite(user_a, 'b', 'r1', {})
    first_handle = res.handle
    first_handle.should.be.a('number')

    res = invites.invite(user_a, 'b', 'r2', {})
    second_handle = res.handle
    second_handle.should.be.a('number')

    first_handle.should.not.equal(second_handle)


  it 'should clean up invitation after resolving', () ->
    res = invites.invite(user_a, 'b', 'r1', {})
    handle = res.handle

    user_a.invites.out.should.not.be.empty
    user_b.invites.in.should.not.be.empty

    invites.cancel(user_a, handle)

    user_a.invites.out.should.be.empty
    user_b.invites.in.should.be.empty


  it 'should tell recipient that it is invited', () ->
    invites.invite(user_a, 'b', 'r', {})

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')
    msg.user.should.equal('a')
    msg.status.should.deep.equal({})
    msg.data.should.deep.equal({})


  it 'should be able to cancel invitation', () ->
    res = invites.invite(user_a, 'b', 'r', {})

    a_handle = res.handle

    invites.cancel(user_a, a_handle)

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')
    b_handle = msg.handle

    msg = user_b.sent[1]
    msg.type.should.equal('invite_cancelled')
    msg.handle.should.equal(b_handle)


  it 'should be able to accept an invitation', () ->
    res = invites.invite(user_a, 'b', 'r', {})

    a_handle = res.handle

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')
    b_handle = msg.handle

    res = invites.accept(user_b, b_handle)

    res.room.should.equal('r')

    msg = user_a.sent[0]
    msg.type.should.equal('invite_response')
    msg.handle.should.equal(a_handle)
    msg.accepted.should.equal(true)


  it 'should be able to deny an invitation', () ->
    res = invites.invite(user_a, 'b', 'r', {})

    a_handle = res.handle

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')
    b_handle = msg.handle

    invites.deny(user_b, b_handle)

    msg = user_a.sent[0]
    msg.type.should.equal('invite_response')
    msg.handle.should.equal(a_handle)
    msg.accepted.should.equal(false)


  it 'should not allow to accept after cancel', () ->
    res = invites.invite(user_a, 'b', 'r', {})

    a_handle = res.handle

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')
    b_handle = msg.handle

    invites.cancel(user_a, a_handle)

    expect(() -> invites.deny(user_b, b_handle)).to.throw("Invalid invitation handle")


  it 'should not allow to cancel after accept', () ->
    res = invites.invite(user_a, 'b', 'r', {})

    a_handle = res.handle

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')
    b_handle = msg.handle

    invites.accept(user_b, b_handle)
    expect(() -> invites.cancel(user_a, a_handle)).to.throw("Invalid invitation handle")


  it 'should cancel invitations after user leaves', () ->
    invites.invite(user_a, 'b', 'r', {})

    msg = user_b.sent[0]
    user_b.sent.length.should.equal(1)
    msg.type.should.equal('invite_incoming')
    b_handle = msg.handle

    user_a.emit('left')

    msg = user_b.sent[1]
    user_b.sent.length.should.equal(2)
    msg.type.should.equal('invite_cancelled')
    msg.handle.should.equal(b_handle)


  it 'should deny invitations after user leaves', () ->
    res = invites.invite(user_a, 'b', 'r', {})

    a_handle = res.handle

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')

    user_b.emit('left')

    msg = user_a.sent[0]
    msg.type.should.equal('invite_response')
    msg.handle.should.equal(a_handle)
    msg.accepted.should.be.false


  it 'should deny and cancel invitations after room is empty', () ->
    res = invites.invite(user_a, 'b', 'r', {})

    a_handle = res.handle

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')

    rooms.rooms['r'].emit('empty')

    msg = user_b.sent[1]
    msg.type.should.equal('invite_cancelled')
    msg.handle.should.equal(a_handle)

    msg = user_a.sent[0]
    msg.type.should.equal('invite_response')
    msg.handle.should.equal(a_handle)
    msg.accepted.should.be.false


  it 'should clean up `empty` listeners after resolving', () ->
    res = invites.invite(user_a, 'b', 'r', {})
    handle = res.handle

    room = rooms.rooms['r']
    room.listeners('empty').length.should.equal(1)

    invites.cancel(user_a, handle)

    room.listeners('empty').should.be.empty


  it 'should fail on inviting unknown user', () ->
    expect(() -> invites.invite(user_a, 'nobody', 'r', {})).to.throw("Unknown recipient")


  it 'should put invited user into room', () ->
    invites.invite(user_a, 'b', 'r', {})
    rooms.rooms['r'].users['b'].should.exist


  it 'should resolve invite promise to `true` on accept', () ->
    invites.invite(user_a, 'b', 'r', {})

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')
    b_handle = msg.handle

    invites.accept(user_b, b_handle)

    return rooms.rooms['r'].users['b'].should.become(true)


  it 'should resolve invite promise to `false` on deny', () ->
    invites.invite(user_a, 'b', 'r', {})

    msg = user_b.sent[0]
    msg.type.should.equal('invite_incoming')
    b_handle = msg.handle

    invites.deny(user_b, b_handle)

    return rooms.rooms['r'].users['b'].should.become(false)


  it 'should resolve invite promise to `false` on cancel', () ->
    res = invites.invite(user_a, 'b', 'r', {})

    a_handle = res.handle

    invites.cancel(user_a, a_handle)

    return rooms.rooms['r'].users['b'].should.become(false)


  it 'should test commands'
