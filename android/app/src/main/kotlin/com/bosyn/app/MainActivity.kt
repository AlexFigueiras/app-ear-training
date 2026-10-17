package com.bosyn.app

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Saída de áudio para o teste auditivo (lib/services/audio_output_service.dart):
        // volume de mídia (o teste exige volume fixo) e tipo de fone conectado. Sem pacote novo.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bosyn/audio_output")
            .setMethodCallHandler { call, result ->
                val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "mediaVolume" -> result.success(
                        mapOf(
                            "current" to audio.getStreamVolume(AudioManager.STREAM_MUSIC),
                            "max" to audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                        )
                    )
                    "outputRoute" -> result.success(outputRoute(audio))
                    else -> result.notImplemented()
                }
            }
        // Links externos (lib/services/external_links.dart): página de assinaturas do Google Play
        // e páginas legais. Só https; sem pacote novo.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bosyn/external")
            .setMethodCallHandler { call, result ->
                if (call.method != "openUrl") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.argument<String>("url")
                if (url == null || !url.startsWith("https://")) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }
    }

    private fun outputRoute(audio: AudioManager): String {
        val types = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type }.toSet()
        val wired = setOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
        )
        val bluetooth = setOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
        )
        return when {
            types.any { it in wired } -> "wired"
            types.any { it in bluetooth } -> "bluetooth"
            else -> "speaker"
        }
    }
}
