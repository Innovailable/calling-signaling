# calling-signaling

## What is this?

This is a (WebRTC) signaling server with support for calling. It is developed
and tested with [rtc-lib](https://github.com/Innovailable/rtc-lib).

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
  * each feature (rooms, invitations, ...) is implemented in seperate module
  * as few dependencies as possible
  * easily extendable
  * feature set can be adapted to use case

## How to use?

### Standalone with npm

Install with

    npm install -g calling-signaling

And run with

    calling-signaling

### Standalone from git

Install the dependencies with

    npm install

and run the server with

    coffee src/main.coffee

### As library

To integrate the library into you node project install with

    npm install calling-signaling

And require in your source files

    var calling = require('calling-signaling')
    new calling.CallingWebsocketServer(8080, "0.0.0.0")

You can also integrate the signaling server into express

    var calling = require('calling-signaling');

    var calling_server = new calling.CallingServer();

    require('express-ws')(app);
    app.ws('/signaling', function(ws) {
        var channel = new WebsocketChannel(ws);
        calling_server.create_user(channel);
    });

You can create servers with custom transports, custom feature sets and
integrate your own modules. See `calling_server.coffee` to find out how to
write your own server.

