package dev.vela.browser

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import androidx.webkit.ProfileStore
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native glue that flutter_inappwebview does not provide:
 *
 * - `vela/webview_profile`: real cookie/storage isolation for private tabs using
 *   the AndroidX WebView multi-profile API. A private tab's WebView is created
 *   with no initial URL, attached to a dedicated profile here, and only then
 *   loads its page. The profile is deleted when the private session ends.
 * - `vela/pip`: Picture-in-Picture for fullscreen web video.
 */
class MainActivity : FlutterActivity() {
    private var pipChannel: MethodChannel? = null
    private var autoPipArmed = false
    private var pipAspect = Rational(16, 9)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "vela/webview_profile").setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isMultiProfileSupported())
                "attach" -> {
                    val keepAliveId = call.argument<String>("keepAliveId")
                    val profile = call.argument<String>("profile")
                    if (keepAliveId == null || profile == null || !isMultiProfileSupported()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val plugin = flutterEngine.plugins.get(InAppWebViewFlutterPlugin::class.java)
                        as? InAppWebViewFlutterPlugin
                    val webView = plugin?.inAppWebViewManager?.keepAliveWebViews?.get(keepAliveId)?.webView
                    if (webView == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        ProfileStore.getInstance().getOrCreateProfile(profile)
                        WebViewCompat.setProfile(webView, profile)
                        result.success(WebViewCompat.getProfile(webView).name == profile)
                    } catch (e: IllegalStateException) {
                        // WebView already used: refuse rather than share the default profile.
                        result.success(false)
                    }
                }
                "deleteProfiles" -> {
                    val prefix = call.argument<String>("prefix") ?: ""
                    if (prefix.isEmpty() || !isMultiProfileSupported()) {
                        result.success(0)
                        return@setMethodCallHandler
                    }
                    var deleted = 0
                    val store = ProfileStore.getInstance()
                    for (name in store.allProfileNames) {
                        if (!name.startsWith(prefix)) continue
                        try {
                            if (store.deleteProfile(name)) deleted++
                        } catch (e: IllegalStateException) {
                            // Still in use by a live WebView; retried on next launch.
                        }
                    }
                    result.success(deleted)
                }
                else -> result.notImplemented()
            }
        }

        pipChannel = MethodChannel(messenger, "vela/pip").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(isPipSupported())
                    "enter" -> result.success(enterPip())
                    "setAuto" -> {
                        autoPipArmed = call.argument<Boolean>("enabled") == true
                        val w = call.argument<Int>("width") ?: 16
                        val h = call.argument<Int>("height") ?: 9
                        pipAspect = clampAspect(w, h)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && isPipSupported()) {
                            setPictureInPictureParams(
                                PictureInPictureParams.Builder()
                                    .setAspectRatio(pipAspect)
                                    .setAutoEnterEnabled(autoPipArmed)
                                    .build()
                            )
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun isMultiProfileSupported(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)

    private fun isPipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature("android.software.picture_in_picture")

    /** Android requires an aspect ratio between 1:2.39 and 2.39:1. */
    private fun clampAspect(w: Int, h: Int): Rational {
        if (w <= 0 || h <= 0) return Rational(16, 9)
        val r = w.toDouble() / h
        return when {
            r > 2.39 -> Rational(239, 100)
            r < 1 / 2.39 -> Rational(100, 239)
            else -> Rational(w, h)
        }
    }

    private fun enterPip(): Boolean {
        if (!isPipSupported() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder().setAspectRatio(pipAspect).build()
            )
        } catch (e: IllegalStateException) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Android 12+ handles this via setAutoEnterEnabled.
        if (autoPipArmed && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) enterPip()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
    }
}
