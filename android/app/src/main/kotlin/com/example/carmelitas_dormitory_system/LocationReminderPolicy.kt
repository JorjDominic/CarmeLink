package com.example.carmelitas_dormitory_system

/** The cooldown controls sound; it must not suppress a missing outage reminder. */
object LocationReminderPolicy {
    enum class Action { ALERT, RESTORE_SILENTLY, KEEP }

    fun decide(changed: Boolean, visible: Boolean, lastAlertAt: Long, now: Long): Action = when {
        changed || lastAlertAt <= 0L || now < lastAlertAt || now - lastAlertAt >= 3_600_000L -> Action.ALERT
        !visible -> Action.RESTORE_SILENTLY
        else -> Action.KEEP
    }
}
