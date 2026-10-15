# Home screen widgets

Three Android home screen widgets put the countdown where it is actually seen: on the launcher,
without opening the app.

| Widget | Size | Shows |
| --- | --- | --- |
| **Next birthday** | 2×2 | The day count, large, and who it belongs to |
| **Next 3 birthdays** | 4×2 | The three nearest birthdays with their counts |
| **Today & next** | 4×2 | Who is today, then who is next |

Each layout is a separate entry in the launcher's widget picker, so the user chooses by picking a
widget. The sizes are fixed (`resizeMode="none"`); there is no configuration screen and no in-app
setting. A widget tap opens the app — on a name it opens that person's details, anywhere else it
opens Home.

## Where the data comes from

The backend stays the source of truth. The app never hands the widget a precomputed "12 days":

- When Home loads, the app writes a small snapshot of the facts it just fetched — name, month, day
  and optional birth year per person — into shared storage, then refreshes the widgets.
- The widget recomputes the day count from the **device's own date** every time it renders, using the
  same rules as the backend (`backend/src/lib/time.ts`): the next occurrence on or after today,
  whole days in between, and 29 February observed on 28 February in non-leap years.

That is what keeps the numbers honest overnight: the date moves, the countdown follows, and no
network call, token or background job is involved. The widget process never holds a bearer token and
never talks to the API.

The tradeoff is latency for data changes. A birthday added on another device appears once this app
next loads Home, because that is when a fresh snapshot is written. The snapshot holds Home's today
plus its five upcoming birthdays, so a phone that is not opened for several days still shows correct
counts; once nothing upcoming is left, the widget falls back to its empty state.

## Snapshot contract

Stored under the key `birthday_widget_snapshot` in the `home_widget` plugin's preferences
(`HomeWidgetPreferences`), as a JSON string:

```json
{
  "version": 1,
  "syncedAt": "2026-09-25T14:00:00.000Z",
  "timezone": "Asia/Kuala_Lumpur",
  "birthdays": [
    { "id": "…", "name": "Sarah Tan", "month": 9, "day": 30, "birthYear": 2000 }
  ]
}
```

Rules the native side relies on:

- `version` must be `1`. Anything else is treated as no data, so an old widget can never render half
  a newer payload.
- `birthYear` is omitted when the user never entered one; the widget then shows the countdown
  without an age.
- The app **deletes** the key when the user signs out. A missing key is what puts the widgets into
  their "sign in to see your countdowns" state, which is why signing out takes the names off the
  home screen immediately.
- The timezone is informational. The widget counts against the phone's local date, so a device that
  changes timezone is right on the next render without a sync.

## When the widgets refresh

| Trigger | Why |
| --- | --- |
| Home loads, or a birthday is added, edited or deleted | There are new facts to publish |
| Just after each local midnight | Flips today/tomorrow and steps every count down |
| The app resumes | Re-arms the midnight alarms a force-stop or battery sweep can drop |
| Reboot or app update | The plugin's scheduled-update receiver re-arms them |

The midnight refreshes are armed three nights ahead through `HomeWidget.scheduleWidgetUpdates`, so a
single missed alarm heals itself. They are deliberately *inexact*: the app does not request
`SCHEDULE_EXACT_ALARM`, so Android may deliver a midnight refresh a few minutes late — harmless
here, because the number drawn comes from the date at render time rather than from the alarm. There
is no periodic polling; `updatePeriodMillis` is `0`.

## Appearance

The widgets mirror the app's palette (`app/lib/app/theme.dart`) and follow the Appearance setting
when it is pinned to light or dark; otherwise they follow the phone. Text is deliberately drawn in
the system font: Glance can only resolve built-in font families, and using the bundled DM Sans and
Fraunces would mean picture-of-text bitmaps that ignore the user's type-size setting. Avatars use the
same initials and tints as the app, so a person looks the same in both places. Photos are not shown —
they sit behind the bearer token.

## Code map

| Path | Role |
| --- | --- |
| `app/lib/core/widgets/` | Snapshot contract, the `home_widget` bridge, and the sync that publishes Home |
| `app/lib/app/widget_coordinator.dart` | Routes widget taps into the router and re-arms refreshes |
| `app/android/app/src/main/kotlin/com/birthdayreminder/app/widget/` | Glance layouts, countdown maths and the snapshot parser |
| `app/android/app/src/main/res/xml/*_widget_info.xml` | One provider description per layout |

## Verifying a change

```bash
cd app && flutter analyze && flutter test
cd app/android && ./gradlew :app:testDebugUnitTest
cd app && flutter build apk --debug
```

The Gradle wrapper needs a JDK 17+ on `JAVA_HOME`; a shell still pointing at Java 8 fails before the
first task runs.

On a device or emulator: add each of the three widgets from the launcher picker, check them in light
and dark mode, tap a name and confirm the details screen opens, add a birthday in the app and watch
the widget follow, then move the device date forward a day and confirm the counts step down and a
birthday flips to *Today*. Signing out should blank every widget.
