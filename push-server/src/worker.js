// Wasted push-to-start server — a Cloudflare Worker.
//
// Its ONE job: keep the Dynamic Island / Lock Screen Live Activity alive for
// users who don't open the app. The app registers its ActivityKit
// push-to-start token here; a cron sends APNs `start` pushes on a schedule so
// iOS (re)creates the island without the app launching. Each push resets the
// 8-hour cap.
//
// PRIVACY: this server never receives, stores, or sends any usage data. It
// holds an opaque APNs token + an install id, and sends an EMPTY envelope —
// the start push carries a placeholder total of 0, and the island's own view
// fills in the real number by reading the on-device App Group. The server
// cannot know what the number is.
//
// Bindings (wrangler.toml / secrets):
//   TOKENS         KV namespace — stores { token, env } per install id
//   APNS_KEY_P8    secret — the .p8 APNs auth key contents (PEM)
//   APNS_KEY_ID    var    — the 10-char Key ID
//   APNS_TEAM_ID   var    — the 10-char Team ID (ZZZ87SSQ8S)
//   APP_BUNDLE_ID  var    — com.sanskar.Wasted

const APNS_HOSTS = {
  sandbox: "https://api.sandbox.push.apple.com",
  production: "https://api.push.apple.com",
};

export default {
  // ---- token registration from the app ------------------------------------
  async fetch(request, env) {
    const url = new URL(request.url);

    // Privacy policy, served as a stable HTTPS page for the App Store listing
    // and the in-app paywall link. Hosted here only because it's free and
    // instant; can move to a custom domain later.
    if (url.pathname === "/privacy") {
      return new Response(PRIVACY_HTML, {
        status: 200,
        headers: { "content-type": "text/html; charset=utf-8" },
      });
    }

    if (request.method !== "POST") return new Response("ok", { status: 200 });
    if (url.pathname !== "/register") return new Response("not found", { status: 404 });

    // Per-IP rate limit. The endpoint is public and unauthenticated, so cap how
    // fast one source can create records — otherwise an attacker floods the KV
    // store with valid-shaped junk (unique install UUIDs), and every hourly cron
    // then fans out APNs pushes for all of it, eventually starving real devices.
    // Counter keys are prefixed `rl:`, expire on their own, and the cron skips them.
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const rlKey = `rl:${ip}`;
    const rlCount = Number(await env.TOKENS.get(rlKey)) || 0;
    if (rlCount >= 20) return new Response("rate limited", { status: 429 });
    await env.TOKENS.put(rlKey, String(rlCount + 1), { expirationTtl: 60 });

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response("bad json", { status: 400 });
    }
    const { token, install, env: apnsEnv, tz } = body || {};

    // Strict shape validation — the endpoint is public, so reject anything that
    // isn't a real APNs token + UUID install + known env + sane offset. This
    // keeps junk out of the KV store without needing a shared secret (which,
    // shipped inside the app binary, wouldn't be secret anyway). App Attest is
    // the real hardening if abuse ever shows up.
    const tokenOK = typeof token === "string" && /^[0-9a-f]{64,200}$/i.test(token);
    const installOK =
      typeof install === "string" &&
      /^[0-9A-F-]{36}$/i.test(install); // UUID shape
    const tzNum = Number(tz);
    const tzOK = Number.isFinite(tzNum) && tzNum >= -720 && tzNum <= 840;
    if (!tokenOK || !installOK || !["sandbox", "production"].includes(apnsEnv) || !tzOK) {
      return new Response("bad request", { status: 400 });
    }

    // One record per install — replaces the old token, never hoards.
    await env.TOKENS.put(
      install,
      JSON.stringify({ token, env: apnsEnv, tz: tzNum })
    );
    return new Response("registered", { status: 200 });
  },

  // ---- scheduled start pushes (cron, hourly) ------------------------------
  // The cron ticks every hour; each device is only pushed when its LOCAL hour
  // is one of REVIVAL_LOCAL_HOURS. So every device gets a handful of quiet
  // revivals a day at its own waking hours — well within the push-to-start
  // budget, and never at 3am.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(sendStartPushes(env));
  },
};

// A few revivals a day, at the user's local waking hours. Spacing (~5h) means a
// dismissed or expired island is back within a few hours without the app being
// opened — the practical ceiling given iOS forces a notification per push.
const REVIVAL_LOCAL_HOURS = [8, 13, 18, 22];

async function sendStartPushes(env) {
  const jwtByEnv = {}; // cache one signed JWT per APNs host for this run
  const utcHour = new Date().getUTCHours();
  let cursor;
  do {
    const page = await env.TOKENS.list({ cursor, limit: 1000 });
    cursor = page.list_complete ? undefined : page.cursor;

    for (const key of page.keys) {
      // Rate-limit counters share this KV; they are not device records.
      if (key.name.startsWith("rl:")) continue;
      const rec = await env.TOKENS.get(key.name, "json");
      if (!rec) continue;
      const host = APNS_HOSTS[rec.env];
      if (!host) continue;

      // Only revive when it's a target hour in THIS device's timezone.
      const localHour = ((utcHour + Math.round((rec.tz || 0) / 60)) % 24 + 24) % 24;
      if (!REVIVAL_LOCAL_HOURS.includes(localHour)) continue;

      if (!jwtByEnv[rec.env]) {
        jwtByEnv[rec.env] = await makeAPNsJWT(env);
      }
      await pushStart(host, jwtByEnv[rec.env], rec.token, env, key.name, rec.tz);
    }
  } while (cursor);
}

// The push-to-start payload. `event: "start"` tells iOS to CREATE the activity.
// content-state is a placeholder; the app's Live Activity view reads the real
// total from the App Group at render time (max(pushed, pulled)), so 0 here just
// means "the app will fill it in".
async function pushStart(host, jwt, deviceToken, env, install, tz) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    aps: {
      timestamp: now,
      event: "start",
      // Passive: the required notification slips into Notification Center
      // without a banner or sound. The island still appears; the alert doesn't
      // interrupt. This is the least-intrusive way to satisfy iOS's rule that
      // a push-to-start MUST carry an alert.
      "interruption-level": "passive",
      // Date fields as Unix epoch SECONDS (numbers) — ActivityKit's push
      // decoder wants that, not ISO strings. Both the content-state and the
      // attributes carry Dates, so both must be numeric.
      "content-state": { totalSeconds: 0, confirmedAt: now },
      "attributes-type": "TimeTrackerAttributes",
      attributes: { day: localDay(tz), startedAt: now },
      "stale-date": now + 8 * 3600,
      // REQUIRED: iOS rejects a push-to-start with no alert ("Received start
      // without an alert configuration"). Both title and body must be
      // non-empty. This does surface a quiet notification each time the island
      // is revived — the cadence (a few times a day) keeps it tolerable, and
      // the wording is on-brand rather than spammy.
      alert: {
        title: "wasted",
        body: "your day is being counted.",
      },
    },
  };

  const res = await fetch(`${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": `${env.APP_BUNDLE_ID}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  // Prune dead tokens so junk can't accumulate and the cron doesn't retry it
  // forever. 410 = Unregistered (app uninstalled). 400 = permanent token errors
  // (BadDeviceToken / DeviceTokenNotForTopic) — the signature of flooded junk.
  // Other 400s are our own payload bugs, so don't delete a good token for those.
  if (res.status === 410) {
    await env.TOKENS.delete(install);
  } else if (res.status === 400) {
    const reason = await res
      .json()
      .then((b) => b && b.reason)
      .catch(() => "");
    if (reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic") {
      await env.TOKENS.delete(install);
    }
  }
}

// ---- APNs token auth (ES256 JWT), signed with the .p8 key -----------------
async function makeAPNsJWT(env) {
  const header = { alg: "ES256", kid: env.APNS_KEY_ID };
  const claims = { iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };
  const signingInput =
    b64url(JSON.stringify(header)) + "." + b64url(JSON.stringify(claims));

  const key = await importP8(env.APNS_KEY_P8);
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );
  return signingInput + "." + b64urlBytes(new Uint8Array(sig));
}

async function importP8(pem) {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
}

// ---- helpers --------------------------------------------------------------
function b64url(str) {
  return b64urlBytes(new TextEncoder().encode(str));
}
function b64urlBytes(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function isoNow() {
  return new Date().toISOString();
}
// The activity's `day` must match the device's LOCAL day, or the island view's
// midnight check (attributes.day vs the device's local day string) never matches
// and the card reads 0m. The cron runs in UTC, so shift by the device's stored
// timezone offset (minutes) before taking the calendar date.
function localDay(tzOffsetMinutes = 0) {
  const local = new Date(Date.now() + (Number(tzOffsetMinutes) || 0) * 60 * 1000);
  return local.toISOString().slice(0, 10);
}

// ---- privacy policy page --------------------------------------------------
const PRIVACY_HTML = `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Wasted — Privacy Policy</title>
<style>
  :root { color-scheme: light dark; }
  body { max-width: 44rem; margin: 3rem auto; padding: 0 1.25rem;
    font: 17px/1.6 -apple-system, system-ui, sans-serif;
    color: #1c1c1e; background: #fff; }
  @media (prefers-color-scheme: dark) { body { color: #e7e5e0; background: #0a0a0a; } }
  h1 { font-size: 1.9rem; } h2 { font-size: 1.15rem; margin-top: 2rem; }
  .lede { font-size: 1.05rem; opacity: .8; }
  a { color: #d63a2f; }
  footer { margin-top: 3rem; opacity: .6; font-size: .9rem; }
</style></head><body>
<h1>Wasted — Privacy Policy</h1>
<p class="lede">Wasted is built so that we cannot see your data. This policy is
short because there is almost nothing to disclose.</p>

<h2>The one-sentence version</h2>
<p>Your screen-time data is processed entirely on your device and is never
transmitted to us or anyone else. The only thing that leaves your device is an
anonymous Apple push token (and your timezone), used solely to keep the Live
Activity on your Lock Screen and Dynamic Island alive — it carries none of
your usage.</p>

<h2>What the app accesses</h2>
<p><strong>Screen Time</strong> (Apple's FamilyControls / DeviceActivity
frameworks). With your permission, iOS reports usage thresholds for the apps
you select. Wasted counts your time; it cannot read your content, messages, or
browsing.</p>

<h2>Where your data lives</h2>
<p>All usage records, settings, and history are stored in the app's private
container on your device. There is no account and no cloud sync. Deleting the
app deletes this data.</p>

<h2>What we collect</h2>
<p>No usage data, ever. No analytics, no advertising identifiers, no tracking,
no third-party SDKs, no account.</p>

<h2>The one thing that leaves your device: a push token</h2>
<p>To keep the counter on your Lock Screen and Dynamic Island alive when the
app isn't open, Apple's Live Activity system requires a small server to send
scheduled "wake up" pushes. For that, the app sends one anonymous Apple Push
Notification token, a random install identifier, and your timezone offset to
our push server. The token is an opaque delivery address issued by Apple; it
is not linked to your name, Apple ID, or device identity, and it contains none
of your usage. The "wake up" push we send back is empty — your device fills in
the number locally. This data is discarded when you delete the app.</p>

<h2>Purchases</h2>
<p>Wasted Pro is sold through Apple's App Store. Apple processes your payment;
we never see your payment details.</p>

<h2>Your rights</h2>
<p>Rights of access, correction, and deletion apply to data an organisation
holds about you. We hold no usage data. Everything the app creates is on your
device, under your control, and destroyed by deleting the app.</p>

<h2>Contact</h2>
<p><a href="mailto:singhsanskar2000@gmail.com">singhsanskar2000@gmail.com</a></p>

<footer>Effective 2026. Sanskar Singh.</footer>
</body></html>`;
