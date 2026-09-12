package com.crystal_messenger.app.core.supabase

import com.crystal_messenger.app.core.network.AuthSessionDto
import com.crystal_messenger.app.core.network.CrystalJson
import com.crystal_messenger.app.core.network.UserDto
import com.crystal_messenger.app.core.settings.SessionManager
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import java.security.MessageDigest

fun JsonObject.toUserDto(): UserDto =
    CrystalJson.decodeFromJsonElement(UserDto.serializer(), this)

fun JsonArrayOfUsers(json: kotlinx.serialization.json.JsonArray): List<UserDto> =
    json.mapNotNull { it.jsonObject.runCatching { toUserDto() }.getOrNull() }

class AuthRepository(
    private val client: SupabaseClient,
    private val sessionManager: SessionManager
) {

    private fun emailFromPhone(phone: String): String {
        val digits = phone.filter { it.isDigit() }
        return "$digits@crystal.local"
    }

    /**
     * Multi-device enabled: the password is derived deterministically from the
     * phone number, so signing in with the same number on any device always
     * reaches the same account (like WhatsApp).
     */
    private fun devicePassword(phone: String): String {
        val seed = phone.filter { it.isDigit() }
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("crystal-multi-device-v1::$seed".toByteArray(Charsets.UTF_8))
        val hex = digest.joinToString("") { "%02x".format(it) }
        return "cm-$hex"
    }

    suspend fun signUp(phone: String, name: String): AuthSessionDto {
        val email = emailFromPhone(phone)
        val password = devicePassword(phone)
        val session = try {
            client.signUp(email, password)
        } catch (signupError: Exception) {
            try {
                client.logIn(email, password)
            } catch (loginError: Exception) {
                throw RuntimeException(
                    "This number already belongs to an account created by an older build. " +
                        "Sign out there (or reinstall) and try again.", loginError
                )
            }
        }
        applySession(session, phone, name)
        return session
    }

    /** Sign in to an existing account on a new device using the same phone number. */
    suspend fun login(phone: String): AuthSessionDto {
        val session = client.logIn(emailFromPhone(phone), devicePassword(phone))
        applySession(session, phone, sessionManager.current().name.orEmpty())
        return session
    }

    private suspend fun applySession(session: AuthSessionDto, phone: String, name: String) {
        client.accessToken.set(session.accessToken)
        ensureProfile(session.user?.id.orEmpty(), phone, name)
        sessionManager.saveAuth(session.user?.id.orEmpty(), session.accessToken, session.refreshToken)
        sessionManager.saveProfile(phone, name)
        sessionManager.completeOnboarding()
    }

    private suspend fun ensureProfile(userId: String, phone: String, name: String) {
        if (userId.isBlank()) return
        val existing = client.selectOne("users", filters = mapOf("id" to "eq.$userId"))
        if (existing == null) {
            client.insert("users", buildJsonObject {
                put("id", userId)
                put("phone", phone)
                put("name", name)
                put("status", "online")
            })
        } else {
            client.update(
                "users",
                mapOf("id" to "eq.$userId"),
                buildJsonObject {
                    put("name", name)
                    put("phone", phone)
                    put("status", "online")
                }
            )
        }
    }

    suspend fun setPresence(status: String) {
        val me = sessionManager.current().userId ?: return
        client.update(
            "users",
            mapOf("id" to "eq.$me"),
            buildJsonObject { put("status", status) }
        )
    }

    suspend fun updateMyProfile(name: String, about: String, avatarUrl: String? = null) {
        val me = sessionManager.current().userId ?: return
        client.update(
            "users",
            mapOf("id" to "eq.$me"),
            buildJsonObject {
                put("name", name)
                put("about", about)
                if (avatarUrl != null) put("avatar_url", JsonPrimitive(avatarUrl))
            }
        )
        sessionManager.saveProfile(sessionManager.current().phone.orEmpty(), name)
    }

    suspend fun logout() = sessionManager.clear()
}