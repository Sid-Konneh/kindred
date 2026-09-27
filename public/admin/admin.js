"use strict";
/* Kindred admin console. Every action goes through admin_* database functions, which check the
   caller's role on the server; this page only decides what to show. */
(() => {
  const CFG = window.KINDRED_CONFIG || {};
  const sb = window.supabase.createClient(CFG.SUPABASE_URL, CFG.SUPABASE_KEY, { auth: { persistSession: true, autoRefreshToken: true } });
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const root = $("#root"), drawer = $("#drawer"), toastEl = $("#toast");
  const nf = new Intl.NumberFormat("en-GB");
  const num = n => nf.format(Number(n) || 0);
  const LOOKING = { relationship: "A relationship", marriage: "Marriage", friendship: "New friends", not_sure: "Still figuring it out" };
  const ACTIONS = {
    suspend: "Suspended member", unsuspend: "Lifted suspension", remove_photo: "Removed a photo", delete_member: "Deleted member",
    mark_test: "Marked as test account", unmark_test: "Unmarked test account", admin_add: "Added to admin team", admin_remove: "Removed from admin team",
    report_reviewed: "Closed report (no action)", report_actioned: "Closed report (action taken)", report_open: "Reopened report",
    flag_dismissed: "Dismissed scam alert", flag_actioned: "Closed scam alert (action taken)", flag_open: "Reopened scam alert",
    note_add: "Added a private note", note_delete: "Deleted a private note", export_members: "Exported members (CSV)", export_reports: "Exported reports (CSV)",
  };
  const METRICS = [["signups", "New members", "new"], ["matches", "Matches", "matches"], ["messages", "Messages", "messages"], ["likes", "Likes", "likes"], ["reports", "Reports", "reports"], ["flags", "Scam alerts", "alerts"]];
  const state = { me: null, tab: "overview", reportStatus: "open", memberFilter: "all", memberSearch: "", memberOffset: 0, openReports: 0, openFlags: 0, flagStatus: "open", metric: "signups", days: 30 };

  const ICON = {
    overview: '<path d="M3 3v18h18"/><path d="M7 15l4-4 3 3 5-6"/>',
    reports: '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1zM4 22v-7"/>',
    members: '<circle cx="9" cy="8" r="4"/><path d="M2 21a7 7 0 0 1 14 0M17 11a3 3 0 1 0 0-6M22 21a6 6 0 0 0-5-5.9"/>',
    team: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/>',
    activity: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    flags: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
    insights: '<path d="M12 20V10M18 20V4M6 20v-4"/>',
    photos: '<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21"/>',
  };
  const svgI = d => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  const MARK = '<svg width="28" height="28" viewBox="0 0 100 100" fill="none" stroke="url(#kg)" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"><defs><linearGradient id="kg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F2436B"/><stop offset="1" stop-color="#FF8A3D"/></linearGradient></defs><path d="M43 27.5C36 20.5 24.5 21.5 18 32c-8 14 2 32 32 52"/><path d="M57 27.5C64 20.5 75.5 21.5 82 32c8 14-2 32-32 52" stroke-opacity=".82"/><circle cx="50" cy="16" r="5" fill="#F2436B" stroke="none"/></svg>';

  function when(iso) {
    if (!iso) return "—";
    const d = new Date(iso), s = (Date.now() - d) / 1000;
    if (s < 60) return "just now";
    if (s < 3600) return Math.floor(s / 60) + " min ago";
    if (s < 86400) return Math.floor(s / 3600) + " h ago";
    if (s < 86400 * 7) return Math.floor(s / 86400) + " d ago";
    return d.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
  }
  const fullDate = iso => iso ? new Date(iso).toLocaleString("en-GB", { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";
  function friendly(e) {
    const m = e?.message || String(e);
    if (/invalid login/i.test(m)) return "Email or password is incorrect.";
    if (/admins only/i.test(m)) return "Your account doesn't have admin access.";
    if (/failed to fetch|network/i.test(m)) return "Can't reach Kindred. Check your connection.";
    return m;
  }
  let tt;
  function toast(m) { toastEl.textContent = m; toastEl.classList.add("show"); clearTimeout(tt); tt = setTimeout(() => toastEl.classList.remove("show"), 3200); }
  async function rpc(name, args) { const { data, error } = await sb.rpc(name, args); if (error) throw error; return data; }
  function avatar(p, size = 36) {
    const url = p?.photo || p?.photos?.[0];
    if (url) return `<img class="av" style="width:${size}px;height:${size}px" src="${esc(url)}" alt="" loading="lazy">`;
    const hues = ["#EC3B63", "#7B5CFA", "#0E9F8E", "#F59E0B", "#DB2777", "#2F6FEB"];
    let h = 0; for (const c of String(p?.id || p?.name || "?")) h = (h * 31 + c.charCodeAt(0)) >>> 0;
    return `<span class="av" style="width:${size}px;height:${size}px;background:${hues[h % hues.length]}">${esc((p?.name || "?")[0].toUpperCase())}</span>`;
  }
  const storagePath = url => { const i = String(url).indexOf("/object/public/photos/"); return i < 0 ? null : decodeURIComponent(url.slice(i + "/object/public/photos/".length).split("?")[0]); };

  /* ---------- dialogs ---------- */
  function ask({ title, text = "", input = null, confirm = "Confirm", danger = false, select = null }) {
    return new Promise(resolve => {
      const d = document.createElement("dialog");
      d.innerHTML = `<form method="dialog"><h3>${esc(title)}</h3>${text ? `<p class="muted" style="margin:0">${text}</p>` : ""}
        ${select ? `<label class="f">${esc(select.label)}<select name="sel">${select.options.map(([v, l]) => `<option value="${esc(v)}">${esc(l)}</option>`).join("")}</select></label>` : ""}
        ${input ? `<label class="f">${esc(input.label)}<${input.multiline ? "textarea rows=3" : "input"} name="val" ${input.placeholder ? `placeholder="${esc(input.placeholder)}"` : ""} ${input.type ? `type="${input.type}"` : ""} autocomplete="off">${input.multiline ? "</textarea>" : ""}</label>` : ""}
        <p class="err" id="derr"></p>
        <div class="row"><button class="btn" value="cancel" type="button" data-x>Cancel</button><button class="btn ${danger ? "danger" : "primary"}" value="ok">${esc(confirm)}</button></div></form>`;
      document.body.append(d);
      const close = v => { d.close(); d.remove(); resolve(v); };
      $("[data-x]", d).onclick = () => close(null);
      d.addEventListener("cancel", e => { e.preventDefault(); close(null); });
      $("form", d).onsubmit = e => {
        e.preventDefault();
        const val = d.querySelector("[name=val]")?.value?.trim() ?? true, sel = d.querySelector("[name=sel]")?.value;
        if (input?.required && !val) { $("#derr", d).textContent = input.required; return; }
        if (input?.mustEqual && val !== input.mustEqual) { $("#derr", d).textContent = `Type ${input.mustEqual} to confirm.`; return; }
        close(select ? { val, sel } : val);
      };
      d.showModal();
      (d.querySelector("[name=val]") || d.querySelector("[name=sel]"))?.focus();
    });
  }

  /* ---------- sign in ---------- */
  function renderSignIn(msg = "") {
    root.innerHTML = `<div class="auth"><form class="box" id="signin">
      <div class="brand">${MARK}kindred <small>Admin</small></div>
      <h1>Admin sign in</h1><p class="muted" style="margin:0">Use your Kindred account. Only people on the admin team can open this console.</p>
      <label class="f">Email<input name="email" type="email" autocomplete="username" required></label>
      <label class="f">Password<input name="password" type="password" autocomplete="current-password" required></label>
      <p class="err">${esc(msg)}</p>
      <button class="btn primary block" type="submit">Sign in</button></form></div>`;
    $("#signin").onsubmit = async e => {
      e.preventDefault();
      const f = e.target, btn = $("button", f);
      btn.disabled = true; btn.innerHTML = '<span class="spin" style="width:18px;height:18px;border-width:2px"></span>';
      const { error } = await sb.auth.signInWithPassword({ email: f.email.value.trim(), password: f.password.value });
      if (error) { btn.disabled = false; btn.textContent = "Sign in"; $(".err", f).textContent = friendly(error); return; }
      boot();
    };
  }

  async function boot() {
    const { data: { session } } = await sb.auth.getSession();
    if (!session) return renderSignIn();
    let me;
    try { me = await rpc("admin_me"); } catch (e) { return renderSignIn(friendly(e)); }
    if (!me) {
      root.innerHTML = `<div class="auth"><div class="box"><div class="brand">${MARK}kindred <small>Admin</small></div>
        <h1>No admin access</h1><p class="muted">You're signed in as <b>${esc(session.user.email)}</b>, but this account isn't on the Kindred admin team. Ask a super admin to add you.</p>
        <button class="btn block" id="out">Sign out</button></div></div>`;
      $("#out").onclick = async () => { await sb.auth.signOut(); renderSignIn(); };
      return;
    }
    state.me = me;
    const t = location.hash.slice(1);
    state.tab = ["overview", "insights", "reports", "flags", "photos", "members", "team", "activity"].includes(t) ? t : "overview";
    renderShell();
  }

  /* ---------- shell ---------- */
  function renderShell() {
    const tabs = [["overview", "Overview"], ["insights", "Insights"], ["reports", "Reports"], ["flags", "Scam alerts"], ["photos", "Photo review"], ["members", "Members"], ["team", "Admin team"], ["activity", "Activity log"]];
    root.innerHTML = `<div class="shell"><aside class="side">
      <div class="brand">${MARK}kindred <small>Admin</small></div>
      <nav class="nav">${tabs.map(([k, l]) => `<a href="#${k}" data-tab="${k}" class="${state.tab === k ? "on" : ""}">${svgI(ICON[k === "team" ? "team" : k])}${l}${k === "reports" ? `<span class="count" id="rc" ${state.openReports ? "" : "hidden"}>${state.openReports}</span>` : ""}${k === "flags" ? `<span class="count" id="fc" ${state.openFlags ? "" : "hidden"}>${state.openFlags}</span>` : ""}</a>`).join("")}</nav>
      <div class="me"><b>${esc(state.me.name || state.me.email)}</b><span class="muted">${esc(state.me.email)}</span><div style="margin:8px 0"><span class="role ${state.me.role}">${state.me.role === "super_admin" ? "Super admin" : "Moderator"}</span></div>
        <button class="btn sm" id="out">Sign out</button> <a class="btn sm ghost" href="../app/">Open app</a></div>
      </aside><main id="main"></main></div>`;
    $$("[data-tab]").forEach(a => a.onclick = e => { e.preventDefault(); go(a.dataset.tab); });
    $("#out").onclick = async () => { await sb.auth.signOut(); renderSignIn(); };
    go(state.tab);
    refreshReportCount();
  }
  function go(tab) {
    state.tab = tab;
    history.replaceState(null, "", "#" + tab);
    $$("[data-tab]").forEach(a => a.classList.toggle("on", a.dataset.tab === tab));
    ({ overview: viewOverview, insights: viewInsights, reports: viewReports, flags: viewFlags, photos: viewPhotos, members: viewMembers, team: viewTeam, activity: viewActivity })[tab]();
  }
  async function refreshReportCount() {
    try { const s = await rpc("admin_reports", { p_status: "open", p_limit: 500 }); state.openReports = s.length; const el = $("#rc"); if (el) { el.textContent = s.length; el.hidden = !s.length; } } catch { /* ignore */ }
    try { const f = await rpc("admin_flags", { p_status: "open", p_limit: 500 }); state.openFlags = f.length; const el = $("#fc"); if (el) { el.textContent = f.length; el.hidden = !f.length; } } catch { /* ignore */ }
  }
  const main = () => $("#main");
  const loading = () => { main().innerHTML = '<div class="boot" style="min-height:40vh"><span class="spin"></span></div>'; };
  const failed = e => { main().innerHTML = `<div class="card empty">Couldn't load this page: ${esc(friendly(e))}</div>`; };

  /* ---------- overview ---------- */
  async function viewOverview() {
    loading();
    let s;
    try { s = await rpc("admin_stats"); } catch (e) { return failed(e); }
    const likeRate = s.likes + s.passes ? Math.round((100 * s.likes) / (s.likes + s.passes)) : 0;
    const tile = (label, n, note, alert) => `<div class="card tile ${alert ? "alert" : ""}"><div class="label">${label}</div><div class="num">${num(n)}</div>${note ? `<div class="note">${note}</div>` : ""}</div>`;
    main().innerHTML = `<div class="head"><div><h1>Overview</h1><p>Real members only. ${num(s.test_accounts)} test and reviewer account${s.test_accounts === 1 ? " is" : "s are"} left out.</p></div>
        <button class="btn sm" id="rf">Refresh</button></div>
      <div class="tiles">
        ${tile("Members", s.members, `${num(s.onboarded)} finished their profile`)}
        ${tile("New this week", s.new_7d, `${num(s.new_30d)} in the last 30 days`)}
        ${tile("Active today", s.active_24h, `<span id="online"></span>${num(s.active_7d)} active this week`)}
        ${tile("Matches", s.matches, `${num(s.matches_7d)} this week`)}
        ${tile("Messages", s.messages, `${num(s.messages_7d)} this week`)}
        <div class="card tile" id="t-calls"><div class="label">Calls</div><div class="num">…</div></div>
        <div class="card tile" id="t-media"><div class="label">Photos &amp; videos sent</div><div class="num">…</div></div>
        ${tile("Open reports", s.reports_open, `${num(s.reports_total)} report${s.reports_total === 1 ? "" : "s"} in total`, s.reports_open > 0)}
      </div>
      <div class="grid2">
        <div class="card"><div class="head" style="margin:0 0 8px;align-items:flex-start"><div><h2 id="act-title">Activity per day</h2><p class="sub" id="act-sub" style="margin:0"></p></div>
            <div class="seg" id="range">${[[30, "30 days"], [90, "90 days"]].map(([d, l]) => `<button data-days="${d}" class="${state.days === d ? "on" : ""}">${l}</button>`).join("")}</div></div>
          <div class="seg" id="metric" style="margin-bottom:12px">${METRICS.map(([k, l]) => `<button data-metric="${k}" class="${state.metric === k ? "on" : ""}">${l}</button>`).join("")}</div>
          <div id="signups"><div class="boot" style="min-height:220px"><span class="spin"></span></div></div></div>
        <div class="card"><h2>Sign-up funnel</h2><p class="sub">How far real members get after joining</p><div class="hbars" id="funnel"><div class="boot" style="min-height:160px"><span class="spin"></span></div></div>
          <p class="sub" style="margin:16px 0 0">Like rate <b style="color:var(--text)">${likeRate}%</b> of ${num(s.likes + s.passes)} swipes · Suspended members <b style="color:var(--text)">${num(s.suspended)}</b></p></div>
      </div>
      <div class="grid3">
        <div class="card"><h2>Top towns</h2><p class="sub">Where members live</p><div class="hbars">${hbarRows((s.top_cities || []).map(c => [c.label, c.count]))}</div></div>
        <div class="card"><h2>Age groups</h2><p class="sub">Members with a date of birth</p><div class="hbars">${hbarRows((s.age_groups || []).map(c => [c.label, c.count]))}</div></div>
        <div class="card"><h2>Looking for</h2><p class="sub">Women ${num(s.women)} · Men ${num(s.men)}</p><div class="hbars">${hbarRows((s.looking_for || []).map(c => [LOOKING[c.label] || c.label, c.count]))}</div></div>
      </div>`;
    $("#rf").onclick = viewOverview;
    rpc("admin_call_stats").then(c => {
      const t = $("#t-calls"), m = $("#t-media"); if (!t || !m) return;
      const avg = c.avg_seconds ? `${Math.floor(c.avg_seconds / 60)}:${String(c.avg_seconds % 60).padStart(2, "0")} average` : "";
      t.innerHTML = `<div class="label">Calls</div><div class="num">${num(c.calls)}</div><div class="note">${num(c.calls_7d)} this week${c.calls ? ` · ${c.answered_rate}% answered · ${c.video_share}% video` : ""}${avg ? " · " + avg : ""}${c.failed ? ` · ${num(c.failed)} couldn't connect` : ""}</div>`;
      m.innerHTML = `<div class="label">Photos &amp; videos sent</div><div class="num">${num(c.media)}</div><div class="note">${num(c.media_7d)} this week · ${num(c.videos)} video${c.videos === 1 ? "" : "s"}</div>`;
    }).catch(() => {});
    rpc("admin_online").then(n => { const el = $("#online"); if (el) el.innerHTML = `<b style="color:var(--good)">● ${num(n)} online now</b><br>`; }).catch(() => {});
    $$("#metric [data-metric]").forEach(b => b.onclick = () => { state.metric = b.dataset.metric; $$("#metric button").forEach(x => x.classList.toggle("on", x === b)); drawActivity(); });
    $$("#range [data-days]").forEach(b => b.onclick = () => { state.days = +b.dataset.days; $$("#range button").forEach(x => x.classList.toggle("on", x === b)); loadActivity(); });
    loadActivity();
    rpc("admin_funnel").then(steps => {
      const first = steps[0]?.count || 0;
      $("#funnel").innerHTML = steps.map(st => `<div class="hb" title="${esc(st.label)}: ${num(st.count)}"><span class="k">${esc(st.label)}</span><span class="track"><span class="fill" style="width:${first && st.count ? Math.max(2, (100 * st.count) / first) : 0}%"></span></span><span class="v">${num(st.count)}</span></div>`).join("")
        + (first ? `<p class="sub" style="margin:10px 0 0">${Math.round((100 * (steps[5]?.count || 0)) / first)}% of members have sent a message.</p>` : "");
    }).catch(e => { $("#funnel").innerHTML = `<p class="empty">${esc(friendly(e))}</p>`; });
  }
  let activity = [];
  async function loadActivity() {
    const el = $("#signups"); if (!el) return;
    el.innerHTML = '<div class="boot" style="min-height:220px"><span class="spin"></span></div>';
    try { activity = await rpc("admin_activity", { p_days: state.days }); drawActivity(); }
    catch (e) { el.innerHTML = `<p class="empty">${esc(friendly(e))}</p>`; }
  }
  function drawActivity() {
    const el = $("#signups"); if (!el) return;
    const [, label, unit] = METRICS.find(m => m[0] === state.metric);
    const total = activity.reduce((n, d) => n + d[state.metric], 0);
    $("#act-title").textContent = `${label} per day`;
    $("#act-sub").textContent = `Last ${state.days} days · ${num(total)} in total`;
    barChart(el, activity.map(d => ({ label: d.day, value: d[state.metric] })), unit);
  }
  function hbarRows(rows, keepZero) {
    rows = rows.filter(([, v]) => keepZero || v > 0);
    if (!rows.length) return '<p class="empty" style="padding:10px">No data yet</p>';
    const max = Math.max(...rows.map(r => r[1]), 1);
    return rows.map(([k, v]) => `<div class="hb" title="${esc(k)}: ${num(v)}"><span class="k">${esc(k)}</span><span class="track"><span class="fill" style="width:${v ? Math.max(2, (100 * v) / max) : 0}%"></span></span><span class="v">${num(v)}</span></div>`).join("");
  }
  function barChart(el, data, unit = "new") {
    const narrow = el.clientWidth < 520;
    const W = narrow ? 360 : 640, H = narrow ? 240 : 220, pad = { l: 30, r: 6, t: 10, b: 26 };
    const max = Math.max(1, ...data.map(d => d.value));
    const step = Math.max(1, Math.ceil(max / 4));
    const top = step * Math.ceil(max / step);
    const iw = W - pad.l - pad.r, ih = H - pad.t - pad.b, bw = iw / data.length;
    const y = v => pad.t + ih - (ih * v) / top;
    let g = "";
    for (let v = 0; v <= top; v += step) g += `<line class="gl" x1="${pad.l}" x2="${W - pad.r}" y1="${y(v)}" y2="${y(v)}"/><text class="ax" x="${pad.l - 8}" y="${y(v) + 4}" text-anchor="end">${v}</text>`;
    const fmt = d => new Date(d + "T00:00:00").toLocaleDateString("en-GB", { day: "numeric", month: "short" });
    let bars = "";
    data.forEach((d, i) => {
      const x = pad.l + i * bw + 1, w = Math.max(2, bw - 2), yy = y(d.value), h = pad.t + ih - yy;
      bars += `<rect class="hit" x="${pad.l + i * bw}" y="${pad.t}" width="${bw}" height="${ih}" data-i="${i}"/>`;
      if (d.value > 0) bars += `<path class="bar" data-b="${i}" d="M${x},${pad.t + ih} V${yy + Math.min(4, h)} q0,-${Math.min(4, h)} ${Math.min(4, w / 2)},-${Math.min(4, h)} H${x + w - Math.min(4, w / 2)} q${Math.min(4, w / 2)},0 ${Math.min(4, w / 2)},${Math.min(4, h)} V${pad.t + ih} Z"/>`;
      if (i === 0 || i === data.length - 1 || (i % Math.max(narrow ? 14 : 7, Math.ceil(data.length / (narrow ? 3 : 5))) === 0 && i < data.length - Math.ceil(data.length / (narrow ? 5 : 8)))) bars += `<text class="ax" x="${pad.l + i * bw + bw / 2}" y="${H - 6}" text-anchor="middle">${fmt(d.label)}</text>`;
    });
    el.innerHTML = `<div class="chart"><svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(unit)} per day for the last ${data.length} days">${g}${bars}</svg><div class="tip"></div></div>
      <details class="tv"><summary>Show as table</summary><table><thead><tr><th>Day</th><th>${esc(unit)}</th></tr></thead><tbody>${data.map(d => `<tr><td>${fmt(d.label)}</td><td>${d.value}</td></tr>`).join("")}</tbody></table></details>`;
    const tip = $(".tip", el), svg = $("svg", el);
    $$(".hit", el).forEach(h => {
      h.addEventListener("mouseenter", () => {
        const i = +h.dataset.i, d = data[i], r = svg.getBoundingClientRect(), sx = r.width / W;
        $$(".bar", el).forEach(b => b.classList.toggle("hl", b.dataset.b === String(i)));
        tip.innerHTML = `${fmt(d.label)} · <b>${d.value}</b> ${esc(unit)}`;
        tip.style.left = (pad.l + i * bw + bw / 2) * sx + "px"; tip.style.top = y(d.value) * sx + "px"; tip.classList.add("on");
      });
      h.addEventListener("mouseleave", () => { tip.classList.remove("on"); $$(".bar", el).forEach(b => b.classList.remove("hl")); });
    });
  }

  /* ---------- reports ---------- */
  async function viewReports() {
    const tabs = [["open", "Open"], ["reviewed", "Closed, no action"], ["actioned", "Action taken"], ["all", "All"]];
    main().innerHTML = `<div class="head"><div><h1>Reports</h1><p>Handle the oldest open reports first. Evidence is the chat as it was when the report was sent.</p></div>${exportBtn("admin_export_reports", "kindred-reports", "Export CSV")}</div>
      <div class="toolbar"><div class="seg">${tabs.map(([k, l]) => `<button data-s="${k}" class="${state.reportStatus === k ? "on" : ""}">${l}</button>`).join("")}</div></div><div id="rl"></div>`;
    $$("[data-s]").forEach(b => b.onclick = () => { state.reportStatus = b.dataset.s; viewReports(); });
    wireExport();
    const list = $("#rl");
    list.innerHTML = '<div class="boot" style="min-height:30vh"><span class="spin"></span></div>';
    let rows;
    try { rows = await rpc("admin_reports", { p_status: state.reportStatus, p_limit: 200 }); } catch (e) { list.innerHTML = `<div class="card empty">${esc(friendly(e))}</div>`; return; }
    if (state.reportStatus === "open") rows.reverse();
    if (!rows.length) { list.innerHTML = `<div class="card empty">${state.reportStatus === "open" ? "No open reports. Nice." : "Nothing here yet."}</div>`; return; }
    list.innerHTML = rows.map(r => {
      const ev = r.evidence || {}, msgs = ev.messages || [], rep = r.reported || {};
      const status = { open: '<span class="badge warn">Open</span>', reviewed: '<span class="badge">Closed, no action</span>', actioned: '<span class="badge good">Action taken</span>' }[r.status];
      return `<div class="card report" data-id="${r.id}">
        <div class="top"><div><div class="reason">${esc(r.reason)}</div>
          <div class="who">${r.reporter ? `<a data-member="${r.reporter.id}">${esc(r.reporter.name)}</a>` : "A deleted member"} reported <a data-member="${rep.id}">${esc(rep.name)}</a>
            ${rep.reports_against > 1 ? `<span class="badge bad">${rep.reports_against} reports against them</span>` : ""}${rep.banned_at ? '<span class="badge bad">Suspended</span>' : ""} · ${when(r.created_at)}</div></div>
          <div>${status}</div></div>
        ${r.details ? `<div class="details">“${esc(r.details)}”</div>` : ""}
        <div class="evidence"><h4>Evidence</h4>
          ${ev.profile?.photos?.length ? `<div class="thumbs" style="margin-bottom:10px">${ev.profile.photos.map(u => `<div class="thumb"><img src="${esc(u)}" alt="" loading="lazy"></div>`).join("")}</div>` : ""}
          ${ev.profile?.bio ? `<p style="margin:0 0 10px;font-size:14px"><b>Bio:</b> ${esc(ev.profile.bio)}</p>` : ""}
          ${msgs.length ? `<div class="msgs">${msgs.map(m => `<div class="msg ${m.from}"><small>${m.from === "reported" ? esc(rep.name) : "Reporter"} · ${fullDate(m.at)}</small>${m.media_path ? `<button class="btn sm ev-media" data-path="${esc(m.media_path)}" data-kind="${esc(m.kind)}">${m.kind === "video" ? "🎥 Video" : "📷 Photo"} · Show</button>` : ""}${esc(m.body)}</div>`).join("")}</div>` : '<p class="muted" style="margin:0;font-size:14px">No messages between them.</p>'}
        </div>
        ${r.resolution_note || r.resolved_by ? `<p class="muted" style="font-size:13px;margin:10px 0 0">${r.resolved_by ? `Closed by ${esc(r.resolved_by)} ${when(r.resolved_at)}` : ""}${r.resolution_note ? ` — “${esc(r.resolution_note)}”` : ""}</p>` : ""}
        <div class="actions">
          ${r.status === "open" ? `${rep.banned_at ? "" : `<button class="btn sm danger" data-act="suspend-close">Suspend ${esc(rep.name)} &amp; close</button>`}
             <button class="btn sm" data-act="actioned">Close: action taken</button><button class="btn sm" data-act="reviewed">Close: no action needed</button>`
          : `<button class="btn sm" data-act="open">Reopen</button>`}
          <button class="btn sm ghost" data-member="${rep.id}">View ${esc(rep.name)}</button>
        </div></div>`;
    }).join("");
    $$("[data-member]", list).forEach(a => a.onclick = () => openMember(a.dataset.member));
    // Chat photos/videos are private; admins open them through a short-lived signed link, only when they choose to
    $$(".ev-media", list).forEach(b => b.onclick = async () => {
      b.disabled = true;
      const { data, error } = await sb.storage.from("chat-media").createSignedUrl(b.dataset.path, 600);
      if (error || !data?.signedUrl) { b.textContent = "File no longer available"; return; }
      const u = esc(data.signedUrl);
      b.outerHTML = b.dataset.kind === "video" ? `<video class="ev-file" src="${u}" controls playsinline preload="metadata"></video>` : `<a href="${u}" target="_blank" rel="noopener"><img class="ev-file" src="${u}" alt="Photo sent in chat"></a>`;
    });
    $$(".report [data-act]", list).forEach(b => b.onclick = async () => {
      const card = b.closest(".report"), id = card.dataset.id, r = rows.find(x => x.id === id), act = b.dataset.act;
      try {
        if (act === "suspend-close") {
          const reason = await ask({ title: `Suspend ${r.reported.name}?`, text: "They'll be signed out, can't sign back in, and disappear from every feed and chat. You can lift this later.", input: { label: "Reason (kept in the log)", required: "Give a reason.", multiline: true, placeholder: r.reason }, confirm: "Suspend", danger: true });
          if (!reason) return;
          await rpc("admin_suspend", { p_user: r.reported.id, p_reason: reason });
          await rpc("admin_resolve_report", { p_id: id, p_status: "actioned", p_note: "Suspended: " + reason });
          toast(`${r.reported.name} suspended and report closed`);
        } else if (act === "open") {
          await rpc("admin_resolve_report", { p_id: id, p_status: "open", p_note: null });
          toast("Report reopened");
        } else {
          const note = await ask({ title: act === "actioned" ? "Close: action taken" : "Close: no action needed", input: { label: "Note for the team (optional)", multiline: true }, confirm: "Close report" });
          if (note === null) return;
          await rpc("admin_resolve_report", { p_id: id, p_status: act, p_note: note || null });
          toast("Report closed");
        }
        refreshReportCount(); viewReports();
      } catch (e) { toast(friendly(e)); }
    });
  }

  /* ---------- insights ---------- */
  const SHOW_ME = { everyone: "Everyone", women: "Women", men: "Men" };
  const RELIGION = { muslim: "Muslim", christian: "Christian", other: "Other", prefer_not: "Prefer not to say", not_set: "Not set" };
  const fmtHours = h => h == null ? "—" : h < 1 ? `${Math.round(h * 60)} min` : h < 48 ? `${h} h` : `${Math.round(h / 24)} days`;
  const fmtMins = m => m == null ? "—" : m < 60 ? `${m} min` : `${Math.round(m / 6) / 10} h`;
  const pct = v => v == null ? "—" : `${v}%`;
  async function viewInsights() {
    loading();
    let d;
    try { d = await rpc("admin_insights"); } catch (e) { return failed(e); }
    const e = d.engagement || {}, p = d.profiles || {}, sf = d.safety || {}, ld = d.leaders || {};
    const tile = (label, value, note) => `<div class="card tile"><div class="label">${label}</div><div class="num">${value}</div>${note ? `<div class="note">${note}</div>` : ""}</div>`;
    const leaderList = (rows, unit) => rows.length ? rows.map((r, i) => `<div class="hb" style="grid-template-columns:22px 1fr auto;cursor:pointer" data-member="${r.id}">
        <span class="muted" style="font-weight:800">${i + 1}</span><span class="person" style="min-width:0">${avatar(r, 30)}<span style="min-width:0"><b style="display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(r.name)}</b><span>${esc(r.city || "—")} · joined ${when(r.joined)}</span></span></span>
        <span class="v">${num(r.count)} ${r.count === 1 ? unit.replace(/s$/, "") : unit}</span></div>`).join("") : '<p class="empty" style="padding:10px">No data yet</p>';
    main().innerHTML = `<div class="head"><div><h1>Insights</h1><p>How members use Kindred. Real members only; test and reviewer accounts are left out.</p></div><button class="btn sm" id="rf">Refresh</button></div>
      <div class="tiles">
        ${tile("Match rate", pct(e.match_rate), `of ${num(e.likes)} likes became a match`)}
        ${tile("Matches that chat", pct(e.pct_matches_with_chat), "at least one message sent")}
        ${tile("Two-way chats", pct(e.pct_two_way), "both people replied")}
        ${tile("Messages per chat", e.avg_messages_per_chat ?? "—", "average, in chats that started")}
        ${tile("Time to first match", fmtHours(e.median_hours_to_first_match), "median, after joining")}
        ${tile("Reply time", fmtMins(e.median_reply_minutes), "median gap before a reply")}
      </div>
      <div class="grid2">
        <div class="card"><h2>When members are active</h2><p class="sub">Messages and swipes in the last 30 days, by day and hour (Freetown time)</p><div id="heat"></div></div>
        <div class="card"><h2>Are new members staying?</h2><p class="sub">Members who joined each week, and how many were active in the last 7 days</p><div id="ret"></div></div>
      </div>
      <div class="grid3" style="margin-bottom:16px">
        <div class="card"><h2>Profile quality</h2><p class="sub">Finished profiles only</p>
          <div class="hbars">${[["3+ photos", p.pct_3_photos], ["Wrote a bio", p.pct_bio]].map(([k, v]) => `<div class="hb" title="${k}: ${pct(v)} of profiles"><span class="k">${k}</span><span class="track"><span class="fill" style="width:${v || 0}%"></span></span><span class="v">${pct(v == null ? null : Math.round(v))}</span></div>`).join("")}</div>
          <p class="sub" style="margin:12px 0 4px">Average photos per profile: <b style="color:var(--text)">${p.avg_photos ?? "—"}</b></p>
          <h2 style="margin-top:16px">Who they want to see</h2><div class="hbars" style="margin-top:8px">${hbarRows((p.show_me || []).map(x => [SHOW_ME[x.label] || x.label, x.count]))}</div>
          <h2 style="margin-top:16px">Religion</h2><div class="hbars" style="margin-top:8px">${hbarRows((p.religion || []).map(x => [RELIGION[x.label] || x.label, x.count]))}</div></div>
        <div class="card"><h2>Top interests</h2><p class="sub">Most chosen on profiles</p><div class="hbars">${hbarRows((p.interests || []).map(x => [x.label, x.count]))}</div></div>
        <div class="card"><h2>Languages spoken</h2><p class="sub">Most listed on profiles</p><div class="hbars">${hbarRows((p.languages || []).map(x => [x.label, x.count]))}</div></div>
      </div>
      <div class="grid2">
        <div class="card"><h2>Safety</h2><p class="sub">Reports, scam alerts and blocks</p>
          <div class="counts" style="margin:6px 0 14px"><div><b>${num(sf.open_reports)}</b><span>Open reports</span></div><div><b>${num(sf.open_flags)}</b><span>Open scam alerts</span></div><div><b>${num(sf.blocks_7d)}</b><span>Blocks this week</span></div><div><b>${num(sf.suspended_now)}</b><span>Suspended now</span></div></div>
          <p class="sub" style="margin:0 0 12px">Median time to handle a report: <b style="color:var(--text)">${fmtHours(sf.median_hours_to_resolve)}</b> · Suspensions in the last 30 days: <b style="color:var(--text)">${num(sf.suspensions_30d)}</b> · Blocks all time: <b style="color:var(--text)">${num(sf.blocks)}</b></p>
          <h2 style="font-size:14px">Reports by reason</h2><div class="hbars" style="margin-top:8px">${hbarRows((sf.reports_by_reason || []).map(x => [x.label, x.count]))}</div>
          <h2 style="font-size:14px;margin-top:16px">Scam alerts by type</h2><div class="hbars" style="margin-top:8px">${hbarRows((sf.flags_by_category || []).map(x => [CATEGORY[x.label]?.[0] || x.label, x.count]))}</div></div>
        <div class="card"><h2>Most liked profiles</h2><p class="sub">Very popular brand-new profiles can be fake. Worth a look.</p><div class="hbars">${leaderList(ld.most_liked || [], "likes")}</div>
          <h2 style="margin-top:18px">Most active chatters</h2><p class="sub">Messages sent</p><div class="hbars">${leaderList(ld.most_messages || [], "sent")}</div></div>
      </div>
      <div class="card" style="margin-top:16px" id="devcard"><h2>Devices</h2><p class="sub">What members sign in with. Each member is counted once, by the device they used most recently.</p><div class="boot" style="min-height:120px"><span class="spin"></span></div></div>`;
    $("#rf").onclick = viewInsights;
    $$("[data-member]", main()).forEach(a => a.onclick = () => openMember(a.dataset.member));
    heatmap($("#heat"), d.heatmap || []);
    retention($("#ret"), d.retention || []);
    rpc("admin_device_stats").then(ds => {
      const card = $("#devcard"); if (!card) return;
      const today = (ds.active_24h || []).map(x => `${num(x.count)} ${PLATFORM[x.label] || x.label}`).join(" · ");
      card.innerHTML = `<h2>Devices</h2><p class="sub">What members sign in with. Each member is counted once, by the device they used most recently.</p>
        ${ds.members_with_device ? `<div class="counts" style="margin:6px 0 16px"><div><b>${num(ds.members_with_device)}</b><span>Members with a device</span></div><div><b>${num(ds.devices)}</b><span>Devices in total</span></div><div><b>${num(ds.multi_device)}</b><span>Use 2+ devices</span></div><div><b style="font-size:14px;line-height:1.5">${today || "—"}</b><span>Active in the last 24 h</span></div></div>
        <div class="grid3" style="gap:20px">
          <div><h2 style="font-size:14px">App or website</h2><div class="hbars" style="margin-top:8px">${hbarRows((ds.platform || []).map(x => [PLATFORM[x.label] || x.label, x.count]))}</div>
            <h2 style="font-size:14px;margin-top:16px">Android app versions</h2><div class="hbars" style="margin-top:8px">${hbarRows((ds.app_versions || []).map(x => [x.label, x.count]))}</div></div>
          <div><h2 style="font-size:14px">Operating system</h2><div class="hbars" style="margin-top:8px">${hbarRows((ds.os || []).map(x => [x.label, x.count]))}</div>
            <h2 style="font-size:14px;margin-top:16px">Web browsers</h2><div class="hbars" style="margin-top:8px">${hbarRows((ds.browser || []).map(x => [x.label, x.count]))}</div></div>
          <div><h2 style="font-size:14px">Phone models</h2><div class="hbars" style="margin-top:8px">${hbarRows((ds.models || []).map(x => [x.label, x.count]))}</div></div>
        </div>` : '<p class="empty">No device information yet. It appears as members sign in.</p>'}`;
    }).catch(e => { const card = $("#devcard"); if (card) card.innerHTML = `<h2>Devices</h2><p class="empty">${esc(friendly(e))}</p>`; });
  }
  const PLATFORM = { android_app: "Android app", ios_app: "iPhone app", web: "Website" };
  function heatmap(el, cells) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const grid = Array.from({ length: 7 }, () => Array(24).fill(0));
    cells.forEach(c => { grid[c.dow - 1][c.hour] = c.count; });
    const max = Math.max(0, ...cells.map(c => c.count));
    if (!max) { el.innerHTML = '<p class="empty">No activity in the last 30 days yet.</p>'; return; }
    const steps = [0, .18, .38, .6, .8, 1];
    const shade = v => { if (!v) return "var(--surface-2)"; const k = Math.min(5, Math.max(1, Math.ceil((5 * v) / max))); return `color-mix(in srgb, var(--bar) ${Math.round(steps[k] * 100)}%, var(--surface))`; };
    const hourLabel = h => h === 0 ? "12am" : h < 12 ? `${h}am` : h === 12 ? "12pm" : `${h - 12}pm`;
    el.innerHTML = `<div style="overflow-x:auto"><div style="display:grid;grid-template-columns:34px repeat(24,minmax(14px,1fr));gap:2px;min-width:420px;font-size:11px">
        <span></span>${Array.from({ length: 24 }, (_, h) => `<span class="muted" style="text-align:center">${h % 6 === 0 ? hourLabel(h) : ""}</span>`).join("")}
        ${grid.map((row, i) => `<span class="muted" style="align-self:center">${days[i]}</span>${row.map((v, h) => `<span title="${days[i]} ${hourLabel(h)}–${hourLabel((h + 1) % 24)}: ${v} action${v === 1 ? "" : "s"}" style="aspect-ratio:1;border-radius:3px;background:${shade(v)}"></span>`).join("")}`).join("")}
      </div></div>
      <div style="display:flex;align-items:center;gap:6px;justify-content:flex-end;margin-top:10px;font-size:12px" class="muted">Fewer ${steps.slice(1).map((_, k) => `<span style="width:14px;height:14px;border-radius:3px;background:${shade(Math.ceil(((k + 1) * max) / 5))}"></span>`).join("")} More · busiest hour: ${num(max)}</div>
      <details class="tv"><summary>Show as table</summary><table><thead><tr><th>Day</th><th>Busiest hour</th><th>Actions that day</th></tr></thead><tbody>
        ${grid.map((row, i) => { const t = row.reduce((a, b) => a + b, 0), bh = row.indexOf(Math.max(...row)); return `<tr><td>${days[i]}</td><td>${t ? hourLabel(bh) : "—"}</td><td>${t}</td></tr>`; }).join("")}</tbody></table></details>`;
  }
  function retention(el, rows) {
    if (!rows.length) { el.innerHTML = '<p class="empty">No sign-ups in the last 8 weeks yet.</p>'; return; }
    const fmt = d => new Date(d + "T00:00:00").toLocaleDateString("en-GB", { day: "numeric", month: "short" });
    el.innerHTML = `<table><thead><tr><th>Week of</th><th>Joined</th><th>Still active</th><th style="width:40%"></th></tr></thead><tbody>
      ${rows.map(r => { const p = r.joined ? Math.round((100 * r.active) / r.joined) : 0; return `<tr><td>${fmt(r.week)}</td><td>${num(r.joined)}</td><td><b>${p}%</b> <span class="muted">(${num(r.active)})</span></td>
        <td><span class="track" style="display:block;height:10px;border-radius:4px;background:var(--surface-2);overflow:hidden"><span style="display:block;height:100%;width:${p}%;background:var(--bar);border-radius:0 4px 4px 0"></span></span></td></tr>`; }).join("")}
      </tbody></table><p class="sub" style="margin:10px 0 0">"Still active" means they opened Kindred in the last 7 days.</p>`;
  }

  /* ---------- CSV export ---------- */
  async function exportCsv(fnName, file) {
    try {
      const rows = await rpc(fnName);
      if (!rows.length) return toast("Nothing to export yet");
      const ORDER = {
        admin_export_members: ["name", "email", "age", "gender", "city", "looking_for", "onboarded", "photos", "suspended", "test_account", "reports_against", "joined", "last_active"],
        admin_export_reports: ["created", "reason", "details", "status", "reporter", "reported", "reported_email", "resolved_by", "resolved_at", "note"],
      };
      const cols = (ORDER[fnName] || Object.keys(rows[0])).filter(c => c in rows[0]);
      const cell = v => { const s = v == null ? "" : String(v); return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
      const csv = "﻿" + [cols.join(","), ...rows.map(r => cols.map(c => cell(r[c])).join(","))].join("\r\n");
      const a = document.createElement("a");
      a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
      a.download = `${file}-${new Date().toISOString().slice(0, 10)}.csv`;
      document.body.append(a); a.click(); a.remove();
      toast(`Exported ${rows.length} row${rows.length === 1 ? "" : "s"}`);
    } catch (e) { toast(friendly(e)); }
  }
  const exportBtn = (fn, file, label) => state.me.role === "super_admin" ? `<button class="btn sm" data-export="${fn}" data-file="${file}">${label}</button>` : "";
  const wireExport = () => $$("[data-export]").forEach(b => b.onclick = () => exportCsv(b.dataset.export, b.dataset.file));

  /* ---------- scam alerts ---------- */
  const CATEGORY = { money: ["Money request", "bad"], off_platform: ["Moving off Kindred", "warn"] };
  async function viewFlags() {
    const tabs = [["open", "Open"], ["dismissed", "Dismissed"], ["actioned", "Action taken"], ["all", "All"]];
    main().innerHTML = `<div class="head"><div><h1>Scam alerts</h1><p>Messages flagged automatically because they mention money (Orange Money, Afrimoney, airtime, amounts in Leones) or try to move the chat to WhatsApp or a phone number. Many are harmless, so check before acting.</p></div></div>
      <div class="toolbar"><div class="seg">${tabs.map(([k, l]) => `<button data-fs="${k}" class="${state.flagStatus === k ? "on" : ""}">${l}</button>`).join("")}</div></div><div id="fl"></div>`;
    $$("[data-fs]").forEach(b => b.onclick = () => { state.flagStatus = b.dataset.fs; viewFlags(); });
    const list = $("#fl");
    list.innerHTML = '<div class="boot" style="min-height:30vh"><span class="spin"></span></div>';
    let rows;
    try { rows = await rpc("admin_flags", { p_status: state.flagStatus, p_limit: 300 }); } catch (e) { list.innerHTML = `<div class="card empty">${esc(friendly(e))}</div>`; return; }
    if (!rows.length) { list.innerHTML = `<div class="card empty">${state.flagStatus === "open" ? "No scam alerts waiting." : "Nothing here yet."}</div>`; return; }
    const mark = (body, m) => { const b = esc(body); if (!m) return b; const i = body.toLowerCase().indexOf(m.toLowerCase()); return i < 0 ? b : esc(body.slice(0, i)) + `<mark style="background:color-mix(in srgb,var(--bad) 22%,transparent);color:inherit;border-radius:4px;padding:0 2px">${esc(body.slice(i, i + m.length))}</mark>` + esc(body.slice(i + m.length)); };
    list.innerHTML = rows.map(f => {
      const [cl, tone] = CATEGORY[f.category] || [f.category, ""], s = f.sender || {};
      return `<div class="card report" data-id="${f.id}">
        <div class="top"><div><span class="badge ${tone}">${cl}</span>
          <div class="who" style="margin-top:6px"><a data-member="${s.id}">${esc(s.name)}</a> wrote to ${f.recipient ? `<a data-member="${f.recipient.id}">${esc(f.recipient.name)}</a>` : "a match"} · ${when(f.created_at)}
            ${s.flags > 1 ? `<span class="badge bad">${s.flags} alerts on this member</span>` : ""}${s.banned_at ? '<span class="badge bad">Suspended</span>' : ""}</div></div>
          <div>${{ open: '<span class="badge warn">Open</span>', dismissed: '<span class="badge">Dismissed</span>', actioned: '<span class="badge good">Action taken</span>' }[f.status]}</div></div>
        <div class="details" style="font-size:15px">“${mark(f.body, f.matched)}”</div>
        ${f.resolved_by ? `<p class="muted" style="font-size:13px;margin:10px 0 0">Handled by ${esc(f.resolved_by)} ${when(f.resolved_at)}</p>` : ""}
        <div class="actions">${f.status === "open" ? `${s.banned_at ? "" : `<button class="btn sm danger" data-fa="suspend">Suspend ${esc(s.name)}</button>`}
            <button class="btn sm" data-fa="dismissed">Not a problem</button><button class="btn sm" data-fa="actioned">Close: action taken</button>`
          : `<button class="btn sm" data-fa="open">Reopen</button>`}
          <button class="btn sm ghost" data-member="${s.id}">View ${esc(s.name)}</button></div></div>`;
    }).join("");
    $$("[data-member]", list).forEach(a => a.onclick = () => openMember(a.dataset.member));
    $$("[data-fa]", list).forEach(b => b.onclick = async () => {
      const id = b.closest(".report").dataset.id, f = rows.find(x => x.id === id), act = b.dataset.fa;
      try {
        if (act === "suspend") {
          const reason = await ask({ title: `Suspend ${f.sender.name}?`, text: "They'll be signed out, can't sign back in, and disappear from every feed and chat. All their open scam alerts will be closed.", input: { label: "Reason (kept in the log)", required: "Give a reason.", multiline: true, placeholder: CATEGORY[f.category]?.[0] }, confirm: "Suspend", danger: true });
          if (!reason) return;
          await rpc("admin_suspend", { p_user: f.sender.id, p_reason: reason });
          await rpc("admin_resolve_flags_for", { p_sender: f.sender.id, p_status: "actioned" });
          toast(`${f.sender.name} suspended`);
        } else {
          await rpc("admin_resolve_flag", { p_id: id, p_status: act });
          toast(act === "open" ? "Alert reopened" : "Alert closed");
        }
        refreshReportCount(); viewFlags();
      } catch (e) { toast(friendly(e)); }
    });
  }

  /* ---------- photo review ---------- */
  async function viewPhotos(append) {
    if (!append) {
      state.photoCursor = null;
      main().innerHTML = `<div class="head"><div><h1>Photo review</h1><p>The newest photos on member profiles, so you can remove anything that breaks the rules before someone reports it.</p></div></div>
        <div id="pg" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px"></div>
        <div style="text-align:center;margin-top:16px"><button class="btn" id="more" hidden>Load more</button></div>`;
      $("#more").onclick = () => viewPhotos(true);
    }
    const grid = $("#pg"), more = $("#more");
    if (!append) grid.innerHTML = '<div class="boot" style="min-height:30vh;grid-column:1/-1"><span class="spin"></span></div>';
    let rows;
    try { rows = await rpc("admin_recent_photos", { p_limit: 60, p_before: state.photoCursor }); } catch (e) { grid.innerHTML = `<div class="card empty" style="grid-column:1/-1">${esc(friendly(e))}</div>`; return; }
    if (!append) grid.innerHTML = "";
    if (!rows.length && !append) { grid.innerHTML = '<div class="card empty" style="grid-column:1/-1">No photos yet.</div>'; more.hidden = true; return; }
    const base = `${CFG.SUPABASE_URL}/storage/v1/object/public/photos/`;
    grid.insertAdjacentHTML("beforeend", rows.map(r => {
      const url = base + r.path.split("/").map(encodeURIComponent).join("/");
      return `<div class="card" style="padding:8px" data-url="${esc(url)}" data-member-id="${r.member.id}">
        <div class="thumb" style="width:100%"><img src="${esc(url)}" alt="Photo by ${esc(r.member.name)}" loading="lazy"></div>
        <div style="display:flex;justify-content:space-between;align-items:center;gap:6px;margin-top:8px;font-size:13px">
          <a data-member="${r.member.id}" style="font-weight:700;cursor:pointer;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(r.member.name)}</a><span class="muted">${when(r.uploaded_at)}</span></div>
        ${r.member.is_test ? '<span class="badge">Test</span>' : ""}${r.member.banned_at ? '<span class="badge bad">Suspended</span>' : ""}
        <button class="btn sm danger" style="width:100%;margin-top:8px" data-rm>Remove photo</button></div>`;
    }).join(""));
    state.photoCursor = rows.length ? rows[rows.length - 1].uploaded_at : state.photoCursor;
    more.hidden = rows.length < 60;
    $$("[data-member]", grid).forEach(a => a.onclick = () => openMember(a.dataset.member));
    $$("[data-rm]", grid).forEach(b => b.onclick = async () => {
      const card = b.closest("[data-url]");
      if (!(await ask({ title: "Remove this photo?", text: "It's taken off the member's profile and deleted from storage.", confirm: "Remove photo", danger: true }))) return;
      try {
        await rpc("admin_remove_photo", { p_user: card.dataset.memberId, p_url: card.dataset.url });
        const p = storagePath(card.dataset.url); if (p) await sb.storage.from("photos").remove([p]);
        card.remove(); toast("Photo removed");
      } catch (e) { toast(friendly(e)); }
    });
  }

  /* ---------- members ---------- */
  async function viewMembers() {
    const filters = [["all", "All"], ["reported", "Reported"], ["suspended", "Suspended"], ["incomplete", "Profile not finished"], ["admins", "Admins"], ["test", "Test accounts"]];
    main().innerHTML = `<div class="head"><div><h1>Members</h1><p>Search by name, email or town. Click a member to see their full profile and take action.</p></div>${exportBtn("admin_export_members", "kindred-members", "Export CSV")}</div>
      <div class="toolbar"><input type="search" id="q" placeholder="Search members…" value="${esc(state.memberSearch)}">
        <div class="seg">${filters.map(([k, l]) => `<button data-f="${k}" class="${state.memberFilter === k ? "on" : ""}">${l}</button>`).join("")}</div></div>
      <div id="ml"></div>`;
    let t;
    wireExport();
    $("#q").oninput = e => { clearTimeout(t); t = setTimeout(() => { state.memberSearch = e.target.value; state.memberOffset = 0; loadMembers(); }, 300); };
    $$("[data-f]").forEach(b => b.onclick = () => { state.memberFilter = b.dataset.f; state.memberOffset = 0; $$("[data-f]").forEach(x => x.classList.toggle("on", x === b)); loadMembers(); });
    loadMembers();
  }
  async function loadMembers() {
    const el = $("#ml"), size = 50;
    el.innerHTML = '<div class="boot" style="min-height:30vh"><span class="spin"></span></div>';
    let res;
    try { res = await rpc("admin_members", { p_search: state.memberSearch || null, p_filter: state.memberFilter, p_limit: size, p_offset: state.memberOffset }); }
    catch (e) { el.innerHTML = `<div class="card empty">${esc(friendly(e))}</div>`; return; }
    if (!res.rows.length) { el.innerHTML = '<div class="card empty">No members match.</div>'; return; }
    el.innerHTML = `<div class="tablewrap"><table><thead><tr><th>Member</th><th>Age</th><th>Town</th><th>Joined</th><th>Last active</th><th>Status</th></tr></thead><tbody>
      ${res.rows.map(m => `<tr class="click" data-member="${m.id}"><td><div class="person">${avatar(m)}<div><b>${esc(m.name)}</b><span>${esc(m.email)}</span></div></div></td>
        <td>${m.age ?? "—"} ${m.gender ? `<span class="muted">${m.gender === "woman" ? "F" : "M"}</span>` : ""}</td><td>${esc(m.city || "—")}</td>
        <td class="muted">${when(m.created_at)}</td><td class="muted">${when(m.last_active)}</td>
        <td>${m.banned_at ? '<span class="badge bad">Suspended</span>' : ""}${m.reports_against ? `<span class="badge warn">${m.reports_against} report${m.reports_against > 1 ? "s" : ""}</span>` : ""}${!m.onboarded ? '<span class="badge">Profile not finished</span>' : ""}${m.admin_role ? `<span class="badge info">${m.admin_role === "super_admin" ? "Super admin" : "Moderator"}</span>` : ""}${m.is_test ? '<span class="badge">Test</span>' : ""}</td></tr>`).join("")}
      </tbody></table></div>
      <div class="pager"><span>${num(state.memberOffset + 1)}–${num(state.memberOffset + res.rows.length)} of ${num(res.total)}</span>
        <span><button class="btn sm" id="prev" ${state.memberOffset ? "" : "disabled"}>Previous</button> <button class="btn sm" id="next" ${state.memberOffset + size < res.total ? "" : "disabled"}>Next</button></span></div>`;
    $$("[data-member]", el).forEach(r => r.onclick = () => openMember(r.dataset.member));
    $("#prev").onclick = () => { state.memberOffset = Math.max(0, state.memberOffset - size); loadMembers(); };
    $("#next").onclick = () => { state.memberOffset += size; loadMembers(); };
  }

  function closeDrawer() { drawer.classList.remove("open"); drawer.setAttribute("aria-hidden", "true"); setTimeout(() => { if (!drawer.classList.contains("open")) drawer.innerHTML = ""; }, 260); }
  async function openMember(id) {
    drawer.innerHTML = '<div class="scrim"></div><div class="panel"><div class="boot" style="min-height:50vh"><span class="spin"></span></div></div>';
    drawer.classList.add("open"); drawer.setAttribute("aria-hidden", "false");
    $(".scrim", drawer).onclick = closeDrawer;
    let m;
    try { m = await rpc("admin_member", { p_id: id }); } catch (e) { $(".panel", drawer).innerHTML = `<p class="err">${esc(friendly(e))}</p>`; return; }
    if (!m) { $(".panel", drawer).innerHTML = '<p class="empty">This member no longer exists.</p>'; return; }
    const superA = state.me.role === "super_admin", c = m.counts || {};
    $(".panel", drawer).innerHTML = `<button class="btn sm x" data-close>Close</button>
      <div class="person" style="margin-top:4px">${avatar(m, 56)}<div><b style="font-size:20px">${esc(m.name)}${m.age ? `, ${m.age}` : ""}</b><span>${esc(m.email)}</span></div></div>
      <div style="margin-top:10px">${m.banned_at ? `<span class="badge bad">Suspended ${when(m.banned_at)}</span>` : '<span class="badge good">Active account</span>'}${m.admin_role ? `<span class="badge info">${m.admin_role === "super_admin" ? "Super admin" : "Moderator"}</span>` : ""}${m.is_test ? '<span class="badge">Test account</span>' : ""}${m.email_confirmed ? "" : '<span class="badge warn">Email not confirmed</span>'}${m.onboarded ? "" : '<span class="badge">Profile not finished</span>'}</div>
      ${m.banned_at && m.ban_reason ? `<p class="details" style="margin-top:10px;padding:10px 12px;background:var(--surface-2);border-radius:10px">Suspension reason: ${esc(m.ban_reason)}</p>` : ""}
      <div class="counts"><div><b>${num(c.matches)}</b><span>Matches</span></div><div><b>${num(c.messages_sent)}</b><span>Messages sent</span></div><div><b>${num(c.likes_received)}</b><span>Likes received</span></div><div><b>${num(c.reports_against)}</b><span>Reports against</span></div></div>
      <h3>Photos</h3>${m.photos?.length ? `<div class="thumbs">${m.photos.map(u => `<div class="thumb"><img src="${esc(u)}" alt="" loading="lazy"><button data-rmphoto="${esc(u)}">Remove</button></div>`).join("")}</div>` : '<p class="muted">No photos.</p>'}
      <h3>Profile</h3>
      <dl class="kv"><dt>Gender</dt><dd>${esc(m.gender || "—")} · shows ${esc(m.show_me)}</dd><dt>Town</dt><dd>${esc(m.city || "—")}</dd><dt>Work</dt><dd>${esc(m.job || "—")}</dd>
        <dt>Looking for</dt><dd>${esc(LOOKING[m.looking_for] || "—")}</dd><dt>Bio</dt><dd>${esc(m.bio || "—")}</dd>
        <dt>Interests</dt><dd>${esc((m.interests || []).join(", ") || "—")}</dd><dt>Languages</dt><dd>${esc((m.languages || []).join(", ") || "—")}</dd>
        <dt>Joined</dt><dd>${fullDate(m.created_at)}</dd><dt>Last signed in</dt><dd>${fullDate(m.last_sign_in_at)}</dd><dt>Last active</dt><dd>${fullDate(m.last_active)}</dd>
        <dt>Likes given</dt><dd>${num(c.likes_given)}</dd><dt>Blocked by</dt><dd>${num(c.blocked_by)} member${c.blocked_by === 1 ? "" : "s"}</dd><dt>Reports made</dt><dd>${num(c.reports_made)}</dd></dl>
      ${m.reports_against?.length ? `<h3>Reports against ${esc(m.name)}</h3>${m.reports_against.map(r => `<div style="font-size:14px;margin-bottom:6px">${esc(r.reason)} <span class="muted">· ${when(r.created_at)}</span> <span class="badge ${r.status === "open" ? "warn" : r.status === "actioned" ? "good" : ""}">${({ open: "Open", reviewed: "Closed, no action", actioned: "Action taken" })[r.status] || r.status}</span></div>`).join("")}` : ""}
      <h3>Devices</h3><div id="devices"><span class="muted" style="font-size:13px">Loading…</span></div>
      <h3>Private notes</h3><p class="muted" style="margin:-4px 0 8px;font-size:13px">Only the admin team can see these. The member never does.</p>
      <form id="noteform" style="display:flex;gap:8px"><input name="note" maxlength="2000" placeholder="e.g. Warned about sharing phone numbers" style="flex:1;height:38px;padding:0 12px;border-radius:10px;border:1.5px solid var(--line);background:var(--surface)"><button class="btn sm primary" type="submit" style="height:38px">Add note</button></form>
      <div id="notes" style="margin-top:10px"><span class="muted" style="font-size:13px">Loading…</span></div>
      <h3>Actions</h3><div style="display:flex;gap:8px;flex-wrap:wrap">
        ${m.banned_at ? '<button class="btn" data-a="unsuspend">Lift suspension</button>' : '<button class="btn danger" data-a="suspend">Suspend member</button>'}
        ${superA && !m.admin_role ? '<button class="btn" data-a="make-admin">Add to admin team</button>' : ""}
        ${superA ? `<button class="btn" data-a="test">${m.is_test ? "Unmark test account" : "Mark as test account"}</button>` : ""}</div>
      ${superA ? `<div class="danger-zone"><b>Delete member</b><p class="muted" style="margin:4px 0 10px;font-size:14px">Permanently removes their account, photos, matches and messages. Can't be undone.</p><button class="btn danger sm" data-a="delete">Delete ${esc(m.name)}</button></div>` : ""}`;
    $("[data-close]", drawer).onclick = closeDrawer;
    const loadNotes = async () => {
      const box = $("#notes", drawer); if (!box) return;
      try {
        const notes = await rpc("admin_notes", { p_member: id });
        box.innerHTML = notes.length ? notes.map(n => `<div style="background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:10px 12px;margin-bottom:8px;font-size:14px">
            <div style="white-space:pre-wrap">${esc(n.body)}</div>
            <div class="muted" style="font-size:12px;margin-top:4px;display:flex;justify-content:space-between;gap:8px"><span>${esc(n.admin || "Former admin")} · ${when(n.created_at)}</span>
              ${n.mine || state.me.role === "super_admin" ? `<button class="btn sm ghost" style="height:24px;padding:0 6px" data-delnote="${n.id}">Delete</button>` : ""}</div></div>`).join("")
          : '<span class="muted" style="font-size:13px">No notes yet.</span>';
        $$("[data-delnote]", box).forEach(b => b.onclick = async () => { try { await rpc("admin_delete_note", { p_id: b.dataset.delnote }); loadNotes(); } catch (e) { toast(friendly(e)); } });
      } catch (e) { box.innerHTML = `<span class="err">${esc(friendly(e))}</span>`; }
    };
    loadNotes();
    rpc("admin_member_devices", { p_member: id }).then(devs => {
      const box = $("#devices", drawer); if (!box) return;
      const icon = pl => pl === "web" ? "🌐" : "📱";
      box.innerHTML = devs.length ? devs.map(d => `<div style="display:flex;gap:12px;align-items:flex-start;background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:10px 12px;margin-bottom:8px;font-size:14px">
          <span style="font-size:20px;line-height:1">${icon(d.platform)}</span>
          <div style="flex:1;min-width:0"><b>${esc(PLATFORM[d.platform] || d.platform)}${d.model ? ` · ${esc(d.model)}` : ""}</b>
            <div class="muted" style="font-size:13px">${esc([d.os, d.browser, d.app_version ? `App ${d.app_version}` : null].filter(Boolean).join(" · ") || "Details not available")}</div>
            <div class="muted" style="font-size:12px;margin-top:2px">Last used ${when(d.last_seen)} · first seen ${fullDate(d.first_seen)} · ${num(d.sign_ins)} sign-in${d.sign_ins === 1 ? "" : "s"}</div></div></div>`).join("")
        : '<span class="muted" style="font-size:13px">No devices recorded yet. They appear the next time this member opens Kindred.</span>';
    }).catch(e => { const box = $("#devices", drawer); if (box) box.innerHTML = `<span class="err">${esc(friendly(e))}</span>`; });
    $("#noteform", drawer).onsubmit = async e => {
      e.preventDefault(); const inp = e.target.note, v = inp.value.trim(); if (!v) return;
      try { await rpc("admin_add_note", { p_member: id, p_body: v }); inp.value = ""; loadNotes(); } catch (err) { toast(friendly(err)); }
    };
    const act = async (fn, msg) => { try { await fn(); if (msg) toast(msg); openMember(id); if (state.tab === "members") loadMembers(); } catch (e) { toast(friendly(e)); } };
    $$("[data-rmphoto]", drawer).forEach(b => b.onclick = async () => {
      if (!(await ask({ title: "Remove this photo?", text: "It's taken off their profile and deleted from storage.", confirm: "Remove photo", danger: true }))) return;
      act(async () => { await rpc("admin_remove_photo", { p_user: id, p_url: b.dataset.rmphoto }); const p = storagePath(b.dataset.rmphoto); if (p) await sb.storage.from("photos").remove([p]); }, "Photo removed");
    });
    const on = (k, fn) => { const b = $(`[data-a="${k}"]`, drawer); if (b) b.onclick = fn; };
    on("suspend", async () => {
      const reason = await ask({ title: `Suspend ${m.name}?`, text: "They'll be signed out, can't sign back in, and disappear from every feed and chat.", input: { label: "Reason (kept in the log)", required: "Give a reason.", multiline: true }, confirm: "Suspend", danger: true });
      if (reason) act(() => rpc("admin_suspend", { p_user: id, p_reason: reason }), `${m.name} suspended`);
    });
    on("unsuspend", async () => { if (await ask({ title: `Lift ${m.name}'s suspension?`, text: "They'll be able to sign in and appear in feeds again.", confirm: "Lift suspension" })) act(() => rpc("admin_unsuspend", { p_user: id }), "Suspension lifted"); });
    on("test", () => act(() => rpc("admin_set_test", { p_user: id, p_is_test: !m.is_test }), m.is_test ? "Now a real member" : "Moved to the test pool"));
    on("make-admin", async () => {
      const r = await ask({ title: `Add ${m.name} to the admin team`, text: "Moderators handle reports and members. Super admins can also manage the team and delete accounts.", select: { label: "Role", options: [["moderator", "Moderator"], ["super_admin", "Super admin"]] }, confirm: "Add to team" });
      if (r) act(() => rpc("admin_add", { p_email: m.email, p_role: r.sel }), `${m.name} added as ${r.sel === "super_admin" ? "super admin" : "moderator"}`);
    });
    on("delete", async () => {
      const ok = await ask({ title: `Delete ${m.name}?`, text: "This permanently deletes the account and everything in it.", input: { label: "Type DELETE to confirm", mustEqual: "DELETE" }, confirm: "Delete forever", danger: true });
      if (!ok) return;
      try {
        const { data: files } = await sb.storage.from("photos").list(id, { limit: 100 });
        if (files?.length) await sb.storage.from("photos").remove(files.map(f => `${id}/${f.name}`));
        await rpc("admin_delete_member", { p_user: id });
        sb.functions.invoke("chat-media-cleanup", { body: {} }).catch(() => {}); // their chats' photos/videos
        toast(`${m.name} deleted`); closeDrawer(); if (state.tab === "members") loadMembers();
      } catch (e) { toast(friendly(e)); }
    });
  }

  /* ---------- team ---------- */
  async function viewTeam() {
    loading();
    let team;
    try { team = await rpc("admin_team"); } catch (e) { return failed(e); }
    const superA = state.me.role === "super_admin";
    main().innerHTML = `<div class="head"><div><h1>Admin team</h1><p><b>Moderators</b> handle reports, suspensions and photos. <b>Super admins</b> can also add or remove team members and delete accounts.</p></div></div>
      ${superA ? `<form class="card" id="add" style="margin-bottom:16px"><h2>Add someone to the team</h2><p class="sub">They need a Kindred account first. Ask them to sign up at kindred-sl.netlify.app/app, then enter their email here.</p>
        <div class="toolbar" style="margin:0"><input type="search" name="email" placeholder="their-email@example.com" required style="flex:1;min-width:220px;height:40px;padding:0 14px;border-radius:10px;border:1.5px solid var(--line);background:var(--surface)">
        <select name="role" style="height:40px;border-radius:10px;border:1.5px solid var(--line);background:var(--surface);padding:0 10px"><option value="moderator">Moderator</option><option value="super_admin">Super admin</option></select>
        <button class="btn primary" type="submit">Add to team</button></div><p class="err" id="adderr"></p></form>` : '<div class="card" style="margin-bottom:16px"><p class="muted" style="margin:0">Only super admins can change the team.</p></div>'}
      <div class="tablewrap"><table><thead><tr><th>Member</th><th>Role</th><th>Added by</th><th>Since</th><th>Last signed in</th>${superA ? "<th></th>" : ""}</tr></thead><tbody>
        ${team.map(a => `<tr><td><div class="person">${avatar({ id: a.user_id, name: a.name })}<div><b>${esc(a.name || "—")}${a.user_id === (sbUser?.id) ? ' <span class="muted">(you)</span>' : ""}</b><span>${esc(a.email)}</span></div></div></td>
          <td><span class="role ${a.role}">${a.role === "super_admin" ? "Super admin" : "Moderator"}</span></td><td class="muted">${esc(a.added_by || "—")}</td><td class="muted">${when(a.created_at)}</td><td class="muted">${when(a.last_sign_in_at)}</td>
          ${superA ? `<td style="text-align:right;white-space:nowrap">${a.role === "moderator" ? `<button class="btn sm" data-promote="${a.user_id}" data-email="${esc(a.email)}">Make super admin</button>` : ""} <button class="btn sm" data-remove="${a.user_id}" data-name="${esc(a.name || a.email)}">Remove</button></td>` : ""}</tr>`).join("")}
      </tbody></table></div>`;
    if (superA) {
      $("#add").onsubmit = async e => {
        e.preventDefault();
        const f = e.target;
        try { await rpc("admin_add", { p_email: f.email.value.trim(), p_role: f.role.value }); toast("Added to the admin team"); viewTeam(); }
        catch (err) { $("#adderr").textContent = friendly(err); }
      };
      $$("[data-promote]").forEach(b => b.onclick = async () => { try { await rpc("admin_add", { p_email: b.dataset.email, p_role: "super_admin" }); toast("Promoted to super admin"); viewTeam(); } catch (e) { toast(friendly(e)); } });
      $$("[data-remove]").forEach(b => b.onclick = async () => {
        if (!(await ask({ title: `Remove ${b.dataset.name} from the team?`, text: "They keep their member account but lose admin access.", confirm: "Remove", danger: true }))) return;
        try { await rpc("admin_remove", { p_user: b.dataset.remove }); toast("Removed from the team"); if (b.dataset.remove === sbUser?.id) return boot(); viewTeam(); } catch (e) { toast(friendly(e)); }
      });
    }
  }

  /* ---------- activity ---------- */
  async function viewActivity() {
    loading();
    let log;
    try { log = await rpc("admin_audit_log", { p_limit: 300 }); } catch (e) { return failed(e); }
    main().innerHTML = `<div class="head"><div><h1>Activity log</h1><p>Every admin action, newest first. This log can't be edited.</p></div></div>
      ${log.length ? `<div class="tablewrap"><table><thead><tr><th>When</th><th>Admin</th><th>Action</th><th>Member</th><th>Details</th></tr></thead><tbody>
        ${log.map(l => `<tr><td class="muted" title="${fullDate(l.created_at)}">${when(l.created_at)}</td><td>${esc(l.admin_email || "—")}</td><td><b>${esc(ACTIONS[l.action] || l.action)}</b></td>
          <td>${l.target && l.action !== "delete_member" ? `<a href="#" data-member="${l.target}">${esc(l.target_name || "member")}</a>` : esc(l.details?.name || l.target_name || "—")}</td>
          <td class="muted" style="max-width:320px">${esc(l.details?.reason || l.details?.note || l.details?.role || "")}</td></tr>`).join("")}
      </tbody></table></div>` : '<div class="card empty">No admin actions yet.</div>'}`;
    $$("[data-member]").forEach(a => a.onclick = e => { e.preventDefault(); openMember(a.dataset.member); });
  }

  let sbUser = null;
  sb.auth.onAuthStateChange((_e, s) => { sbUser = s?.user || null; });
  document.addEventListener("keydown", e => { if (e.key === "Escape" && drawer.classList.contains("open")) closeDrawer(); });
  boot();
})();
