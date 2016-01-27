exports.is_empty = (obj) ->
  for _, _ of obj
    return false

  return true

exports.extend = (root, obj) ->
  for key, value of obj
    root[key] = value

  return root

