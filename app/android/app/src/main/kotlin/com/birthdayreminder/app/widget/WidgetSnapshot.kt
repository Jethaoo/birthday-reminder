package com.birthdayreminder.app.widget

import org.json.JSONException
import org.json.JSONObject

/**
 * The payload the Flutter app writes whenever it refreshes Home.
 *
 * It carries raw month/day facts rather than a precomputed countdown so the
 * widget can work out the days left itself, and `null` (a missing key) means
 * "this device has no session": the app deletes the snapshot when the user
 * signs out.
 *
 * ```json
 * {"version":1,"syncedAt":"2026-09-25T14:00:00Z","timezone":"Asia/Kuala_Lumpur",
 *  "birthdays":[{"id":"…","name":"Sarah Tan","month":9,"day":30,"birthYear":2000}]}
 * ```
 */
data class WidgetSnapshot(
    val birthdays: List<BirthdayFacts>,
    val syncedAt: String?,
) {
    companion object {
        /** The key the app writes the payload under. */
        const val KEY = "birthday_widget_snapshot"

        private const val VERSION = 1

        val empty = WidgetSnapshot(birthdays = emptyList(), syncedAt = null)

        /**
         * Reads [raw] into a snapshot, treating anything unusable as [empty].
         *
         * A widget has nowhere to show an error, so unknown versions, broken
         * JSON and malformed people all degrade to the "add your first
         * birthday" state rather than rendering half a payload.
         */
        fun parse(raw: String?): WidgetSnapshot {
            if (raw.isNullOrBlank()) return empty
            val json = try {
                JSONObject(raw)
            } catch (_: JSONException) {
                return empty
            }

            if (json.optInt("version", 0) != VERSION) return empty

            val people = json.optJSONArray("birthdays") ?: return empty
            val birthdays = buildList {
                for (index in 0 until people.length()) {
                    val person = people.optJSONObject(index) ?: continue
                    val parsed = parseBirthday(person) ?: continue
                    add(parsed)
                }
            }

            return WidgetSnapshot(
                birthdays = birthdays,
                syncedAt = json.optString("syncedAt").takeIf { it.isNotEmpty() },
            )
        }

        private fun parseBirthday(json: JSONObject): BirthdayFacts? {
            val id = json.optString("id").takeIf { it.isNotEmpty() } ?: return null
            val name = json.optString("name").trim().takeIf { it.isNotEmpty() } ?: return null
            val month = json.optInt("month", 0)
            val day = json.optInt("day", 0)
            if (!CountdownMath.isValidMonthDay(month, day)) return null

            val birthYear = json.optInt("birthYear", 0).takeIf { it > 0 }
            return BirthdayFacts(id = id, name = name, month = month, day = day, birthYear = birthYear)
        }
    }
}
