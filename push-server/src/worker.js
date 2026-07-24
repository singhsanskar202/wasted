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
    if (request.method !== "POST") return new Response("ok", { status: 200 });
    const url = new URL(request.url);
    if (url.pathname !== "/register") return new Response("not found", { status: 404 });

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response("bad json", { status: 400 });
    }
    const { token, install, env: apnsEnv } = body || {};
    if (!token || !install || !["sandbox", "production"].includes(apnsEnv)) {
      return new Response("missing fields", { status: 400 });
    }
    // One record per install — replaces the old token, never hoards.
    await env.TOKENS.put(install, JSON.stringify({ token, env: apnsEnv }));
    return new Response("registered", { status: 200 });
  },

  // ---- scheduled start pushes (cron) --------------------------------------
  async scheduled(event, env, ctx) {
    ctx.waitUntil(sendStartPushes(env));
  },
};

async function sendStartPushes(env) {
  const jwtByEnv = {}; // cache one signed JWT per APNs host for this run
  let cursor;
  do {
    const page = await env.TOKENS.list({ cursor, limit: 1000 });
    cursor = page.list_complete ? undefined : page.cursor;

    for (const key of page.keys) {
      const rec = await env.TOKENS.get(key.name, "json");
      if (!rec) continue;
      const host = APNS_HOSTS[rec.env];
      if (!host) continue;

      if (!jwtByEnv[rec.env]) {
        jwtByEnv[rec.env] = await makeAPNsJWT(env);
      }
      await pushStart(host, jwtByEnv[rec.env], rec.token, env, key.name);
    }
  } while (cursor);
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
      "content-state": { totalSeconds: 0, confirmedAt: isoNow() },
      "attributes-type": "TimeTrackerAttributes",
      attributes: { day: localDay(), startedAt: isoNow() },
      "stale-date": now + 8 * 3600,
      alert: { title: "wasted", body: "" }, // required by APNs; the island shows the number, not this
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
