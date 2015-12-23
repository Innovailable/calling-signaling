{TestServer, TestUser} = require('./helper')
{hello_handler} = require('../../src/hello')

server_id = 'Test Server'

describe 'Hello', () ->

  server = null

  beforeEach () ->
    server = new TestServer()
    hello_handler(server, server_id)

  it 'should send hello to new users', () ->
    user = new TestUser('a')
    server.add_user(user)

    user.sent.should.deep.equal([{
      type: 'hello'
      id: user.id
      server: server_id
    }])

