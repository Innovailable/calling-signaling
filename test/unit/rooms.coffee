{Promise} = require('bluebird')
{TestUser, TestServer} = require('./helper')
{RoomManager, Room, RoomUser} = require('../../src/rooms')

describe 'Rooms', () ->
  user_a = null
  user_b = null
  user_c = null

  beforeEach () ->
    user_a = new TestUser('a')
    user_b = new TestUser('b')
    user_c = new TestUser('c')

  describe 'RoomManager', () ->
    server = null
    rooms = null

    beforeEach () ->
      server = new TestServer()
      rooms = new RoomManager(server)

    it 'should let users join', () ->
      server.trigger(user_a, {type: 'join', room: 'r'})
      res = server.trigger(user_b, {type: 'join', room: 'r'})

      res.should.deep.equal({
        room: 'r'
        peers: {
          a: {
            pending: false
            status: {}
          }
        }
        status: {}
      })


    it 'should let users leave', () ->
      server.trigger(user_a, {type: 'join', room: 'r'})
      server.trigger(user_a, {type: 'leave', room: 'r'})

      res = server.trigger(user_b, {type: 'join', room: 'r'})

      res.should.deep.equal({
        room: 'r'
        peers: {}
        status: {}
      })


    it 'should let users send messages', () ->
      server.trigger(user_a, {type: 'join', room: 'r'})
      server.trigger(user_b, {type: 'join', room: 'r'})

      server.trigger(user_a, {
        type: 'to'
        room: 'r'
        user: 'b'
        event: 'test'
        data: {}
      })

      user_b.sent[0].should.deep.equal({
        type: 'from'
        room: 'r'
        user: 'a'
        event: 'test'
        data: {}
      })


    it 'should clean up rooms after users left', () ->
      server.trigger(user_a, {type: 'join', room: 'r'})
      expect(() -> rooms.get_room('r')).to.not.throw()

      server.trigger(user_a, {type: 'leave', room: 'r'})
      expect(() -> rooms.get_room('r')).to.throw('Room does not exist')


    it 'should let users change room status', () ->
      server.trigger(user_a, {type: 'join', room: 'r'})

      server.trigger(user_b, {type: 'join', room: 'r'})

      server.trigger(user_a, {
        type: 'room_status'
        room: 'r'
        key: 'a'
        value: 'b'
      })

      user_b.sent[0].should.deep.equal({
        type: 'room_status'
        room: 'r'
        status: {a: 'b'}
      })

      res = server.trigger(user_c, {type: 'join', room: 'r'})
      res.status.should.deep.equal({a: 'b'})


    it 'should let users change their status', () ->
      server.trigger(user_a, {type: 'join', room: 'r'})
      server.trigger(user_b, {type: 'join', room: 'r'})

      server.trigger(user_a, {
        type: 'peer_status'
        room: 'r'
        status: {a: 'b'}
      })

      user_b.sent[0].should.deep.equal({
        type: 'peer_status'
        room: 'r'
        user: 'a'
        status: {a: 'b'}
      })

      res = server.trigger(user_c, {type: 'join', room: 'r'})
      res.peers['a'].status.should.deep.equal({a: 'b'})


  describe 'Room', () ->
    room = null

    beforeEach () ->
      room = new Room('room')

    describe 'join answer', () ->
      it 'should have room name', () ->
        res = room.join(user_a)

        res.should.deep.equal({
          room: 'room'
          peers: {}
          status: {}
        })


      it 'should list joined peer', () ->
        room.join(user_a)
        res = room.join(user_b)

        res.peers.should.deep.equal({
          a: {
            pending: false
            status: {}
          }
        })


      it 'should not list peer who left', () ->
        room.join(user_a)
        room.leave(user_a)
        res = room.join(user_b)

        res.peers.should.deep.equal({})


      it 'should list invited peer in answer', () ->
        room.invite(user_a, new Promise(() ->))
        res = room.join(user_b)

        res.peers.should.deep.equal({
          a: {
            pending: true
            status: {}
          }
        })


      it 'should not list invited peer which rejceted', () ->
        room.invite(user_a, Promise.resolve(false))

        return Promise.delay(null, 10).then () ->
          res = room.join(user_b)

          res.peers.should.deep.equal({})


    describe 'events', () ->

      it 'should notify on joined user', () ->
        room.join(user_a)
        room.join(user_b)

        user_a.sent[0].should.deep.equal({
          type: 'peer_joined'
          room: 'room'
          user: 'b'
          pending: false
          status: {}
        })


      it 'should notify on invited user', () ->
        room.join(user_a)
        room.invite(user_b, new Promise(() ->))

        user_a.sent[0].should.deep.equal({
          type: 'peer_joined'
          room: 'room'
          user: 'b'
          pending: true
          status: {}
        })


      it 'should notify on accepted invite', () ->
        room.invite(user_b, Promise.resolve(true))
        room.join(user_a)

        return Promise.delay(null, 10).then () ->
          user_a.sent[0].should.deep.equal({
            type: 'peer_accepted'
            room: 'room'
            user: 'b'
          })

          return


      it 'should notify on leaving peer', () ->
        room.join(user_b)
        room.join(user_a)
        room.leave(user_b)

        user_a.sent[0].should.deep.equal({
          type: 'peer_left'
          room: 'room'
          user: 'b'
        })


      it 'should notify on status update', () ->
        room.join(user_b)
        room.join(user_a)

        status = {hello: 'world'}

        user_b.status = status
        user_b.emit('status_changed')

        user_a.sent[0].should.deep.equal({
          type: 'peer_status'
          room: 'room'
          user: 'b'
          status: status
        })


      it 'should not notify users who left', () ->
        room.join(user_a)
        room.leave(user_a)
        room.join(user_b)

        user_a.sent.length.should.equal(0)


      it 'should not notify users who are pending', () ->
        room.invite(user_a, new Promise(() ->))
        room.join(user_b)

        user_a.sent.length.should.equal(0)


    describe 'sanity checks', () ->

      it 'should not allow joining twice', () ->
        room.join(user_a)
        expect(() -> room.join(user_a)).to.throw("User is already in room")


      it 'should not allow inviting twice', () ->
        room.invite(user_a, new Promise(() ->))
        expect(() -> room.invite(user_a, new Promise(() ->))).to.throw("User is already in room")


      it 'should not allow inviting and joining with same user', () ->
        room.join(user_a)
        expect(() -> room.invite(user_a, new Promise(() ->))).to.throw("User is already in room")


      it 'should not accept invites after disconnecting', () ->
        room.invite(user_b, Promise.resolve(true))
        user_b.emit('left')

        room.join(user_a)

        return Promise.delay(null, 10).then () ->
          user_a.sent.length.should.equal(0)
          return


      it 'should not reject invites after disconnecting', () ->
        room.invite(user_b, Promise.resolve(false))
        user_b.emit('left')

        room.join(user_a)

        return Promise.delay(null, 10).then () ->
          user_a.sent.length.should.equal(0)
          return


    describe 'message', () ->

      it 'should transmit message to other peer', () ->
        room.join(user_a)
        room.join(user_b)

        room.message(user_a, 'b', 'test', {})

        user_b.sent[0].should.deep.equal({
          type: 'from'
          room: 'room'
          user: 'a'
          event: 'test'
          data: {}
        })


      it 'should not allow sending to unknown peers', () ->
        room.join(user_a)
        expect(() -> room.message(user_a, 'b', 'test', {})).to.throw('Unknown recipient')


      it 'should not allow sending to pending peers', () ->
        room.invite(user_b, new Promise(() ->))
        room.join(user_a)
        expect(() -> room.message(user_a, 'b', 'test', {})).to.throw('Recipient is pending')


    describe 'room status', () ->

      it 'should be able to change status', () ->
        room.join(user_a)
        room.room_status(user_a, 'a', 'b')

        room.status.should.deep.equal({a: 'b'})


      it 'should broadcast changes', () ->
        room.join(user_a)
        room.join(user_b)

        room.room_status(user_a, 'a', 'b')

        user_b.sent[0].should.deep.equal({
          type: 'room_status'
          room: 'room'
          status: {a:'b'}
        })


      it 'should check previous value when provided', () ->
        room.join(user_a)

        room.room_status(user_a, 'a', {a: true}, true, undefined)
        room.status.should.deep.equal({a: {a: true}})

        expect(() -> room.room_status(user_a, 'a', false, true, undefined)).to.throw('Status not in expected state')
        room.status.should.deep.equal({a: {a: true}})

        room.room_status(user_a, 'a', false, true, {a: true})
        room.status.should.deep.equal({a: false})


    describe 'peer status', () ->

      it 'should set status on joining', () ->
        room.join(user_a, {a: 'b'})
        room.users['a'].status.should.deep.equal({a: 'b'})


      it 'should be be able to change status', () ->
        return new Promise (resolve) ->
          room.join(user_a)

          room.users['a'].status.should.be.empty

          room.users['a'].on 'status_changed', (status) ->
            status.should.deep.equal({a: 'b'})
            resolve()

          room.peer_status(user_a, {a: 'b'})


  describe 'RoomUser', () ->
    test_user = null
    room_user = null

    beforeEach () ->
      test_user = new TestUser('a')
      room_user = new RoomUser(test_user)

    describe 'life cycle', () ->

      it 'should emit `left` when user does', () ->
        return new Promise (resolve, reject) ->
          room_user.on 'left', () ->
            resolve()

          test_user.emit('left')


      it 'should not emit `left` after being destroyed', () ->
        return new Promise (resolve, reject) ->
          room_user.destroy()

          room_user.on 'left', () ->
            reject("Event `left` thrown")

          test_user.emit('left')

          setTimeout () ->
            resolve()
          , 10


      it 'should not emit `status_changed` after being destroyed', () ->
        return new Promise (resolve, reject) ->
          room_user.destroy()

          room_user.on 'status_changed', () ->
            reject("Event `status_changed` thrown")

          test_user.emit('status_changed')

          setTimeout () ->
            resolve()
          , 10


      it 'should not be active after being destroyed', () ->
        room_user.active.should.be.true
        room_user.destroy()
        room_user.active.should.be.false


    describe 'status', () ->

      it 'should emit `status_changed` when user status changes', () ->
        return new Promise (resolve, reject) ->
          room_user.on 'status_changed', (status) ->
            status.should.deep.equal({a: 'b'})
            room_user.status.should.deep.equal({a: 'b'})
            resolve()

          room_user.status.should.be.empty

          test_user.status = {a: 'b'}
          test_user.emit('status_changed')


      it 'should emit `status_changed` after `set_status()` was called', () ->
        return new Promise (resolve, reject) ->
          room_user.on 'status_changed', (status) ->
            status.should.deep.equal({a: 'b'})
            room_user.status.should.deep.equal({a: 'b'})
            resolve()

          room_user.status.should.be.empty

          room_user.set_status({a: 'b'})


      it 'should overwrite user status with peer status', () ->
        test_user.status = {a: 1, b: 1}
        room_user.set_status({b: 2, c: 2})

        room_user.status.should.deep.equal({
          a: 1
          b: 2
          c: 2
        })

