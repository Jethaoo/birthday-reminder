package com.birthdayreminder.app.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The widget counts down against the device date, so these cases have to match
 * `backend/src/lib/time.ts` exactly.
 */
class CountdownMathTest {
    private fun person(name: String, month: Int, day: Int, birthYear: Int? = null) =
        BirthdayFacts(id = name, name = name, month = month, day = day, birthYear = birthYear)

    @Test
    fun `today counts as zero days`() {
        val today = CivilDate(2026, 9, 30)

        assertEquals(0, CountdownMath.countdown(person("Sarah", 9, 30), today).daysUntil)
    }

    @Test
    fun `tomorrow counts as one day`() {
        val today = CivilDate(2026, 9, 30)

        assertEquals(1, CountdownMath.countdown(person("Sarah", 10, 1), today).daysUntil)
    }

    @Test
    fun `a date later in the year counts the days between`() {
        val today = CivilDate(2026, 9, 30)

        assertEquals(12, CountdownMath.countdown(person("Sarah", 10, 12), today).daysUntil)
    }

    @Test
    fun `a date that already passed rolls into next year`() {
        val today = CivilDate(2026, 12, 31)

        assertEquals(1, CountdownMath.countdown(person("Sarah", 1, 1), today).daysUntil)
    }

    @Test
    fun `a leap day is observed on the 28th in a non-leap year`() {
        val today = CivilDate(2027, 2, 1)

        val countdown = CountdownMath.countdown(person("Sarah", 2, 29), today)

        assertEquals(27, countdown.daysUntil)
        assertEquals(CivilDate(2027, 2, 28), CountdownMath.nextOccurrence(2, 29, today))
    }

    @Test
    fun `a leap day keeps its own date in a leap year`() {
        val today = CivilDate(2028, 2, 1)

        assertEquals(28, CountdownMath.countdown(person("Sarah", 2, 29), today).daysUntil)
    }

    @Test
    fun `the age turned is worked out from the next occurrence`() {
        val today = CivilDate(2026, 9, 30)

        assertEquals(26, CountdownMath.countdown(person("Sarah", 10, 12, 2000), today).turningAge)
        assertNull(CountdownMath.countdown(person("Sarah", 10, 12), today).turningAge)
    }

    @Test
    fun `days between handles both directions`() {
        assertEquals(
            1,
            CountdownMath.daysBetween(CivilDate(2026, 12, 31), CivilDate(2027, 1, 1)),
        )
        assertEquals(
            -1,
            CountdownMath.daysBetween(CivilDate(2027, 1, 1), CivilDate(2026, 12, 31)),
        )
    }

    @Test
    fun `upcoming drops the past, sorts by distance and honours the limit`() {
        val today = CivilDate(2026, 9, 30)
        val birthdays = listOf(
            person("Priya", 12, 1),
            person("Yesterday", 9, 29),
            person("Alex", 10, 2),
            person("Sarah", 9, 30),
        )

        val upcoming = CountdownMath.upcoming(birthdays, today, limit = 3)

        assertEquals(listOf("Sarah", "Alex", "Priya"), upcoming.map { it.birthday.name })
    }

    @Test
    fun `today only holds the people whose birthday it is`() {
        val today = CivilDate(2026, 9, 30)
        val birthdays = listOf(person("Sarah", 9, 30), person("Alex", 10, 2))

        assertEquals(listOf("Sarah"), CountdownMath.today(birthdays, today).map { it.birthday.name })
    }

    @Test
    fun `leap years follow the calendar rule`() {
        assertTrue(CountdownMath.isLeapYear(2028))
        assertTrue(CountdownMath.isLeapYear(2000))
        assertFalse(CountdownMath.isLeapYear(2100))
        assertFalse(CountdownMath.isLeapYear(2027))
    }

    @Test
    fun `only real month and day pairs are accepted`() {
        assertTrue(CountdownMath.isValidMonthDay(2, 29))
        assertTrue(CountdownMath.isValidMonthDay(9, 30))
        assertFalse(CountdownMath.isValidMonthDay(2, 30))
        assertFalse(CountdownMath.isValidMonthDay(4, 31))
        assertFalse(CountdownMath.isValidMonthDay(13, 1))
        assertFalse(CountdownMath.isValidMonthDay(0, 1))
    }

    @Test
    fun `initials and tints follow the app's avatar rules`() {
        assertEquals("ST", person("Sarah Tan", 9, 30).initials)
        assertEquals("S", person("Sarah", 9, 30).initials)
        assertEquals("?", person("   ", 9, 30).initials)
        assertEquals("Sarah Tan".sumOf { it.code }, person("Sarah Tan", 9, 30).colorSeed)
    }
}
