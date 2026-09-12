package com.crystal_messenger.app.core.onboarding

/**
 * Sealed decision for a phone entering onboarding.
 *
 * - [FreshAccount]  : phone NOT found on the backend → create a new account.
 * - [ExistingAccount]: phone found on the backend → sign the user in.
 * - [DeviceBlocked] : phone is in the server-side block list → blocked flow,
 *                     independent of account existence.
 * - [InvalidPhone]  : input cannot be normalized to a plausible phone.
 */
sealed class OnboardingDecision {
    data object FreshAccount : OnboardingDecision()
    data object ExistingAccount : OnboardingDecision()
    data class DeviceBlocked(val reason: String?) : OnboardingDecision()
    data object InvalidPhone : OnboardingDecision()
}

/**
 * Pure onboarding decision logic. Decides purely from server state that is
 * looked up via the injected lambdas:
 *
 *   - [accountExists]: authoritative existence check against the Supabase
 *     `users` table keyed by the canonical phone.
 *   - [isDeviceBlocked]: server-side DEVICE_BLOCKED state check.
 *
 * The decider deliberately receives NO Room cache, NO SessionManager and NO
 * Android identifiers. A previous local account can therefore never influence
 * the classification of the *entered* phone number.
 */
class OnboardingController(
    private val accountExists: suspend (phone: String) -> Boolean,
    private val isDeviceBlocked: suspend (phone: String) -> Boolean,
    private val localSession: () -> String,
    private val onDecision: (decision: OnboardingDecision, normalizedPhone: String) -> Unit = { _, _ -> },
    private val logDecision: (input: String, normalized: String, local: String, lookup: String, device: String, decision: String) -> Unit =
        { input, phone, local, lookup, device, decision ->
            OnboardingLogger.decision(
                input = input,
                normalized = phone,
                localSessionState = local,
                backendLookup = lookup,
                deviceStatus = device,
                decision = decision
            )
        }
) {

    /**
     * Classifies a raw phone input. Throws [OnboardingException] only for
     * non-invalid but unclassifiable cases; a well-formed phone always maps to
     * one of the four decisions (network failures are surfaced by the caller).
     */
    suspend fun decide(rawPhone: String): OnboardingDecision {
        val normalized = PhoneNormalizer.normalize(rawPhone)
        if (!PhoneNormalizer.isValid(rawPhone)) return OnboardingDecision.InvalidPhone

        // DEVICE_BLOCKED is its own server-side state, checked first and never
        // merged with account existence.
        val blocked = isDeviceBlocked(normalized)
        if (blocked) {
            onDecision(OnboardingDecision.DeviceBlocked(null), normalized)
            return OnboardingDecision.DeviceBlocked(null)
        }

        val exists = accountExists(normalized)
        val decision =
            if (exists) OnboardingDecision.ExistingAccount
            else OnboardingDecision.FreshAccount

        logDecision(
            rawPhone,
            normalized,
            localSession(),
            if (exists) "FOUND" else "NOT_FOUND",
            "ALLOWED",
            if (exists) "EXISTING" else "NEW"
        )
        onDecision(decision, normalized)
        return decision
    }
}

/** Thrown when onboarding cannot proceed for a server-side policy reason. */
class OnboardingException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)