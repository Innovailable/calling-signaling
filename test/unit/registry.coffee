{TestUser, TestServer, TestRooms, TestRoom, TestPeer} = require('./helper')
{Promise} = require('bluebird')

{Registry, Namespace, NamespaceRoom} = require('../../src/registry')

describe 'Registry', () ->

  user_a = null
  user_b = null
  user_c = null

  beforeEach () ->
    user_a = new TestUser('a')
    user_b = new TestUser('b')
    user_c = new TestUser('c')

  describe 'Namespace', () ->

    namespace = null
    nsid = 'namespace_id'

    beforeEach () ->
      namespace = new Namespace(nsid)

    describe 'Subscribe', () ->

      it 'should not allow subscribing twice on same namespace', () ->
        namespace.subscribe(user_a)
        expect(() -> namespace.subscribe(user_a)).to.throw("User was already subscribed to that namespace")


      it 'should not allow to unsubscribe without subscribing', () ->
        expect(() -> namespace.unsubscribe(user_a)).to.throw("User was not subscribed to namespace")


      it 'should answer with users and rooms', () ->
        res = namespace.subscribe(user_a)

        res.should.deep.equal({
          users: {}
          rooms: {}
        })


    describe 'Broadcast', () ->

      it 'should send broadcast to all subscribed user', () ->
        msg = { test: 'me' }

        namespace.subscribe(user_a)
        namespace.subscribe(user_b)
        namespace.broadcast(msg)

        user_a.sent.should.deep.equal([msg])
        user_b.sent.should.deep.equal([msg])


      it 'should not send broadcast to user after unsubscribing', () ->
        msg = { test: 'me' }

        namespace.subscribe(user_a)
        namespace.subscribe(user_b)
        namespace.unsubscribe(user_a)
        namespace.broadcast(msg)

        user_a.sent.should.be.empty
        user_b.sent.should.deep.equal([msg])


    describe 'User Register', () ->

      it 'should not allow registering twice on same namespace', () ->
        namespace.register_user(user_a)
        expect(() -> namespace.register_user(user_a)).to.throw("User was already registered to that namespace")


      it 'should not allow to unregistering without registering', () ->
        expect(() -> namespace.unsubscribe(user_a)).to.throw("User was not subscribed to namespace")


      it 'should return registered user on `subscribe()`', () ->
        user_a.userdata.status = {b: 'c'}
        namespace.register_user(user_a)

        res = namespace.subscribe(user_b)

        res.should.deep.equal({
          users: {
            a: {
              status: {b: 'c'}
            }
          }
          rooms: {}
        })


      it 'should not return unregistered user on `subscribe()`', () ->
        namespace.register_user(user_a)
        namespace.unregister_user(user_a)

        res = namespace.subscribe(user_b)

        res.should.deep.equal({
          users: {}
          rooms: {}
        })


      it 'should not return user which left on `subscribe()`', () ->
        namespace.register_user(user_a)
        user_a.emit('left')

        res = namespace.subscribe(user_b)

        res.should.deep.equal({
          users: {}
          rooms: {}
        })


      it 'should notify of new user', () ->
        namespace.subscribe(user_a)

        user_b.userdata.status = {a: 'b'}
        namespace.register_user(user_b)

        user_a.sent.should.deep.equal([{
          type: 'ns_user_add'
          namespace: nsid
          user: 'b'
          status: {a: 'b'}
        }])


      it 'should notify of unregistered user', () ->
        namespace.register_user(user_b)
        namespace.subscribe(user_a)
        namespace.unregister_user(user_b)

        user_a.sent.should.deep.equal([{
          type: 'ns_user_rm'
          namespace: nsid
          user: 'b'
        }])


      it 'should notify when user leaves', () ->
        namespace.register_user(user_b)
        namespace.subscribe(user_a)
        user_b.emit('left')

        user_a.sent.should.deep.equal([{
          type: 'ns_user_rm'
          namespace: nsid
          user: 'b'
        }])


      it 'should notify of updated user status', () ->
        namespace.register_user(user_b)
        namespace.subscribe(user_a)

        user_b.userdata.status = {a: 'b'}
        user_b.emit('userdata_changed', 'status', user_b.status)

        user_a.sent.should.deep.equal([{
          type: 'ns_user_update'
          namespace: nsid
          user: 'b'
          status: user_b.status
        }])


      it 'should not notify of updated user status after unregistering', () ->
        namespace.register_user(user_b)
        namespace.unregister_user(user_b)
        namespace.subscribe(user_a)

        user_b.status = {a: 'b'}
        user_b.emit('userdata_changed', user_b.status)

        user_a.sent.should.be.empty


      it 'should remove listeners after user left', () ->
        namespace.register_user(user_a)

        user_a.listeners('userdata_changed').should.have.length(1)
        user_a.listeners('left').should.have.length(1)

        namespace.unregister_user(user_a)

        user_a.listeners('userdata_changed').should.be.empty
        user_a.listeners('left').should.be.empty


      it 'should remove listeners unregistering', () ->
        namespace.register_user(user_a)

        user_a.listeners('userdata_changed').should.have.length(1)
        user_a.listeners('left').should.have.length(1)

        user_a.emit('left')

        user_a.listeners('userdata_changed').should.be.empty
        user_a.listeners('left').should.be.empty


    describe 'Rom Register', () ->

      room = null
      peer = null

      beforeEach () ->
        room = new TestRoom('room', {a: 'b'})
        peer = room.add_peer('user', {c: 'd'}, false)


      describe 'Register', () ->

        it 'should not allow registering twice on same namespace', () ->
          namespace.register_room(room)
          expect(() -> namespace.register_room(room)).to.throw('Room was already registered to that namespace')


        it 'should not allow unregistering without registering', () ->
          expect(() -> namespace.unregister_room(room)).to.throw('Room was not registered to namespace')


        it 'should return registered room on `subscribe()`', () ->
          room = new TestRoom('room', {a: 'b'})
          room.add_peer('user', {c: 'd'}, false)

          namespace.register_room(room)

          res = namespace.subscribe(user_b)

          res.should.deep.equal({
            users: {}
            rooms: {
              room: {
                status: {a: 'b'}
                peers: {
                  user: {
                    status: {c: 'd'}
                    pending: false
                  }
                }
              }
            }
          })


        it 'should not return unregistered room on `subscribe()`', () ->
          namespace.register_room(room)
          namespace.unregister_room(room)

          res = namespace.subscribe(user_b)

          res.should.deep.equal({
            users: {}
            rooms: {}
          })


        it 'should not return room which emitted `empty` on `subscribe()`', () ->
          namespace.register_room(room)
          room.emit('empty')

          res = namespace.subscribe(user_b)

          res.should.deep.equal({
            users: {}
            rooms: {}
          })


        it 'should notify of new room', () ->
          namespace.subscribe(user_a)

          namespace.register_room(room)

          user_a.sent.should.deep.equal([{
            type: 'ns_room_add'
            namespace: nsid
            room: 'room'
            status: {a: 'b'}
            peers: {
              user: {
                status: {
                  c: 'd'
                }
                pending: false
              }
            }
          }])


        it 'should notify of removed room', () ->
          namespace.register_room(room)
          namespace.subscribe(user_a)
          namespace.unregister_room(room)

          user_a.sent.should.deep.equal([{
            type: 'ns_room_rm'
            namespace: nsid
            room: 'room'
          }])


        it 'should notify of emptied room', () ->
          namespace.register_room(room)
          namespace.subscribe(user_a)
          room.emit('empty')

          user_a.sent.should.deep.equal([{
            type: 'ns_room_rm'
            namespace: nsid
            room: 'room'
          }])


      describe 'Status', () ->

        it 'should notify of changed room status', () ->
          namespace.register_room(room)
          namespace.subscribe(user_a)

          room.status = {c: 'd'}
          room.emit('status_changed', 'status', room.status)

          user_a.sent.should.deep.equal([{
            type: 'ns_room_update'
            namespace: nsid
            room: 'room'
            status: {c: 'd'}
          }])


      describe 'Peers', () ->

        it 'should notify of new peer', () ->
          namespace.register_room(room)
          namespace.subscribe(user_a)

          new_peer = new TestPeer('new', {new: 'peer'}, true)

          room.emit('new_peer', new_peer)

          user_a.sent.should.deep.equal([{
            type: 'ns_room_peer_add'
            namespace: nsid
            room: 'room'
            user: 'new'
            status: {new: 'peer'}
            pending: true
          }])


        it 'should notify of peer which left', () ->
          namespace.register_room(room)
          namespace.subscribe(user_a)

          peer.emit('left')

          user_a.sent.should.deep.equal([{
            type: 'ns_room_peer_rm'
            namespace: nsid
            room: 'room'
            user: 'user'
          }])


        it 'should not list peer which was removed', () ->
          namespace.register_room(room)

          peer.emit('left')
          delete room.peers['user']

          res = namespace.subscribe(user_a)
          res.rooms['room'].peers.should.be.empty


        it 'should notify of peer which accepted', () ->
          namespace.register_room(room)
          namespace.subscribe(user_a)

          peer.emit('accepted')

          user_a.sent.should.deep.equal([{
            type: 'ns_room_peer_update'
            namespace: nsid
            room: 'room'
            user: 'user'
            pending: false
          }])


        it 'should notify of peer status change', () ->
          namespace.register_room(room)
          namespace.subscribe(user_a)

          peer.status = {test: 'status'}
          peer.emit('userdata_changed', 'status', peer.status)

          user_a.sent.should.deep.equal([{
            type: 'ns_room_peer_update'
            namespace: nsid
            room: 'room'
            user: 'user'
            status: {test: 'status'}
          }])


      describe 'Cleanup', () ->

        it 'should remove room listeners after unregistering', () ->
          namespace.register_room(room)

          room.listeners('empty').should.have.length(1)
          room.listeners('status_changed').should.have.length(1)
          room.listeners('new_peer').should.have.length(1)

          namespace.unregister_room(room)

          room.listeners('empty').should.be.empty
          room.listeners('userdata_changed').should.be.empty
          room.listeners('new_peer').should.be.empty


        it 'should remove room listeners after emitting `empty`', () ->
          namespace.register_room(room)

          room.listeners('empty').should.have.length(1)
          room.listeners('status_changed').should.have.length(1)
          room.listeners('new_peer').should.have.length(1)

          room.emit('empty')

          room.listeners('empty').should.be.empty
          room.listeners('status_changed').should.be.empty
          room.listeners('new_peer').should.be.empty


        it 'should remove peer listeners after unregistering', () ->
          namespace.register_room(room)

          peer.listeners('left').should.have.length(1)
          peer.listeners('userdata_changed').should.have.length(1)
          peer.listeners('accepted').should.have.length(1)

          namespace.unregister_room(room)

          peer.listeners('left').should.be.empty
          peer.listeners('userdata_changed').should.be.empty
          peer.listeners('accepted').should.be.empty


    describe 'Empty', () ->

      it 'should emit empty after last unsubscribe if empty', () ->
        return new Promise (resolve) ->
          namespace.on('empty', resolve)

          namespace.subscribe(user_a)
          namespace.unsubscribe(user_a)


      it 'should not emit empty after last unsubscribe if not empty', () ->
        namespace.on 'empty', () ->
          throw new Error("Empty should not be called")

        namespace.subscribe(user_a)
        namespace.register_user(user_b)
        namespace.unsubscribe(user_a)


      it 'should emit empty after last unregister user if empty', () ->
        return new Promise (resolve) ->
          namespace.on('empty', resolve)

          namespace.register_user(user_a)
          namespace.unregister_user(user_a)


      it 'should not emit empty after last unregister user if not empty', () ->
        namespace.on 'empty', () ->
          throw new Error("Empty should not be called")

        namespace.register_user(user_a)
        namespace.subscribe(user_b)
        namespace.unregister_user(user_a)


      it 'should emit empty after last unregister room if empty', () ->
        return new Promise (resolve) ->
          namespace.on('empty', resolve)

          room = new TestRoom('room')

          namespace.register_room(room)
          namespace.unregister_room(room)


      it 'should not emit empty after last unregister room if not empty', () ->
        namespace.on 'empty', () ->
          throw new Error("Empty should not be called")

        room = new TestRoom('room')
        namespace.register_room(room)
        namespace.subscribe(user_a)
        namespace.unregister_room(room)


  describe 'Registry', () ->
    server = null
    registry = null

    ns_msg = (user, type, ns='a') ->
      server.trigger(user, {
        type: type
        namespace: ns
      })

    beforeEach () ->
      server = new TestServer()
      rooms = new TestRooms()
      registry = new Registry(server, rooms)


    it 'should let users subscribe', () ->
      res = ns_msg(user_a, 'ns_subscribe')

      res.should.deep.equal({
        users: {}
        rooms: {}
      })


    it 'should register users', () ->
      ns_msg(user_a, 'ns_user_register')

      res = ns_msg(user_a, 'ns_subscribe')

      res.should.deep.equal({
        users: {
          a: {}
        }
        rooms: {}
      })

    it 'should register rooms', () ->
      server.trigger(user_a, {
        type: 'ns_room_register'
        room: 'r'
        namespace: 'a'
      })

      res = ns_msg(user_a, 'ns_subscribe')

      res.should.deep.equal({
        users: {}
        rooms: {
          r: {
            status: {}
            peers: {}
          }
        }
      })

    it 'should create new namespace using `get_namespace()`', () ->
      ns = registry.get_namespace('test', true)

      ns.id.should.equal('test')
      ns.should.be.an.instanceof(Namespace)


    it 'should find existing namespace using `get_namespace()`', () ->
      ns1 = registry.get_namespace('test', true)

      ns1.id.should.equal('test')
      ns1.should.be.an.instanceof(Namespace)

      ns2 = registry.get_namespace('test', true)

      ns2.should.equal(ns1)

