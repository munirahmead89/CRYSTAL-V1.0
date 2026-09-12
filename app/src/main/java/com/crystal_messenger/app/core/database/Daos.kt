package com.crystal_messenger.app.core.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface UserDao {
    @Query("SELECT * FROM users WHERE id = :id")
    fun observeUser(id: String): Flow<UserEntity?>

    @Query("SELECT * FROM users WHERE id = :id")
    suspend fun getUser(id: String): UserEntity?

    @Query("SELECT * FROM users WHERE phone = :phone LIMIT 1")
    suspend fun getUserByPhone(phone: String): UserEntity?

    @Query("SELECT * FROM users WHERE isMe = 1 LIMIT 1")
    suspend fun getMe(): UserEntity?

    @Query("SELECT * FROM users")
    fun observeAllUsers(): Flow<List<UserEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(users: List<UserEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(user: UserEntity)

    @Query("UPDATE users SET status = :status, lastSeen = :lastSeen WHERE id = :id")
    suspend fun updatePresence(id: String, status: String, lastSeen: Long)
}

@Dao
interface ConversationDao {
    @Query("SELECT * FROM conversations ORDER BY updatedAt DESC")
    fun observeAll(): Flow<List<ConversationEntity>>

    @Query("SELECT * FROM conversations WHERE id = :id")
    suspend fun get(id: String): ConversationEntity?

    @Query("SELECT * FROM conversations WHERE id = :id")
    fun observeById(id: String): Flow<ConversationEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(list: List<ConversationEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(conv: ConversationEntity)

    @Query("DELETE FROM conversations WHERE id = :id")
    suspend fun delete(id: String)

    @Query("UPDATE conversations SET lastMessageText = :lastMessage, updatedAt = :updatedAt, lastMessageBy = :by WHERE id = :id")
    suspend fun updateBlurb(id: String, lastMessage: String, updatedAt: Long, by: String?)

    @Query("UPDATE conversations SET unreadCount = unreadCount + 1 WHERE id = :id")
    suspend fun bumpUnread(id: String)

    @Query("UPDATE conversations SET unreadCount = 0 WHERE id = :id")
    suspend fun clearUnread(id: String)
}

@Dao
interface MemberDao {
    @Query("SELECT * FROM conversation_members WHERE conversationId = :conversationId")
    fun observeMembers(conversationId: String): Flow<List<ConversationMemberEntity>>

    @Query("SELECT userId FROM conversation_members WHERE conversationId = :conversationId")
    suspend fun memberIds(conversationId: String): List<String>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(list: List<ConversationMemberEntity>)
}

@Dao
interface MessageDao {
    @Query("SELECT * FROM messages WHERE conversationId = :conversationId ORDER BY createdAt ASC LIMIT :limit")
    fun observeMessages(conversationId: String, limit: Int = 500): Flow<List<MessageEntity>>

    @Query("SELECT * FROM messages WHERE conversationId = :conversationId ORDER BY createdAt DESC LIMIT 1")
    suspend fun lastMessage(conversationId: String): MessageEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(message: MessageEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(messages: List<MessageEntity>)

    @Update
    suspend fun update(message: MessageEntity)

    @Query("UPDATE messages SET deliveredAt = :at WHERE id = :id")
    suspend fun markDelivered(id: String, at: Long)

    @Query("UPDATE messages SET readAt = :at WHERE conversationId = :conversationId AND senderId = :myId AND readAt IS NULL")
    suspend fun markAllRead(conversationId: String, myId: String, at: Long)

    @Query("SELECT * FROM messages WHERE id = :id")
    suspend fun getById(id: String): MessageEntity?

    @Query("DELETE FROM messages WHERE id = :id")
    suspend fun delete(id: String)
}

@Dao
interface StatusDao {
    @Query("SELECT * FROM statuses WHERE expiresAt > :now ORDER BY createdAt DESC")
    fun observeActive(now: Long): Flow<List<StatusEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(statuses: List<StatusEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(status: StatusEntity)

    @Query("DELETE FROM statuses WHERE expiresAt < :now")
    suspend fun purgeExpired(now: Long)

    @Query("SELECT * FROM status_views WHERE statusId = :statusId")
    suspend fun viewsFor(statusId: String): List<StatusViewEntity>
}

@Dao
interface CallDao {
    @Query("SELECT * FROM calls ORDER BY startedAt DESC")
    fun observeAll(): Flow<List<CallEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(call: CallEntity)

    @Query("SELECT * FROM calls WHERE id = :id")
    suspend fun get(id: String): CallEntity?
}

@Dao
interface CommunityDao {
    @Query("SELECT * FROM communities ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<CommunityEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(list: List<CommunityEntity>)

    @Query("SELECT * FROM communities WHERE id = :id")
    suspend fun get(id: String): CommunityEntity?
}