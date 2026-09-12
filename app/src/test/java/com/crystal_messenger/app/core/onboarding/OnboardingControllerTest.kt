package com.crystal_messenger.app.core.onboarding

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the 8 onboarding scenarios. The controller is pure JVM logic: phone
 * normalization, an authoritative existence lambda and a device-block lambda
 * drive the decision. Local session/Room/cache state is only ever rendered for
 * logs and can never flip the classification.
 */
class OnboardingControllerTest {

    private val noLog: (
        String, String, String, String, String, String
    ) -> Unit = { _, _, _, _, _, _ -> }

    private fun controller(
        exists: (String) -> Boolean = { false },
        blocked: (String) -> Boolean = { false },
        local: () -> String = { "loggedIn=false" }
    ) = OnboardingController(
        accountExists = { p -> exists(p) },
        isDeviceBlocked = { p -> blocked(p) },
        localSession = local,
        onDecision = { _, _ -> },
        logDecision = noLog
    )

    @Test
    fun `fresh phone is NEW even if a previous local session exists`() = runTest {
        val c = controller(
            exists = { false },
            local = { "loggedIn=true phone=+19999999999" }
        )
        assertEquals(OnboardingDecision.FreshAccount, c.decide("+15551234567"))
    }

    @Test
    fun `fresh phone is NEW after logout local session cleared`() = runTest {
        val c = controller(exists = { false }, local = { "loggedIn=false" })
        assertEquals(OnboardingDecision.FreshAccount, c.decide("+15551234567"))
    }

    @Test
    fun `existing phone from users table is EXISTING`() = runTest {
        val c = controller(exists = { p -> p == "+15551234567" })
        assertEquals(OnboardingDecision.ExistingAccount, c.decide("+15551234567"))
    }

    @Test
    fun `different phone same device is NEW unaffected by stale local state`() = runTest {
        val c = controller(
            exists = { p -> p == "+15550000001" },
            local = { "loggedIn=true phone=+15559999999 onboarded=true" }
        )
        // Device previously used for a different account; new number is fresh.
        assertEquals(OnboardingDecision.FreshAccount, c.decide("+15551234567"))
        // The old number itself remains EXISTING.
        assertEquals(OnboardingDecision.ExistingAccount, c.decide("+15550000001"))
    }

    @Test
    fun `stale local session manager state cannot force EXISTING`() = runTest {
        val c = controller(
            exists = { false },
            local = { "loggedIn=true onboarded=true phone=+15551234567" }
        )
        // Even though local state claims the very same phone, backend says NEW.
        assertEquals(OnboardingDecision.FreshAccount, c.decide("+15551234567"))
    }

    @Test
    fun `blocked device is DEVICE_BLOCKED for fresh and existing phones`() = runTest {
        val blocked = controller(blocked = { true })
        assertEquals(OnboardingDecision.DeviceBlocked(null), blocked.decide("+15551234567"))

        val blockedExisting = controller(exists = { true }, blocked = { true })
        assertEquals(OnboardingDecision.DeviceBlocked(null), blockedExisting.decide("+15550000001"))
    }

    @Test
    fun `device block is its own state never merged with existence`() = runTest {
        var existsChecked = false
        var blockedChecked = false
        val c = OnboardingController(
            accountExists = { existsChecked = true; true },
            isDeviceBlocked = { blockedChecked = true; true },
            localSession = { "x" },
            logDecision = noLog
        )
        val result = c.decide("+15551234567")
        assertEquals(OnboardingDecision.DeviceBlocked(null), result)
        assertTrue(blockedChecked)
        // Existence must NOT even be consulted for a blocked device.
        assertEquals(false, existsChecked)
    }

    @Test
    fun `malformed and empty phones are INVALID`() = runTest {
        val c = controller()
        assertEquals(OnboardingDecision.InvalidPhone, c.decide(""))
        assertEquals(OnboardingDecision.InvalidPhone, c.decide("abc"))
        assertEquals(OnboardingDecision.InvalidPhone, c.decide("1234567"))
        assertEquals(OnboardingDecision.InvalidPhone, c.decide("+1234567890123456"))
    }

    @Test
    fun `normalization is applied before the existence lookup`() = runTest {
        var lookedUp: String? = null
        val c = OnboardingController(
            accountExists = { lookedUp = it; false },
            isDeviceBlocked = { false },
            localSession = { "x" },
            logDecision = noLog
        )
        val result = c.decide("+1 (555) 123-4567")
        assertEquals(OnboardingDecision.FreshAccount, result)
        assertEquals("+15551234567", lookedUp)
    }
}