{TestServer, TestUser} = require('./helper')
{status_handler} = require('../../src/status')

test_status = { a: 'b', c: 'd' }

describe 'Status', () ->
  server = null
  user = null

  beforeEach () ->
    server = new TestServer()
    status_handler(server)
    user = new TestUser()

  it 'should set status on command', () ->
    server.trigger(user, {type: 'status', status: test_status})
    user.userdata.status.should.deep.equal(test_status)


  it 'should emit event on command', (next) ->
    user.on 'userdata_changed', (key, value) ->
      key.should.equal("status")
      value.should.deep.equal(test_status)
      next()

    server.trigger(user, {type: 'status', status: test_status})


  it 'should initialize users with empty status', () ->
    delete user.status
    server.add_user(user)
    user.userdata.status.should.deep.equal({})

