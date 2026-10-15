package com.birthdayreminder.app.widget

import android.content.Context
import android.content.res.Configuration
import androidx.compose.ui.graphics.Color

/** The design tokens from `app/lib/app/theme.dart`, for the widget. */
data class WidgetPalette(
    val surface: Color,
    val primary: Color,
    val onPrimary: Color,
    val accent: Color,
    val accentText: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val border: Color,
    val softPink: Color,
    val avatarTints: List<Color>,
) {
    /** The tint the app gives this person, so avatars match across screens. */
    fun tintFor(birthday: BirthdayFacts): Color =
        avatarTints[(birthday.colorSeed % avatarTints.size + avatarTints.size) % avatarTints.size]

    companion object {
        val light = WidgetPalette(
            surface = Color(0xFFFFFFFF),
            primary = Color(0xFF293D32),
            onPrimary = Color(0xFFFFFFFF),
            accent = Color(0xFFFB8269),
            accentText = Color(0xFFD75A45),
            textPrimary = Color(0xFF243029),
            textSecondary = Color(0xFF7C857F),
            border = Color(0xFFE5E5DC),
            softPink = Color(0xFFFDE5DE),
            avatarTints = listOf(
                Color(0xFFFFDDD2),
                Color(0xFFD8E6FF),
                Color(0xFFDFF4DC),
                Color(0xFFF1DCFF),
            ),
        )

        val dark = WidgetPalette(
            surface = Color(0xFF18201B),
            primary = Color(0xFF4E6B57),
            onPrimary = Color(0xFFFFFFFF),
            accent = Color(0xFFFF9C86),
            accentText = Color(0xFFFF9C86),
            textPrimary = Color(0xFFEDF1EC),
            textSecondary = Color(0xFF9BA69F),
            border = Color(0xFF2B352F),
            softPink = Color(0xFF3A2622),
            avatarTints = listOf(
                Color(0xFF4A2F29),
                Color(0xFF25334A),
                Color(0xFF26382A),
                Color(0xFF35263F),
            ),
        )

        /**
         * The palette this device should use.
         *
         * Appearance can be pinned in the app, so that choice wins; otherwise
         * the widget follows the phone's light/dark setting. Glance re-renders
         * on a configuration change, so a system theme switch is picked up
         * without any explicit refresh.
         */
        fun forContext(context: Context): WidgetPalette = when (themeOverride(context)) {
            "light" -> light
            "dark" -> dark
            else -> if (isSystemDark(context)) dark else light
        }
    }
}

/** `shared_preferences` on Android writes here, with every key prefixed. */
private const val FLUTTER_PREFERENCES = "FlutterSharedPreferences"
private const val THEME_MODE_KEY = "flutter.pref_theme_mode"

private fun themeOverride(context: Context): String? = runCatching {
    context
        .getSharedPreferences(FLUTTER_PREFERENCES, Context.MODE_PRIVATE)
        .getString(THEME_MODE_KEY, null)
}.getOrNull()

private fun isSystemDark(context: Context): Boolean {
    val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
    return mode == Configuration.UI_MODE_NIGHT_YES
}
