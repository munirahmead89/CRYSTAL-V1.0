package com.crystal_messenger.app.features.calls

import android.content.Context
import com.crystal_messenger.app.di.AppContainer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Creates a call row through the repository and opens the full-screen call UI.
 */
object CallLauncher {

    fun startCall(
        context: Context,
        container: AppContainer,
        calleeId: String,
        calleeName: String? = null,
        calleeAvatar: String? = null,
        kind: String = "audio"
    ) {
        val scope = CoroutineScope(Dispatchers.IO)
        scope.launch {
            val call = container.chatRepository.createCall(calleeId, kind) ?: return@launch
            val user = container.chatRepository.findUser(calleeId)
            val name = calleeName ?: user?.name ?: "Unknown"
            val avatar = calleeAvatar ?: user?.avatarUrl
            context.startActivity(
                CallActivity.outgoingIntent(context, call.id, name, avatar, kind, calleeId)
            )
        }
    }
}