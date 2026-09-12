package com.crystal_messenger.app.core.supabase

import com.crystal_messenger.app.core.network.AuthSessionDto
import com.crystal_messenger.app.core.network.CrystalJson
import com.crystal_messenger.app.core.network.UserDto
import com.crystal_messenger.app.core.onboarding.OnboardingController
import com.crystal_messenger.app.core.onboarding.OnboardingDecision
import com.crystal_messenger.app.core.onboarding.OnboardingException
import com.crystal_messenger.app.core.onboarding.OnboardingLogger
import com.crystal_messenger.app.core.onboarding.PhoneNormalizer
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
    private val sessionManager: SessionManager,
    private val onLoggedOut: suspend () -> Unit = {}
) {
    private val controller by lazy {
        OnboardingController(
            accountExists = { phone -> client.accountExistsByPhone(phone) },
            isDeviceBlocked = { phone -> client.isDeviceBlocked(phone) },
            localSession = { localSessionSummary() }
        )
    }

    private fun emailFromPhone(phone: String): String {
        val digits = PhoneNormalizer.digits(phone)
        return "$digits@crystal.local"
    }

    /**
     * Multi-device enabled: the password is derived deterministically from the
     * phone number, so signing in with the same number on any device always
     * reaches the same account (like WhatsApp).
     */
    private fun devicePassword(phone: String): String {
        val seed = PhoneNormalizer.digits(phone)
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("crystal-multi-device-v1::$seed".toByteArray(Charsets.UTF_8))
        val hex = digest.joinToString("") { "%02x".format(it) }
        return "cm-$hex"
    }

    private fun localSessionSummary(): String {
        val s = sessionManager.cachedCurrent()
        return buildString {
            append("loggedIn=").append(s?.isLoggedIn ?: false)
            append(" onboarded=").append(s?.onboarded ?: false)
            append(" samePhone=").append(s?.phone != null)
        }
    }

    /**
     * Onboarding entry point.
     *
     * 1. Normalize the phone (E.164-ish).
     * 2. Ask the authoritative server check for DEVICE_BLOCKED.
     * 3. Classify NEW vs EXISTING purely from the backend users table.
     * 4. Sign up or sign in accordingly.
     *
     * A fresh phone is ALWAYS classified NEW, regardless of any previous local
     * account/session on this device.
     */
    suspend fun signUp(inputPhone: String, name: String): AuthSessionDto {
        val phone = PhoneNormalizer.normalize(inputPhone)
        if (!PhoneNormalizer.isValid(inputPhone)) {
            throw OnboardingException("Enter a valid phone number (8–15 digits).")
        }
        OnboardingLogger.info("onboarding start: normalizedPhone=$phone name=${name.take(40)}")

        val decision = controller.decide(phone)
        return when (decision) {
            is OnboardingDecision.FreshAccount -> signUpAsNew(phone, name)
            is OnboardingDecision.ExistingAccount -> signInExisting(phone, name)
            is OnboardingDecision.DeviceBlocked -> {
                throw OnboardingException("This device has been blocked. Contact support if you think this is a mistake.")
            }
            OnboardingDecision.InvalidPhone ->
                throw OnboardingException("Enter a valid phone number (8–15 digits).")
        }
    }

    /** Sign in to an existing account on a new device using the same phone number. */
    suspend fun login(inputPhone: String): AuthSessionDto {
        val phone = PhoneNormalizer.normalize(inputPhone)
        if (!PhoneNormalizer.isValid(inputPhone)) {
            throw OnboardingException("Enter a valid phone number (8–15 digits).")
        }
        val session = try {
            client.logIn(emailFromPhone(phone), devicePassword(phone))
        } catch (e: Exception) {
            OnboardingLogger.warn("existing-account login failed: phone=$phone")
            throw OnboardingException("Could not sign in to this number on another device. Try again later.", e)
        }
        applySession(session, phone, sessionManager.current().name.orEmpty())
        return session
    }

    private suspend fun signUpAsNew(phone: String, name: String): AuthSessionDto {
        val email = emailFromPhone(phone)
        val password = devicePassword(phone)
        return try {
            val session = client.signUp(email, password)
            applySession(session, phone, name)
            session
        } catch (signupError: Exception) {
            // The account may already exist (created by an older build or a
            // previous session) even though the users-table lookup race left it
            // classified NEW. Signup then fails with "User already registered";
            // falling back to login is correct multi-device behaviour.
            if (isAlreadyRegistered(signupError)) {
                OnboardingLogger.info("signup rejected, retrying login with deterministic password")
                try {
                    val session = client.logIn(email, password)
                    applySession(session, phone, name)
                    session
                } catch (loginError: Exception) {
                    OnboardingLogger.warn("signup+login both failed for phone=$phone")
                    throw OnboardingException(
                        "This number already belongs to an account created by an older build. " +
                            "Sign out there (or reinstall) and try again.",
                        loginError
                    )
                }
            } else {
                OnboardingLogger.warn("network signup failure for phone=$phone: ${signupError.message}")
                throw OnboardingException(
                    "Could not create your account. Check your internet connection and try again.",
                    signupError
                )
            }
        }
    }

    private suspend fun signInExisting(phone: String, name: String): AuthSessionDto {
        return try {
            val session = client.logIn(emailFromPhone(phone), devicePassword(phone))
            applySession(session, phone, name)
            session
        } catch (loginError: Exception) {
            OnboardingLogger.warn("existing-account login failed: phone=$phone")
            throw OnboardingException(
                "This number is already in use. Could not sign in on this device. Try again later.",
                loginError
            )
        }
    }

    private fun isAlreadyRegistered(e: Exception): Boolean {
        val message = e.message.orEmpty().lowercase()
        return message.contains("already registered") ||
            message.contains("already been registered") ||
            message.contains("user_already_exists") ||
            message.contains("422") || message.contains("409")
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

    /** Full logout: clear backend auth state, cached local session, room isMe and cached user data. */
    suspend fun logout() {
        try { setPresence("offline") } catch (_: Exception) {}
        client.clearAuth()
        sessionManager.clear()
        onLoggedOut()
    }
}