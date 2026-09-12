package com.crystal_messenger.app.core.settings

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.sessionDataStore by preferencesDataStore(name = "mm.session")

data class Session(
    val userId: String? = null,
    val accessToken: String? = null,
    val refreshToken: String? = null,
    val phone: String? = null,
    val name: String? = null,
    val onboarded: Boolean = false
) {
    val isLoggedIn: Boolean get() = userId != null && accessToken != null
}

class SessionManager(private val context: Context) {

    private object Keys {
        val USER_ID = stringPreferencesKey("user_id")
        val ACCESS_TOKEN = stringPreferencesKey("access_token")
        val REFRESH_TOKEN = stringPreferencesKey("refresh_token")
        val PHONE = stringPreferencesKey("phone")
        val NAME = stringPreferencesKey("name")
        val ONBOARDED = stringPreferencesKey("onboarded")
    }

    val session: Flow<Session> = context.sessionDataStore.data.map { prefs ->
        Session(
            userId = prefs[Keys.USER_ID],
            accessToken = prefs[Keys.ACCESS_TOKEN],
            refreshToken = prefs[Keys.REFRESH_TOKEN],
            phone = prefs[Keys.PHONE],
            name = prefs[Keys.NAME],
            onboarded = prefs[Keys.ONBOARDED] == "1"
        )
    }

    suspend fun current(): Session = session.first()

    /**
     * Non-suspending snapshot for sync call sites (logging, summaries).
     * Kept in sync with the DataStore writes performed by this class.
     */
    @Volatile
    private var snapshot: Session = Session()

    fun cachedCurrent(): Session = snapshot

    suspend fun saveAuth(userId: String, accessToken: String, refreshToken: String?) {
        snapshot = session.first().copy(userId = userId, accessToken = accessToken,
            refreshToken = refreshToken ?: snapshot.refreshToken, onboarded = true)
        context.sessionDataStore.edit { prefs ->
            prefs[Keys.USER_ID] = userId
            prefs[Keys.ACCESS_TOKEN] = accessToken
            if (refreshToken != null) prefs[Keys.REFRESH_TOKEN] = refreshToken
            prefs[Keys.ONBOARDED] = "1"
        }
    }

    suspend fun saveProfile(phone: String, name: String) {
        snapshot = session.first().copy(phone = phone, name = name)
        context.sessionDataStore.edit { prefs ->
            prefs[Keys.PHONE] = phone
            prefs[Keys.NAME] = name
        }
    }

    suspend fun updateLocalName(name: String, about: String) {
        val current = current()
        saveProfile(current.phone.orEmpty(), name)
    }

    suspend fun completeOnboarding() {
        snapshot = session.first().copy(onboarded = true)
        context.sessionDataStore.edit { prefs -> prefs[Keys.ONBOARDED] = "1" }
    }

    suspend fun clear() {
        snapshot = Session()
        context.sessionDataStore.edit { it.clear() }
    }
}