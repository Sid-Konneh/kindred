// Sends one alert to every device a member registered for push (see migration 018), so it reaches them even
// when Kindred is closed: Web Push for browsers and the iPhone home-screen app, Firebase for the Android app.
// Only the database triggers call this, with the shared secret; members can't.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

type Alert = { to: string; kind: string; title: string; body: string; link: string; tag: string; match_id?: string | null };
type Device = { id: string; kind: "web" | "fcm"; endpoint: string; p256dh: string | null; auth: string | null };

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
let cfg: Record<string, string> | null = null, cfgAt = 0;
async function config() {
  if (!cfg || Date.now() - cfgAt > 600_000) { // re-read every 10 min, so new keys (e.g. Firebase) apply without a redeploy
    cfgAt = Date.now();
    const { data, error } = await sb.rpc("push_config");
    if (error) throw error;
    cfg = (data ?? {}) as Record<string, string>;
    if (cfg.push_vapid_public && cfg.push_vapid_private) {
      const contact = cfg.push_contact || "https://kindred-sl.netlify.app";
      webpush.setVapidDetails(contact.startsWith("http") ? contact : `mailto:${contact}`, cfg.push_vapid_public, cfg.push_vapid_private);
    }
  }
  return cfg;
}

// Firebase: exchange the service account for a short-lived access token (cached until just before it expires)
let fcm: { token: string; exp: number; project: string } | null = null;
async function fcmAuth(saJson: string) {
  if (fcm && fcm.exp > Date.now() + 60_000) return fcm;
  const sa = JSON.parse(saJson);
  const now = Math.floor(Date.now() / 1000);
  const jwt = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email).setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now).setExpirationTime(now + 3600)
    .sign(await importPKCS8(sa.private_key, "RS256"));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error("Firebase auth failed: " + JSON.stringify(j));
  fcm = { token: j.access_token, exp: Date.now() + (j.expires_in ?? 3600) * 1000, project: sa.project_id };
  return fcm;
}

const isCall = (a: Alert) => a.kind === "call";

async function sendWeb(d: Device, a: Alert): Promise<boolean> {
  try {
    await webpush.sendNotification(
      { endpoint: d.endpoint, keys: { p256dh: d.p256dh!, auth: d.auth! } },
      JSON.stringify({ title: a.title, body: a.body, link: a.link, tag: a.tag, kind: a.kind }),
      { TTL: isCall(a) ? 45 : 86400, urgency: "high" },
    );
    return true;
  } catch (e) {
    const code = (e as { statusCode?: number }).statusCode;
    return !(code === 404 || code === 410); // gone: forget the device
  }
}

async function sendFcm(d: Device, a: Alert, saJson: string): Promise<boolean> {
  const f = await fcmAuth(saJson);
  const r = await fetch(`https://fcm.googleapis.com/v1/projects/${f.project}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${f.token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token: d.endpoint,
        notification: { title: a.title, body: a.body },
        data: { link: a.link, tag: a.tag, kind: a.kind, match_id: a.match_id ?? "" },
        android: {
          priority: "high",
          ttl: isCall(a) ? "45s" : "86400s",
          notification: { channel_id: isCall(a) ? "calls" : "activity", tag: a.tag, icon: "ic_stat_kindred", color: "#EC3B63", sound: "default" },
        },
      },
    }),
  });
  if (r.ok) return true;
  const t = await r.text();
  return !(r.status === 404 || t.includes("UNREGISTERED") || t.includes("INVALID_ARGUMENT"));
}

Deno.serve(async (req) => {
  const c = await config();
  if (!c.push_hook_secret || req.headers.get("x-push-secret") !== c.push_hook_secret) return new Response("forbidden", { status: 403 });
  const a = (await req.json()) as Alert;
  const { data: devices, error } = await sb.from("push_devices").select("id,kind,endpoint,p256dh,auth").eq("user_id", a.to);
  if (error) return new Response(error.message, { status: 500 });
  const gone: string[] = [];
  let sent = 0;
  await Promise.all((devices as Device[] ?? []).map(async (d) => {
    let ok = true;
    if (d.kind === "web" && c.push_vapid_private && d.p256dh && d.auth) ok = await sendWeb(d, a);
    else if (d.kind === "fcm" && c.push_fcm_service_account) ok = await sendFcm(d, a, c.push_fcm_service_account).catch(() => true);
    else return;
    if (ok) sent++; else gone.push(d.id);
  }));
  if (gone.length) await sb.from("push_devices").delete().in("id", gone);
  return new Response(JSON.stringify({ sent, removed: gone.length }), { headers: { "Content-Type": "application/json" } });
});
