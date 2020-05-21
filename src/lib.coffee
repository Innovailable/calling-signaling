{extend} = require('./helper')

extend(exports, require('./calling_server'))
extend(exports, require('./hello'))
extend(exports, require('./invitations'))
extend(exports, require('./ping'))
extend(exports, require('./registry'))
extend(exports, require('./rooms'))
extend(exports, require('./server'))
extend(exports, require('./status'))
extend(exports, require('./websocket_channel'))
extend(exports, require('./cli'))

