# Wasted — Product Requirements Guide

## Executive summary

**Wasted** is a screen time mirror for iOS that shows users how much time they've lost to their phone. Unlike blockers (which users bypass), Wasted shows an unstoppable running counter of daily app usage in the Dynamic Island, lock screen, home widget, and notifications.

**The thesis:** you can ignore a blocker. you can't unsee a number.

**Launch model:** free 7-day full trial, then $9.99 one-time lifetime purchase (no subscription).

**Target launch:** Q3 2026, with Family Controls distribution entitlement approval.

---

## Product vision

### The problem

Screen time apps try to solve addiction via **control**—blockers, time limits, streaks, shame cycles. They all fail the same way: the user bypasses the block once, feels guilt, then deletes the app. Control works for the user who's already committed. It doesn't reach the user who doesn't believe they have a problem yet.

### The solution

Wasted sells **the truth**. A relentless, auditable, inescapable running number that:
- Ticks live in the Dynamic Island while the user scrolls
- Reappears on the lock screen and home widget
- Sends nudges every 30 minutes
- Delivers a nightly receipt of the day's breakdown
- Shows a week-long trend of the user's worst hours

The app never blocks, never shames, never offers a "solution"—it just keeps count.

### The insight

The first "aha" moment is the **Reality Check**: after the first full day, users see *"you guessed 2h. reality: 4h 12m."* This is when they learn their own intuition lies to them, and only the number tells the truth. That moment is the conversion engine.

---

## Target user

**Demographics:**
- Age 18–50, smartphone-dependent, aware they "use their phone too much"
- Tech-literate but not necessarily interested in optimization or quantification
- Skeptical of blockers, annoyed by constant notifications
- Willing to pay once if the product is honest and works

**Mindset:**
- "I know I scroll too much, I just don't know how much"
- "I don't want my phone locked—I want to know what I'm doing"
- "I'd rather see the truth than be forced to change"

**Use case:**
User opens Instagram, loses track of time. The Dynamic Island ticks: 15m → 30m → 45m. A nudge fires: "that's enough for now — back to it?" User sees the number, either closes the app or ignores the nudge. That number is now seared into their consciousness. They open the app tomorrow knowing the price of their scroll.

---

## Core features

### 1. Tracked app monitoring
- User selects 1–N apps to track during onboarding via FamilyControls picker
- System monitors screen time per-app in 30-minute increments (then 10-min, then 15-min steps)
- Data is recorded to App Group shared storage, accessible to all parts of the app

**Constraints:**
- Requires Family Controls entitlement (approved by Apple; distribution requires separate request)
- Requires paid Apple Developer account (free accounts can develop, but can't distribute)
- No way to know which user is using the app (only aggregate per-app usage)
- Can't tell if user is actively scrolling or the phone is in a bag—only "time inside the app"

### 2. Dynamic Island (Live Activity)

The Island is the app's hero. It shows:
- **Compact/minimal:** app icon (or letter tile) + time in `Xh Ym` format, ticking live
- **Expanded:** app name, time, and the current nudge text (if applicable)
- **Lock screen:** time + nudge text

The timer ticks from a calculated anchor point (`accumulatedStart = Date() - totalSeconds`) so it resumes the day's total, not resets on every foreground.

**Constraints:**
- ActivityKit is limited to one activity per app (we use one all-day activity)
- Activity can't be updated from the extension background process—only from main app
- Activity goes stale after ~8 hours without update (iOS kills it). App foreground re-anchors it.
- Requires iOS 17+, iPhone 14 Pro+ (models with an Island)

### 3. 30-minute nudges

Every 30 minutes of tracked usage triggers a local notification. Example:

**Title:** "30m on Instagram"  
**Body:** "that's enough for now — back to it?" (or other variants)

**Gate logic:**
- Nudges fire at 30, 60, 90, 120... minute marks only
- At most one nudge per 30-minute step per app per day
- At least 10 minutes of wall-clock time between nudges (prevents spam)

**Copy variants (selected randomly):**
- "that's enough for now — back to it?"
- "just so you know."
- "the count doesn't pause. you can."
- "still worth it?"
- "you opened it for a reason. was this it?"
- "the number only goes up from here."

**Tone:** lowercase, no exclamation points, no guilt—just flat facts and redirects.

**Constraints:**
- Fires only if notification permission was granted during onboarding
- Does not repeat infinitely—capped at actual usage (only when thresholds fire)
- No smart quiet hours; respects system notification settings

### 4. Daily receipt

At 9 PM, a notification fires with a summary of the day:

**Notification body:** "you wasted 3h 12m today — 20% of your waking hours."

Users can tap to open a receipt sheet showing:
- List of tracked apps + time each (sorted by time, desc)
- Total time for the day
- Percentage of waking hours (baseline: 16 hours/day)

**In-app receipt:**
- Accessible via "today's receipt" row on the home screen
- Receipt-printer aesthetic: sans header, dashed rules, serif total
- Designed to be printed or screenshotted

**Auto-show:** receipt sheet automatically opens if app is opened after 21:00 on a day with usage (once per day).

**Constraints:**
- Time window is fixed at 21:00. No customization.
- Only fires if there was usage that day
- Uses local notification scheduling; no server-side push

### 5. Home screen dashboard

The home screen is the single entry point, showing:

**Header:**
- Rotating daily quote (serif, italic) — "your life is shorter today than yesterday"
- Reality Check (once, post-launch) — "you guessed 2h. reality: 4h 12m."

**Main content:**
- **Big number** (serif, bold) — "you wasted 4h 32m on your phone today"
- **Equivalent** (serif, italic, faint) — "that's watching a movie"
- **Today's receipt** — tap to open receipt sheet
- **Heatmap** (7-day grid) — hourly breakdown, red for peaks ≥1h
- **Weekly summary** — bar chart of daily totals, red for days ≥2h
- **Danger zones** — days with skewed usage (afternoon heavy, evening heavier)
- **Peak-hour insight** (post-day-3) — "you lose the most time between 9pm–11pm. 5 of the last 7 days."

**Trial chrome (days 1–7):** small line at bottom — "day N of 7 — then it's $9.99 once."

**Expired state (day 8+, unpurchased):** number is blurred, insights hidden, receipt/insights buttons present paywall instead.

### 6. Onboarding flow

The 6-step flow establishes the mirror thesis and collects permissions:

1. **Hook** — serif quote, "ready to look?" (acknowledges user knows they scroll too much)
2. **Differentiation** — "this won't block anything. blockers get deleted. streaks get abandoned. wasted just keeps count—a number you can't unsee."
3. **Permissions** — requests FamilyControls authorization ("your data. your device. nobody else sees it.")
4. **App Picker** — user selects 1–N apps to track
5. **Notification Permissions** — explains nudge cadence ("a nudge every 30 minutes. you keep scrolling. one receipt at night. nothing else.")
6. **Done** — "you're all set. open an app you picked—watch the island light up."

**Design:** each screen fades in/out. Done screen has a heavy haptic (the strongest in the app). Button text is lowercase, e.g., "i understand", "lock it in", "let's go".

**Constraints:**
- Runs once. After completion, stored in `@AppStorage` as `onboarding_complete = true`
- Simulator bypasses onboarding (shows HomeView directly) for development convenience

### 7. Reality Check

After the first full day of tracking, a card appears above the quote on HomeView:

**Content:**
- "you guessed 2h."
- "reality: 4h 12m."
- "off by 110%." (or "you actually knew." if actual ≤ guess)

**Behavior:**
- Appears once, never again (flag: `reality_check_shown`)
- Serif font for all lines (mirror's voice)
- Medium haptic on first appearance
- Dismiss button ("understood") with light haptic

**Purpose:** This is the moment of realization. The guess-vs-reality delta is the conversion engine. Every user who sees this card is more likely to pay.

### 8. Trial & paywall

**Trial:**
- 7 days from first launch
- All features fully unlocked (no limits, no reduced version)
- Clear disclosure on home screen: "day N of 7"

**On expiry (day 8):**
- Home screen number becomes blurred + redacted: "still counting. you just can't see it."
- Insights, heatmap, receipt are hidden
- Receipt + insights buttons present paywall instead
- Dynamic Island and nudges stop firing (but data keeps recording)
- Widget shows `??m` with "unlock to see"

**Paywall:**
- Canvas background, serif headline: "keep the mirror."
- Sans body: "no subscription. no streak to protect. pay once. it's yours — until you don't need it anymore."
- Primary button: "unlock forever — $9.99" (or regional equivalent)
- Footer: "restore purchases" button

**Restore purchases:** always accessible, even after purchase (Apple requirement; also good UX for multi-device users).

### 9. Widgets

Three widget families (iOS 17+ only):

**systemSmall (home screen):**
- Canvas background, serif bold total, red if ≥1h
- `"you wasted"` label
- `"today"` label
- Refreshes on every threshold + hourly backstop

**accessoryRectangular (lock screen):**
- Compact: `"wasted · 3h 12m"`
- Total is red-tinted if ≥1h

**accessoryCircular (lock screen):**
- Serif total only, centered
- Red if ≥1h

**Expired state:** all show `??m` with `"unlock to see"` label.

---

## Monetization model

### Overview

- **Download:** free
- **Trial:** 7 days, all features unlocked
- **Purchase:** $9.99 USD (Apple tier, regional pricing applied automatically)
- **Model:** one-time non-consumable IAP, restorable, owned forever

### Rationale

**Why $9.99?**
- $2.99: junk-tier utility app pricing. Signals low effort.
- $9.99: signals a considered product. Below impulse-purchase ceiling for audiences who've tried blockers ($99/year) and know the value of screen time awareness.
- $99: equivalent annual subscription (what Opal charges). We're cheaper *and* forever.

**Why one-time, not subscription?**
The anti-subscription positioning is *the* marketing: "an app whose goal is that you need it less shouldn't bill you forever." It's honest, distinctive, and attracts the user who's tired of subscriptions.

**Why free trial, not paid?**
- Free trials drive downloads (trial users decide to buy after seeing the number)
- Paid apps at launch get ~zero downloads (no social proof yet)
- Paid option available post-launch for later editions (e.g., "Wasted Pro")

**Why 7 days?**
- Long enough to see a full weekly cycle (Monday through Sunday)
- Long enough to see the full emotional sequence (guess → reality → habit → choice)
- Tight enough that users don't forget they're on trial

### Revenue expectations (not a projection; a sanity check)

At 3–5% trial-to-paid conversion and 1,000 downloads:
- Revenue: $250–$425 (net of 15% commission in Small Business Program)
- Cost per purchase: effective $8.49

This is a niche product solving a specific insight (the mirror, not the blocker). It will never have Opal's million-user scale unless it proves retention and then raises price. Version 1 is about proving the loop works.

### App Store compliance

- **3.1.1 (In-App Purchases):** compliant—digital feature (trial state) gated by purchase
- **3.2.2 (Bait-and-switch):** compliant—trial clearly labeled from day 1 on home screen; paywall is dismissible; Restore Purchases is always visible
- **5.1 (Data usage):** compliant—"Data Not Collected" (no analytics, no network calls, no tracking)
- **4.3 (Physical harm):** compliant—not a blocker (doesn't physically prevent access); user retains full control

---

## User journey (day-by-day)

### Day 0 (First launch)

1. User opens app
2. Onboarding: Hook → Differentiation → Permissions → App Picker → Notifications → Done
3. User selects Instagram, TikTok, Reddit
4. HomeView loads, shows quote, empty number ("0m"), no receipt/insights yet
5. Island shows "0m" (no usage yet on device)

### Day 1–6 (Trial week)

1. User opens Instagram, scrolls 45 minutes
2. Island updates: 15m → 30m → 45m (ticking live)
3. Nudge fires at 30m: "that's enough for now — back to it?"
4. User opens TikTok, scrolls 2 hours
5. Another nudge at 30m, 60m
6. Heatmap shows usage across 2 apps
7. At 21:00, receipt notification fires
8. User opens app, receipt sheet auto-opens, shows: "Instagram: 45m, TikTok: 2h 0m, Total: 2h 45m — 17% of waking hours"
9. HomeView shows big number, quote, heatmap starting to populate

### Day 1 end-of-day (evening of Day 1)

After first full 24-hour period (assuming user also tracked on Day 0):
- Reality Check card appears: "you guessed 3h. reality: 5h 12m. off by 73%."
- User sees the delta and realizes their intuition was wrong

### Day 7 end-of-day

Trial ends. If user hasn't purchased:
- HomeView number blurs
- Paywall appears behind the number
- Receipt/insights show paywall instead
- Widget shows `??m`
- Island disappears
- Nudges stop

User sees: *"still counting. you just can't see it."* and the price: *"$9.99 once."*

### After purchase (Day 8+)

- Everything unfrozen instantly (StoreKit updates entitlement cache)
- Island returns, ticks live
- Nudges resume
- Receipts return
- All history is preserved (data kept recording the whole time)

---

## Success metrics

### Activation
- **Onboarding completion:** >85% of installs complete all 6 screens (without hard drops)
- **App picker:** >80% select 2+ apps (signals genuine intent to track)

### Engagement (trial week)
- **Day 1 return:** >70% return on day 2 (strong: mirrors work early)
- **Day 3 return:** >50% return on day 3 (signals sustained interest)
- **Reality Check reaction:** TBD post-launch (this is the conversion moment)

### Monetization
- **Trial-to-paid conversion:** 3–5% target (conservative industry baseline; premium product should exceed 5%)
- **Revenue per download:** $0.25–$0.425 at 3–5% conversion

### Retention
- **30-day active:** >30% (indicator of habit formation)
- **User feedback:** NPS question to TestFlight users: *"after a week, did you open Wasted on your own?"* (Y = product-market fit signal; N = pivot needed)

### Quality
- **Crash rate:** <0.1% (iOS app quality baseline)
- **Test coverage:** 80% (XCTest in WastedTests target)
- **Review rating:** >4.2 stars (signals mirror thesis resonates)

---

## Constraints & assumptions

### Platform constraints

- **iOS 17+ only** — ActivityKit (Live Activity) and latest SwiftUI features
- **iPhone 14 Pro+ only** — Dynamic Island required for hero feature
- **iPad / Mac:** out of scope; no app distribution beyond iPhone
- **Family Controls:** dev entitlement works; distribution entitlement requires separate Apple request (lead time: days to weeks)
- **Paid account:** free tier can't distribute; purchase entitlements; wait for dev approval

### Technical constraints

- **No server:** all data lives on device. No sync, no backup, no account.
- **App Group only:** extension and main app communicate via shared UserDefaults only; no XPC, no background tasks between them
- **One activity per app:** LiveActivityKit limit; we use one all-day activity, updated on every foreground
- **No push notifications:** all local notifications only; no server-side remote push capability
- **Type-checker slow:** extension target has performance issues with chained functional expressions; prefer explicit loops

### Business constraints

- **No ads, no analytics, no tracking** — privacy is non-negotiable
- **No upsell path** (for launch): paywall is $9.99 lifetime only; no Pro tier, no "more insights", no add-ons
- **No dark patterns:** trial clearly labeled, paywall dismissible, Restore Purchases visible
- **No engagement-bait:** no streaks, no badges, no "open 7 days in a row" — no shame tactics

### Design constraints

- **Offline-first:** no internet required (implies no server sign-up, no account)
- **Dark only:** design commits to dark mode (canvas #0A0A0A, ink #F5F3EE)
- **Serif for mirror, sans for interface:** visual hierarchy is not negotiable
- **Red only for bad numbers:** no decorative color, no success states
- **One haptic per moment:** spring + haptics on entrance, light haptic on button press

---

## Competitive positioning

| Feature | Wasted | Opal | Screen Time | Moment |
|---|---|---|---|---|
| **Cost** | $9.99 once | $119.99/yr | Free (native OS) | $19.99 once |
| **Blocks apps** | ❌ | ✅ | Limited | ✅ |
| **Shows mirror (counter)** | ✅ Mirror focus | Counter secondary | ✅ (native) | ❌ |
| **Lock screen presence** | ✅ Widget + Activity | ✅ Widget | ✅ Widget | ❌ |
| **30-min nudges** | ✅ Random copy | ✅ Customizable | ❌ Hourly native | ❌ |
| **Daily receipt** | ✅ | ❌ | ❌ | ❌ |
| **Free trial** | ✅ 7 days | ❌ | N/A | ✅ 7 days |
| **One-time pricing** | ✅ | ❌ | N/A | ✅ |

**Wasted's edge:** it's the only app that *doesn't* try to lock the phone. It trusts the user to see the truth and decide. For the user tired of blocker shame cycles, Wasted is the antidote.

---

## Launch timeline & dependencies

### Critical path (before App Store submission)

1. **Family Controls distribution entitlement request** (Apple, lead time: 3–14 days)
   - Submit to developer.apple.com entitlement request form
   - Bundle IDs: `com.sanskar.Wasted` + `com.sanskar.Wasted.DeviceActivityMonitorExt`
   - This is the launch long pole—submit early

2. **App Store Connect setup** (1 day, human)
   - Create app record
   - Reserve bundle ID
   - Reserve app name (target: "Wasted — Screen Time Mirror", fallback: "Wasted: Screen Time Mirror")

3. **Code completion** (2–3 days)
   - Phase 0: Device bring-up smoke test
   - Phase 1: Correctness tuning (home refresh, receipt reliability, threshold diet)
   - Phase 2: Trial + purchase + gating + reality check + widgets

4. **Privacy & compliance** (1 day)
   - Privacy policy (static page, 1-pager, "nothing leaves your device")
   - Nutrition label (Data Not Collected)
   - No analytics SDKs, no tracking cookies (already compliant)

5. **Store assets** (1–2 days)
   - App icon (serif italic W)
   - 6 screenshots (hook line, home number, receipt, island, reality check, paywall)
   - Promo text, keywords
   - Subtitle: "you can't unsee the number"

### Critical path (after submission)

- Family Controls distribution approval (days–weeks, Apple)
- App Store review (1–3 days typical)
- Beta via TestFlight (1 week, internal + 5–10 friends)
- Launch (go/no-go decision before this point)

---

## Launch decision checklist

Before going live, verify:

- [ ] Entitlement request submitted and approved
- [ ] All four targets build (`xcodebuild -scheme Wasted build`)
- [ ] All 61+ tests pass (`xcodebuild test`)
- [ ] Device smoke test complete (onboarding, tracking, island, nudges, receipt, paywall)
- [ ] Reality check moment felt right in user testing (is it a conversion moment?)
- [ ] Paywall copy and price approved
- [ ] Privacy policy and nutrition label live and linked
- [ ] Store assets uploaded (icon, screenshots, description)
- [ ] Restore Purchases works in TestFlight
- [ ] TestFlight feedback positive ("did you open it on your own?" = mostly yes)
- [ ] No crashes on device (crash rate <0.1%)
- [ ] No bugs in trial-to-expired transition
- [ ] No analytics or tracking SDK called anywhere in codebase

---

## Post-launch roadmap (not v1)

Approved only if v1 retention >30% and user feedback is 4.2+ stars:

1. **iPad version** — split-view receipt, landscape heatmap
2. **Paid tier:** "Wasted Pro" ($4.99/mo or $29.99/yr)
   - Custom app groups (e.g., "social media" vs "work")
   - Trend reports (weekly PDF export)
   - Scheduled reports (emails)
   - Custom nudge schedule (vs fixed 30-min)
3. **Streaks (but honest)** — "days in a row you've checked in" (no shame, no pressure—just visible)
4. **Collaborative families** — see family members' numbers (opt-in, privacy-respecting)
5. **Price increase** — to $14.99 or $19.99 after 1k+ reviews (signal of value proof)
6. **watchOS** — minimal, read-only (Island equivalent)

**Not doing:**
- Subscription model (ever)
- Blocking or app locks
- Gamification / badges / rewards
- Notifications outside the 30-min cadence
- AI summaries or advice
- Server-side data, account login, or cloud sync

---

## Key messages for launch

### App Store description

**Subtitle:** "you can't unsee the number"

**Promo text:** "no subscription. no streaks. no blocks. just the count."

**Body:**
You know you scroll too much. Wasted shows you exactly how much. A running counter on your lock screen, in your notifications, in your pocket. The number grows. You see it every day. You can't unsee it.

Wasted doesn't block apps. Blockers get deleted. Wasted doesn't shame you with streaks. Wasted just keeps count.

**Features:**
- Live counter in the Dynamic Island (ticking in real time)
- Lock screen widget and home screen widget
- Nudges every 30 minutes
- Daily receipt at 9 PM
- 7-day trend analysis
- And the one thing blockers never give you: the truth

**What Wasted never does:**
- Blocks or locks your phone
- Tracks you across other apps or websites
- Sends marketing notifications
- Charges a subscription
- Collects analytics
- Leaves your device

*7-day free trial. Then $9.99 once.*

### One-liner pitch

"you can ignore a blocker. you can't unsee a number."

---

## Questions for future you

- **Did the Reality Check moment convert users?** Post-launch, check trial-to-paid conversion at day 1 (right after reality check). If <3%, the moment didn't land.
- **Do users keep the app after trial?** 30-day active metric is the retention signal. If <30%, the mirror thesis isn't sticking.
- **What's the NPS?** TestFlight question ("did you open it on your own?") will tell you if product-market fit exists.
- **Icon rendering on device:** did letter-tile fallback end up in shipping, or did `ImageRenderer(Label(token))` work? Document the decision.
- **Trial price sensitivity:** did changing trial to 5 days or 14 days affect conversion? Test post-launch.
- **Nudge fatigue:** are users dismissing nudges consistently by day 7? If so, consider AI backoff or user customization.

---

## Version: 1.0 (Wasted on App Store)

**Status:** Approved for implementation  
**Last updated:** 2026-07-10  
**Owner:** Sanskar Singh  
**Stakeholders:** iOS development team, product, design  

This PRD is the source of truth for feature scope, pricing, trial logic, and launch readiness. Changes require alignment with all stakeholders.
