package fr.domotique.deltahome

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Coupe les bips de la reconnaissance vocale pendant l'écoute du prénom.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "domus/audio")
            .setMethodCallHandler { call, result ->
                if (call.method == "muteBeeps") {
                    val mute = call.argument<Boolean>("mute") ?: false
                    val audio = getSystemService(AUDIO_SERVICE) as AudioManager
                    val direction = if (mute) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE
                    for (stream in intArrayOf(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.STREAM_SYSTEM,
                        AudioManager.STREAM_NOTIFICATION,
                    )) {
                        try {
                            audio.adjustStreamVolume(stream, direction, 0)
                        } catch (e: Exception) {
                            // Mode Ne pas déranger : réglage refusé, sans gravité.
                        }
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
