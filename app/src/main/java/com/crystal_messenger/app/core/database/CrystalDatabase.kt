package com.crystal_messenger.app.core.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [
        UserEntity::class,
        ConversationEntity::class,
        ConversationMemberEntity::class,
        MessageEntity::class,
        StatusEntity::class,
        StatusViewEntity::class,
        CallEntity::class,
        CommunityEntity::class
    ],
    version = 1,
    exportSchema = true
)
abstract class CrystalDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao
    abstract fun conversationDao(): ConversationDao
    abstract fun memberDao(): MemberDao
    abstract fun messageDao(): MessageDao
    abstract fun statusDao(): StatusDao
    abstract fun callDao(): CallDao
    abstract fun communityDao(): CommunityDao

    companion object {
        @Volatile
        private var instance: CrystalDatabase? = null

        fun get(context: Context): CrystalDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    CrystalDatabase::class.java,
                    "crystal_messenger.db"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { instance = it }
            }
    }
}