package com.crystal_messenger.app.core.repository

import com.crystal_messenger.app.core.database.CallDao
import com.crystal_messenger.app.core.database.CallEntity
import com.crystal_messenger.app.core.database.CommunityDao
import com.crystal_messenger.app.core.database.CommunityEntity
import com.crystal_messenger.app.core.database.ConversationDao
import com.crystal_messenger.app.core.database.ConversationEntity
import com.crystal_messenger.app.core.database.MemberDao
import com.crystal_messenger.app.core.database.MessageDao
import com.crystal_messenger.app.core.database.MessageEntity
import com.crystal_messenger.app.core.database.StatusDao
import com.crystal_messenger.app.core.database.StatusEntity
import com.crystal_messenger.app.core.database.UserDao
import com.crystal_messenger.app.core.database.UserEntity
import com.crystal_messenger.app.core.network.CallDto
import com.crystal_messenger.app.core.network.CommunityDto
import com.crystal_messenger.app.core.network.ConversationDto
import com.crystal_messenger.app.core.network.CrystalJson
import com.crystal_messenger.app.core.network.MessageDto
import com.crystal_messenger.app.core.network.StatusDto
import com.crystal_messenger.app.core.network.UserDto
import com.crystal_messenger.app.core.settings.SessionManager
import com.crystal_messenger.app.core.supabase.Deleted
import com.crystal_messenger.app.core.supabase.Inserted
import com.crystal_messenger.app.core.supabase.SupabaseClient
import com.crystal_messenger.app.core.supabase.Updated
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import java.util.UUID

class ChatRepository(
    private val api: SupabaseClient,
    private val session: SessionManager,
    private val userDao: UserDao,
    private val convDao: ConversationDao,
    private val memberDao: MemberDao,
    private val msgDao: MessageDao,
    private val statusDao: StatusDao,
    private val callDao: CallDao,
    private val communityDao: CommunityDao
) {

    suspend fun meId(): String = session.current().userId.orEmpty()

    suspend fun touchPresence(userId: String, status: String) {
        if (userId.isBlank()) return
        try {
            api.rpc("touch_presence", buildJsonObject {
                put("uid", JsonPrimitive(userId))
                put("s", JsonPrimitive(status))
            })
        } catch (_: Exception) {}
    }

    fun observeUsers(): kotlinx.coroutines.flow.Flow<List<UserEntity>> = userDao.observeAllUsers()

    fun observeUser(userId: String): kotlinx.coroutines.flow.Flow<UserEntity?> = userDao.observeUser(userId)

    suspend fun getConversation(conversationId: String): ConversationEntity? = convDao.get(conversationId)

    fun observeConversation(conversationId: String): kotlinx.coroutines.flow.Flow<ConversationEntity?> =
        convDao.observeById(conversationId)

    // ── users ──────────────────────────────────────────────

    suspend fun searchUsers(phone: String): List<UserDto> = try {
        parseUsers(api.select("users", filters = mapOf("phone" to "eq.${phone.trim()}"), limit = 5))
    } catch (_: Exception) { emptyList() }

    suspend fun searchUsersByNameOrPhone(q: String): List<UserDto> {
        val me = meId()
        val term = q.trim()
        if (term.isBlank()) return emptyList()
        return try {
            api.select(
                "users",
                select = "id,phone,name,about,avatar_url,status,last_seen",
                filters = mapOf(
                    "or" to "(name.ilike.*$term*,phone.ilike.*$term*)"
                ),
                limit = 20
            ).let { parseUsers(it) }.filter { it.id != me }
        } catch (_: Exception) { emptyList() }
    }

    suspend fun allUsers(): List<UserDto> = try {
        val me = meId()
        parseUsers(api.select("users", select = "id,phone,name,about,avatar_url,status,last_seen", limit = 5000))
            .filter { it.id != me }
            .sortedBy { it.name.lowercase() }
    } catch (_: Exception) { emptyList() }

    suspend fun findUser(userId: String): UserDto? = try {
        api.selectOne("users", filters = mapOf("id" to "eq.$userId"))?.let { parseUser(it) }
    } catch (_: Exception) { null }

    // ── conversations ──────────────────────────────────────

    fun observeConversations() = convDao.observeAll()

    suspend fun createConversation(memberIds: List<String>, type: String = "single"): ConversationDto? {
        val result = api.rpc("find_or_create_conversation", buildJsonObject {
            put("p_member_ids", buildJsonArray { memberIds.forEach { add(JsonPrimitive(it)) } })
            put("p_name", JsonPrimitive(""))
            put("p_type", JsonPrimitive(type))
        })
        val row = (result as? JsonObject) ?: result.jsonObject
        val conv = parseConversation(row) ?: return null
        convDao.upsert(conv.toEntity())
        return conv
    }

    suspend fun syncConversations(meId: String) {
        val rows = try {
            api.select("conversations", order = "last_message_at.desc")
        } catch (_: Exception) { return }
        convDao.upsertAll(parseConversations(rows).map { it.toEntity() })
    }

    suspend fun syncMembers(conversationId: String) {
        val me = meId()
        val rows = api.select(
            "conversation_members",
            select = "*, users!inner(*)",
            filters = mapOf("conversation_id" to "eq.$conversationId")
        )
        // users!inner embeds the user as a nested object
        rows.forEach { row ->
            val nested = row.jsonObject["users"] as? JsonObject ?: return@forEach
            val user = parseUser(nested)
            userDao.upsert(user.toEntity())
            memberDao.upsertAll(listOf(com.crystal_messenger.app.core.database.ConversationMemberEntity(
                conversationId = conversationId,
                userId = user.id
            )))
        }
    }

    suspend fun markRead(conversationId: String) {
        convDao.clearUnread(conversationId)
        val me = meId().takeIf { it.isNotBlank() } ?: return
        try {
            api.rpc("mark_conversation_read", buildJsonObject { put("p_conversation", JsonPrimitive(conversationId)) })
        } catch (_: Exception) {}
    }

    // ── messages ───────────────────────────────────────────

    fun observeMessages(conversationId: String) = msgDao.observeMessages(conversationId)

    suspend fun membersOf(conversationId: String): List<String> = memberDao.memberIds(conversationId)

    suspend fun sendMessage(
        conversationId: String,
        senderId: String,
        text: String,
        mtype: String = "text",
        mediaUrl: String? = null,
        mediaDuration: Double? = null,
        replyToId: String? = null
    ): MessageEntity {
        val id = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        val msg = MessageEntity(
            id = id,
            conversationId = conversationId,
            senderId = senderId,
            mtype = mtype,
            body = text,
            mediaUrl = mediaUrl,
            mediaDuration = mediaDuration,
            replyToId = replyToId,
            createdAt = now,
            pendingSync = true
        )
        msgDao.insert(msg)
        try {
            api.insert("messages", buildJsonObject {
                put("id", JsonPrimitive(id))
                put("conversation_id", JsonPrimitive(conversationId))
                put("sender_id", JsonPrimitive(senderId))
                put("mtype", JsonPrimitive(mtype))
                if (text.isNotBlank()) put("body", JsonPrimitive(text))
                if (mediaUrl != null) put("media_url", JsonPrimitive(mediaUrl))
                if (mediaDuration != null) put("media_duration", JsonPrimitive(mediaDuration))
                if (replyToId != null) put("reply_to_id", JsonPrimitive(replyToId))
            })
            msgDao.insert(msg.copy(pendingSync = false))
        } catch (_: Exception) { }
        convDao.updateBlurb(conversationId, text.ifBlank { "[media]" }, now, senderId)
        msgDao.markAllRead(conversationId, senderId, now)
        return msg
    }

    suspend fun syncRecentMessages(conversationId: String) {
        try {
            val rows = api.select(
                "messages",
                filters = mapOf("conversation_id" to "eq.$conversationId"),
                order = "created_at.desc",
                limit = 100
            )
            msgDao.insertAll(parseMessages(rows).map { it.toEntity() })
        } catch (_: Exception) {}
    }

    suspend fun markReadRemote(messageId: String) {
        val msg = msgDao.getById(messageId) ?: return
        val me = meId()
        val now = System.currentTimeMillis()
        msgDao.markAllRead(msg.conversationId, me, now)
        try {
            api.update(
                "messages",
                mapOf("id" to "eq.$messageId"),
                buildJsonObject { put("read_at", JsonPrimitive(java.time.Instant.ofEpochMilli(now).toString())) }
            )
        } catch (_: Exception) {}
    }

    // ── typing ─────────────────────────────────────────────

    suspend fun setTyping(conversationId: String, isTyping: Boolean) {
        val me = meId().takeIf { it.isNotBlank() } ?: return
        try {
            api.insert(
                "typing",
                buildJsonObject {
                    put("conversation_id", JsonPrimitive(conversationId))
                    put("user_id", JsonPrimitive(me))
                    put("is_typing", JsonPrimitive(isTyping))
                },
                select = "*",
                prefer = "return=representation,resolution=ignore-duplicates",
                filters = mapOf("on_conflict" to "conversation_id,user_id")
            )
        } catch (_: Exception) {}
    }

    // ── statuses ───────────────────────────────────────────

    fun observeStatuses() = statusDao.observeActive(System.currentTimeMillis())

    suspend fun postStatus(body: String, mediaUrl: String?, type: String = "text") {
        val me = meId().takeIf { it.isNotBlank() } ?: return
        val dto = StatusDto(
            id = UUID.randomUUID().toString(),
            userId = me,
            stype = type,
            body = body.ifBlank { null },
            mediaUrl = mediaUrl,
            createdAt = java.time.Instant.now().toString(),
            expiresAt = java.time.Instant.now().plusSeconds(86400).toString()
        )
        statusDao.insert(dto.toEntity())
        try {
            api.insert("statuses", buildJsonObject {
                put("id", JsonPrimitive(dto.id))
                put("user_id", JsonPrimitive(dto.userId))
                put("stype", JsonPrimitive(dto.stype))
                if (!body.isBlank()) put("body", JsonPrimitive(body))
                if (mediaUrl != null) put("media_url", JsonPrimitive(mediaUrl))
            })
        } catch (_: Exception) {}
    }

    suspend fun syncStatuses() {
        try {
            val rows = api.select("statuses", order = "created_at.desc", limit = 100)
            statusDao.insertAll(parseStatuses(rows).map { it.toEntity() })
            statusDao.purgeExpired(System.currentTimeMillis())
        } catch (_: Exception) {}
    }

    suspend fun viewStatus(statusId: String) {
        val me = meId().takeIf { it.isNotBlank() } ?: return
        try {
            api.insert("status_views", buildJsonObject {
                put("status_id", JsonPrimitive(statusId))
                put("viewer_id", JsonPrimitive(me))
            })
        } catch (_: Exception) {}
    }

    // ── calls ──────────────────────────────────────────────

    fun observeCalls() = callDao.observeAll()

    suspend fun createCall(calleeId: String, kind: String = "audio"): CallDto? {
        val me = meId().takeIf { it.isNotBlank() } ?: return null
        val dto = CallDto(
            id = UUID.randomUUID().toString(),
            callerId = me,
            calleeId = calleeId,
            kind = kind,
            startedAt = java.time.Instant.now().toString()
        )
        try {
            api.insert("calls", buildJsonObject {
                put("id", JsonPrimitive(dto.id))
                put("caller_id", JsonPrimitive(dto.callerId))
                put("callee_id", JsonPrimitive(dto.calleeId))
                put("kind", JsonPrimitive(dto.kind))
                put("status", JsonPrimitive("ringing"))
            })
            callDao.insert(dto.toEntity())
            return dto
        } catch (_: Exception) { return null }
    }

    suspend fun updateCallStatus(callId: String, status: String, duration: Int = 0) {
        try {
            api.update("calls", mapOf("id" to "eq.$callId"), buildJsonObject {
                put("status", JsonPrimitive(status))
                if (status == "completed") put("duration", JsonPrimitive(duration))
            })
        } catch (_: Exception) {}
        val existing = callDao.get(callId) ?: return
        callDao.insert(
            existing.copy(
                status = status,
                duration = duration,
                answeredAt = if (status == "completed" && existing.answeredAt == null) System.currentTimeMillis() else existing.answeredAt,
                endedAt = if (status != "ringing") System.currentTimeMillis() else existing.endedAt
            )
        )
    }

    // ── communities ────────────────────────────────────────

    fun observeCommunities() = communityDao.observeAll()

    suspend fun createCommunity(name: String, description: String) {
        val me = meId().takeIf { it.isNotBlank() } ?: return
        val id = UUID.randomUUID().toString()
        try {
            api.insert("communities", buildJsonObject {
                put("id", JsonPrimitive(id))
                put("name", JsonPrimitive(name))
                put("description", JsonPrimitive(description))
                put("created_by", JsonPrimitive(me))
            })
            api.insert("community_members", buildJsonObject {
                put("community_id", JsonPrimitive(id))
                put("user_id", JsonPrimitive(me))
                put("role", JsonPrimitive("admin"))
            })
            communityDao.upsertAll(listOf(CommunityEntity(
                id = id, name = name, description = description,
                createdBy = me, createdAt = System.currentTimeMillis()
            )))
        } catch (_: Exception) {}
    }

    suspend fun syncCommunities() {
        try {
            val rows = api.select("communities", order = "created_at.desc")
            communityDao.upsertAll(parseCommunities(rows).map { it.toEntity() })
        } catch (_: Exception) {}
    }

    // ── realtime ingestion ─────────────────────────────────

    suspend fun onRealtimeChange(change: kotlinx.serialization.json.JsonElement, table: String) {
        val row = (change as? JsonObject) ?: return
        when (table) {
            "messages" -> {
                val dto = parseMessage(row) ?: return
                val entity = dto.toEntity()
                val me = meId()
                if (dto.senderId != me) {
                    val sender = findUser(dto.senderId)
                    if (sender != null) userDao.upsert(sender.toEntity())
                    convDao.bumpUnread(dto.conversationId)
                }
                msgDao.insert(entity)
                convDao.updateBlurb(dto.conversationId, dto.body ?: "[media]", dto.createdAt.toEpochMilli(), dto.senderId)
            }
            "typing" -> Unit // UI reads raw realtime, not persisted
            "conversations" -> {
                val dto = parseConversation(row) ?: return
                convDao.upsert(dto.toEntity())
            }
            "users" -> {
                val dto = parseUser(row) ?: return
                userDao.upsert(dto.toEntity())
            }
            "calls" -> {
                val dto = parseCall(row) ?: return
                callDao.insert(dto.toEntity())
            }
            "statuses" -> {
                val dto = parseStatus(row) ?: return
                statusDao.insert(dto.toEntity())
            }
            "conversation_members" -> {
                val conversationId = row["conversation_id"]?.jsonPrimitive?.content.orEmpty()
                val userId = row["user_id"]?.jsonPrimitive?.content.orEmpty()
                if (conversationId.isNotBlank() && userId.isNotBlank()) {
                    val user = parseUser(row)
                    if (user != null) {
                        userDao.upsert(user.toEntity())
                        memberDao.upsertAll(listOf(
                            com.crystal_messenger.app.core.database.ConversationMemberEntity(
                                conversationId = conversationId,
                                userId = userId
                            )
                        ))
                    }
                }
            }
            "communities" -> {
                val dto = parseCommunity(row) ?: return
                communityDao.upsertAll(listOf(dto.toEntity()))
            }
            "status_views", "community_members", "community_announcements", "typing" ->
                Unit // read-only/no local table or consumed by UI directly
        }
    }

    // ── parsers ────────────────────────────────────────────

    private fun parseUser(row: JsonObject): UserDto? =
        runCatching { CrystalJson.decodeFromJsonElement(UserDto.serializer(), row) }.getOrNull()

    private fun parseUsers(rows: JsonArray) = rows.mapNotNull { parseUser(it.jsonObject) }

    private fun parseConversation(row: JsonObject): ConversationDto? =
        runCatching { CrystalJson.decodeFromJsonElement(ConversationDto.serializer(), row) }.getOrNull()

    private fun parseConversations(rows: JsonArray) = rows.mapNotNull { parseConversation(it.jsonObject) }

    private fun parseMessage(row: JsonObject): MessageDto? =
        runCatching { CrystalJson.decodeFromJsonElement(MessageDto.serializer(), row) }.getOrNull()

    private fun parseMessages(rows: JsonArray) = rows.mapNotNull { parseMessage(it.jsonObject) }

    private fun parseStatus(row: JsonObject): StatusDto? =
        runCatching { CrystalJson.decodeFromJsonElement(StatusDto.serializer(), row) }.getOrNull()

    private fun parseStatuses(rows: JsonArray) = rows.mapNotNull { parseStatus(it.jsonObject) }

    private fun parseCall(row: JsonObject): CallDto? =
        runCatching { CrystalJson.decodeFromJsonElement(CallDto.serializer(), row) }.getOrNull()

    private fun parseCommunities(rows: JsonArray) = rows.mapNotNull {
        runCatching { CrystalJson.decodeFromJsonElement(CommunityDto.serializer(), it.jsonObject) }.getOrNull()
    }

    private fun parseCommunity(row: JsonObject): CommunityDto? =
        runCatching { CrystalJson.decodeFromJsonElement(CommunityDto.serializer(), row) }.getOrNull()

    // ── mappers (DTO -> Room) ──────────────────────────────

    private fun UserDto.toEntity() = UserEntity(
        id = id, phone = phone, name = name, about = about ?: "",
        avatarUrl = avatarUrl, status = status,
        lastSeen = lastSeen?.toEpochMilli() ?: 0L, isMe = false
    )

    private fun ConversationDto.toEntity() = ConversationEntity(
        id = id, ctype = ctype, name = name ?: "", description = description,
        avatarUrl = avatarUrl, lastMessageText = lastMessageText ?: "",
        updatedAt = (lastMessageAt ?: createdAt)?.let { it.toEpochMilli() }
            ?: System.currentTimeMillis(),
        createdAt = createdAt?.toEpochMilli() ?: System.currentTimeMillis()
    )

    private fun MessageDto.toEntity() = MessageEntity(
        id = id, conversationId = conversationId, senderId = senderId,
        mtype = mtype, body = body, mediaUrl = mediaUrl, mediaThumb = mediaThumb,
        mediaDuration = mediaDuration, mediaName = mediaName, lat = lat, lng = lng,
        replyToId = replyToId,
        deliveredAt = deliveredAt?.toEpochMilli(), readAt = readAt?.toEpochMilli(),
        createdAt = createdAt.toEpochMilli(), pendingSync = false
    )

    private fun StatusDto.toEntity() = StatusEntity(
        id = id, userId = userId, stype = stype, body = body,
        mediaUrl = mediaUrl, mediaThumb = mediaThumb,
        createdAt = createdAt.toEpochMilli(), expiresAt = expiresAt.toEpochMilli()
    )

    private fun CallDto.toEntity() = CallEntity(
        id = id, conversationId = conversationId, callerId = callerId,
        calleeId = calleeId, kind = kind, status = status,
        startedAt = startedAt.toEpochMilli(),
        answeredAt = answeredAt?.toEpochMilli(), endedAt = endedAt?.toEpochMilli(),
        duration = duration
    )

    private fun CommunityDto.toEntity() = CommunityEntity(
        id = id, name = name, description = description, coverUrl = coverUrl,
        createdBy = createdBy, createdAt = createdAt.toEpochMilli()
    )

    private fun String.toEpochMilli(): Long = try {
        java.time.Instant.parse(this).toEpochMilli()
    } catch (_: Exception) { System.currentTimeMillis() }
}