package com.crystal_messenger.app.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.crystal_messenger.app.CrystalApp
import com.crystal_messenger.app.R
import com.crystal_messenger.app.features.calls.IncomingCallActivity

class CallService : Service() {

    companion object {
        private const val CHANNEL_ID = "crystal_call"
        private const val NOTIF_ID = 7777
        const val EXTRA_CALL_ID = "call_id"
        const val EXTRA_NAME = "name"
        const val EXTRA_AVATAR = "avatar"

        fun start(context: Context, callId: String, name: String, avatar: String?) {
            val intent = Intent(context, CallService::class.java).apply {
                putExtra(EXTRA_CALL_ID, callId)
                putExtra(EXTRA_NAME, name)
                putExtra(EXTRA_AVATAR, avatar)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) = context.stopService(Intent(context, CallService::class.java))
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val name = intent?.getStringExtra(EXTRA_NAME) ?: "Crystal Call"
        startForeground(NOTIF_ID, buildNotification(name))
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Crystal Calls",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Active call notification"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(name: String): Notification {
        val fullScreenIntent = Intent(this, IncomingCallActivity::class.java).apply {
            putExtra(IncomingCallActivity.EXTRA_NAME, name)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.placeholder)
            .setContentTitle("Crystal Messenger")
            .setContentText("Active call with $name")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()
    }
}