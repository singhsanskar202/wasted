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

    // TEMPORARY test trigger — runs the scheduled push on demand and reports
    // each token's APNs response, so we can verify end-to-end without waiting
    // for the cron. Guarded by an obscure path; REMOVE before real launch.
    if (url.pathname === "/test-send-9f3a2c") {
      const results = await sendStartPushes(env, { report: true });
      return new Response(JSON.stringify(results, null, 2), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }

    if (request.method !== "POST") return new Response("ok", { status: 200 });
    if (url.pathname !== "/register") return new Response("not found", { status: 404 });

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response("bad json", { status: 400 });
    }
    const { token, install, env: apnsEnv, tz } = body || {};
    if (!token || !install || !["sandbox", "production"].includes(apnsEnv)) {
      return new Response("missing fields", { status: 400 });
    }
    // One record per install — replaces the old token, never hoards. `tz` is
    // the device's minutes-offset from GMT, so revivals land at local time.
    await env.TOKENS.put(
      install,
      JSON.stringify({ token, env: apnsEnv, tz: Number(tz) || 0 })
    );
    return new Response("registered", { status: 200 });
  },

  // ---- scheduled start pushes (cron, hourly) ------------------------------
  // The cron ticks every hour; each device is only pushed when its LOCAL hour
  // is one of REVIVAL_LOCAL_HOURS. So every device gets a handful of quiet
  // revivals a day at its own waking hours — well within the push-to-start
  // budget, and never at 3am.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(sendStartPushes(env, { onlyAtLocalHours: true }));
  },
};

// A few revivals a day, at the user's local waking hours. Spacing (~5h) means a
// dismissed or expired island is back within a few hours without the app being
// opened — the practical ceiling given iOS forces a notification per push.
const REVIVAL_LOCAL_HOURS = [8, 13, 18, 22];

async function sendStartPushes(env, { report = false, onlyAtLocalHours = false } = {}) {
  const jwtByEnv = {}; // cache one signed JWT per APNs host for this run
  const results = [];
  const utcHour = new Date().getUTCHours();
  let cursor;
  do {
    const page = await env.TOKENS.list({ cursor, limit: 1000 });
    cursor = page.list_complete ? undefined : page.cursor;

    for (const key of page.keys) {
      const rec = await env.TOKENS.get(key.name, "json");
      if (!rec) continue;
      const host = APNS_HOSTS[rec.env];
      if (!host) continue;

      // Only revive when it's a target hour in THIS device's timezone.
      if (onlyAtLocalHours) {
        const localHour = ((utcHour + Math.round((rec.tz || 0) / 60)) % 24 + 24) % 24;
        if (!REVIVAL_LOCAL_HOURS.includes(localHour)) continue;
      }

      if (!jwtByEnv[rec.env]) {
        jwtByEnv[rec.env] = await makeAPNsJWT(env);
      }
      const r = await pushStart(host, jwtByEnv[rec.env], rec.token, env, key.name);
      if (report) results.push({ install: key.name, env: rec.env, ...r });
    }
  } while (cursor);
  return results;
}

// The push-to-start payload. `event: "start"` tells iOS to CREATE the activity.
// content-state is a placeholder; the app's Live Activity view reads the real
// total from the App Group at render time (max(pushed, pulled)), so 0 here just
// means "the app will fill it in".
async function pushStart(host, jwt, deviceToken, env, install) {
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
      attributes: { day: localDay(), startedAt: now },
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

  // 410 = the token is dead (app uninstalled) — drop it so we stop trying.
  if (res.status === 410) {
    await env.TOKENS.delete(install);
  }
  // APNs returns 200 empty on success, or JSON { reason } on failure.
  const reason = res.status === 200 ? "" : await res.text();
  return { status: res.status, apnsId: res.headers.get("apns-id") || "", reason };
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
// The activity's `day` must match the device's local day for the view's
// midnight reset. Cron runs in UTC; this uses UTC day, which is close enough
// for a placeholder the app immediately re-anchors. (For strict correctness a
// future version can store each device's timezone.)
function localDay() {
  return new Date().toISOString().slice(0, 10);
}
