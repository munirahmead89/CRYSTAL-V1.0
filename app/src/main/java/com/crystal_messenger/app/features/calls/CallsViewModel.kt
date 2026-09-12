package com.crystal_messenger.app.features.calls

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.crystal_messenger.app.core.database.CallEntity
import com.crystal_messenger.app.core.database.UserEntity
import com.crystal_messenger.app.core.repository.ChatRepository
import com.crystal_messenger.app.core.settings.SessionManager
import com.crystal_messenger.app.di.AppContainer
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class CallItem(
    val call: CallEntity,
    val otherId: String,
    val name: String,
    val avatarUrl: String?,
    val incoming: Boolean,
    val missed: Boolean
)

class CallsViewModel(private val container: AppContainer) : ViewModel() {

    private val repo: ChatRepository = container.chatRepository
    private val session: SessionManager = container.sessionManager

    private var meId: String? = null

    val calls: StateFlow<List<CallItem>> =
        combine(repo.observeCalls(), repo.observeUsers()) { calls, users ->
            val userMap = users.associateBy { it.id }
            calls.sortedByDescending { it.startedAt }.map { call ->
                val incoming = call.callerId != meId
                val otherId = if (incoming) call.callerId else call.calleeId
                val user = userMap[otherId]
                CallItem(
                    call = call,
                    otherId = otherId,
                    name = user?.name ?: "Unknown",
                    avatarUrl = user?.avatarUrl,
                    incoming = incoming,
                    missed = call.status == "missed"
                )
            }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        viewModelScope.launch {
            meId = session.current().userId
        }
    }

    suspend fun startCall(calleeId: String, kind: String = "audio"): CallEntity? =
        repo.createCall(calleeId, kind)?.let { dto ->
            CallEntity(
                id = dto.id,
                conversationId = dto.conversationId,
                callerId = dto.callerId,
                calleeId = dto.calleeId,
                kind = dto.kind,
                status = dto.status,
                startedAt = java.time.Instant.parse(dto.startedAt).toEpochMilli(),
                duration = 0
            )
        }

    fun refresh() = viewModelScope.launch { }
}