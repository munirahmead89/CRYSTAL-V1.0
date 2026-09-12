package com.crystal_messenger.app.core.onboarding

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PhoneNormalizerTest {

    @Test
    fun `spaces dashes and dots are stripped`() {
        assertEquals("+15551234567", PhoneNormalizer.normalize("+1 (555) 123-4567"))
        assertEquals("+15551234567", PhoneNormalizer.normalize("+1-555-123-4567"))
        assertEquals("5551234567", PhoneNormalizer.normalize("555.123.4567"))
    }

    @Test
    fun `leading plus is kept, embedded plus removed`() {
        assertEquals("+15551234567", PhoneNormalizer.normalize("+15551234567"))
        assertEquals("15551234567", PhoneNormalizer.normalize("1+5551234567"))
    }

    @Test
    fun `validation enforces 8 to 15 digits`() {
        assertTrue(PhoneNormalizer.isValid("+15551234567"))
        assertTrue(PhoneNormalizer.isValid("12345678"))
        assertFalse(PhoneNormalizer.isValid("1234567"))
        assertFalse(PhoneNormalizer.isValid("1234567890123456"))
        assertFalse(PhoneNormalizer.isValid(""))
        assertFalse(PhoneNormalizer.isValid("abc"))
    }

    @Test
    fun `digits strips the plus for deterministic derivation`() {
        assertEquals("15551234567", PhoneNormalizer.digits("+1 (555) 123-4567"))
    }
}