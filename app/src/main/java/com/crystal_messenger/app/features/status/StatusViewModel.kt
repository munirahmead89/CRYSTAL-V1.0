package com.crystal_messenger.app.features.status

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.crystal_messenger.app.core.database.StatusEntity
import com.crystal_messenger.app.core.database.UserEntity
import com.crystal_messenger.app.core.repository.ChatRepository
import com.crystal_messenger.app.core.repository.StorageRepository
import com.crystal_messenger.app.core.settings.SessionManager
import com.crystal_messenger.app.di.AppContainer
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class StatusGroup(
    val user: UserEntity,
    val statuses: List<StatusEntity>
)

class StatusViewModel(private val container: AppContainer) : ViewModel() {

    private val repo: ChatRepository = container.chatRepository
    private val session: SessionManager = container.sessionManager
    private val storage: StorageRepository = container.storageRepository

    val statuses: StateFlow<List<StatusGroup>> =
        combine(repo.observeStatuses(), repo.observeUsers()) { statusList, users ->
            val userMap = users.associateBy { it.id }
            statusList
                .groupBy { it.userId }
                .map { (userId, statuses) ->
                    StatusGroup(
                        user = userMap[userId] ?: UserEntity(id = userId, phone = "", name = "Unknown"),
                        statuses = statuses.sortedBy { it.createdAt }
                    )
                }
                .sortedByDescending { it.statuses.last().createdAt }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val myStatuses: StateFlow<List<StatusGroup>> = statuses.map { groups ->
        groups.filter { it.user.id == currentMeId }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private var currentMeId: String? = null

    init {
        viewModelScope.launch {
            currentMeId = session.current().userId
            repo.syncStatuses()
        }
    }

    fun postText(text: String) = viewModelScope.launch {
        repo.postStatus(text, null, "text")
    }

    fun postMedia(uri: Uri, mime: String) {
        viewModelScope.launch {
            val me = session.current().userId ?: return@launch
            val url = storage.uploadUri(me, uri, mime)
            if (!url.isNullOrBlank()) repo.postStatus("", url, if (mime.startsWith("video")) "video" else "image")
        }
    }

    fun view(statusId: String) = viewModelScope.launch {
        repo.viewStatus(statusId)
    }

    fun refresh() = viewModelScope.launch {
        repo.syncStatuses()
    }
}