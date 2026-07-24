# Wasted push-to-start server

Keeps the Dynamic Island / Lock Screen Live Activity **alive for users who
never open the app** — the whole point of the product. iOS kills a Live
Activity 8 hours after creation and only the foreground can start one, so
without this the island dies overnight and stays dark until the app is opened.
This server sends APNs `start` pushes on a schedule so iOS re-creates the
island on its own.

**Privacy:** the server holds only an opaque APNs token + a random install id.
The start push is an empty envelope (`totalSeconds: 0`); the island's own view
reads the real number from the on-device App Group. **No usage data ever
reaches the server** — it cannot know what the number is.

---

## What you need (one-time)

1. **Enable Push Notifications on the App ID.**
   developer.apple.com → Certificates, Identifiers & Profiles → Identifiers →
   `com.sanskar.Wasted` → check **Push Notifications** → Save. (This is what
   lets the app get a push-to-start token. Do this BEFORE adding the
   `aps-environment` entitlement, or dev builds fail to sign.)

2. **Create an APNs Auth Key (.p8).**
   Same portal → Keys → ➕ → check **Apple Push Notifications service (APNs)** →
   Register → **Download the .p8** (you can only download it once). Note the
   **Key ID** (10 chars). Your **Team ID** is `ZZZ87SSQ8S`.

3. **Add the entitlement + capability in Xcode.**
   Open the project → target **Wasted** → Signing & Capabilities → **+
   Capability → Push Notifications**. That adds `aps-environment` and lets
   Xcode manage development (Xcode builds) vs production (TestFlight/App Store)
   automatically. Rebuild to your device — you should see
   `push-to-start token registered` in the logs once the server URL is set.

## Deploy the server (Cloudflare Workers — free tier)

```bash
cd push-server
npm install
npx wrangler login                       # opens the browser once

# create the token store, paste the printed id into wrangler.toml (TOKENS id)
npx wrangler kv namespace create TOKENS

# put the .p8 contents in as a secret (never commit it)
npx wrangler secret put APNS_KEY_P8       # paste the whole .p8 file contents

# fill APNS_KEY_ID in wrangler.toml (Team ID + bundle id are already set)

npx wrangler deploy
```

Deploy prints a URL like `https://wasted-push.<your>.workers.dev`.

## Wire the app to the server

Set that URL in the app:
`Wasted/Shared/PushToStartRegistrar.swift` → `serverBase = "https://…workers.dev"`
Rebuild + install. On next launch the app registers its token.

## Verify it works (do this before trusting it)

```bash
# force the cron immediately in local dev
npx wrangler dev --test-scheduled
# then hit http://localhost:8787/__scheduled  (wrangler prints the exact URL)
npx wrangler tail                          # watch live logs on the deployed worker
```

**The one thing to confirm by eye:** after a start push, the island should
appear on the device showing the REAL number (pulled from the App Group). If
the island does **not** appear, the most likely cause is the `content-state`
date format — ActivityKit is strict about how `confirmedAt` decodes. In
`src/worker.js`, the placeholder sends it as an ISO string
(`"confirmedAt": isoNow()`); if the push is rejected or the island never shows,
switch it to a Unix timestamp number (`"confirmedAt": Math.floor(Date.now()/1000)`)
and redeploy. `totalSeconds` is a plain Int and never a problem. Once one test
push lights up the island, the format is correct and it's done.

## Cost

Cloudflare Workers free tier covers 100k requests/day and cron triggers; KV
free tier covers this easily. Expect **$0/month** until Wasted has serious
scale, then a few dollars.

## App Review note

The pushes restart a **daily usage counter on a schedule** — a legitimate
Live Activity use, the same pattern delivery and sports apps use. It does not
resurrect a Live Activity the instant a user dismisses it (the schedule is
hours apart), which is the behaviour Apple objects to. Keep the cadence at a
few times a day, not minutes.
