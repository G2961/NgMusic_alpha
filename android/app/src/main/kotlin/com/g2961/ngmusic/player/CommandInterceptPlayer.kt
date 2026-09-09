package com.g2961.ngmusic.player

import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.Player

class CommandInterceptPlayer(player: Player) : ForwardingPlayer(player) {

    var onNextRequested: (() -> Unit)? = null
    var onPrevRequested: (() -> Unit)? = null

    override fun seekToNext() { onNextRequested?.invoke() }
    override fun seekToNextMediaItem() { onNextRequested?.invoke() }
    override fun seekToPrevious() { onPrevRequested?.invoke() }
    override fun seekToPreviousMediaItem() { onPrevRequested?.invoke() }

    override fun isCommandAvailable(command: Int): Boolean {
        if (command == COMMAND_SEEK_TO_NEXT ||
            command == COMMAND_SEEK_TO_NEXT_MEDIA_ITEM ||
            command == COMMAND_SEEK_TO_PREVIOUS ||
            command == COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM
        ) return true
        return super.isCommandAvailable(command)
    }

    override fun getAvailableCommands(): Player.Commands {
        return super.getAvailableCommands().buildUpon()
            .add(COMMAND_SEEK_TO_NEXT)
            .add(COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
            .add(COMMAND_SEEK_TO_PREVIOUS)
            .add(COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
            .build()
    }
}
