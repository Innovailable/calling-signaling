get_cli_options = () ->
  res = {}

  # configure room timeout

  timeout_str = process.env.CALLING_ROOM_TIMEOUT

  if timeout_str?
    res.rooms = {
      timeout: Number(timeout_str) * 1000
    }

  # apply disabled modules

  disable_str = process.env.CALLING_DISABLE

  if disable_str?
    for module in disable_str.split(/\s+/)
      res[module] = false

  return res

module.exports = {
  get_cli_options
}
