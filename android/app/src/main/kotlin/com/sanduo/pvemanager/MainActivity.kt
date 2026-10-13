package com.sanduo.pvemanager

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.URI

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "com.sanduo.pvemanager/webview_security"
        private const val AUTH_COOKIE_NAME = "PVEAuthCookie"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        CookieManager.getInstance().removeSessionCookies(null)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureCookie" -> setSecureCookie(call, result)
                    "clearAuthCookie" -> clearAuthCookie(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun setSecureCookie(call: MethodCall, result: MethodChannel.Result) {
        val origin = canonicalHttpsOrigin(call.argument<String>("origin"))
        val ticket = call.argument<String>("ticket")

        if (origin == null) {
            result.error("invalid_origin", "A valid HTTPS origin is required.", null)
            return
        }
        if (
            ticket.isNullOrEmpty() ||
                ticket.any { it <= ' ' || it >= '\u007f' || it == '"' || it == ',' || it == ';' || it == '\\' }
        ) {
            result.error("invalid_ticket", "The PVE ticket contains invalid cookie characters.", null)
            return
        }

        // PVE's official workspace reads this cookie in authOK() before it
        // starts noVNC/xterm.js, so HttpOnly would force its login window.
        val cookie = "$AUTH_COOKIE_NAME=$ticket; Path=/; Secure; SameSite=Strict"
        val manager = CookieManager.getInstance()
        manager.setAcceptCookie(true)
        manager.setCookie(origin, cookie) { accepted ->
            if (accepted) {
                result.success(true)
            } else {
                result.error("cookie_rejected", "Android WebView rejected the auth cookie.", null)
            }
        }
    }

    private fun clearAuthCookie(call: MethodCall, result: MethodChannel.Result) {
        val origin = canonicalHttpsOrigin(call.argument<String>("origin"))
        if (origin == null) {
            result.error("invalid_origin", "A valid HTTPS origin is required.", null)
            return
        }

        val expiredCookie =
            "$AUTH_COOKIE_NAME=; Path=/; Max-Age=0; Secure; SameSite=Strict"
        val manager = CookieManager.getInstance()
        manager.setCookie(origin, expiredCookie) { accepted ->
            result.success(accepted)
        }
    }

    private fun canonicalHttpsOrigin(value: String?): String? {
        if (value.isNullOrBlank()) return null

        return try {
            val uri = URI(value)
            if (
                !uri.scheme.equals("https", ignoreCase = true) ||
                    uri.host.isNullOrBlank() ||
                    (uri.port != -1 && uri.port !in 1..65535) ||
                    uri.rawUserInfo != null ||
                    uri.rawQuery != null ||
                    uri.rawFragment != null ||
                    (uri.rawPath?.isNotEmpty() == true && uri.rawPath != "/")
            ) {
                null
            } else {
                URI("https", null, uri.host, uri.port, null, null, null).toASCIIString()
            }
        } catch (_: Exception) {
            null
        }
    }
}
