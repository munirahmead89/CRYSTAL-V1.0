package com.crystal_messenger.app.core.network

import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards the resilient auth-session decoding: a full session works, and a
 * confirmation-pending/no-token response decodes without crashing so the
 * caller can fall back to login (multi-device behaviour).
 */
class AuthSessionDecodeTest {

    private fun decode(raw: String): AuthSessionDto =
        CrystalJson.decodeFromString(AuthSessionDto.serializer(), raw)

    @Test
    fun `full session decodes with token and user`() {
        val s = decode(
            """
            {"access_token":"tok","refresh_token":"r","token_type":"bearer",
             "expires_in":3600,"user":{"id":"u1","email":"a@b.c"}}
            """.trimIndent()
        )
        assertTrue(s.hasSession)
        assertEquals("tok", s.accessToken)
        assertEquals("u1", s.user?.id)
    }

    @Test
    fun `no-session response decodes as hasSession false`() {
        val s = decode(
            """
            {"id":"u2","aud":"authenticated","role":"authenticated",
             "email":"a@b.c","identities":[],"created_at":"2026-01-01T00:00:00Z"}
            """.trimIndent()
        )
        assertFalse(s.hasSession)
        assertEquals("u2", s.user?.id) // absent -> user is null
    }

    @Test
    fun `array response never decodes to a session`() {
        // A rate-limit/error array should fail decodes clearly; the client
        // layer rejects non-object responses before reaching this decode.
        val s = runCatching { decode("""[{"message":"nope"}]""".trimIndent()) }
        assertTrue(s.isFailure)
    }
}