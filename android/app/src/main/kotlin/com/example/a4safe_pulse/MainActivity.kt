package com.example.a4safe_pulse

import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
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

                var sent = false

                // TRY 1: Use active subscription
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val sm = getSystemService(SmsManager::class.java)
                        val subManager = getSystemService(SubscriptionManager::class.java)
                        val subs = subManager?.activeSubscriptionInfoList
                        if (!subs.isNullOrEmpty()) {
                            val subId = subs[0].subscriptionId
                            val smsManager = sm.createForSubscriptionId(subId)
                            val parts = smsManager.divideMessage(message)
                            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            sent = true
                        }
                    } catch (e: Exception) {
                        sent = false
                    }
                }

                // TRY 2: Use getDefault
                if (!sent) {
                    try {
                        @Suppress("DEPRECATION")
                        val smsManager = SmsManager.getDefault()
                        val parts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                        sent = true
                    } catch (e: Exception) {
                        sent = false
                    }
                }

                // TRY 3: createForSubscriptionId(1)
                if (!sent && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val smsManager = getSystemService(SmsManager::class.java)
                            .createForSubscriptionId(1)
                        val parts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                        sent = true
                    } catch (e: Exception) {
                        sent = false
                    }
                }

                if (sent) {
                    result.success("SMS sent")
                } else {
                    result.error("SMS_FAILED", "All methods failed", null)
                }
            }
        }
    }
}