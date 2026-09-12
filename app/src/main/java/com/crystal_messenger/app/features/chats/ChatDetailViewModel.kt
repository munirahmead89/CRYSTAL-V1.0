package com.crystal_messenger.app.features.chats

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.crystal_messenger.app.core.database.ConversationEntity
import com.crystal_messenger.app.core.database.MemberDao
import com.crystal_messenger.app.core.database.MessageEntity
import com.crystal_messenger.app.core.repository.ChatRepository
import com.crystal_messenger.app.core.repository.StorageRepository
import com.crystal_messenger.app.core.settings.SessionManager
import com.crystal_messenger.app.core.supabase.Inserted
import com.crystal_messenger.app.core.supabase.RealtimeClient
import com.crystal_messenger.app.core.supabase.Updated
import com.crystal_messenger.app.di.AppContainer
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.serialization.json.jsonPrimitive

data class ChatUiState(
    val conversation: ConversationEntity? = null,
    val title: String = "",
    val avatarUrl: String? = null,
    val online: Boolean = false,
    val typingPeer: Boolean = false,
    val sending: Boolean = false,
    val meId: String? = null,
    val peerId: String? = null
)

class ChatDetailViewModel(
    private val container: AppContainer,
    private val conversationId: String
) : ViewModel() {

    private val repo: ChatRepository = container.chatRepository
    private val realtime: RealtimeClient = container.realtime
    private val session: SessionManager = container.sessionManager
    private val storage: StorageRepository = container.storageRepository
    private val memberDao: MemberDao = container.db.memberDao()

    var messages: StateFlow<List<MessageEntity>> =
        repo.observeMessages(conversationId)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private var currentMe: String? = null

    private val meIdFlow = MutableStateFlow<String?>(null)

    private val repoTyping = realtime.changesFor("typing")
        .map { change ->
            val row = (change as? Inserted)?.row ?: (change as? Updated)?.row ?: return@map false
            row["conversation_id"]?.jsonPrimitive?.content == conversationId &&
                row["is_typing"]?.jsonPrimitive?.content == "true" &&
                row["user_id"]?.jsonPrimitive?.content != currentMe
        }
        .distinctUntilChanged()

    private val uiState: StateFlow<ChatUiState> = combine(
        repo.observeConversation(conversationId),
        memberDao.observeMembers(conversationId),
        repo.observeUsers(),
        repoTyping,
        meIdFlow
    ) { conv, members, users, typing, me ->
        val other = members.firstOrNull { it.userId != me }?.userId
        val peer = users.firstOrNull { it.id == other }
        ChatUiState(
            conversation = conv,
            title = conv?.name?.takeIf { conv.ctype == "group" } ?: peer?.name ?: "Chat",
            avatarUrl = peer?.avatarUrl,
            online = peer?.status == "online" && conv?.ctype != "group",
            typingPeer = typing,
            meId = me,
            peerId = other
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), ChatUiState())

    val state: StateFlow<ChatUiState> = uiState

    private var typingJob: Job? = null

    init {
        viewModelScope.launch {
            currentMe = session.current().userId
            meIdFlow.value = currentMe
            repo.syncRecentMessages(conversationId)
            repo.syncMembers(conversationId)
            repo.markRead(conversationId)
        }
    }

    fun sendText(text: String) {
        val me = currentMe ?: return
        viewModelScope.launch {
            repo.sendMessage(conversationId, me, text)
            repo.markRead(conversationId)
        }
    }

    fun sendReplyTo(reply: MessageEntity, text: String) {
        val me = currentMe ?: return
        viewModelScope.launch {
            repo.sendMessage(conversationId, me, text, replyToId = reply.id)
        }
    }

    fun sendMedia(uri: Uri, mime: String) {
        val me = currentMe ?: return
        viewModelScope.launch {
            val url = storage.uploadUri(me, uri, mime)
            val type = when {
                mime.startsWith("image") -> "image"
                mime.startsWith("video") -> "video"
                else -> "file"
            }
            repo.sendMessage(conversationId, me, "", mtype = type, mediaUrl = url)
        }
    }

    fun onTypingChange(isTyping: Boolean) {
        val me = currentMe ?: return
        typingJob?.cancel()
        typingJob = viewModelScope.launch {
            repo.setTyping(conversationId, isTyping)
        }
        typingJob = null
    }

    fun markRead() = viewModelScope.launch { repo.markRead(conversationId) }

    fun onMessageVisible() = viewModelScope.launch { repo.markRead(conversationId) }

    // ── voice notes ────────────────────────────────────────

    private var recorder: android.media.MediaRecorder? = null
    private var voiceFile: java.io.File? = null

    val isRecording = MutableStateFlow(false)

    fun startVoiceNote(context: android.content.Context): Boolean = try {
        val file = java.io.File(context.cacheDir, "voice_${System.currentTimeMillis()}.m4a")
        val rec = if (android.os.Build.VERSION.SDK_INT >= 31) {
            android.media.MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            android.media.MediaRecorder()
        }
        rec.setAudioSource(android.media.MediaRecorder.AudioSource.MIC)
        rec.setOutputFormat(android.media.MediaRecorder.OutputFormat.MPEG_4)
        rec.setAudioEncoder(android.media.MediaRecorder.AudioEncoder.AAC)
        rec.setAudioSamplingRate(44100)
        rec.setOutputFile(file.absolutePath)
        rec.prepare()
        rec.start()
        recorder = rec
        voiceFile = file
        isRecording.value = true
        true
    } catch (e: Exception) {
        false
    }

    fun stopVoiceNoteAndSend() {
        try {
            recorder?.let {
                runCatching { it.stop() }
                it.release()
            }
        } catch (_: Exception) {}
        recorder = null
        isRecording.value = false
        val file = voiceFile
        voiceFile = null
        val me = currentMe ?: return
        if (file != null && file.exists() && file.length() > 0) {
            viewModelScope.launch {
                val url = storage.uploadFile(me, file, "audio/mp4")
                if (url != null) {
                    repo.sendMessage(
                        conversationId, me, "",
                        mtype = "audio",
                        mediaUrl = url,
                        mediaDuration = (file.length() / 44100.0 / 2.0)
                    )
                }
            }
        }
        file?.delete()
    }
}