package com.g2961.ngmusic.player

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

class PlaybackBridge(private val context: Context, messenger: BinaryMessenger) {

    companion object {
        var instance: PlaybackBridge? = null
    }

    private val methodChannel = MethodChannel(messenger, "ngmusic/player")
    private val eventChannel = EventChannel(messenger, "ngmusic/player/events")

    private var eventSink: EventChannel.EventSink? = null
    private var controller: MediaController? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { cmd -> mainHandler.post(cmd) }
    private var positionRunnable: Runnable? = null

    private val playerListener = object : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emit(mapOf("type" to "playing", "value" to isPlaying))
            if (isPlaying) startPositionUpdates() else stopPositionUpdates()
        }

        override fun onPlaybackStateChanged(state: Int) {
            val s = when (state) {
                Player.STATE_IDLE      -> "idle"
                Player.STATE_BUFFERING -> "buffering"
                Player.STATE_READY     -> "ready"
                Player.STATE_ENDED     -> "ended"
                else                   -> "idle"
            }
            emit(mapOf("type" to "state", "value" to s))
            if (state == Player.STATE_READY) {
                val dur = controller?.duration?.takeIf { it > 0 } ?: 0L
                emit(mapOf("type" to "duration", "value" to dur))
            }
        }
    }

    init {
        instance = this

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                connectController()
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
                stopPositionUpdates()
            }
        })

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val url = call.argument<String>("url")
                        ?: return@setMethodCallHandler result.error("BAD_ARGS", "url required", null)
                    play(
                        url = url,
                        title = call.argument<String>("title") ?: "",
                        artist = call.argument<String>("artist") ?: "",
                        artworkUri = call.argument<String>("artworkUri")
                    )
                    result.success(null)
                }
                "pause"     -> { controller?.pause(); result.success(null) }
                "resume"    -> { controller?.play();  result.success(null) }
                "stop"      -> { controller?.stop();  result.success(null) }
                "seek"      -> {
                    val pos = call.argument<Number>("position")?.toLong() ?: 0L
                    controller?.seekTo(pos)
                    result.success(null)
                }
                "getPosition" -> result.success(controller?.currentPosition ?: 0L)
                else -> result.notImplemented()
            }
        }
    }

    private fun connectController() {
        val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
        val future = MediaController.Builder(context, token).buildAsync()
        future.addListener({
            try {
                controller = future.get()
                controller?.addListener(playerListener)
            } catch (_: Exception) {}
        }, mainExecutor)
    }

    private fun play(url: String, title: String, artist: String, artworkUri: String?) {
        val meta = MediaMetadata.Builder()
            .setTitle(title)
            .setArtist(artist)
            .apply { artworkUri?.let { setArtworkUri(Uri.parse(it)) } }
            .build()
        val mediaItem = MediaItem.Builder()
            .setUri(url)
            .setMediaMetadata(meta)
            .build()
        controller?.run {
            setMediaItem(mediaItem)
            prepare()
            play()
        }
    }

    private fun startPositionUpdates() {
        stopPositionUpdates()
        val r = object : Runnable {
            override fun run() {
                val pos = controller?.currentPosition ?: 0L
                emit(mapOf("type" to "position", "value" to pos))
                mainHandler.postDelayed(this, 500)
            }
        }
        positionRunnable = r
        mainHandler.postDelayed(r, 500)
    }

    private fun stopPositionUpdates() {
        positionRunnable?.let { mainHandler.removeCallbacks(it) }
        positionRunnable = null
    }

    fun emitCommand(cmd: String) {
        emit(mapOf("type" to "command", "value" to cmd))
    }

    private fun emit(data: Any) {
        mainHandler.post { eventSink?.success(data) }
    }

    fun release() {
        instance = null
        stopPositionUpdates()
        controller?.removeListener(playerListener)
        controller = null
    }
}
