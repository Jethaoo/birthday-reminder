package com.birthdayreminder.app.widget

import java.util.Calendar

/** A calendar date without a time or a zone, mirroring the backend's `LocalDate`. */
data class CivilDate(val year: Int, val month: Int, val day: Int) {
    companion object {
        /**
         * The device's local date.
         *
         * The widget counts down against the phone rather than the server: the
         * snapshot only carries month/day facts, so the number of days left is
         * always right, even when the app has not been opened since yesterday.
         */
        fun now(calendar: Calendar = Calendar.getInstance()): CivilDate = CivilDate(
            year = calendar.get(Calendar.YEAR),
            month = calendar.get(Calendar.MONTH) + 1,
            day = calendar.get(Calendar.DAY_OF_MONTH),
        )
    }
}

/** One stored birthday, as the app last saw it. */
data class BirthdayFacts(
    val id: String,
    val name: String,
    val month: Int,
    val day: Int,
    val birthYear: Int?,
) {
    /** Stable per-person tint seed, matching `InitialsMixin.colorSeed` in Dart. */
    val colorSeed: Int get() = name.fold(0) { sum, char -> sum + char.code }

    /** `ST`, matching `InitialsMixin.initials` in Dart. */
    val initials: String
        get() {
            val parts = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
            if (parts.isEmpty()) return "?"
            if (parts.size == 1) return parts.first().substring(0, 1).uppercase()
            return (parts.first().substring(0, 1) + parts.last().substring(0, 1)).uppercase()
        }
}

/** A birthday paired with the countdown the widget should draw right now. */
data class Countdown(
    val birthday: BirthdayFacts,
    val daysUntil: Int,
    val turningAge: Int?,
)

/**
 * The countdown maths, mirroring `backend/src/lib/time.ts`.
 *
 * Everything is plain integer arithmetic on purpose: `java.time` is only
 * available from API 26 and the app supports API 24.
 */
object CountdownMath {
    fun isLeapYear(year: Int): Boolean = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0

    fun daysInMonth(year: Int, month: Int): Int = when (month) {
        1, 3, 5, 7, 8, 10, 12 -> 31
        4, 6, 9, 11 -> 30
        2 -> if (isLeapYear(year)) 29 else 28
        else -> 0
    }

    fun isValidMonthDay(month: Int, day: Int): Boolean {
        if (month !in 1..12) return false
        if (day < 1) return false
        // 29 February is valid so leap-day birthdays can be stored.
        return day <= if (month == 2) 29 else daysInMonth(2023, month)
    }

    /** 29 February birthdays are observed on 28 February in non-leap years. */
    fun resolveOccurrenceDate(year: Int, month: Int, day: Int): CivilDate =
        CivilDate(year, month, minOf(day, daysInMonth(year, month)))

    /** The next occurrence on or after [today]. */
    fun nextOccurrence(month: Int, day: Int, today: CivilDate): CivilDate {
        val thisYear = resolveOccurrenceDate(today.year, month, day)
        return if (daysBetween(today, thisYear) < 0) {
            resolveOccurrenceDate(today.year + 1, month, day)
        } else {
            thisYear
        }
    }

    /** Whole days from [from] to [to]; negative when [to] is earlier. */
    fun daysBetween(from: CivilDate, to: CivilDate): Int = daysFromCivil(to) - daysFromCivil(from)

    /** Days since 1970-01-01 (Howard Hinnant's `days_from_civil`). */
    fun daysFromCivil(date: CivilDate): Int {
        val year = date.year - if (date.month <= 2) 1 else 0
        val era = (if (year >= 0) year else year - 399) / 400
        val yearOfEra = year - era * 400
        val dayOfYear =
            (153 * (date.month + (if (date.month > 2) -3 else 9)) + 2) / 5 + date.day - 1
        val dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146097 + dayOfEra - 719468
    }

    /** The countdown for one person, evaluated against [today]. */
    fun countdown(birthday: BirthdayFacts, today: CivilDate): Countdown {
        val occurrence = nextOccurrence(birthday.month, birthday.day, today)
        return Countdown(
            birthday = birthday,
            daysUntil = daysBetween(today, occurrence),
            turningAge = birthday.birthYear?.let { occurrence.year - it },
        )
    }

    /**
     * Everyone whose birthday is on or after [today], nearest first.
     *
     * Entries that slipped into the past since the last sync are dropped, which
     * is what keeps the widget sane when the app has not run for a few days.
     */
    fun upcoming(
        birthdays: List<BirthdayFacts>,
        today: CivilDate,
        limit: Int = Int.MAX_VALUE,
    ): List<Countdown> = birthdays
        .map { countdown(it, today) }
        .filter { it.daysUntil >= 0 }
        .sortedWith(compareBy({ it.daysUntil }, { it.birthday.name }))
        .take(limit)

    /** Everyone whose birthday is today. */
    fun today(birthdays: List<BirthdayFacts>, today: CivilDate): List<Countdown> =
        upcoming(birthdays, today).filter { it.daysUntil == 0 }
}
