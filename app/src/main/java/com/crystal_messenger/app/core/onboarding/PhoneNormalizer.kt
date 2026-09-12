package com.crystal_messenger.app.core.onboarding

/**
 * Canonical, E.164-style phone normalization used EVERYWHERE a phone identity
 * is derived (email, deterministic password, backend lookup, profile storage).
 *
 * Rules:
 *  - strip spaces, dashes, dots, parentheses
 *  - keep one leading '+', drop any '+' inside the number
 *  - enforce 8..15 digits (E.164 national+country number span)
 * Returns null when the input cannot be a plausible phone number.
 */
object PhoneNormalizer {

    const val MIN_DIGITS = 8
    const val MAX_DIGITS = 15

    /** Parses a raw user input into its canonical (digits-only) form. */
    fun normalize(raw: String): String {
        var s = raw.trim()
        val leadingPlus = s.startsWith("+")
        val digits = s.filter { it.isDigit() }
        return if (leadingPlus && digits.isNotEmpty()) "+$digits" else digits
    }

    /** True when [raw] can plausibly represent a phone number. */
    fun isValid(raw: String): Boolean {
        val digits = normalize(raw)
        return digits.length in MIN_DIGITS..MAX_DIGITS
    }

    /** Pure digits — used for deterministic password/email derivation. */
    fun digits(raw: String): String = normalize(raw)
}