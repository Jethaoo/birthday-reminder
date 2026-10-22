# Birthday Reminder — V1 product and design reference

This is the product and workflow reference for the shipping Flutter Android app. The runnable visual
reference is `design/src/DesignSurface.tsx`; API and deployment details live in the repository
`docs/` directory. V1 does not include AI-generated wishes or Google sign-in.

## 1. Product Overview

Design a modern Android birthday reminder application built with Flutter.

The app helps users store birthdays, receive advance birthday reminders, and keep gift ideas, notes
and contact details in one place.

The application should feel:

* Clean
* Modern
* Friendly
* Personal
* Lightweight
* Easy to use
* Suitable for everyday use
* Professional enough for a production Android application

The design should prioritize quick access to upcoming birthdays and make adding a birthday extremely simple.

---

# 2. Target Platform

Platform:

* Android
* Flutter implementation
* Mobile-first design
* Primary design frame: Android phone
* Support common Android screen sizes

Recommended Figma base frame:

**390 × 844 px**

Use responsive layouts so the Flutter implementation can adapt to smaller and larger Android devices.

---

# 3. Main Navigation

Use a bottom navigation bar with four main sections:

1. Home
2. Birthdays
3. Calendar
4. Settings

Primary action:

A floating "+" button or prominent "Add Birthday" button should be available from the Home and Birthdays screens.

Navigation structure:

```text
Home
├── Today's Birthdays
├── Upcoming Birthdays
├── Add Birthday
└── Birthday Details

Birthdays
├── Search
├── Filter
├── Birthday List
├── Add Birthday
└── Birthday Details

Calendar
├── Monthly Calendar
└── Birthday Details

Settings
├── Notifications
├── Account
├── Appearance
└── About
```

---

# 4. Home Screen

The Home screen is the primary screen.

## Header

Display:

* Greeting or simple "Birthdays"
* Current date
* Optional profile/avatar button

Example:

```text
Good morning 👋

23 September 2026
```

Avoid making the greeting overly large.

---

## Today's Birthdays

If there are birthdays today:

```text
Today's Birthdays

┌─────────────────────────┐
│ Avatar                  │
│ Sarah Tan               │
│ Today • 26 years old    │
│                         │
│ [ Send Wish ]           │
└─────────────────────────┘
```

If multiple birthdays exist, display them as a vertical list or horizontal cards.

If there are no birthdays today:

```text
Today's Birthdays

No birthdays today

Enjoy the day! 🎉
```

---

# 5. Upcoming Birthdays

Display the nearest upcoming birthdays.

Example:

```text
Upcoming Birthdays

Sarah Tan
30 Sep
7 days

Alex Lim
5 Oct
12 days

Jason Lee
12 Oct
19 days
```

Each birthday item should show:

* Profile image/avatar
* Name
* Birthday date
* Countdown
* Optional age

Example:

```text
┌─────────────────────────────┐
│ 👤  Sarah Tan               │
│     30 September            │
│                    7 days   │
└─────────────────────────────┘
```

---

# 6. Monthly Summary

Provide a lightweight summary of the current month's today and upcoming birthdays.

Example:

```text
September

5 birthdays
2 upcoming
1 today
```

Optional:

```text
View Calendar →
```

---

# 7. Add Birthday Screen

This is one of the most important screens.

The form should be simple and not overwhelming.

Fields:

### Required

* Name
* Birthday

### Optional

* Birth year
* Relationship
* Phone number
* Email
* Notes
* Gift ideas
* Photo

Example:

```text
Add Birthday

[ Add Photo ]

Name
[ Sarah Tan                    ]

Birthday
[ 30 September                 ]

Birth Year
[ 2000                         ]

Relationship
[ Friend                  ▼    ]

Phone
[                              ]

Email
[                              ]

Notes
[                              ]

Gift Ideas
[                              ]

Reminder

☑ Enable reminders

Remind me
[ 7 days before            ▼  ]

Time
[ 09:00 AM                    ]

              [ Save Birthday ]
```

The user should be able to save with only:

```text
Name
Birthday
```

Everything else should be optional.

---

# 8. Birthday Details Screen

Show the person's birthday information prominently.

Example:

```text
          [ Photo ]

        Sarah Tan

        30 September

        🎂 7 days left

        Friend
```

Then sections:

## Birthday

```text
30 September
7 days from now
```

If birth year exists:

```text
Turning 26
```

---

## Gift Ideas

```text
Gift Ideas

• Perfume
• Chocolate
• Book

+ Add Gift Idea
```

---

## Notes

```text
Notes

Likes lavender scent.
Enjoys travelling.
```

---

## Reminder

```text
Reminder

7 days before
9:00 AM

[ Edit Reminder ]
```

---

## Actions

Provide:

```text
[ Edit ]

[ Delete ]
```

Delete should require confirmation.

---

# 9. Reminder Editor

Each birthday can have several reminders, each with its own day offset and time. Available offsets
are on the day, 1, 3, 7, 14 and 30 days before. An individual reminder can be disabled without being
deleted, and a birthday can hold at most 10 reminders.

```text
Reminders

Sarah Tan · 30 September

7 days before       09:00       ON
1 day before        09:00       ON
On birthday         09:00       ON

[ Add another reminder ]
```

---

# 10. Birthdays Screen

Display all saved birthdays.

Header:

```text
Birthdays

🔍 Search
```

Filters:

```text
All
Today
This Week
This Month
Family
Friend
Colleague
Other
```

Display the birthdays as a paginated list. The default sort is upcoming, with name and
recently-added alternatives available from the sort control.

Example:

```text
30 Sep   Sarah Tan    Friend     Today
5 Oct    Alex Lim     Family     12 days
12 Oct   Jason Lee    Colleague  19 days
```

---

# 11. Search

Search should support:

* Name
* Relationship
* Notes

Example:

```text
🔍 Search birthdays...

Sarah
```

Results:

```text
Sarah Tan
30 September
Friend
```

Include a clear empty state:

```text
No birthdays found.

Try another name.
```

---

# 12. Calendar Screen

Display a monthly calendar.

Example:

```text
September 2026

       ‹       ›

Mo Tu We Th Fr Sa Su
   1  2  3  4  5  6
7  8  9 10 11 12 13
14 15 16 17 18 19
21 22 23 24 25 26 27
28 29 30

            🎂
```

Dates containing birthdays should have a clear visual indicator.

Selecting a date should show birthdays below the calendar.

Example:

```text
30 September

🎂 Sarah Tan
🎂 Michael Lee
```

---

# 13. Settings Screen

Sections:

## Account

```text
Account
Email
[ user@example.com ]

[ Manage Account ]
```

## Notifications

```text
Notifications

Birthday reminders       ON
Today's birthdays        ON
Tomorrow reminders       ON
Reminder sound           ON
```

## Default Reminder

```text
Default reminder

7 days before
9:00 AM
```

## Appearance

```text
Appearance

Theme
○ System
○ Light
○ Dark
```

## About

```text
About

Version 1.2.0

Privacy Policy
Terms of Service
```

---

# 14. Notification UI

The application uses server push notifications through Firebase Cloud Messaging.

Notification examples:

### Advance reminder

```text
🎂 Birthday Reminder

Sarah Tan's birthday is in 7 days.
30 September
```

### Tomorrow

```text
🎂 Birthday Tomorrow

Sarah Tan's birthday is tomorrow.
```

### Today

```text
🎉 Wish Sarah Tan a happy birthday!

It's Sarah Tan's birthday today!
```

Tapping a notification should open the person's Birthday Details screen.

---

# 15. Authentication Screens

Because birthday data is stored in the cloud, include authentication.

## Welcome

```text
🎂

Remember Every Birthday

Never forget an important birthday again.

[ Get Started ]

[ Sign In ]
```

## Sign Up

```text
Create Account

Name
[                         ]

Email
[                         ]

Password
[                         ]

Confirm Password
[                         ]

[ Create Account ]

Already have an account?
Sign In
```

## Sign In

```text
Welcome Back

Email
[                         ]

Password
[                         ]

[ Sign In ]

Forgot password?
```

---

# 16. Contact Import

The app imports birthdays from Android contacts. The user grants access, selects individual
contacts, and only those selections are saved to their account. A birthday already saved is skipped
and included in the result summary.

Entry point:

```text
Add Birthday
     ↓
[ Import from Contacts ]
```

Contact selection:

```text
Import Birthdays

☑ Sarah Tan
☐ Alex Lim
☑ Michael Lee
☐ Jason Wong

2 contacts selected

[ Import Selected ]
```

After import:

```text
2 imported · 1 already saved
```

---

# 17. Empty States

Design proper empty states instead of leaving blank screens.

### No birthdays

```text
🎂

No birthdays yet

Add your first birthday and
never forget an important date.

[ Add Birthday ]
```

### No upcoming birthdays

```text
You're all caught up! 🎉

No upcoming birthdays.
```

### No search results

```text
No birthdays found.

Try searching for another name.
```

---

# 18. Loading States

Include loading states for:

* Login
* Birthday list
* Birthday details
* Saving birthday
* Contact import

Use skeleton loaders where appropriate instead of excessive spinners.

---

# 19. Error States

Design friendly error messages.

Example:

```text
Something went wrong.

We couldn't load the birthdays.

[ Try Again ]
```

Network error:

```text
No Internet Connection

Check your connection and try again.
```

---

# 20. Confirmation Dialogs

Delete:

```text
Delete Birthday?

Are you sure you want to delete
Sarah Tan's birthday?

This action cannot be undone.

[ Cancel ]    [ Delete ]
```

Logout:

```text
Log Out?

[ Cancel ]    [ Log Out ]
```

---

# 21. Design System

Create reusable components in Figma.

Components should include:

* Primary button
* Secondary button
* Text button
* Floating action button
* Text field
* Date picker field
* Dropdown
* Search field
* Birthday card
* Birthday list item
* Avatar
* Calendar
* Filter chip
* Bottom navigation
* Top app bar
* Dialog
* Bottom sheet
* Toast/snackbar
* Notification preview
* Empty state
* Loading state
* Error state

Use Auto Layout and reusable components/variants.

---

# 22. Visual Style

Recommended design direction:

**Modern + Friendly + Minimal**

Avoid making it look like a children's birthday-party application.

Use subtle birthday-related visual elements such as:

* Small cake icons
* Confetti used sparingly
* Rounded cards
* Soft illustrations
* Friendly typography

Do not overuse emojis.

The application should remain professional.

---

# 23. Color System

Create design tokens rather than hard-coding colors.

Required tokens:

```text
Primary
Primary Container
Secondary
Background
Surface
Surface Variant
Text Primary
Text Secondary
Border
Error
Success
Warning
```

Provide both:

* Light theme
* Dark theme

The exact color palette can be established by the designer, but it should have sufficient contrast for accessibility.

---

# 24. Typography

Use a modern Android-friendly font.

Recommended:

**Inter** or **Roboto**

Typography hierarchy:

```text
Display
Headline
Title
Body
Label
Caption
```

Use clear hierarchy rather than excessive font sizes.

---

# 25. Accessibility

The design must account for:

* Minimum touch target around 48 × 48 dp
* Sufficient color contrast
* Text scaling
* Screen readers
* Icons paired with labels where meaning isn't obvious
* Do not rely on color alone to communicate birthday status
* Clear focus states

---

# 26. Important User Flows

Design the following complete flows.

## Flow 1. First-time user

```text
Welcome
 ↓
Sign Up
 ↓
Home
 ↓
Add Birthday
 ↓
Save
 ↓
Birthday appears on Home
```

## Flow 2. Add birthday

```text
Home
 ↓
+
 ↓
Add Birthday
 ↓
Enter details
 ↓
Save
 ↓
Birthday Details
```

## Flow 3. Reminders

```text
Birthday Details
 ↓
Add Reminder
 ↓
Pick day and time
 ↓
Save
 ↓
Updated reminder list
```

## Flow 4. Notification

```text
Server
 ↓
FCM
 ↓
Android Notification
 ↓
Tap Notification
 ↓
Birthday Details
```

## Flow 5. Calendar

```text
Calendar
 ↓
Select date
 ↓
Birthday list
 ↓
Birthday Details
```

## Flow 6. Contact import

```text
Add Birthday
 ↓
Import from Contacts
 ↓
Select Contacts
 ↓
Import
 ↓
Back to Add Birthday
```

---

# 27. Figma Deliverables

The Figma file should contain:

### Page 1. Design System

* Colors
* Typography
* Spacing
* Icons
* Components
* Buttons
* Inputs
* Cards
* Navigation

### Page 2. Authentication

* Welcome
* Login
* Register
* Forgot Password

### Page 3. Main App

* Home
* Birthdays
* Calendar
* Settings

### Page 4. Birthday Management

* Add Birthday
* Edit Birthday
* Birthday Details
* Delete confirmation

### Page 5. Reminders & notifications

* Multiple reminders on a birthday
* Default reminder settings
* Notification previews
* Test delivery state

### Page 6. Contact Import

* Contact permission
* Contact selection
* Import result

### Page 7. States

* Empty
* Loading
* Error
* Offline
* Success
* Confirmation dialogs

### Page 8. Prototype

Connect the primary flows into a clickable prototype.

---

# 28. Flutter Implementation Considerations

The design should be implementable using standard Flutter widgets.

Avoid designs that require excessive custom painting or complex animations.

Use:

* Material 3 principles
* Responsive layouts
* SafeArea
* BottomNavigationBar / NavigationBar
* Sliver-based scrolling where appropriate
* Modal bottom sheets
* Standard dialogs
* Reusable widgets

All dimensions should be documented in a way that can be translated into Flutter's logical pixels/dp.

---

# 29. Important Backend/UI Boundary

The UI should not expose backend implementation details.

The user should simply experience:

```text
Birthday saved
Reminder enabled
Notification received
```

The implementation behind it will be:

```text
Flutter
 ↓
Cloudflare Worker
 ↓
D1
 ↓
Cron Trigger
 ↓
FCM
 ↓
Android
```

The UI should never require the user to understand Cloudflare, FCM, databases, or server scheduling.

---

# 30. Overall Design Goal

The finished application should communicate one simple idea:

**"Never forget someone's birthday."**

The primary user experience should therefore revolve around:

**Today's birthdays → Upcoming birthdays → Countdown → Reminder → Birthday details**

The UI should make these actions obvious within a few seconds of opening the application.
