# calling-signaling

This is a signaling server with the following feature set:

* rooms
  * abstraction of a multi or single user signaling session
  * support of multiple rooms using one connection
* status objects
  * status on rooms and users
  * can be changed during a session and will be updated on other clients
  * users have a global state which can be overwritten in rooms
* namespaces
  * used to announce users and rooms
  * subscribe to get updates on a namespace
  * register to get announced to subscribers
  * subscribers will receive messages on new users/rooms and changed state
  * can be subscribed to multiple namespaces
  * can be registered to multiple namespaces
* invitations
  * invite users into a room
  * invited users will be listed in the room as pending
  * can be accepted or denied by receiving user
  * can be cancelled by sending user
* protocol
  * can be used over any channel with any serialization
  * JSON over WebSockets transport layer included
  * requests receive an answer or an error message from the server
  * async handling using transaction ids
* modularized
  * each function is implemented in seperate module
  * as few dependencies as possible
  * easily extendable
  * feature set can be adapted to use case

It was developed to work with `rtc-lib`.

