package com.crystal_messenger.app.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

val CrystalJson: Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
    isLenient = true
}

@Serializable
data class AuthSessionDto(
    @SerialName("access_token") val accessToken: String? = null,
    @SerialName("refresh_token") val refreshToken: String? = null,
    @SerialName("token_type") val tokenType: String = "bearer",
    @SerialName("expires_in") val expiresIn: Long? = null,
    val user: AuthUserDto? = null
) {
    val hasSession: Boolean get() = !accessToken.isNullOrBlank()
}

@Serializable
data class AuthUserDto(
    val id: String,
    val email: String? = null,
    val phone: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class UserDto(
    val id: String,
    val phone: String,
    val name: String,
    val about: String? = "",
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val status: String = "offline",
    @SerialName("last_seen") val lastSeen: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class ConversationDto(
    val id: String,
    val ctype: String = "single",
    val name: String? = null,
    val description: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("last_message_text") val lastMessageText: String? = null,
    @SerialName("last_message_at") val lastMessageAt: String? = null,
    @SerialName("created_by") val createdBy: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class ConversationMemberDto(
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("user_id") val userId: String,
    val nickname: String? = null,
    val role: String = "member",
    @SerialName("joined_at") val joinedAt: String? = null
)

@Serializable
data class MessageDto(
    val id: String,
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("sender_id") val senderId: String,
    val mtype: String = "text",
    val body: String? = null,
    @SerialName("media_url") val mediaUrl: String? = null,
    @SerialName("media_thumb") val mediaThumb: String? = null,
    @SerialName("media_duration") val mediaDuration: Double? = null,
    @SerialName("media_name") val mediaName: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    @SerialName("reply_to_id") val replyToId: String? = null,
    @SerialName("delivered_at") val deliveredAt: String? = null,
    @SerialName("read_at") val readAt: String? = null,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class TypingDto(
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("is_typing") val isTyping: Boolean,
    @SerialName("updated_at") val updatedAt: String? = null
)

@Serializable
data class StatusDto(
    val id: String,
    @SerialName("user_id") val userId: String,
    val stype: String = "text",
    val body: String? = null,
    @SerialName("media_url") val mediaUrl: String? = null,
    @SerialName("media_thumb") val mediaThumb: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("expires_at") val expiresAt: String
)

@Serializable
data class StatusViewDto(
    @SerialName("status_id") val statusId: String,
    @SerialName("viewer_id") val viewerId: String,
    @SerialName("viewed_at") val viewedAt: String? = null
)

@Serializable
data class CallDto(
    val id: String,
    @SerialName("conversation_id") val conversationId: String? = null,
    @SerialName("caller_id") val callerId: String,
    @SerialName("callee_id") val calleeId: String,
    val kind: String = "audio",
    val status: String = "ringing",
    @SerialName("started_at") val startedAt: String,
    @SerialName("answered_at") val answeredAt: String? = null,
    @SerialName("ended_at") val endedAt: String? = null,
    val duration: Int = 0
)

@Serializable
data class CommunityDto(
    val id: String,
    val name: String,
    val description: String? = null,
    @SerialName("cover_url") val coverUrl: String? = null,
    @SerialName("created_by") val createdBy: String,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class CommunityMemberDto(
    @SerialName("community_id") val communityId: String,
    @SerialName("user_id") val userId: String,
    val role: String = "member",
    @SerialName("joined_at") val joinedAt: String? = null
)

@Serializable
data class AnnouncementDto(
    val id: String,
    @SerialName("community_id") val communityId: String,
    @SerialName("user_id") val userId: String,
    val body: String,
    @SerialName("created_at") val createdAt: String
)