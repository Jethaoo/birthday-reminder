package com.birthdayreminder.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Hosts the Flutter UI and registers the FCM notification channels.
 *
 * From Android 8 the *channel* decides whether a notification makes a sound, so
 * reminders are delivered on one of two channels and the backend picks the
 * channel from the user's "notification sound" preference.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return

        val audible = NotificationChannel(
            CHANNEL_AUDIBLE,
            getString(R.string.notification_channel_audible),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.notification_channel_audible_description)
            enableVibration(true)
        }

        val silent = NotificationChannel(
            CHANNEL_SILENT,
            getString(R.string.notification_channel_silent),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = getString(R.string.notification_channel_silent_description)
            setSound(null, null)
            enableVibration(false)
        }

        manager.createNotificationChannels(listOf(audible, silent))
    }

    private companion object {
        const val CHANNEL_AUDIBLE = "birthday_reminders"
        const val CHANNEL_SILENT = "birthday_reminders_silent"
    }
}
