package com.birthdayreminder.app.widget

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/**
 * Receivers are what the launcher actually registers, one per layout offered in
 * its widget picker. Extending [HomeWidgetGlanceWidgetReceiver] is what lets the
 * app refresh them by name with `HomeWidget.updateWidget`.
 */
class NextBirthdayWidgetReceiver : HomeWidgetGlanceWidgetReceiver<NextBirthdayWidget>() {
    override val glanceAppWidget: NextBirthdayWidget = NextBirthdayWidget()
}

class NextBirthdaysWidgetReceiver : HomeWidgetGlanceWidgetReceiver<NextBirthdaysWidget>() {
    override val glanceAppWidget: NextBirthdaysWidget = NextBirthdaysWidget()
}

class TodayAndNextWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodayAndNextWidget>() {
    override val glanceAppWidget: TodayAndNextWidget = TodayAndNextWidget()
}
