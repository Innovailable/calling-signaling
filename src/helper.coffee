exports.is_empty = (obj) ->
  for _, _ of obj
    return false

  return true
