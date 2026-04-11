package com.example.a4safe_pulse

import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.a4safe_pulse/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSMS") {
                val phone = call.argument<String>("phone") ?: ""
                val message = call.argument<String>("message") ?: ""

                try {
                    sendSMSWithFallback(phone, message)
                    result.success("SMS sent")
                } catch (e: Exception) {
                    result.error("SMS_FAILED", e.message, null)
                }
            }
        }
    }

    private fun sendSMSWithFallback(phone: String, message: String) {

        // METHOD 1: Try using default SMS subscription ID (best for eSIM/dual SIM)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val defaultSubId = SubscriptionManager.getDefaultSmsSubscriptionId()
                val smsManager = applicationContext
                    .getSystemService(SmsManager::class.java)
                    .createForSubscriptionId(defaultSubId)
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                return // success, stop here
            } catch (e: Exception) {
                // failed, try next method
            }
        }

        // METHOD 2: Try using getDefault (works on older Android)
        try {
            @Suppress("DEPRECATION")
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            return // success, stop here
        } catch (e: Exception) {
            // failed, try next method
        }

        // METHOD 3: Last resort — open SMS app with message pre-filled
        try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("smsto:$phone")
                putExtra("sms_body", message)
                putExtra("exit_on_sent", true)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            applicationContext.startActivity(intent)
        } catch (e: Exception) {
            throw Exception("All SMS methods failed: ${e.message}")
        }
    }
}