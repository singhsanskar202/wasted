# Release Review: Wasted

**Platform**: iOS · **Distribution**: TestFlight → App Store · **Date**: 2026-07-19

## Summary

| Priority | Count |
|----------|-------|
| Critical (ship blockers) | 3 |
| High | 2 |
| Medium | 3 |
| Low | 2 |

All three criticals are known, tracked, and intentional for the beta — none is
a surprise. The mechanical release surface (manifests, entitlements, export
compliance, icons, launch screen) is in unusually good shape.

---

## 🔴 Critical — must resolve before submission

### 1. Family Controls DISTRIBUTION entitlement unconfirmed
The only hard external blocker. Development builds work; App Store signing
fails until Apple grants `com.apple.developer.family-controls` for
`com.sanskar.Wasted` + `…DeviceActivityMonitorExt` distribution profiles.
**Action**: check email/ASC; if silent > 2 weeks, reply on the request thread.

### 2. Paywall is off and its products don't exist
`ProGate.paywallEnabled = false` (Wasted/Shared/TrialClock.swift:25), and the
three product IDs the code sells are not yet in App Store Connect.
**Action**: create `pro.monthly` / `pro.yearly` (+7-day free intro offer) /
`lifetime` in ASC → flip the flag → update the tripwire assertion in
ProGateTests (it fails on purpose when the flag flips). Never flip before the
products exist: the paywall would show three dead "loading…" buttons.

### 3. Beta diagnostics button still on the home screen
HomeView footer "send diagnostics" (marked BETA ONLY in code).
**Action**: delete before App Store build; keep for TestFlight builds.

---

## 🟠 High

### 4. Paywall has no Terms of Use / Privacy Policy links
Auto-renewable subscriptions require a EULA and privacy policy link in
metadata, and reviewers regularly want them visible near the purchase
buttons (Guideline 3.1.2). Ready to paste under "restore purchases":

```swift
HStack(spacing: 16) {
    Link("terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
    Link("privacy", destination: URL(string: PRIVACY_POLICY_URL)!)
}
.font(.system(size: 12, weight: .light))
.foregroundStyle(Color.ink.opacity(0.3))
```

Blocked on hosting `docs/privacy-policy.md` (GitHub Pages is enough) — do that
first, then wire the real URL and add both links to ASC metadata.

### 5. Subscription expiry is only caught at next app open
`ProStore.refreshEntitlement()` runs on HomeView's `.task` once per launch. A
lapsed subscriber keeps Pro until they next cold-open the app. Acceptable for
v1 (the long receipt is not a service with marginal cost), but add a refresh
on `scenePhase == .active` in a follow-up.

---

## 🟡 Medium

### 6. Zero VoiceOver support
No `accessibilityLabel` anywhere. The hero number, danger-zone chart, week
heatmap and receipt are all silent or noisy under VoiceOver. Minimum viable
pass: label the hero ("you wasted 2 hours 25 minutes today"), the chart
("busiest hour 9 pm, 1 hour 2 minutes"), and mark decorative rules hidden.

### 7. Store screenshots must come from a real device
The island and lock screen cannot be faked in the simulator, and the sim
seeds fake data (guarded `#if targetEnvironment(simulator)` — verified it
cannot ship). Plan in docs/store-listing.md.

### 8. English only
Fine for v1; the brand voice is hard to translate well. Revisit after launch
with downloads by storefront.

---

## 🟢 Low

- `LiveActivityManager.hasActiveActivity` is now unused — delete on next pass.
- `docs/pull-logs.sh` and EventLog session stamps mention beta workflows;
  harmless to ship, tidy later.

---

## ✅ Strengths (verified on disk this review)

- **Privacy manifest correct and honest**: no collection, no tracking,
  UserDefaults declared with CA92.1. Matches the drafted privacy policy.
- **Export compliance declared** (`ITSAppUsesNonExemptEncryption = false`).
- **No third-party SDKs, no analytics, no insecure URLs** (grep-verified:
  zero `http://`, zero tracking imports). The "nothing leaves your device"
  claim is architecturally true.
- **Entitlements minimal and clean**; the stale family-controls entitlement
  on LiveActivityExt (old P5) is already removed.
- **App Group failure degrades instead of crashing** (`UserDefaults.wastedShared`
  fallback) — the classic provisioning crash-loop is designed out.
- **StoreKit 2 done right**: verified transactions only, restore button,
  price always from `displayPrice`, trial copy only when StoreKit returns an
  intro offer.
- **BGTask identifiers, background modes, Live Activity keys** all present in
  build settings; icons in all three iOS 18 variants (light/dark/tinted).
- **Debug surfaces already cleaned** (old P4 `debug_la` keys gone).

## Action order

1. Confirm the entitlement (external, days–weeks — everything else can happen in parallel).
2. Host the privacy policy → wire paywall legal links (High #4).
3. Create ASC products → flip `ProGate.paywallEnabled` → fix tripwire test.
4. Remove the diagnostics button in the App Store build.
5. Device pass: island rotation over a day, meter-dark nudge, long receipt, screenshots.
6. VoiceOver minimum pass (#6) — before App Store, after TestFlight.
