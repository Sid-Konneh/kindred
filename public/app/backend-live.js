"use strict";
/* ============ live backend (Supabase) ============
   Same interface as backend-demo.js. Everything sensitive (matching, feed, deleting an
   account) runs in database functions defined in supabase/migrations, under row level security. */
window.KindredLive = function (cfg) {
  const sb = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: "pkce" },
  });
  const home = () => location.origin + location.pathname;
  const must = ({ data, error }) => { if (error) throw error; return data; };
  let uidCache = null;
  const mediaCache = new Map();
  sb.auth.onAuthStateChange((_e, s) => { uidCache = s?.user?.id || null; });
  const uid = () => uidCache || (() => { throw new Error("Please sign in again."); })();

  return {
    mode: "live",
    onAuth(cb) { const { data } = sb.auth.onAuthStateChange((e, s) => cb(e, s)); return () => data.subscription.unsubscribe(); },
    async getSession() { const s = must(await sb.auth.getSession()).session; uidCache = s?.user?.id || null; return s; },
    async signUp({ name, email, password, birthdate }) {
      const data = must(await sb.auth.signUp({ email, password, options: { emailRedirectTo: home(), data: { name, birthdate } } }));
      // With email confirmation on, Supabase hides "already registered" by returning a user with no identities.
      if (data.user && Array.isArray(data.user.identities) && data.user.identities.length === 0) throw new Error("User already registered");
      return { needsVerification: !data.session };
    },
    async signIn({ email, password }) { must(await sb.auth.signInWithPassword({ email, password })); },
    async resendSignup(email) { must(await sb.auth.resend({ type: "signup", email, options: { emailRedirectTo: home() } })); },
    async sendPasswordReset(email) { must(await sb.auth.resetPasswordForEmail(email, { redirectTo: home() + "#/reset" })); },
    canReset() { return !!uidCache; },
    async updatePassword(password) { must(await sb.auth.updateUser({ password })); },
    async signOut() { await sb.auth.signOut(); },

    async getMyProfile() {
      const p = must(await sb.from("profiles").select("*").eq("id", uid()).single());
      return { ...p, age: p.birthdate ? ageFrom(p.birthdate) : null };
    },
    async saveProfile(patch) {
      const p = must(await sb.from("profiles").update(patch).eq("id", uid()).select("*").single());
      return { ...p, age: p.birthdate ? ageFrom(p.birthdate) : null };
    },
    async uploadPhoto(blob) {
      const path = `${uid()}/${crypto.randomUUID()}.jpg`;
      must(await sb.storage.from("photos").upload(path, blob, { contentType: "image/jpeg", cacheControl: "31536000", upsert: false }));
      return sb.storage.from("photos").getPublicUrl(path).data.publicUrl;
    },
    async touch() { if (uidCache) await sb.from("profiles").update({ last_active: new Date().toISOString() }).eq("id", uidCache); },
    async registerDevice(d) {
      await sb.rpc("register_device", { p_key: d.key, p_platform: d.platform, p_os: d.os, p_browser: d.browser, p_model: d.model, p_app_version: d.app_version, p_new_sign_in: d.new_sign_in });
    },

    async getFeed({ city, recycle } = {}) { return must(await sb.rpc("discover_feed", { p_limit: 20, p_city: city || null, p_recycle: !!recycle })) || []; },
    async swipe(targetId, action) { return must(await sb.rpc("swipe", { p_target: targetId, p_action: action })); },
    async getMatches() {
      const rows = must(await sb.rpc("my_matches")) || [];
      return rows.map(r => ({ id: r.match_id, created_at: r.created_at, last_message_at: r.last_message_at, last_body: r.last_body, last_sender: r.last_sender, unread: r.unread, other: r.other }));
    },
    async getMessages(matchId) {
      return must(await sb.from("messages").select("*").eq("match_id", matchId).order("created_at", { ascending: true }).limit(300));
    },
    async sendMessage(matchId, body) {
      return must(await sb.from("messages").insert({ match_id: matchId, sender: uid(), body }).select("*").single());
    },
    // Photo or video: upload to the match's private folder, then post a message pointing at it.
    async sendMedia(matchId, blob, kind, ext, meta) {
      const path = `${matchId}/${crypto.randomUUID()}.${ext}`;
      must(await sb.storage.from("chat-media").upload(path, blob, { contentType: blob.type || (kind === "image" ? "image/jpeg" : "video/mp4"), upsert: false }));
      return must(await sb.from("messages").insert({ match_id: matchId, sender: uid(), body: "", kind, media_path: path, media_meta: meta || null }).select("*").single());
    },
    // Short-lived private link to a chat photo/video (cached for most of its lifetime)
    async mediaUrl(path) {
      const hit = mediaCache.get(path);
      if (hit && hit.until > Date.now()) return hit.url;
      const { signedUrl } = must(await sb.storage.from("chat-media").createSignedUrl(path, 3600));
      mediaCache.set(path, { url: signedUrl, until: Date.now() + 50 * 60 * 1000 });
      return signedUrl;
    },
    // Calls: WebRTC offer/answer travel through the calls table (see migration 014)
    async startCall(matchId, video, offer) { return must(await sb.rpc("start_call", { p_match: matchId, p_video: !!video, p_offer: offer })); },
    async updateCall(id, status, answer) { return must(await sb.rpc("update_call", { p_call: id, p_status: status, p_answer: answer || null })); },
    async ringingCalls() { return must(await sb.rpc("my_ringing_calls")) || []; },
    async getCalls(matchId) {
      return must(await sb.from("calls").select("id,match_id,caller,callee,video,status,created_at,answered_at,ended_at")
        .eq("match_id", matchId).order("created_at", { ascending: false }).limit(40)) || [];
    },
    onCalls(cb) {
      const me = uid(), h = p => cb(p.new);
      const ch = sb.channel("calls:" + me)
        .on("postgres_changes", { event: "INSERT", schema: "public", table: "calls", filter: `callee=eq.${me}` }, h)
        .on("postgres_changes", { event: "UPDATE", schema: "public", table: "calls", filter: `callee=eq.${me}` }, h)
        .on("postgres_changes", { event: "UPDATE", schema: "public", table: "calls", filter: `caller=eq.${me}` }, h)
        .subscribe();
      return () => sb.removeChannel(ch);
    },
    async markRead(matchId) { await sb.rpc("mark_read", { p_match: matchId }); },
    subscribe(matchId, cb) {
      const ch = sb.channel("chat:" + matchId)
        .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `match_id=eq.${matchId}` }, p => cb({ type: "message", message: p.new }))
        .on("postgres_changes", { event: "UPDATE", schema: "public", table: "messages", filter: `match_id=eq.${matchId}` }, () => cb({ type: "read" }))
        .subscribe();
      return () => sb.removeChannel(ch);
    },
    async unmatch(matchId) { must(await sb.rpc("unmatch", { p_match: matchId })); cleanupMedia(); },
    async block(userId) { must(await sb.from("blocks").insert({ blocker: uid(), blocked: userId })); },
    async report(userId, reason, details) {
      must(await sb.from("reports").insert({ reporter: uid(), reported: userId, reason, details: details || null }));
      await this.block(userId).catch(() => {});
    },
    async deleteAccount() {
      const me = uid();
      const files = must(await sb.storage.from("photos").list(me, { limit: 100 })) || [];
      if (files.length) must(await sb.storage.from("photos").remove(files.map(f => `${me}/${f.name}`)));
      const sent = must(await sb.from("messages").select("media_path").eq("sender", me).not("media_path", "is", null).limit(1000)) || [];
      if (sent.length) await sb.storage.from("chat-media").remove(sent.map(x => x.media_path)).catch(() => {});
      must(await sb.rpc("delete_my_account"));
      await cleanupMedia();
      await sb.auth.signOut();
    },
  };

  // Chat files of removed matches are deleted by an edge function (storage can't be cleared from SQL)
  function cleanupMedia() { return sb.functions.invoke("chat-media-cleanup", { body: {} }).catch(() => {}); }

  function ageFrom(bd) {
    const b = new Date(bd + "T00:00:00"), n = new Date();
    let a = n.getFullYear() - b.getFullYear();
    const m = n.getMonth() - b.getMonth();
    if (m < 0 || (m === 0 && n.getDate() < b.getDate())) a--;
    return a;
  }
};
