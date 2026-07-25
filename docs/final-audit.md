# Wasted — final pre-launch audit

Date: 2026-07-25. Covers everything through the push-to-start server + copy
pass. Verdict: **the app is in good shape; the blockers are all known, mostly
account/ASC steps, not code defects.**

## 🔴 Critical

1. ~~Push server `/test-send` endpoint public~~ — **FIXED 2026-07-25.** Endpoint
   + report plumbing removed and redeployed (POST → 404 verified). `/register`
   now strictly validates token/install/env/tz shape (junk → 400 verified).

2. **Paywall is off and its products don't exist yet** — the one remaining
   real blocker, and it's an ASC task. Create the 3 IAPs (`pro.monthly`,
   `pro.yearly` + 7-day intro, `lifetime`) → flip `ProGate.paywallEnabled` →
   update the tripwire test in ProGateTests. NOTE: flipping that one flag now
   ALSO removes the diagnostics button (they're gated together), so this is the
   single switch for "ship mode".

3. ~~Beta "send diagnostics" button~~ — **FIXED 2026-07-25.** Now gated on
   `!ProGate.paywallEnabled`, so it disappears automatically when the paywall
   goes live. No separate step to forget.

4. ~~Paywall missing Terms / Privacy links~~ — **FIXED 2026-07-25.** Both links
   added (Apple standard EULA + hosted privacy policy). Privacy policy is now
   served at `https://wasted-push.singhsanskar2000.workers.dev/privacy`.

5. ~~Family Controls distribution entitlement~~ — **RESOLVED** (granted, signed
   build verified).

## 🟠 High

6. **Privacy nutrition label must be updated in ASC.** The app now sends a push
   token + timezone to the push server, so "Data Not Collected" is no longer
   strictly accurate. In the ASC privacy questionnaire declare it honestly:
   an identifier (push token) used for **App Functionality only, not linked to
   the user's identity, not used for tracking**. The privacy policy already
   discloses this. This is an ASC form accuracy item, not a code bug — but
   getting it wrong is a rejection/appstore-trust risk.

7. ~~Push `/register` unauthenticated~~ — **MITIGATED 2026-07-25.** Strict shape
   validation now rejects non-token/non-UUID/bad-tz junk (400). A shared secret
   in the app binary wouldn't be secret; App Attest is the real hardening if
   abuse ever appears.

8. **Zero VoiceOver support** (0 accessibilityLabels app-wide). The hero
   number, danger-zone chart, week bars, receipts read as silent or noisy.
   Not a launch blocker, but do a minimum pass (label the hero, the charts;
   hide decorative rules) before or right after launch.

## 🟡 Medium

9. **Screenshots must be captured on a real device** — the island and lock
   screen can't be faked in the simulator. Storyboard in docs/store-listing.md.
10. **New screens (Long Receipt / History, the intentions step) want a device
    visual check** — unit-tested and building, but eyeball them rendered.
11. **Push revival is ~30 min early for half-hour timezones** (India etc.) —
    the worker rounds the GMT offset to whole hours. Harmless for "waking
    hours"; fixable later with fractional handling.
12. **Subscription expiry is caught only at next app open** (ProStore refreshes
    entitlement on launch). Fine for v1; add a scenePhase refresh later.

## ✅ Strengths (verified this pass)

- No insecure URLs (zero `http://`), no hardcoded secrets in app or server.
- The APNs `.p8` is gitignored AND stored as a Cloudflare secret — never in
  the repo. Confirmed no `.p8` is tracked by git.
- No risky force-unwraps in the new code (push, history, habit bell, threshold).
- No third-party SDKs, no analytics, no tracking domains. Privacy manifest
  declares no tracking; UserDefaults reason (CA92.1) present.
- The push server holds only an opaque token + timezone + random install id —
  **never any usage data**; APNs ES256 JWT signing is correct; dead tokens
  (410) are pruned.
- Entitlements are minimal and correct (family-controls, app-groups,
  aps-environment); distribution signing verified earlier.
- The session's correctness fixes (island rotation, dismissal/ghost handling,
  total-inflation delta-cap + self-heal, personal nudges, long receipt) are
  covered by tests — **170 tests green**.
- StoreKit 2 done right: verified transactions only, restore present, price
  from displayPrice, trial copy only when StoreKit returns an intro offer.

## Recommended order to launch

1. Cut **build 3** to TestFlight now (everything's in it) and live on it a few
   days — the island, totals, push-to-start all need real-world time.
2. In parallel: create the 3 ASC IAPs, enroll Small Business Program, host the
   privacy policy (GitHub Pages).
3. Then the App Store build: remove `/test-send` + redeploy, remove the
   diagnostics button, flip `paywallEnabled` + fix the tripwire test, wire the
   paywall legal links, fill the ASC privacy questionnaire (item 6),
   screenshots from device.
4. Submit. App Review 24–48h.
