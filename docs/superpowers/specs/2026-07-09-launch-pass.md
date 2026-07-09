# Wasted 1.0 Launch Pass — Product & Monetization Spec
**Date:** 2026-07-09
**Status:** Approved
**Prerequisite verified:** Apple Developer Program active; Family Controls dev provisioning succeeds for all 3 targets (checked 2026-07-09, `xcodebuild -allowProvisioningUpdates` → BUILD SUCCEEDED).

---

## 1. The thesis (what we are selling)

Every screen-time app on the store sells **control**: blockers, locks, streaks, "shields." They all fail the same way — the user bypasses the block, breaks the streak once, feels shame, deletes the app. Wasted sells the only thing that can't be bypassed: **the truth**. A running number that follows you into the scroll, onto your lock screen, into your notifications, and hands you a receipt at night.

The one-line pitch, in the app's own voice:

> **you can ignore a blocker. you can't unsee a number.**

Everything in this pass either sharpens that pitch or removes friction from believing it. Nothing else ships.

### Why someone pays for this (the emotional sequence)

1. **The guess.** During onboarding we ask them to estimate their daily scroll. Everyone lowballs.
2. **The reality.** After the first full tracked day, the app shows: *"you guessed 2h. reality: 4h 12m."* This is the aha — the moment they learn their own intuition lies to them and only the mirror doesn't. This single screen is the conversion engine.
3. **The habit.** For seven days the number is everywhere — island, lock screen, widget, receipt. It becomes the truth-teller in their pocket.
4. **The choice.** Trial ends. The app keeps counting — but the mirror frosts over. *"still counting. you just can't see it."* They've seen what a week of truth looks like; now they decide if they can go back to not knowing.

## 2. Monetization decision

**Model: free download → 7-day full trial → one-time lifetime unlock (non-consumable IAP). No subscription. Ever.**

This is a product decision as much as a pricing one. Opal and Jomo charge ~$99/year — a *permanent tax on your own weakness*. Wasted's anti-subscription stance is the marketing:

> "no subscription. an app whose goal is that you need it less shouldn't bill you forever."

| Decision | Value | Rationale |
|---|---|---|
| Product | Non-consumable `com.sanskar.Wasted.lifetime` | One purchase, owned forever, restorable |
| Price | **$9.99** (Apple tier, auto region pricing) | Above the $2.99 utility junk tier — signals a considered product; below impulse-purchase ceiling; room to raise after reviews. Not paid-upfront: a $9.99 upfront app gets ~zero downloads with no trust |
| Trial | 7 days, **everything unlocked**, tracked locally from first launch | Non-consumables get no App Store trial mechanism; local `TrialClock` from first-launch date. 7 days = one full weekly receipt cycle |
| Small Business Program | Enroll | 15% commission instead of 30% → ~$8.49/sale |

### Gating (what happens when the trial ends, unpurchased)

Principle: **the app never stops telling the truth to itself — it stops showing you.** Data keeps recording so the day they buy, the missing days are all there ("we kept counting. it's all here."). Honest loss-aversion, no dark patterns: clear price, one tap to dismiss the paywall, Restore Purchases always visible.

| Surface | Trial (day 1–7) | Expired, unpurchased | Purchased |
|---|---|---|---|
| Usage recording (App Group) | ✅ | ✅ keeps recording | ✅ |
| Home daily number | ✅ | 🔒 blurred + "still counting. you just can't see it." | ✅ |
| Dynamic Island / Live Activity | ✅ | ❌ not started | ✅ |
| 30-min nudges | ✅ | ❌ | ✅ |
| Daily receipt (notif + sheet) | ✅ | 🔒 | ✅ |
| Insights / heatmap / weekly / peak-hour | ✅ | 🔒 | ✅ |
| Widgets | ✅ | 🔒 locked state | ✅ |

App Review notes: complies with 3.1.1 (IAP for digital features), no 3.2.2 bait-and-switch (trial clearly labeled from day 1 — a small "day N of 7" line lives on the home screen during trial), Restore Purchases present, paywall dismissible.

### Revenue sanity check (not a projection, a floor-check)

$9.99 × 85% = ~$8.49 net/sale. At a modest 3–5% trial→paid conversion, 1,000 downloads ≈ $250–$425. The million-dollar version of this app is not v1 revenue — it's proving the mirror loop retains, then raising price and riding the anti-subscription positioning. Don't over-build for scale now.

## 3. New product surface in this pass

1. **Guess → Reality check** (the conversion engine, §1). Guess captured in onboarding; reality card shown once, after first archived day.
2. **Widgets** (now possible with paid account): `systemSmall` home widget — the number in serif on canvas, red past 1h — plus `accessoryRectangular` + `accessoryCircular` lock-screen widgets. The mirror lives on the home screen, between the very apps it counts.
3. **Auto-receipt after 9 PM**: first app open after 21:00 presents the receipt sheet unprompted, once per day. Closes the gap where the 9 PM notification can't fire (no threshold event before 21:00).
4. **Paywall + trial chrome**, in the voice (copy locked in the plan).
5. **App icon**: serif italic "W", `#F5F3EE` on `#0A0A0A`. The receipt aesthetic on the home screen.

## 4. Launch risks (ordered by lead time)

1. **Family Controls *distribution* entitlement** — dev entitlement works today for device testing; **App Store distribution requires applying to Apple via the Family Controls request form**, per bundle ID (app + monitor extension). Turnaround: days to weeks. **Submit the request the moment the App Store Connect app record exists.** This is the launch long pole; nothing else on the critical path comes close.
2. **App name availability** — "Wasted" alone is likely taken/reserved; target "Wasted — Screen Time Mirror" (27 chars). Reserve in App Store Connect early.
3. **Icon rendering on device** — `ImageRenderer(Label(token))` is known to render blank off-screen on real devices for FamilyControls labels. Letter-tile fallback already exists; verify on device before investing further.
4. **Deployment target 26.5** — fine for personal testing; decide before public launch whether to lower (wider reach) or keep (zero API audit cost). Not this pass.

## 5. Non-negotiables (unchanged, restated for the executor)

Never blocks or locks the phone. No streak guilt. No engagement-bait notifications. No analytics SDKs, no tracking, nothing leaves the device — privacy label will be **"Data Not Collected"**, and that's a selling point, print it on the store page. No settings bloat. Red only when the number is bad. Serif only when the mirror speaks. One haptic per moment, per the existing table, plus exactly two new ones defined in the plan (reality check reveal; purchase success).
