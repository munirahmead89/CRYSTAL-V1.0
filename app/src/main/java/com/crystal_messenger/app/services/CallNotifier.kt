package com.crystal_messenger.app.services

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.crystal_messenger.app.R
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.features.calls.IncomingCallActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Watches the local call log for newly arrived "ringing" calls where I am the
 * callee and surfaces an OS-level full-screen incoming call notification.
 */
class CallNotifier(
    private val container: AppContainer,
    private val context: Context
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val processed = mutableSetOf<String>()
    private var meId: String? = null

    fun start() {
        scope.launch {
            meId = container.sessionManager.current().userId
            ensureChannel(context)
            container.db.callDao().observeAll().collect { calls ->
                for (call in calls) {
                    if (call.status == "ringing" && call.calleeId == meId && call.id !in processed) {
                        processed += call.id
                        showIncoming(call.id, call.callerId)
                    }
                }
            }
        }
    }

    fun stop() {
        scope.cancel()
    }

    private suspend fun showIncoming(callId: String, callerId: String) = withContext(Dispatchers.Main) {
        ensureChannel(context)
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) return@withContext

        val activityIntent = Intent(context, IncomingCallActivity::class.java).apply {
            putExtra(IncomingCallActivity.EXTRA_CALL_ID, callId)
            putExtra(IncomingCallActivity.EXTRA_NAME, "Crystal call")
            putExtra("targetUserId", callerId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val fullScreen = PendingIntent.getActivity(
            context, callId.hashCode(), activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.placeholder)
            .setContentTitle("Incoming crystal call")
            .setContentText("Tap to answer")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreen, true)
            .setAutoCancel(false)
            .setOngoing(true)
            .build()

        withContext(Dispatchers.IO) {
            runCatching { NotificationManagerCompat.from(context).notify(callId.hashCode(), notification) }
        }
    }

    companion object {
        private const val CHANNEL_ID = "crystal_incoming"

        private fun ensureChannel(ctx: Context) {
            val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Incoming calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Show incoming call alerts"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }
    }
}