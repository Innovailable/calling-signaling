class WebsocketHeartbeat

  constructor: (@ws, @interval=30000, @threshold=3) ->
    @outstanding = 0
    @timeout = null

    @ws.on 'message', () =>
      @reset()

    @ws.on 'pong', () =>
      @reset()

    @ws.on 'close', () =>
      if @timeout
        clearTimeout(@timeout)

    @schedule()

  reset: () ->
    @outstanding = 0
    @schedule()

  schedule: () ->
    if @timeout?
      clearTimeout(@timeout)

    if @outstanding >= @threshold
      @ws.terminate()
      return

    @outstanding += 1

    @timeout = setTimeout () =>
      @ws.ping()
      @schedule()
    , @interval / @outstanding

module.exports.WebsocketHeartbeat = WebsocketHeartbeat
