package com.birthdayreminder.app.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetSnapshotTest {
    private val valid = """
        {
          "version": 1,
          "syncedAt": "2026-09-25T14:00:00.000Z",
          "timezone": "Asia/Kuala_Lumpur",
          "birthdays": [
            {"id": "a", "name": "Sarah Tan", "month": 9, "day": 30, "birthYear": 2000},
            {"id": "b", "name": "Alex Lim", "month": 2, "day": 29}
          ]
        }
    """.trimIndent()

    @Test
    fun `reads the payload the app writes`() {
        val snapshot = WidgetSnapshot.parse(valid)

        assertEquals(2, snapshot.birthdays.size)
        assertEquals("Sarah Tan", snapshot.birthdays.first().name)
        assertEquals(2000, snapshot.birthdays.first().birthYear)
        assertNull(snapshot.birthdays.last().birthYear)
    }

    @Test
    fun `an absent snapshot means there is nothing to show`() {
        // The app deletes the key when the user signs out.
        assertEquals(WidgetSnapshot.empty, WidgetSnapshot.parse(null))
        assertEquals(WidgetSnapshot.empty, WidgetSnapshot.parse(""))
        assertEquals(WidgetSnapshot.empty, WidgetSnapshot.parse("   "))
    }

    @Test
    fun `broken json degrades to the empty state`() {
        assertEquals(WidgetSnapshot.empty, WidgetSnapshot.parse("{not json"))
        assertEquals(WidgetSnapshot.empty, WidgetSnapshot.parse("[]"))
    }

    @Test
    fun `a payload from another version is ignored`() {
        assertEquals(
            WidgetSnapshot.empty,
            WidgetSnapshot.parse(valid.replace("\"version\": 1", "\"version\": 2")),
        )
    }

    @Test
    fun `people without a usable date are skipped`() {
        val snapshot = WidgetSnapshot.parse(
            """
            {"version":1,"birthdays":[
              {"id":"a","name":"Sarah","month":9,"day":30},
              {"id":"b","name":"Broken","month":2,"day":30},
              {"id":"","name":"No id","month":9,"day":30},
              {"id":"d","name":"   ","month":9,"day":30},
              {"name":"No id at all","month":9,"day":30}
            ]}
            """.trimIndent(),
        )

        assertEquals(listOf("Sarah"), snapshot.birthdays.map { it.name })
    }

    @Test
    fun `a payload without a birthday list is empty`() {
        assertTrue(WidgetSnapshot.parse("""{"version":1}""").birthdays.isEmpty())
    }
}
