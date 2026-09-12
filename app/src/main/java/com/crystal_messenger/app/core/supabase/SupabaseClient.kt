package com.crystal_messenger.app.core.supabase

import com.crystal_messenger.app.core.network.AuthSessionDto
import com.crystal_messenger.app.core.network.CrystalJson
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Response
import java.util.concurrent.atomic.AtomicReference

/**
 * Thin deterministic Supabase client built directly on PostgREST, GoTrue and
 * Storage REST APIs. No external SDK — the version risk stays zero.
 */
class SupabaseClient(
    private val url: String,
    private val anonKey: String,
    private val api: SupabaseApi
) {
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()
    val accessToken = AtomicReference<String?>(null)

    private fun authHeader(): String =
        accessToken.get()?.let { "Bearer $it" } ?: "Bearer $anonKey"

    private fun String.toBody() = this.toRequestBody(jsonMediaType)

    private fun <T> Response<T>.unwrap(): T {
        if (!isSuccessful) {
            val msg = errorBody()?.string() ?: "unknown error"
            throw RuntimeException("Supabase [${code()}]: $msg")
        }
        return body() ?: throw RuntimeException("Supabase empty body")
    }

    private fun String.asArray(): JsonArray {
        val el = CrystalJson.parseToJsonElement(this)
        return when (el) {
            is JsonArray -> el
            is JsonObject -> JsonArray(listOf(el))
            else -> JsonArray(emptyList())
        }
    }

    suspend fun signUp(email: String, password: String): AuthSessionDto {
        val body = buildJsonObject {
            put("email", email)
            put("password", password)
        }.toString()
        val res = api.signup(anonKey, body.toBody()).unwrap()
        return CrystalJson.decodeFromString(AuthSessionDto.serializer(), res)
    }

    suspend fun logIn(email: String, password: String): AuthSessionDto {
        val body = buildJsonObject {
            put("email", email)
            put("password", password)
        }.toString()
        val res = api.token(anonKey, "password", body.toBody()).unwrap()
        return CrystalJson.decodeFromString(AuthSessionDto.serializer(), res)
    }

    /**
     * Authoritative account-existence check against the Supabase database
     * (users table), keyed by the canonical phone number only.
     * Never consults local Room/session state.
     * Fail-loud: a lookup error is surfaced, never misclassified as NEW.
     */
    suspend fun accountExistsByPhone(phone: String): Boolean =
        selectOne("users", select = "id", filters = mapOf("phone" to "eq.$phone")) != null

    /**
     * Server-side DEVICE_BLOCKED state. Completely independent of account
     * existence: a blocked device can have a fresh or existing phone alike.
     * Parses PostgREST's scalar boolean responses ("t"/"f", "true"/"false").
     */
    suspend fun isDeviceBlocked(phone: String): Boolean = try {
        rpcBool("is_device_blocked", buildJsonObject {
            put("p_phone", JsonPrimitive(phone))
        })
    } catch (_: Exception) {
        false
    }

    /** Robust boolean RPC: PostgREST returns scalars as text; content can be "t". */
    suspend fun rpcBool(fn: String, payload: JsonObject): Boolean {
        val raw = api.rpc(anonKey, authHeader(), fn, payload.toString().toBody())
            .unwrap().trim()
        return parseBoolean(raw)
    }

    private fun parseBoolean(raw: String): Boolean = when (raw.lowercase()) {
        "t", "true", "1", "yes", "on" -> true
        "f", "false", "0", "no", "off", "" -> false
        else -> runCatching {
            (CrystalJson.parseToJsonElement(raw) as? JsonPrimitive)
                ?.content?.toBooleanStrictOrNull() ?: false
        }.getOrDefault(false)
    }

    /** Invalidate the cached access token (logout). */
    fun clearAuth() {
        accessToken.set(null)
    }

    suspend fun select(
        table: String,
        select: String = "*",
        filters: Map<String, String> = emptyMap(),
        order: String? = null,
        limit: Int? = null
    ): JsonArray =
        api.select(anonKey, authHeader(), table, select, filters, order, limit, null)
            .unwrap().asArray()

    suspend fun selectOne(
        table: String,
        select: String = "*",
        filters: Map<String, String> = emptyMap()
    ): JsonObject? {
        val arr = api.select(anonKey, authHeader(), table, select, filters, null, 1, null)
            .unwrap().asArray()
        return arr.firstOrNull() as? JsonObject
    }

    suspend fun insert(
        table: String,
        payload: JsonObject,
        select: String = "*",
        prefer: String = "return=representation",
        filters: Map<String, String> = emptyMap()
    ): JsonArray =
        api.insert(anonKey, authHeader(), prefer, table, select, filters, payload.toString().toBody())
            .unwrap().asArray()

    suspend fun update(
        table: String,
        filters: Map<String, String>,
        payload: JsonObject,
        prefer: String = "return=representation"
    ): JsonArray =
        api.update(anonKey, authHeader(), prefer, table, filters, payload.toString().toBody())
            .unwrap().asArray()

    suspend fun delete(
        table: String,
        filters: Map<String, String>,
        prefer: String = "return=representation"
    ): Int {
        val res = api.delete(anonKey, authHeader(), prefer, table, filters).unwrap()
        return if (res.isBlank()) 0 else 1
    }

    suspend fun rpc(fn: String, payload: JsonObject = buildJsonObject { }): JsonElement {
        val res = api.rpc(anonKey, authHeader(), fn, payload.toString().toBody()).unwrap()
        return if (res.isBlank()) JsonPrimitive("{}") else CrystalJson.parseToJsonElement(res)
    }

    suspend fun uploadMedia(
        userId: String,
        fileName: String,
        bytes: ByteArray,
        mimeType: String
    ): String {
        val path = "$userId/$fileName"
        val body = bytes.toRequestBody(mimeType.toMediaType())
        api.upload(anonKey, authHeader(), mimeType, "media", path, body).unwrap()
        return "$url/storage/v1/object/public/media/$path"
    }

    fun publicMediaUrl(path: String): String =
        if (path.startsWith("http")) path else "$url/storage/v1/object/public/media/$path"
}