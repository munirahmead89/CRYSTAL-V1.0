package com.crystal_messenger.app.di

import android.content.Context
import com.crystal_messenger.app.BuildConfig
import com.crystal_messenger.app.core.database.CrystalDatabase
import com.crystal_messenger.app.core.repository.ChatRepository
import com.crystal_messenger.app.core.repository.ContactRepository
import com.crystal_messenger.app.core.repository.StorageRepository
import com.crystal_messenger.app.core.settings.SessionManager
import com.crystal_messenger.app.core.supabase.AuthRepository
import com.crystal_messenger.app.core.supabase.RealtimeClient
import com.crystal_messenger.app.core.supabase.SupabaseApi
import com.crystal_messenger.app.core.supabase.SupabaseClient
import com.crystal_messenger.app.core.supabase.RealtimeSynchronizer
import com.squareup.moshi.Moshi
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import java.util.concurrent.TimeUnit

class AppContainer private constructor(private val appContext: Context) {

    val db: CrystalDatabase = CrystalDatabase.get(appContext)
    val sessionManager = SessionManager(appContext)

    private val supabaseUrl: String = BuildConfig.SUPABASE_URL.ifBlank { "" }
    private val anonKey: String = BuildConfig.SUPABASE_ANON_KEY.ifBlank { "" }

    val okHttpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(if (supabaseUrl.endsWith("/")) supabaseUrl else "$supabaseUrl/")
        .client(okHttpClient)
        .addConverterFactory(MoshiConverterFactory.create(Moshi.Builder().build()))
        .build()

    val supabaseApi: SupabaseApi = retrofit.create(SupabaseApi::class.java)
    val supabaseClient: SupabaseClient = SupabaseClient(supabaseUrl, anonKey, supabaseApi)
    val realtime: RealtimeClient = RealtimeClient(supabaseUrl, anonKey, okHttpClient)

    val authRepository = AuthRepository(supabaseClient, sessionManager)
    val storageRepository = StorageRepository(supabaseClient, appContext)
    val contactRepository = ContactRepository(appContext)
    val chatRepository = ChatRepository(
        api = supabaseClient,
        session = sessionManager,
        userDao = db.userDao(),
        convDao = db.conversationDao(),
        memberDao = db.memberDao(),
        msgDao = db.messageDao(),
        statusDao = db.statusDao(),
        callDao = db.callDao(),
        communityDao = db.communityDao()
    )
    val realtimeSynchronizer = RealtimeSynchronizer(chatRepository, realtime, sessionManager)

    companion object {
        @Volatile private var instance: AppContainer? = null

        fun get(context: Context): AppContainer =
            instance ?: synchronized(this) {
                instance ?: AppContainer(context.applicationContext).also { instance = it }
            }
    }
}