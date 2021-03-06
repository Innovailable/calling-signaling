{Promise} = require('bluebird')
{is_empty} = require('./helper')

class Invitation

  constructor: (@from, @from_handle, @to, @to_handle, @room) ->
    empty_handler = () =>
      @resolve(false)

      @from.send({
        type: 'invite_response'
        handle: @from_handle
        accepted: false
      })

      @to.send({
        type: 'invite_cancelled'
        handle: @to_handle
      })

    @room.on('empty', empty_handler)

    @promise = new Promise (resolve, reject) =>
      @resolve = (accepted) =>
        if not @promise.isPending()
          throw new Error("Invitation is not active anymore")

        delete @from.invites.out[@from_handle]
        delete @to.invites.in[@to_handle]

        @room.removeListener('empty', empty_handler)

        resolve(accepted)

    return


  cancel: () ->
    @resolve()

    @to.send({
      type: 'invite_cancelled'
      handle: @to_handle
    })

    return


  accept: (status) ->
    @resolve(status)

    @from.send({
      type: 'invite_response'
      handle: @from_handle
      accepted: true
    })

    return


  deny: () ->
    @resolve()

    @from.send({
      type: 'invite_response'
      handle: @from_handle
      accepted: false
    })

    return



class InvitationManager

  constructor: (@server, @rooms) ->
    @server.user_init (user) ->
      user.invites = {
        next_id: 0
        in: {}
        out: {}
      }

      user.on 'left', () ->
        for _, invite of user.invites.out
          invite.cancel()

        for _, invite of user.invites.in
          invite.deny()

    @server.command 'invite_send', {
      room: 'string'
      user: 'string'
      data: 'object'
    }, (user, msg) =>
      return @invite(user, msg.user, msg.room, msg.data)

    @server.command 'invite_cancel', {
      handle: 'number'
    }, (user, msg) =>
      return @cancel(user, msg.handle)

    @server.command 'invite_accept', {
      handle: 'number'
      status: 'object'
    }, (user, msg) =>
      return @accept(user, msg.handle, msg.status)

    @server.command 'invite_deny', {
      handle: 'number'
    }, (user, msg) =>
      return @deny(user, msg.handle)


  invite: (user, to_id, room_id, data) ->
    to = @server.users[to_id]

    if not to?
      throw new Error("Unknown recipient")

    room = @rooms.get_room(room_id, true)

    user_handle = user.invites.next_id++
    to_handle = to.invites.next_id++

    invitation = new Invitation(user, user_handle, to, to_handle, room)

    user.invites.out[user_handle] = invitation
    to.invites.in[to_handle] = invitation

    room.invite(to, invitation.promise)

    to.send({
      type: 'invite_incoming'
      handle: to_handle
      room: room.id
      peers: room.peers_object(to_id)
      status: room.status
      sender: user.id
      data: data
    })

    return {
      handle: user_handle
    }


  cancel: (user, handle) ->
    invitation = user.invites.out[handle]

    if not invitation?
      throw new Error("Invalid invitation handle")

    return invitation.cancel()


  accept: (user, handle, status) ->
    invitation = user.invites.in[handle]

    if not invitation?
      throw new Error("Invalid invitation handle")

    return invitation.accept(status)


  deny: (user, handle) ->
    invitation = user.invites.in[handle]

    if not invitation?
      throw new Error("Invalid invitation handle")

    return invitation.deny()


exports.InvitationManager = InvitationManager
