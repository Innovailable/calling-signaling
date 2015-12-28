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

### Status

To update your own status

    // request
    {
      "type": "status",
      "tid": tid,
      "status": { .. status .. }
    }

### Namespace

Subscribe a client to a namespace to get announcements about other users:

    // request
    {
      "type": "ns_subscribe",
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
      "type": "ns_unsubscribe",
      "tid": tid,
      "namespace": "namespace_id"
    }

### Namespace Users

Register a client to a namespace to get announced to other users:

    // request
    {
      "type": "ns_user_register",
      "tid": tid,
      "namespace": "namespace_id"
    }

To undo the registration:

    // request
    {
      "type": "ns_user_unregister",
      "tid": tid,
      "namespace": "namespace_id"
    }

On new users:

    // event
    {
      "type": "ns_user_add",
      "user": "user_id",
      "namespace": "namespace_id",
      "status": { .. status .. }
    }

On user left:

    // event
    {
      "type": "ns_user_rm",
      "user": "user_id"
      "namespace": "namespace_id",
    }

On status update of other users:

    // event
    {
      "type": "user_status",
      "user": "user_id",
      "namespace": "namespace_id",
      "status": { .. status .. }
    }

### Namespace Room

    // request
    {
      "type": "ns_room_register",
      "tid": tid,
      "namespace": "namespace_id",
      "room": "room_id"
    }

    // event
    {
      "type": "ns_room_add",
      "namespace": "namespace_id",
      "room": "room_id",
      "status": { .. status .. }
    }

    // event
    {
      "type": "ns_room_rm",
      "namespace": "namespace_id",
      "room": "room_id"
    }

    // event
    {
      "type": "ns_room_status",
      "namespace": "namespace_id",
      "room": "room_id",
      "status": { .. status .. }
    }

    // event
    {
      "type": "ns_room_user_add",
      "namespace": "namespace_id",
      "room": "room_id",
      "user": "user_id",
      "status": { .. status .. }
    }

    // event
    {
      "type": "ns_room_user_rm",
      "namespace": "namespace_id",
      "room": "room_id",
      "user": "user_id"
    }

    // event
    {
      "type": "ns_room_user_status",
      "namespace": "namespace_id",
      "room": "room_id",
      "user": "user_id",
      "status": { .. status .. }
    }

### Room

To join a specific room:

    // request
    {
      "type": "room_join",
      "tid": tid,
      "room": "room_id"
      "status": { .. peer status ... }
    }

To join a new empty room:

    // request
    {
      "type": "room_join"
      "tid": tid,
      "status": { .. peer status ... }
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

    // request
    {
      "type": "room_leave",
      "tid": tid,
      "room": "room_id"
    }

    // request
    {
      "type": "room_status",
      "room": "room_id",
      "key": "key_id",
      "value": value
    }

    // request
    {
      "type": "room_status",
      "room": "room_id",
      "key": "key_id",
      "value": value,
      "check": true,
      "previous": value
    }

    // event
    {
      "type": "room_peer_add",
      "room": "room_id",
      "user": "user_id",
      "pending": true|false
      "status": { .. status .. }
    }

    // event
    {
      "type": "room_peer_accepted",
      "room": "room_id",
      "user": "user_id"
    }

    // event
    {
      "type": "room_peer_rm",
      "room": "room_id",
      "user": "user_id"
    }

    // request
    {
      "type": "room_peer_status",
      "room": "room_id",
      "status": { .. status .. }
    }

    // event
    {
      "type": "room_peer_status",
      "room": "room_id",
      "user": "user_id",
      "status": { .. status .. }
    }

    // request
    {
      "type": "room_peer_to",
      "tid": tid,
      "room": "room_id",
      "user": "user_id",
      "event": "event_id",
      "data": { .. custom data .. }
    }

    // event
    {
      "type": "room_peer_from",
      "room": "room_id",
      "user": "user_id",
      "event": "event_id",
      "data": { .. custom data .. }
    }

### Invites

    // request
    {
      "type": "invite_send",
      "tid": tid,
      "room": "room_id",
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
      "type": "invite_incoming",
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
