{TestServer} = require('./helper')
{ping_handler} = require('../../src/ping')

describe 'Ping', () ->
  server = null

  beforeEach () ->
    server = new TestServer()
    ping_handler(server)

  it 'should provide ping command', () ->
    server.trigger(null, {type: 'ping'})
