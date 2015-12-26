# calling-signaling

## Protocol

### Basics

The signaling protocol consists of JSON stanzas. Each stanza should be an
object containing a `type` field.

There are three types of messages:

* `request` messages from the client to the server
* `answer` messages responding to a request
* `event` messages from the server to the client

The server initiates the communication with the following message:

  // event
  {
    "type": "hello",
    "id": own_user_id
  }

Each `request` can have a `tid` field. If this field is present the server will
send an answer which is of one of the following formats.

  // positive response
  {
    "type": "answer",
    "tid": tid,
    "data": { .. custom data .. }
  }

  // negative response
  {
    "type": "answer",
    "tid": tid,
    "error": "error msg"
  }

The custom data in the positive answer is defined by the type of the request.
Only this part of the answer will be represented in the documentation of
answers below. Only answers containing custom data will be documented.

### Register and Subscribe

Users can register to a namespace to be announced to all users subscribing this
namespace. You can register and subscribe to any number of namespaces.

Register a client to a namespace to get announced to other users:

  // request
  {
    "type": "register",
    "tid": tid,
    "namespace": "namespace_id"
  }

To undo the registration:

  // request
  {
    "type": "unregister",
    "tid": tid,
    "namespace": "namespace_id"
  }

Subscribe a client to a namespace to get announcements about other users:

  // request
  {
    "type": "subscribe",
    "tid": tid,
    "namespace": "namespace_id"
  }

Answer from server to a subscription:

  // answer
  {
    "user_id": { .. status .. },
    ..
  }

To not get announcements on that namespace anymore:

  // request
  {
    "type": "unsubscribe",
    "tid": tid,
    "namespace": "namespace_id"
  }

On new users:

  // event
  {
    "type": "user_registered",
    "user": "user_id",
    "namespace": "namespace_id",
    "status": { .. status .. }
  }

On user left:

  // event
  {
    "type": "user_left",
    "user": "user_id"
    "namespace": "namespace_id",
  }

To update your own status

  // request
  {
    "type": "status",
    "tid": tid,
    "status": { .. status .. }
  }

On status update of other users:

  // event
  {
    "type": "user_status",
    "user": "user_id",
    "namespace": "namespace_id",
    "status": { .. status .. }
  }

  // request
  {
    "type": "register_room",
    "tid": tid,
    "namespace": "namespace_id",
    "room": "room_id"
  }

  // event
  {
    "type": "room_registered",
    "namespace": "namespace_id",
    "room": "room_id",
    "status": { .. status .. }
  }

  // event
  {
    "type": "room_status",
    "namespace": "namespace_id",
    "room": "room_id",
    "status": { .. status .. }
  }

  // event
  {
    "type": "room_closed",
    "namespace": "namespace_id",
    "room": "room_id"
  }

### Room Joining

To join a specific room:

  // request
  {
    "type": "join",
    "tid": tid,
    "room": "room_id"
    "status": { .. peer status ... }
  }

To join a new empty room:

  // request
  {
    "type": "join"
    "tid": tid
  }

Answer to joining:

  // answer
  {
    "room": "room_id",
    "peers": {
      "user_id": {
        "pending": true|false,
        "status": { .. status .. },
      },
      ..
    }
  }

### Inside Room

  // request
  {
    "type": "leave",
    "tid": tid,
    "room": "room_id"
  }

  // event
  {
    "type": "peer_joined",
    "room": "room_id",
    "user": "user_id",
    "pending": true|false
    "status": { .. status .. }
  }

  // event
  {
    "type": "peer_accepted",
    "room": "room_id",
    "user": "user_id"
  }

  // event
  {
    "type": "peer_left",
    "room": "room_id",
    "user": "user_id"
  }

  // request
  {
    "type": "peer_status",
    "room": "room_id",
    "status": { .. status .. }
  }

  // event
  {
    "type": "peer_status",
    "room": "room_id",
    "user": "user_id",
    "status": { .. status .. }
  }

  // request
  {
    "type": "to",
    "tid": tid,
    "room": "room_id",
    "user": "user_id",
    "event": "event_id",
    "data": { .. custom data .. }
  }

  // event
  {
    "type": "from",
    "room": "room_id",
    "user": "user_id",
    "event": "event_id",
    "data": { .. custom data .. }
  }

### Invites

  // request
  {
    "type": "invite",
    "tid": tid,
    "room": "room_id",
    "user": "user_id",
    "data": { .. custom data .. }
  }

  // request
  {
    "type": "invite",
    "tid": tid,
    "user": "user_id",
    "data": { .. custom data .. }
  }

  // answer
  {
    "handle": invite_handle
  }

  // event
  {
    "type": "invite_response",
    "handle": invite_handle,
    "accepted": true|false
  }

  // request
  {
    "type": "invite_cancel",
    "handle": invite_handle
  }

  // event
  {
    "type": "invited",
    "handle": invite_handle,
    "user": "user_id",
    "status": { .. status of inviting user .. },
    "data": { .. custom data .. }
  }

  // request
  {
    "type": "invite_accept",
    "handle": invite_handle,
    "status": { .. peer status .. }
  }

  // request
  {
    "type": "invite_deny",
    "handle": invite_handle,
  }

  // event
  {
    "type": "invite_cancelled",
    "handle": invite_handle
  }
