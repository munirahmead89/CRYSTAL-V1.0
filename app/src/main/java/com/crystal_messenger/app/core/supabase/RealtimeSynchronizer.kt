package com.crystal_messenger.app.core.supabase

import com.crystal_messenger.app.core.repository.ChatRepository
import com.crystal_messenger.app.core.settings.SessionManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Bridges Supabase Realtime changes into the local Room database.
 * Also performs periodic background syncs for conversations, statuses and communities.
 */
class RealtimeSynchronizer(
    private val chatRepository: ChatRepository,
    private val realtime: RealtimeClient,
    private val session: SessionManager
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun start() {
        scope.launch {
            val s = session.current()
            if (!s.isLoggedIn) return@launch
            val token = s.accessToken.orEmpty()
            val meId = s.userId.orEmpty()

            // Connect WebSocket
            realtime.connect(token)

            // Wire all table change listeners
            subscribeAll()

            // Initial pull of remote data
            runCatching { chatRepository.syncConversations(meId) }
            runCatching { chatRepository.syncStatuses() }
            runCatching { chatRepository.syncCommunities() }

            // Presence heartbeat — mark user as online every 30s
            launch {
                while (isActive) {
                    runCatching {
                        chatRepository.touchPresence(meId, "online")
                    }
                    delay(30_000)
                }
            }

            // Periodic resync every 5 minutes in case WebSocket missed anything
            launch {
                while (isActive) {
                    delay(300_000)
                    runCatching { chatRepository.syncConversations(meId) }
                    runCatching { chatRepository.syncStatuses() }
                }
            }
        }
    }

    fun onUserLoggedIn() {
        scope.launch {
            val s = session.current()
            if (!s.isLoggedIn) return@launch
            val token = s.accessToken.orEmpty()
            realtime.setToken(token)
            subscribeAll()
            runCatching { chatRepository.syncConversations(s.userId.orEmpty()) }
            runCatching { chatRepository.syncStatuses() }
            runCatching { chatRepository.syncCommunities() }
        }
    }

    fun stop() {
        scope.launch {
            val meId = session.current().userId.orEmpty()
            runCatching { chatRepository.touchPresence(meId, "offline") }
        }
        realtime.disconnect()
    }

    private fun subscribeAll() {
        ingest("messages")
        ingest("conversations")
        ingest("conversation_members")
        ingest("users")
        ingest("calls")
        ingest("statuses")
        ingest("status_views")
        ingest("typing")
        ingest("communities")
        ingest("community_members")
        ingest("community_announcements")
    }

    private suspend fun ingest(table: String) {
        realtime.subscribe(table) { change ->
            when (change) {
                is Inserted -> push(table, change.row)
                is Updated  -> push(table, change.row)
                else        -> Unit
            }
        }
    }

    private fun push(table: String, row: kotlinx.serialization.json.JsonObject) {
        scope.launch(Dispatchers.IO) {
            runCatching { chatRepository.onRealtimeChange(row, table) }
        }
    }
}