package com.crystal_messenger.app.core.onboarding

import android.util.Log

/**
 * Structured logging for the onboarding decision.
 *
 * NEVER logs passwords, OTPs, access tokens or refresh tokens.
 * It logs the normalized phone (identity of a fresh/existing account — the
 * user typed it on screen, so it is not a secret here) and local session state
 * without any credential material.
 */
object OnboardingLogger {
    private const val TAG = "CrystalOnboarding"

    fun debug(message: String) {
        Log.d(TAG, message)
    }

    fun info(message: String) {
        Log.i(TAG, message)
    }

    fun warn(message: String) {
        Log.w(TAG, message)
    }

    fun decision(
        input: String,
        normalized: String,
        localSessionState: String,
        backendLookup: String,
        deviceStatus: String,
        decision: String
    ) {
        info(
            "normalizedPhone=$normalized " +
                "localSession=[$localSessionState] " +
                "supabaseLookup=[$backendLookup] " +
                "deviceStatus=[$deviceStatus] " +
                "decision=[$decision]"
        )
    }
}