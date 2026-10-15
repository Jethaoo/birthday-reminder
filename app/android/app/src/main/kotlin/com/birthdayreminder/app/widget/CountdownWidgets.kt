package com.birthdayreminder.app.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ColumnScope
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.birthdayreminder.app.MainActivity
import com.birthdayreminder.app.R
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.actionStartActivity

/**
 * The 2x2 countdown: whoever is next, and how many days away they are.
 */
class NextBirthdayWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*>? = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val render = WidgetRender.load(context, upcomingLimit = 1)
        provideContent {
            WidgetCard(palette = render.palette, onClick = openApp(context)) {
                when {
                    !render.signedIn -> EmptyState(
                        context,
                        render.palette,
                        R.string.widget_signed_out_title,
                        R.string.widget_signed_out_message,
                    )

                    render.upcoming.isEmpty() -> EmptyState(
                        context,
                        render.palette,
                        R.string.widget_no_birthdays_title,
                        R.string.widget_no_birthdays_message,
                    )

                    else -> NextBirthdayBody(context, render)
                }
            }
        }
    }
}

/** The 4x2 ranked list of the three nearest birthdays. */
class NextBirthdaysWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*>? = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val render = WidgetRender.load(context, upcomingLimit = 3)
        provideContent {
            WidgetCard(palette = render.palette, onClick = openApp(context)) {
                when {
                    !render.signedIn -> EmptyState(
                        context,
                        render.palette,
                        R.string.widget_signed_out_title,
                        R.string.widget_signed_out_message,
                    )

                    render.upcoming.isEmpty() -> EmptyState(
                        context,
                        render.palette,
                        R.string.widget_no_birthdays_title,
                        R.string.widget_no_birthdays_message,
                    )

                    else -> NextBirthdaysBody(context, render)
                }
            }
        }
    }
}

/** The 4x2 "who is today, who is next" layout. */
class TodayAndNextWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*>? = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val render = WidgetRender.load(context, upcomingLimit = 4)
        provideContent {
            WidgetCard(palette = render.palette, onClick = openApp(context)) {
                when {
                    !render.signedIn -> EmptyState(
                        context,
                        render.palette,
                        R.string.widget_signed_out_title,
                        R.string.widget_signed_out_message,
                    )

                    render.today.isEmpty() && render.upcoming.isEmpty() -> EmptyState(
                        context,
                        render.palette,
                        R.string.widget_no_birthdays_title,
                        R.string.widget_no_birthdays_message,
                    )

                    else -> TodayAndNextBody(context, render)
                }
            }
        }
    }
}

/**
 * Everything a widget needs for one render: the palette to draw with and the
 * countdowns worked out against the device's local date.
 */
private class WidgetRender(
    val palette: WidgetPalette,
    val signedIn: Boolean,
    val today: List<Countdown>,
    val upcoming: List<Countdown>,
) {
    companion object {
        fun load(context: Context, upcomingLimit: Int): WidgetRender {
            val prefs = HomeWidgetPlugin.getData(context)
            val raw = prefs.getString(WidgetSnapshot.KEY, null)
            val snapshot = WidgetSnapshot.parse(raw)
            val today = CivilDate.now()

            return WidgetRender(
                palette = WidgetPalette.forContext(context),
                signedIn = raw != null,
                today = CountdownMath.today(snapshot.birthdays, today),
                upcoming = CountdownMath.upcoming(snapshot.birthdays, today, upcomingLimit),
            )
        }
    }
}

/** Rounded card that every layout sits in. Tapping the card opens the app. */
@Composable
private fun WidgetCard(
    palette: WidgetPalette,
    onClick: Action,
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(palette.surface)
            .cornerRadius(22.dp)
            .clickable(onClick),
        contentAlignment = Alignment.TopStart,
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(12.dp),
            verticalAlignment = Alignment.Vertical.Top,
            horizontalAlignment = Alignment.Horizontal.Start,
            content = content,
        )
    }
}

@Composable
private fun NextBirthdayBody(context: Context, render: WidgetRender) {
    val palette = render.palette
    val next = render.upcoming.first()

    Column(
        modifier = GlanceModifier.fillMaxSize(),
        horizontalAlignment = Alignment.Horizontal.Start,
    ) {
        Text(
            text = context.getString(R.string.widget_heading_next),
            style = labelStyle(palette.textSecondary),
            maxLines = 1,
        )
        Box(
            modifier = GlanceModifier.fillMaxWidth().defaultWeight(),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.Horizontal.CenterHorizontally) {
                // `Today` is a word, everything else is a number with its unit
                // underneath, matching how the app labels its countdowns.
                val isToday = next.daysUntil == 0
                Text(
                    text = if (isToday) {
                        context.getString(R.string.widget_today)
                    } else {
                        next.daysUntil.toString()
                    },
                    style = if (isToday) {
                        headlineWordStyle(palette.textPrimary)
                    } else {
                        headlineStyle(palette.textPrimary)
                    },
                    maxLines = 1,
                )
                if (!isToday) {
                    Text(
                        text = context.resources.getQuantityString(
                            R.plurals.widget_day_label,
                            next.daysUntil,
                            next.daysUntil,
                        ),
                        style = bodyStyle(palette.textSecondary, sizeSp = 10f),
                        maxLines = 1,
                    )
                }
            }
        }
        Text(
            text = next.birthday.name,
            // Constrained to the card so a long name clips at the edge instead
            // of pushing past it.
            modifier = GlanceModifier.fillMaxWidth(),
            style = bodyStyle(palette.textPrimary, sizeSp = 12f, weight = FontWeight.Medium),
            maxLines = 1,
        )
    }
}

@Composable
private fun NextBirthdaysBody(context: Context, render: WidgetRender) {
    val palette = render.palette

    Column(modifier = GlanceModifier.fillMaxSize()) {
        Text(
            text = context.getString(R.string.widget_heading_coming_up),
            style = labelStyle(palette.textSecondary),
            maxLines = 1,
        )
        Spacer(modifier = GlanceModifier.height(6.dp))
        render.upcoming.forEachIndexed { index, countdown ->
            if (index > 0) Spacer(modifier = GlanceModifier.height(4.dp))
            PersonRow(context, render, countdown)
        }
    }
}

@Composable
private fun PersonRow(context: Context, render: WidgetRender, countdown: Countdown) {
    val palette = render.palette
    val birthday = countdown.birthday

    Row(
        modifier = GlanceModifier.fillMaxWidth().clickable(openBirthday(context, birthday.id)),
        verticalAlignment = Alignment.Vertical.CenterVertically,
    ) {
        Box(
            modifier = GlanceModifier
                .size(18.dp)
                .background(palette.tintFor(birthday))
                .cornerRadius(9.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = birthday.initials,
                style = bodyStyle(palette.textPrimary, sizeSp = 8f, weight = FontWeight.Bold),
                maxLines = 1,
            )
        }
        Spacer(modifier = GlanceModifier.width(8.dp))
        Text(
            text = birthday.name,
            modifier = GlanceModifier.defaultWeight(),
            style = bodyStyle(palette.textPrimary, sizeSp = 12f, weight = FontWeight.Medium),
            maxLines = 1,
        )
        Text(
            text = countdownLabel(context, countdown.daysUntil),
            style = bodyStyle(palette.accentText, sizeSp = 11f, weight = FontWeight.Bold),
            maxLines = 1,
        )
    }
}

@Composable
private fun TodayAndNextBody(context: Context, render: WidgetRender) {
    val palette = render.palette
    val next = render.upcoming.firstOrNull { it.daysUntil > 0 }

    Column(modifier = GlanceModifier.fillMaxSize()) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Box(
                modifier = GlanceModifier
                    .background(palette.softPink)
                    .cornerRadius(999.dp)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Text(
                    text = context.getString(R.string.widget_heading_today),
                    style = bodyStyle(palette.accentText, sizeSp = 9f, weight = FontWeight.Bold),
                    maxLines = 1,
                )
            }
            Spacer(modifier = GlanceModifier.width(8.dp))
            Text(
                text = todaySummary(context, render.today),
                modifier = GlanceModifier.defaultWeight(),
                style = bodyStyle(palette.textPrimary, sizeSp = 12f, weight = FontWeight.Medium),
                maxLines = 1,
            )
        }

        // Nothing left on the calendar: the today row stands on its own rather
        // than leaving an empty "next up" line.
        if (next != null) {
            Spacer(modifier = GlanceModifier.height(8.dp))
            Spacer(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(palette.border),
            )
            Spacer(modifier = GlanceModifier.height(8.dp))

            Row(
                modifier = GlanceModifier.fillMaxWidth().defaultWeight(),
                verticalAlignment = Alignment.Vertical.CenterVertically,
            ) {
                Column(modifier = GlanceModifier.defaultWeight()) {
                    Text(
                        text = context.getString(R.string.widget_heading_next_up),
                        style = labelStyle(palette.textSecondary),
                        maxLines = 1,
                    )
                    Text(
                        text = next.birthday.name,
                        modifier = GlanceModifier.fillMaxWidth(),
                        style = bodyStyle(
                            palette.textPrimary,
                            sizeSp = 12f,
                            weight = FontWeight.Medium,
                        ),
                        maxLines = 1,
                    )
                }
                Text(
                    text = countdownLabel(context, next.daysUntil),
                    style = bodyStyle(palette.accentText, sizeSp = 11f, weight = FontWeight.Bold),
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
private fun EmptyState(context: Context, palette: WidgetPalette, titleRes: Int, messageRes: Int) {
    Column(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.Vertical.CenterVertically,
        horizontalAlignment = Alignment.Horizontal.Start,
    ) {
        Text(
            text = context.getString(titleRes),
            modifier = GlanceModifier.fillMaxWidth(),
            style = bodyStyle(palette.textPrimary, sizeSp = 13f, weight = FontWeight.Bold),
            maxLines = 2,
        )
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = context.getString(messageRes),
            modifier = GlanceModifier.fillMaxWidth(),
            style = bodyStyle(palette.textSecondary, sizeSp = 11f),
            maxLines = 2,
        )
    }
}

/** `Today`, `Tomorrow`, `12 days`, matching the app's `countdownLabel`. */
private fun countdownLabel(context: Context, daysUntil: Int): String = when (daysUntil) {
    0 -> context.getString(R.string.widget_today)
    1 -> context.getString(R.string.widget_tomorrow)
    else -> context.resources.getQuantityString(R.plurals.widget_days, daysUntil, daysUntil)
}

/** `Sarah Tan`, `Sarah Tan +2 more`, or the empty-state line. */
private fun todaySummary(context: Context, today: List<Countdown>): String {
    if (today.isEmpty()) return context.getString(R.string.widget_no_birthdays_today)
    val extra = today.size - 1
    return if (extra == 0) {
        today.first().birthday.name
    } else {
        "${today.first().birthday.name} +$extra"
    }
}

private fun openApp(context: Context): Action =
    actionStartActivity<MainActivity>(context, Uri.parse("birthdayreminder://home"))

private fun openBirthday(context: Context, id: String): Action =
    actionStartActivity<MainActivity>(context, Uri.parse("birthdayreminder://birthdays/$id"))

private fun labelStyle(color: Color): TextStyle = TextStyle(
    color = ColorProvider(color),
    fontSize = 9.sp,
    fontWeight = FontWeight.Bold,
)

private fun headlineStyle(color: Color): TextStyle = TextStyle(
    color = ColorProvider(color),
    fontSize = 32.sp,
    fontWeight = FontWeight.Bold,
)

/** `Today` is drawn smaller so it fits the 2x2 card without wrapping. */
private fun headlineWordStyle(color: Color): TextStyle = TextStyle(
    color = ColorProvider(color),
    fontSize = 20.sp,
    fontWeight = FontWeight.Bold,
)

private fun bodyStyle(
    color: Color,
    sizeSp: Float,
    weight: FontWeight? = null,
): TextStyle = TextStyle(
    color = ColorProvider(color),
    fontSize = sizeSp.sp,
    fontWeight = weight,
)
