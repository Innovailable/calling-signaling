# calling-signaling Protocol

## Basics

The signaling protocol consists of JSON stanzas. Each stanza should be an
object containing a `type` field.

There are three types of messages:

* `request` messages from the client to the server
* `answer` messages responding to a request
* `event` messages from the server to the client

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

The following sections describes all implemented requests and events. They are
implemented in modules which can be removed or extended with minimal
dependencies.

## Hello

The server initiates the communication with the following message.

    // event
    {
      "type": "hello",
      "id": own_user_id,
      "server": "server name"
    }

## Status

To update your own global status.

    // request
    {
      "type": "status",
      "tid": tid,
      "status": { .. status .. }
    }

## Namespace

### Subscribing

Subscribe a client to a namespace to get announcements about other users and
rooms.

    // request
    {
      "type": "ns_subscribe",
      "tid": tid,
      "namespace": "namespace_id"
    }

    // answer
    {
      "users": {
        "user_id": { .. user status .. },
        ..
      },
      "rooms": {
        "room_id": {
          "status": { .. room status .. }
          "peers": {
            "status": { .. peer status .. },
            "pending": true|false
          }
        },
        ..
      }
    }

To not get announcements on that namespace anymore.

    // request
    {
      "type": "ns_unsubscribe",
      "tid": tid,
      "namespace": "namespace_id"
    }

### Users

Register a client to a namespace to get announced to other users.

    // request
    {
      "type": "ns_user_register",
      "tid": tid,
      "namespace": "namespace_id"
    }

To undo the registration.

    // request
    {
      "type": "ns_user_unregister",
      "tid": tid,
      "namespace": "namespace_id"
    }

On new users.

    // event
    {
      "type": "ns_user_add",
      "namespace": "namespace_id",
      "user": "user_id",
      "status": { .. status .. }
    }

On user left.

    // event
    {
      "type": "ns_user_rm",
      "namespace": "namespace_id",
      "user": "user_id"
    }

On status update of other users.

    // event
    {
      "type": "ns_user_update",
      "namespace": "namespace_id",
      "user": "user_id",
      "status": { .. status .. }
    }

### Room

To announce a room to subscribers.

    // request
    {
      "type": "ns_room_register",
      "tid": tid,
      "namespace": "namespace_id",
      "room": "room_id"
    }

To undo the announcement in the namespace.

    // request
    {
      "type": "ns_room_unregister",
      "tid": tid,
      "namespace": "namespace_id",
      "room": "room_id"
    }

Event which subscribers to the namespace receive once the room is registered.

    // event
    {
      "type": "ns_room_add",
      "namespace": "namespace_id",
      "room": "room_id",
      "status": { .. room status .. }
      "peers": {
        "user_id": {
          "status": { ..  user status .. },
          "pending": true|false
        },
        ..
      }
    }

Room is emptied or was unregistered from the namespace.

    // event
    {
      "type": "ns_room_rm",
      "namespace": "namespace_id",
      "room": "room_id"
    }

Changed status of the room.

    // event
    {
      "type": "ns_room_update",
      "namespace": "namespace_id",
      "room": "room_id",
      "status": { .. room status .. }
    }

A user entered the room. If `pending=true` the peer is only invited.

    // event
    {
      "type": "ns_room_user_add",
      "namespace": "namespace_id",
      "room": "room_id",
      "user": "user_id",
      "status": { .. user status .. },
      "pending": true|false
    }

A user left the room.

    // event
    {
      "type": "ns_room_user_rm",
      "namespace": "namespace_id",
      "room": "room_id",
      "user": "user_id"
    }

Changed status and/or invitation was accepted.

    // event
    {
      "type": "ns_room_user_update",
      "namespace": "namespace_id",
      "room": "room_id",
      "user": "user_id",
      [ "pending": false, ]
      [ "status": { .. user status .. } ]
    }

## Room

To join a room. If you do not set a room id the server will create an empty room
with a random room id.

    // request
    {
      "type": "room_join",
      "tid": tid,
      [ "room": "room_id", ]
      "status": { .. peer status ... }
    }

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

To leave the room.

    // request
    {
      "type": "room_leave",
      "tid": tid,
      "room": "room_id"
    }

Change the status of the room. Use `check=true` and `previous` to protect
against simple data races.

    // request
    {
      "type": "room_status",
      "room": "room_id",
      "key": "key_id",
      "value": value,
      [ "check": true, ]
      [ "previous": value ]
    }

The status of the room was updated.

    // status
    {
      "type": "room_update",
      "room": "room_id",
      "status": { .. room status .. }
    }

A peer entered the room. When `pending=true` the peer is only invited and did
not accept yet. You will not be able to exchange signaling messages with such
peers.

    // event
    {
      "type": "room_peer_add",
      "room": "room_id",
      "user": "user_id",
      "pending": true|false
      "status": { .. status .. }
    }

A peer left the room.

    // event
    {
      "type": "room_peer_rm",
      "room": "room_id",
      "user": "user_id"
    }

To set your own status in the room. It will overload your global status. If your
global status contains keys which are also in the room status it will be
overwritten.

    // request
    {
      "type": "room_peer_status",
      "room": "room_id",
      "status": { .. status .. }
    }

A peer changed its status and/or accepted an invitation.

    // event
    {
      "type": "room_peer_update",
      "room": "room_id",
      [ "pending": false, ]
      [ "status": { .. status .. } ]
    }

Send a signaling message to another peer.

    // request
    {
      "type": "room_peer_to",
      "tid": tid,
      "room": "room_id",
      "user": "user_id",
      "event": "event_id",
      "data": { .. custom data .. }
    }

Receive a signaling message to another peer.

    // event
    {
      "type": "room_peer_from",
      "room": "room_id",
      "user": "user_id",
      "event": "event_id",
      "data": { .. custom data .. }
    }

## Invites

Invite a user into a room. You will receive a handle with which the invitation
is identified in subsequent requests and events.

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

Cancel an invitation which you sent.

    // request
    {
      "type": "invite_cancel",
      "handle": invite_handle
    }

An invitation was either denied or accepted.

    // event
    {
      "type": "invite_response",
      "handle": invite_handle,
      "accepted": true|false
    }

Incoming invitation. Contains the user which sent it, its status and user
specific data which can be supplied when the invitation is sent.

    // event
    {
      "type": "invite_incoming",
      "handle": invite_handle,
      "user": "user_id",
      "status": { .. status of inviting user .. },
      "data": { .. custom data .. }
    }

Accept an invitation.

    // request
    {
      "type": "invite_accept",
      "handle": invite_handle,
      "status": { .. peer status .. }
    }

    // answer
    {
      "room": "room_id",
      "status": { .. room status .. },
      "peers": {
        "user_id": {
          "status": { .. user status .. },
          "pending": true|false
        }
        ..
      }
    }

Deny an invitation.

    // request
    {
      "type": "invite_deny",
      "handle": invite_handle,
    }

An invitation was cancelled. Either the user which sent the invitation left, the
room was emptied or the user cancelled the invitation manually.

    // event
    {
      "type": "invite_cancelled",
      "handle": invite_handle
    }

## Ping

A command whose only purpose it is to send an answer. Can be used as heartbeat
and connection check.

    // request
    {
      "type": "ping"
    }
