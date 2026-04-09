# Vision

## What is Sown?

Sown is a habit tracker, todo list, and app blocker — combined into one app. It works on two forces:

1. **Increase friction for distractions** — Block the apps that pull you into procrastination
2. **Motivate you to do what you actually want to do** — Organize your tasks and habits so you know exactly what to focus on

Neither force works alone. Blocking apps without a clear plan leaves you aimless. A todo list without blocking means you'll open Instagram instead. Sown combines both so the wrong choice is harder and the right choice is obvious.

## Who is it for?

People who often make the wrong decision — who know what they should be doing but get overwhelmed and procrastinate instead. People who've tried habit trackers (that eventually get deleted) and app blockers (that aren't strict enough or cost money).

Built primarily to solve this problem for the creator, but designed to be useful to anyone with the same struggle.

## Core Feeling

**In control.** Sown should make the user feel like they control their phone — not the other way around. The phone goes back to being a tool that organizes your life and helps you get things done, instead of a source of endless distraction.

## What makes it different?

- **Habit trackers alone get deleted** — there's no consequence for ignoring them. Sown pairs tracking with blocking so the app stays relevant.
- **App blockers alone are incomplete** — they remove distractions but don't tell you what to do instead. Sown gives you a clear, organized view of what matters today.
- **Blocking must be strict** — if it's easy to bypass, it doesn't work. Sown's blocking is designed to be hard to circumvent.
- **Free** — many blocking apps charge subscriptions. Sown doesn't.

## Why Procrastination Happens

The user's brain is overloaded with tasks — one-off things like booking a GP, buying something from the shops, calling your mother. The mental weight of all these undone things causes overwhelm, and overwhelm causes procrastination. 

Sown addresses this directly: every morning, the user can brain-dump all their one-off tasks. Getting them out of your head and into a list relieves the pressure. Then throughout the day, when you feel like procrastinating, you can pick off a quick task instead of opening Instagram. The tasks are stored, organized, and satisfying to tick off.

## Blocking Philosophy

Blocking is **not** about being an unbreakable wall. It's about forcing a conscious decision. When you tap a blocked app on autopilot, Sown snaps you out of it:

1. Shield appears — reminds you that you should be doing something else
2. User taps "unlock" button on shield → notification sent prompting them to open Sown
3. Sown shows a 10-second wait screen displaying all the things they need to get done today
4. User must write a statement admitting they're experiencing a moment of weakness and accepting it
5. Only then is the app unlocked

The friction is the point. Most people will turn back at step 1 or 3. Those who go through the full flow have made a *conscious choice* rather than a mindless one.

Blocking runs independently on a schedule — it is not tied to habit completion. The schedule is the user's commitment to themselves about when they should be focused. Blocking is strictly schedule-bound: outside the schedule window, all schedule-blocked apps are fully accessible. Exception: apps that exceed a Don't-Do limit are blocked until midnight as a consequence, with a custom shield message explaining why the app was blocked and which habit slipped.

### Future blocking enhancements
- Unlock apps automatically after completing all must-dos (reward-based unblocking)
- Speech-to-text for the admission statement — say it out loud, don't just type it
- Accelerometer/gyroscope enforcement — require the user to put their phone down for a set time
- Face ID check to ensure the user isn't looking at their phone during the put-down period

## Habit Tiers & Groups

**Must-do habits** are the ones you're genuinely trying to instill. They define your "good day." If you complete all must-dos, it's a good day.

**Nice-to-do habits** are things you want to track without the pressure of feeling like you have to do them daily (e.g., "go for a cycle"). No guilt if you skip them.

**Habit groups** let users say "I want to be creative every day" and list multiple ways to do that (draw, paint, play music, write). They're held accountable to the *category* but with less pressure — they only need to do one (or X of Y). Groups reduce the overwhelm of long habit lists.

## Don't-Do Philosophy

Don't-dos are not about total abstinence — sometimes you need social media. They're about **limits**. There are three types of automatic triggers:

1. **Time-limited usage** — "1 hour on Instagram." The app isn't blocked, but once Screen Time hits the limit, the don't-do auto-slips. You can still use it, but you've broken your commitment and lose your good day.
2. **Schedule-blocked apps** — Set in the Block tab, these are fully blocked during certain hours regardless. This is separate from don't-dos.
3. **No-unblocking rule** — A don't-do that auto-slips if you go through the unlock flow for a schedule-blocked app. This makes the unlock flow carry real consequences — it costs you your good day.

The key insight: blocking and don't-dos work as **layers**. Blocking adds friction. Don't-dos add consequences. Together they make the wrong choice both harder and costlier.

## What "Working" Feels Like

Right now, the main reward is the feeling of ticking things off — the tactile satisfaction of the swipe. The month grid and streaks *should* be motivating, but they only work when you're already succeeding. If you haven't had many good days or streaks yet, looking at stats feels discouraging rather than motivating.

The stats need to show something useful even when you're struggling — not just "here's how much you failed." They should help you understand *why* you're struggling and give you a next step, not just a scoreboard.

This is an open design problem. The weekly screen time review (see User Stories) is one answer — it's actionable, not just a metric.

## Journal / Reflection Philosophy

The journal exists to fight two problems:

1. **Days blur together.** If every day is the same routine, life feels like it's passing you by. Sown encourages doing something memorable each day — even something small like trying a different drink at the cafe. The journal captures these moments so days feel distinct.

2. **Negativity bias in memory.** When you feel down, your brain tells you you've *always* felt down. But if you've been logging how you felt day-to-day, you can look back and see that Tuesday and Thursday were actually good. The data corrects the distortion.

The journal should feel like a gentle invitation, never an obligation:
- Prompt appears in the morning to reflect on *yesterday* (not the same evening when you're tired)
- Works like the morning tasks overlay — easy to engage with, easy to skip
- Low friction: add a photo you liked, a song you listened to, one thought, and a score of how you felt
- On by default, can be turned off in settings
- Smart suggestions using Apple's journaling capabilities (music played, photos taken that day)
- Once dismissed, doesn't nag again until the next day

## Design Aesthetic

Journal/paper aesthetic with handwritten PatrickHand font, lined backgrounds, hand-drawn checkmarks, and pen-style strikethroughs. The app should feel personal and tactile — like writing in a notebook, not using enterprise software.
