package com.crystal_messenger.app.features.chats

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.crystal_messenger.app.core.database.ConversationEntity
import com.crystal_messenger.app.core.database.MemberDao
import com.crystal_messenger.app.core.database.UserEntity
import com.crystal_messenger.app.core.database.isGroup
import com.crystal_messenger.app.core.repository.ChatRepository
import com.crystal_messenger.app.core.settings.SessionManager
import com.crystal_messenger.app.core.supabase.Inserted
import com.crystal_messenger.app.core.supabase.RealtimeClient
import com.crystal_messenger.app.core.supabase.Updated
import com.crystal_messenger.app.di.AppContainer
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.serialization.json.jsonPrimitive

data class ConversationItem(
    val id: String,
    val title: String,
    val avatarUrl: String?,
    val subtitle: String,
    val time: Long,
    val unread: Int,
    val isGroup: Boolean,
    val online: Boolean,
    val typing: Boolean
)

@OptIn(ExperimentalCoroutinesApi::class)
class ChatsViewModel(private val container: AppContainer) : ViewModel() {

    private val repo: ChatRepository = container.chatRepository
    private val session: SessionManager = container.sessionManager
    private val memberDao: MemberDao = container.db.memberDao()
    private val realtime: RealtimeClient = container.realtime

    private val meId = MutableStateFlow<String?>(null)
    private val typing = MutableStateFlow<Set<String>>(emptySet())

    private val membersFlow: Flow<Map<String, Set<String>>> =
        repo.observeConversations()
            .distinctUntilChanged()
            .flatMapLatest { convs ->
                if (convs.isEmpty()) {
                    flowOf(emptyMap())
                } else {
                    combine(
                        convs.map { conv ->
                            memberDao.observeMembers(conv.id)
                                .map { members -> conv.id to members.map { it.userId }.toSet() }
                                .distinctUntilChanged()
                        }
                    ) { arrays ->
                        arrays.map { it as Pair<String, Set<String>> }.toMap()
                    }
                }
            }

    val conversations: StateFlow<List<ConversationItem>> =
        combine(
            repo.observeConversations(),
            membersFlow,
            repo.observeUsers(),
            typing,
            meId
        ) { convs, membersMap, users, typingNow, myId ->
            val userMap = users.associateBy { it.id }
            convs.map { conv ->
                val members = membersMap[conv.id].orEmpty()
                val otherId = members.firstOrNull { it != myId }
                val group = conv.ctype == "group"
                ConversationItem(
                    id = conv.id,
                    title = if (group) conv.name.ifBlank { "Group" } else userMap[otherId]?.name ?: "Unknown",
                    avatarUrl = if (group) conv.avatarUrl else userMap[otherId]?.avatarUrl,
                    subtitle = preview(conv, userMap[conv.lastMessageBy]),
                    time = conv.updatedAt,
                    unread = conv.unreadCount,
                    isGroup = group,
                    online = !group && userMap[otherId]?.status == "online",
                    typing = conv.id in typingNow
                )
            }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        viewModelScope.launch {
            meId.value = session.current().userId
            refresh()
            watchTyping()
        }
    }

    fun refresh() {
        viewModelScope.launch {
            val myId = meId.value.orEmpty()
            runCatching { repo.syncConversations(myId) }
            runCatching {
                repo.observeConversations().first().forEach { conv ->
                    runCatching { repo.syncMembers(conv.id) }
                }
            }
            runCatching { repo.syncStatuses() }
        }
    }

    private fun preview(conv: ConversationEntity, sender: UserEntity?): String {
        val prefix = if (conv.isGroup && sender != null) "${sender.name}: " else ""
        return prefix + conv.lastMessageText
    }

    private fun watchTyping() {
        viewModelScope.launch {
            realtime.changesFor("typing").collect { change ->
                val row = (change as? Inserted)?.row ?: (change as? Updated)?.row ?: return@collect
                val convId = row["conversation_id"]?.jsonPrimitive?.content.orEmpty()
                val userId = row["user_id"]?.jsonPrimitive?.content.orEmpty()
                val isTyping = row["is_typing"]?.jsonPrimitive?.content == "true"
                val currentMe = meId.value
                if (convId.isBlank() || userId == currentMe) return@collect
                typing.value = if (isTyping) typing.value + convId else typing.value - convId
            }
        }
    }
}