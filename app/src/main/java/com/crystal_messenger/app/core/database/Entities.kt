package com.crystal_messenger.app.core.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val id: String,
    val phone: String,
    val name: String,
    val about: String = "",
    val avatarUrl: String? = null,
    val status: String = "offline",
    val lastSeen: Long = 0L,
    val isMe: Boolean = false
)

@Entity(
    tableName = "conversations",
    indices = [Index("updatedAt"), Index("createdAt")]
)
data class ConversationEntity(
    @PrimaryKey val id: String,
    val ctype: String,
    val name: String,
    val description: String? = null,
    val avatarUrl: String? = null,
    val lastMessageText: String = "",
    val lastMessageBy: String? = null,
    val updatedAt: Long,
    val createdAt: Long,
    val unreadCount: Int = 0,
    val draft: String = ""
)

val ConversationEntity.isGroup: Boolean get() = ctype == "group"

@Entity(
    tableName = "conversation_members",
    primaryKeys = ["conversationId", "userId"]
)
data class ConversationMemberEntity(
    val conversationId: String,
    val userId: String,
    val nickname: String? = null,
    val role: String = "member"
)

@Entity(
    tableName = "messages",
    indices = [Index("conversationId"), Index("createdAt")]
)
data class MessageEntity(
    @PrimaryKey val id: String,
    val conversationId: String,
    val senderId: String,
    val mtype: String,
    val body: String? = null,
    val mediaUrl: String? = null,
    val mediaThumb: String? = null,
    val mediaDuration: Double? = null,
    val mediaName: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val replyToId: String? = null,
    val replyToBody: String? = null,
    val deliveredAt: Long? = null,
    val readAt: Long? = null,
    val createdAt: Long,
    val pendingSync: Boolean = false
)

@Entity(
    tableName = "statuses",
    indices = [Index("userId"), Index("expiresAt")]
)
data class StatusEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val stype: String,
    val body: String? = null,
    val mediaUrl: String? = null,
    val mediaThumb: String? = null,
    val createdAt: Long,
    val expiresAt: Long
)

@Entity(tableName = "status_views", primaryKeys = ["statusId", "viewerId"])
data class StatusViewEntity(
    val statusId: String,
    val viewerId: String,
    val viewedAt: Long,
    val viewerName: String = ""
)

@Entity(tableName = "calls")
data class CallEntity(
    @PrimaryKey val id: String,
    val conversationId: String? = null,
    val callerId: String,
    val calleeId: String,
    val kind: String,
    val status: String,
    val startedAt: Long,
    val answeredAt: Long? = null,
    val endedAt: Long? = null,
    val duration: Int = 0
)

@Entity(
    tableName = "communities",
    indices = [Index("createdAt")]
)
data class CommunityEntity(
    @PrimaryKey val id: String,
    val name: String,
    val description: String? = null,
    val coverUrl: String? = null,
    val createdBy: String,
    val createdAt: Long,
    val memberCount: Int = 1
)