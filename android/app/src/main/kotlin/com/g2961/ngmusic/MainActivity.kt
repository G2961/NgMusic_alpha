package com.g2961.ngmusic

import android.webkit.CookieManager
import com.g2961.ngmusic.player.PlaybackBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var playbackBridge: PlaybackBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Cookie channel — reads HttpOnly session cookies for login
        MethodChannel(messenger, "ngmusic/cookies").setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url") ?: ""
                    result.success(CookieManager.getInstance().getCookie(url) ?: "")
                }
                "clearCookies" -> {
                    CookieManager.getInstance().removeAllCookies(null)
                    CookieManager.getInstance().flush()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Playback bridge — Media3 MediaSessionService ↔ Flutter
        playbackBridge = PlaybackBridge(this, messenger)
    }

    override fun onDestroy() {
        playbackBridge?.release()
        super.onDestroy()
    }
}
