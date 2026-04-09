# User Stories

Living checklist of what Sown must allow the user to do. Updated as features are built and refined.

Status: [x] done | [~] partial | [ ] planned

---

## Today View

- [x] As a user, I can see all my habits and tasks for today on a single screen
- [x] As a user, I can swipe right on a habit to mark it complete (with strikethrough animation and haptic feedback)
- [x] As a user, I can tap a completed habit to undo it
- [x] As a user, I can see my must-dos separated from nice-to-dos so I know what actually matters today
- [x] As a user, I can see one-off tasks alongside my recurring habits
- [x] As a user, I can see habit groups and complete individual options within them
- [x] As a user, I can reorder my habits by dragging
- [x] As a user, the today view is laid out in order: today tasks, must-dos, nice-to-dos, don't-dos

### Morning Brain Dump

- [x] As a user, when I open the app in the morning I am prompted to add today tasks via the morning view
  - Acceptance: User can skip this prompt if they don't have tasks to add
- [x] As a user, I can quickly brain-dump all the one-off tasks in my head (book GP, buy groceries, call mum)
  - Acceptance: Tasks are stored, appear in today view, and can be ticked off throughout the day. Getting them out of my head relieves the mental pressure that causes procrastination. Once completed, tasks move to the Done section. At end of day, completed today tasks are permanently deleted and do NOT reappear the next morning
  - ~~BUG: Completed today tasks reappear in the today list the next morning instead of being permanently deleted overnight.~~ **FIXED** — Cleanup now runs on every app launch (not just day transitions) and checks completion on any day, not just the creation day.
- [x] As a user, when I feel like procrastinating I can look at my today tasks and pick off a quick one instead of opening a distracting app

## Habits & Tasks

- [x] As a user, I can create a recurring habit with a name, tier (must-do / nice-to-do), and type (positive / negative)
- [x] As a user, I can set a habit's frequency (daily, X times per week, X times per month)
- [x] As a user, I can create a one-off task with a due date
- [x] As a user, I can add a "habit prompt" — a motivational micro-step to get me started
- [x] As a user, I can add success criteria to define what counts as completing a habit
- [x] As a user, I can archive habits I no longer need without losing their history
- [x] As a user, I can unarchive habits to bring them back
- [x] As a user, I can edit or delete habits
- [~] As a user, I can choose from habit templates (pre-built sets) when creating habits
- [~] As a user, I can track negative habits as counters ("days since last...")

### Don't-Do Types

- [x] As a user, I can create a "don't do" with a time limit for an app (e.g., "1 hour on Instagram")
  - Acceptance: Automatically marks as "slipped" once Screen Time detects I've used the app for the set duration. Doesn't fully block the app — just tracks and penalises overuse
- [x] As a user, I can set apps to be fully blocked on a schedule via the Block tab (independent of don't-do habits)
- [x] As a user, I can create a "no unblocking" don't-do that auto-slips if I go through the unlock flow for a blocked app
  - Acceptance: Unblocking any schedule-blocked app triggers the slip. Costs me my good day for that day
- [x] As a user, I can create a "no scrolling" don't-do that auto-slips based on usage detection

## Habit Groups

- [x] As a user, I can create a group (e.g., "Be Creative") with multiple habit options (draw, paint, write)
- [x] As a user, I can set how many options I need to complete (e.g., 1 of 4)
- [x] As a user, I can complete any option within a group to satisfy the group requirement

## Good Day & Streaks

- [x] As a user, I get a "good day" when all my must-do habits are completed
- [x] As a user, I can see my current streak and best streak per habit
- [x] As a user, I can see good days on the month grid at a glance
  - Acceptance: Good day status is locked at midnight — adding new habits the next day doesn't retroactively change it

## Month Grid

- [x] As a user, I can see a calendar view showing which days were good days
- [x] As a user, I can tap a day to see what I completed that day

## Journal

- [x] As a user, I can write a reflection with a fulfillment score (1-10)
  - Acceptance: Editable for 48 hours after creation, then auto-locked
- [x] As a user, I can add photos and notes when completing hobby-type habits

### Morning Reflection Prompt — Planned

- [ ] As a user, I am prompted in the morning to reflect on yesterday (similar to the morning tasks overlay)
  - Acceptance: Appears after/alongside the morning tasks prompt. Easy to skip. Does not reappear once dismissed. On by default, can be turned off in settings. Never feels like pressure or obligation
- [ ] As a user, I can quickly add a moment from yesterday — a photo, a song I liked, one thought, and how I felt
  - Acceptance: Low friction — any combination is fine (just a photo, just a thought, etc.). No required fields beyond the feeling score
- [ ] As a user, I can see smart suggestions based on what happened yesterday (photos taken, music played)
  - Acceptance: Uses Apple's journaling suggestion capabilities to surface moments automatically
- [ ] As a user, I can look back at my feeling scores over time and see that my mood varies naturally
  - Acceptance: Visible in stats or journal view. Helps counter the perception of "I've been feeling down forever" by showing actual day-to-day variation

## Stats

- [x] As a user, I can see my completion rates, streaks, and good day percentage
- [x] As a user, I can see fulfillment score trends over time

## App Blocking

- [x] As a user, I can select which apps and websites to block
  - Acceptance: App selection requires tapping Save before changes take effect. Draft selection shown in UI but shields not updated until saved.
- [x] As a user, I can set a blocking schedule (which days and times)
  - Acceptance: Apps are ONLY blocked during scheduled hours when blocking is enabled. Outside the schedule, apps must be fully accessible with no shields. Schedule edits require tapping Save before they take effect. If schedule is 9AM-9PM, apps must be free at 9:01PM and must not randomly re-block before the next 9AM.
  - ~~BUG: Blocking re-activates outside scheduled hours. Also blocks when the master toggle is disabled.~~ **FIXED** — Schedule shields use a dedicated ManagedSettingsStore. Extension checks isEnabled from App Group defaults. Foreground reconciliation removes stale shields on every app resume.
- [x] As a user, I cannot easily bypass blocking — it requires conscious effort
  - Acceptance: Shield appears → tap unlock → notification opens Sown → 10-second wait showing today's tasks → write admission statement → then unlocked. Unlock flow only appears during active schedule blocking.
- [x] As a user, the blocking runs on a schedule independent of my habit completion
- [x] As a user, when I unlock apps they are only unlocked for 5 minutes, then blocking resumes
  - Acceptance: After 5 minutes the app must be forcibly closed / shield must re-engage immediately — NOT just block on next launch. The user should be kicked off the app, not allowed to keep using it indefinitely. If the schedule ends during the unlock period, shields do not re-apply.
  - ~~BUG: After 5-minute unlock expires, user can keep using the app until they leave it. Should kick them off immediately.~~ **PARTIALLY FIXED** — Unlock now tracks expiry timestamps to prevent stale timers from previous unlocks re-blocking prematurely. Shields re-apply after timeout. Full force-close on expiry still pending (iOS limitation with opaque tokens).
- [x] As a user, when a Don't-Do habit limit is exceeded, the app is blocked until midnight
  - Acceptance: Failure-blocked apps use a separate ManagedSettingsStore that persists until midnight regardless of schedule. Shield shows a custom message: habit name, limit exceeded, blocked until midnight. Block tab shows a failure-block banner with the same info. Cleared at midnight by clearFailureBlocks(). Disabling the blocking toggle also clears failure blocks.

### Blocking UI
- [x] As a user, I must tap Save to apply schedule and app selection changes
  - Acceptance: Edits to days/times and app selections are buffered in local draft state. Save commits changes and updates monitoring. Discard reverts to current settings. Unsaved changes indicator shown on the card. Border highlights amber when unsaved.
- [x] As a user, I cannot change the blocking schedule for the current day while blocking is active
  - Acceptance: Current day's circle turns red with a padlock. Time pickers are disabled. Other days remain editable. Unlocks when the schedule window ends.
- [x] As a user, the blocking status updates live while I'm on the Block tab
  - Acceptance: Time remaining counts down every minute. Status flips from "Blocking Active" (red/locked) to "Blocking Enabled" (green/toggle) when the schedule window ends, without needing to leave and return.
- [x] As a user, the blocking status refreshes when I return to the app
  - Acceptance: If I leave Sown during blocking and return after the schedule ended, the UI correctly shows the schedule has ended. Foreground reconciliation ensures shields match current schedule state.
- [x] As a user, I see a banner on the Block tab when apps are failure-blocked
  - Acceptance: Red-tinted card shows habit name, limit exceeded, and "blocked until midnight". Disappears when failure blocks clear at midnight.

### Blocking — Planned

- [ ] As a user, I can optionally have blocked apps unlock automatically after completing all must-dos
- [ ] As a user, I must speak my admission statement out loud (speech-to-text) instead of typing it
- [ ] As a user, I must put my phone down for a set time (accelerometer/gyroscope) before unblocking
- [ ] As a user, Face ID confirms I'm not looking at my phone during the put-down period

## Notifications & Scheduling

- [x] As a user, I can assign habits to time slots (After Wake, Morning, During Day, Evening, Before Bed)
- [x] As a user, I receive reminders at the right times based on my wake/bed schedule
- [x] As a user, I can set my wake and bed times to customize when reminders arrive
- [x] As a user, I do NOT receive notifications for don't-do habits
  - Acceptance: Don't-dos should never send reminders. Reminding the user about Instagram makes them think about Instagram. The whole point is to forget about it and focus on other things
  - ~~BUG: Don't-do habits are sending notifications. They should be excluded from all reminder scheduling.~~ **FIXED** — Added `type != .negative` filter to notification scheduling.

## HealthKit Integration

- [x] As a user, I can link a habit to a HealthKit metric (steps, exercise minutes, etc.)
- [x] As a user, I can set a target value and have the habit auto-complete when met

## Cloud Sync

- [x] As a user, I can opt in to iCloud sync so my data is on all my devices
- [x] As a user, my settings and habits sync across iPhone and iPad

## Onboarding

- [x] As a user, I am guided through setting up my first habits when I open the app for the first time

## Widget

- [x] As a user, I can see today's habit progress on my home screen via a widget

## Screen Time Weekly Review — Planned

- [ ] As a user, I can see a weekly screen time review in the Stats tab
  - Acceptance: Bar charts showing daily usage (similar to iOS Screen Time), broken down by most-used apps per day
- [ ] As a user, I see actionable cards for apps that took too much time (over 1 hour, especially social media)
  - Acceptance: Each card shows the app with usage stats. Tapping the card auto-generates a "don't do" negative habit for that app with relevant emojis and a 1-hour daily limit that blocks the app after 1 hour of use for the rest of the day
- [ ] As a user, I receive a push notification when my weekly review is ready
  - Acceptance: Tapping the notification opens the app directly to the review in Stats. Notification is sent once only
- [ ] As a user, if I miss the notification I see an in-app prompt the next time I open Sown
  - Acceptance: Overlay/banner suggesting "Check your weekly review in Stats". A red dot badge appears on the Stats tab icon. Both the overlay and the red dot disappear once the user navigates to Stats. If the user already arrived via the push notification, the in-app prompt is not shown. Does not reappear until the next weekly review is ready

## AI Habit Agent — Planned

- [ ] As a user, I can create habits through a conversational interface instead of forms
- [ ] As a user, the agent remembers my existing groups and suggests where new habits fit
- [ ] As a user, I can get auto-generated motivational habit prompts so I don't have to write them myself
