# Wasted — App Store listing

Drafted 2026-07-19. Character counts verified against ASC limits.
ASC app record is currently named "Wastedd" — fix the display name at
submission; options below assume the name can carry a qualifier.

---

## Name (30 chars max)

Primary:    `Wasted — Screen Time Mirror`        (27)
Fallbacks:  `Wasted: Screen Time Receipt`        (27)
            `Wasted: The Screen Time Bill`       (28)

"Wasted" alone is almost certainly taken; the qualifier doubles as the two
highest-value search terms in the name field, which weighs heaviest in search.

## Subtitle (30 chars max)

Primary:    `The bill for your phone time`       (28)
Fallbacks:  `See what your phone costs you`      (29)
            `Your screen time, kept honest`      (29)

## Promotional text (170 chars max — editable without review, use for launches)

> Your phone knows exactly what it took from you today. Now you do too. The
> number on your lock screen, all day. Nothing leaves your device.

(148 chars)

## Description (4000 chars max — draft ~1900)

```
Wasted keeps one number in front of you: how much of today went to your
phone. On your lock screen. In the Dynamic Island. On the home screen when
you open the app. Not to shame you. Not to block you. Just so you can't
not know.

Most screen time apps congratulate you, gamify you, or lock you out.
Wasted is a mirror. It never blocks an app, never breaks a streak, never
tells you what to do. It keeps count — honestly, all day — and lets the
number do the talking.

WHAT IT DOES

— The number, everywhere. A live counter on your lock screen and in the
  Dynamic Island. It climbs while you scroll and resets at midnight.

— Nudges that state facts. Every 15 minutes inside the apps you choose to
  track, a quiet notification: "the number only goes up from here." No
  advice. No guilt trips. Just the count.

— Tonight's receipt. An itemised bill of the day, app by app, with the
  total measured against your waking hours.

— The morning report. Yesterday's bill, delivered at 8am — while today
  can still be different.

— Danger zones. The hours of the day where your time actually leaks,
  drawn to an honest scale.

— A widget that never sleeps, for your lock screen or home screen.

WASTED PRO — THE LONG RECEIPT

The daily mirror is free. Forever. Pro buys its memory: your all-time
total, your average day, your worst day, every month on one ledger, and
what your current rate costs you in days per year. Monthly, yearly, or
own it forever with a one-time purchase.

PRIVATE BY ARCHITECTURE

Wasted uses Apple's Screen Time framework. Your usage data is processed
entirely on your device. There is no account, no analytics, no server —
nothing leaves your phone. We couldn't read your data if we wanted to.

Wasted needs Screen Time permission to count, and it only counts the
apps you pick.

Is this how you want to spend your one life?
```

Subscription boilerplate (required for auto-renewable subs — append):

```
Wasted Pro subscriptions renew automatically unless cancelled at least
24 hours before the end of the period. Manage or cancel in your App
Store account settings.
Terms of Use: [EULA link — Apple standard EULA is fine]
Privacy Policy: [hosted privacy-policy link]
```

## Keywords (100 chars max, comma-separated, no spaces; don't repeat name/subtitle words)

```
screentime,usage,tracker,doomscroll,addiction,digital,detox,habit,focus,limit,distraction,offtime
```
(97 chars. "screen time" as two words is already in the name; "screentime"
as one word is a distinct indexed term. No brand names, no "free/best".)

## Category

Primary: Productivity. Secondary: Lifestyle.
(Health & Fitness invites comparison with meditation apps and a softer
audience; Productivity is where screen-time intent searches happen.)

## Age rating

17+ is not needed; standard questionnaire yields 4+. Family Controls here is
self-managed (individual authorization), not parental controls — say so in
review notes.

## Screenshots (6.9" required; reuse for 6.5". Dark canvas, real UI, one
lowercase caption per shot, serif)

1. HOME HERO — the number at 2h 25m, thesis line visible.
   Caption: "the number you avoid. kept."
2. LOCK SCREEN — island + live activity against a wallpaper.
   Caption: "it follows you all day."
3. NUDGE — notification over a feed-shaped blur: "you've already seen this feed."
   Caption: "it speaks up while it's happening."
4. RECEIPT — tonight's itemised bill.
   Caption: "an itemised bill, every night."
5. DANGER ZONES — the hour strip with one red bar.
   Caption: "see where the day leaks."
6. LONG RECEIPT (Pro) — all-time ledger + "at this rate: 46 days a year."
   Caption: "pro: the mirror remembers."

Optional 7th: plain canvas, single line — "nothing leaves your phone." —
privacy as a closing argument.

No device frames with hands, no gradients, no feature-grid collages: the
app's austerity IS the brand; the shots should look like the app.

## App Review notes (paste into ASC review notes field)

```
Wasted uses the FamilyControls / DeviceActivity / ManagedSettings
(Screen Time) frameworks with INDIVIDUAL authorization only — the user
authorizes their own device. It is not a parental-controls app.
The app never blocks or restricts anything: DeviceActivity thresholds
are used solely to count usage of apps the user explicitly selects via
FamilyActivityPicker, and to render that count in the app, a Live
Activity, notifications and widgets. All usage data stays on-device in
an App Group container; the app has no server and no analytics.
The com.apple.developer.family-controls (distribution) entitlement was
granted for com.sanskar.Wasted and com.sanskar.Wasted.DeviceActivityMonitorExt.
To test: complete onboarding, grant Screen Time permission, select 1-2
apps, use them briefly; the count appears on the home screen, island
and widget. Pro ("The Long Receipt") is a freemium unlock: monthly,
yearly (7-day intro offer), or lifetime.
```

## Launch checklist (ASC side)

- [ ] Fix app record display name ("Wastedd" → chosen name)
- [ ] Distribution entitlement CONFIRMED granted (blocker — check email)
- [ ] Create 3 IAPs: pro.monthly ($1.99), pro.yearly ($14.99 + 7-day free
      intro offer), lifetime ($29.99) — IDs already in code
- [ ] Enroll Small Business Program (85% cut)
- [ ] Host privacy policy (docs/privacy-policy.md → GitHub Pages)
- [ ] Privacy nutrition label: "Data Not Collected" (true — verify no
      third-party SDKs; there are none)
- [ ] Screenshots per plan above (6.9" iPhone; take from device, not sim,
      so the island shot is real)
- [ ] App Review notes pasted
- [ ] ProGate.paywallEnabled = true, diagnostics button removed (code gates)
```
