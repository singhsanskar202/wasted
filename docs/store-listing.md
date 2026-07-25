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

> Nobody thinks they scroll four hours a day. Then they see the number — on
> the lock screen, all day, impossible to unsee. Nothing leaves your device.

(150 chars)

## Description (4000 chars max — draft ~2300)

The arc is the app's own arc: guess → truth → it follows you → it speaks at
the moment of choice → it remembers → it quotes you. The reader should feel
the reality check while still on the store page. No hype, no cure claims —
the transformation on sale is *you will know, and you can't unsee it*.

```
How much do you think you scrolled yesterday?

Lock in a number. That guess is the first thing Wasted asks for — before
it shows you anything. A few days later it shows you what the truth was.
That moment is why this app exists. Almost nobody guesses high.

Wasted is not another screen time app. It never blocks, never shames,
never congratulates, never coaches. It is a mirror: it keeps the one
number you avoid in front of you until you stop avoiding it.

THE NUMBER FOLLOWS YOU
A live counter on your lock screen and in the Dynamic Island, climbing
while you scroll. White while the day is ordinary. Amber after an hour.
Red when a quarter of your waking day is gone. You see it every time you
pick up the phone — which is exactly the problem, working for you.

IT SPEAKS AT THE MOMENT OF CHOICE
Quiet nudges while you're inside the apps you chose to track: "you've
already seen this feed." Never advice. Just the count, and what it means.

IT QUOTES YOU
During setup you finish one sentence: "i keep meaning to…" — play the
ukulele, read, write, run. Mid-scroll, the mirror hands your own words
back: "you said: play the ukulele." Hardest notification to swipe away
that you'll ever receive. You wrote it.

IT BILLS YOU
Tonight's receipt: the day itemised, app by app, measured against your
waking hours. The morning report at 8am: yesterday's bill, while today
can still be different. Danger zones: the exact hours your life leaks.

WASTED PRO — THE MIRROR REMEMBERS, AND ARRIVES EARLY
The daily mirror is free, forever. Pro buys its memory: the long receipt —
your all-time total, average day, worst day, month by month, and what
your current rate costs in days per year. And the habit bell: when your
costliest window keeps repeating, a notification arrives as it OPENS —
"9pm–11pm. 5 of the last 7 nights, about 41m a time. today isn't written
yet." Screen time apps report your past. This one shows up before it
happens again. Yours forever with a single purchase — no subscription.

PRIVATE BY ARCHITECTURE
Everything is computed on your device. No account, no analytics, no
server — nothing leaves your phone. We couldn't read your data if we
wanted to. Wasted counts only the apps you pick.

Is this how you want to spend your one life?
```

Purchase note (lifetime only — no subscription boilerplate needed):

```
Wasted Pro is a one-time purchase. Buy it once and it's yours — no
subscription, nothing to renew or cancel.
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://wasted-push.singhsanskar2000.workers.dev/privacy
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
lowercase caption per shot, serif. The sequence is the transformation arc —
a viewer swiping through should feel watched, then quoted, then billed.)

1. HOME HERO — the number at 2h 25m, thesis line visible.
   Caption: "the number you avoid. kept."
2. LOCK SCREEN — island + live activity, red state, against a wallpaper.
   Caption: "it follows you all day."
3. NUDGE — a real notification: "you said: play the ukulele."
   Caption: "it quotes you. you wrote the line."
4. HABIT BELL (Pro) — "9pm–11pm — 5 of the last 7 days…" notification.
   Caption: "it shows up before the habit does."
5. RECEIPT — tonight's itemised bill.
   Caption: "the day, itemised. every night."
6. LONG RECEIPT (Pro) — all-time ledger + "at this rate: 46 days a year."
   Caption: "the mirror remembers."
7. CLOSER — plain canvas, one line: "nothing leaves your phone."

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
and widget. Pro ("The Long Receipt") is a freemium unlock: a single
one-time lifetime purchase.
```

## Launch checklist (ASC side)

- [ ] Fix app record display name ("Wastedd" → chosen name)
- [ ] Distribution entitlement CONFIRMED granted (blocker — check email)
- [ ] Create 1 non-consumable IAP: `com.sanskar.Wasted.lifetime` (~$29.99) —
      ID already in code. (Subscriptions pulled; lifetime only for launch.)
- [ ] Enroll Small Business Program (85% cut)
- [ ] Host privacy policy (docs/privacy-policy.md → GitHub Pages)
- [ ] Privacy nutrition label: "Data Not Collected" (true — verify no
      third-party SDKs; there are none)
- [ ] Screenshots per plan above (6.9" iPhone; take from device, not sim,
      so the island shot is real)
- [ ] App Review notes pasted
- [ ] ProGate.paywallEnabled = true, diagnostics button removed (code gates)
```
