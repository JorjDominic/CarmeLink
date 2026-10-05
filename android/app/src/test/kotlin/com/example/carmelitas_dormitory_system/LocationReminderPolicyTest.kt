package com.example.carmelitas_dormitory_system

import org.junit.Assert.assertEquals
import org.junit.Test

class LocationReminderPolicyTest {
    @Test fun missingReminderWithStaleCooldownIsRestored() {
        assertEquals(LocationReminderPolicy.Action.RESTORE_SILENTLY,
            LocationReminderPolicy.decide(false, false, 100_000L, 110_000L))
    }

    @Test fun observedRecoveryThenOutageAlertsEvenWithinAnHour() {
        assertEquals(LocationReminderPolicy.Action.ALERT,
            LocationReminderPolicy.decide(true, true, 100_000L, 110_000L))
    }

    @Test fun existingReminderIsNotRepostedEveryThirtySeconds() {
        assertEquals(LocationReminderPolicy.Action.KEEP,
            LocationReminderPolicy.decide(false, true, 100_000L, 130_000L))
    }

    @Test fun failedOrBlockedInitialPostDoesNotSuppressNextAttempt() {
        assertEquals(LocationReminderPolicy.Action.ALERT,
            LocationReminderPolicy.decide(false, false, 0L, 130_000L))
    }

    @Test fun hourlyReminderAlertsAtTheBoundary() {
        assertEquals(LocationReminderPolicy.Action.KEEP,
            LocationReminderPolicy.decide(false, true, 100_000L, 3_699_999L))
        assertEquals(LocationReminderPolicy.Action.ALERT,
            LocationReminderPolicy.decide(false, true, 100_000L, 3_700_000L))
    }

    @Test fun clockRollbackDoesNotSuppressReminder() {
        assertEquals(LocationReminderPolicy.Action.ALERT,
            LocationReminderPolicy.decide(false, true, 130_000L, 100_000L))
    }
}
