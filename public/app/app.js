"use strict";
(() => {
  const CFG = window.KINDRED_CONFIG || {};
  const LIVE = !!(CFG.SUPABASE_URL && CFG.SUPABASE_KEY && window.supabase);
  const api = LIVE ? window.KindredLive(CFG) : window.KindredDemo();

  /* ---------- reference data ---------- */
  const CITIES = ["Freetown", "Bo", "Kenema", "Makeni", "Koidu", "Port Loko", "Lungi", "Waterloo", "Kabala", "Kailahun", "Magburaka", "Moyamba", "Bonthe", "Pujehun", "Kambia"];
  const INTERESTS = ["Afrobeats", "Football", "Cooking", "Beach days", "Church choir", "Gospel & worship", "Fashion", "Tech", "Reading", "Dancing", "Entrepreneurship", "Travel", "Movies", "Nature", "Photography", "Volunteering", "Farming", "Fitness", "Poetry", "Gaming"];
  const LANGUAGES = ["Krio", "English", "Temne", "Mende", "Limba", "Fula", "Kono", "Susu", "Loko", "Sherbro", "Mandingo", "French", "Arabic"];
  const LOOKING = [["relationship", "A relationship", "💞"], ["marriage", "Marriage", "💍"], ["friendship", "New friends", "🤝"], ["not_sure", "Still figuring it out", "✨"]];
  const RELIGION = [["muslim", "Muslim"], ["christian", "Christian"], ["other", "Other"], ["prefer_not", "Prefer not to say"]];
  const REPORT_REASONS = ["Fake profile or scam", "Asked me for money", "Inappropriate photos", "Harassment or threats", "Looks under 18", "Something else"];
  const ICEBREAKERS = ["What's your favourite spot in Salone?", "Jollof or cassava leaves? 😄", "What does a perfect weekend look like for you?", "What are you looking for on Kindred?"];
  const PALETTES = [["#F2436B", "#FF8A3D"], ["#7B5CFA", "#E8375A"], ["#0E9F8E", "#3B82F6"], ["#F59E0B", "#EF4444"], ["#EC4899", "#8B5CF6"], ["#10B981", "#0EA5E9"], ["#F97316", "#DB2777"], ["#6366F1", "#14B8A6"]];

  /* ---------- icons ---------- */
  const svg = (d, cls = "i") => `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true">${d}</svg>`;
  const I = {
    heart: svg('<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>'),
    x: svg('<path d="M18 6 6 18M6 6l12 12"/>'),
    star: svg('<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>'),
    chat: svg('<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>'),
    user: svg('<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>'),
    bell: svg('<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>'),
    sliders: svg('<path d="M21 4h-7M10 4H3M21 12h-9M8 12H3M21 20h-5M12 20H3M14 2v4M8 10v4M16 18v4"/>'),
    pin: svg('<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>'),
    back: svg('<path d="m15 18-6-6 6-6"/>'),
    chev: svg('<path d="m9 18 6-6-6-6"/>', "i chev"),
    send: svg('<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>'),
    more: svg('<circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/>'),
    up: svg('<path d="m18 15-6-6-6 6"/>'),
    plus: svg('<path d="M12 5v14M5 12h14"/>'),
    shield: svg('<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>'),
    logout: svg('<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5M21 12H9"/>'),
    lock: svg('<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>'),
    trash: svg('<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>'),
    eye: svg('<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>'),
    eyeOff: svg('<path d="M9.9 4.24A9 9 0 0 1 12 4c6.5 0 10 8 10 8a13 13 0 0 1-1.67 2.68M6.61 6.61A13.5 13.5 0 0 0 2 12s3.5 8 10 8a9.7 9.7 0 0 0 5.39-1.61M2 2l20 20M14.12 14.12a3 3 0 1 1-4.24-4.24"/>'),
    mail: svg('<rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-10 6L2 7"/>'),
    pencil: svg('<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>'),
    flag: svg('<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1zM4 22v-7"/>'),
    ban: svg('<circle cx="12" cy="12" r="10"/><path d="m4.9 4.9 14.2 14.2"/>'),
    refresh: svg('<path d="M3 12a9 9 0 0 1 15-6.7L21 8M21 3v5h-5M21 12a9 9 0 0 1-15 6.7L3 16M3 21v-5h5"/>'),
    work: svg('<rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/>'),
    search: svg('<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>'),
    globe: svg('<circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 0 20M12 2a15.3 15.3 0 0 0 0 20"/>'),
    unlink: svg('<path d="M18.84 12.25l1.72-1.71a5 5 0 0 0-7.07-7.07l-1.72 1.71M5.17 11.75l-1.71 1.71a5 5 0 0 0 7.07 7.07l1.71-1.71M8 2v3M2 8h3M16 22v-3M22 16h-3"/>'),
    phone: svg('<rect x="6" y="2" width="12" height="20" rx="2.5"/><path d="M11 18h2"/>'),
    image: svg('<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21"/>'),
    call: svg('<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>'),
    phoneOff: svg('<g transform="rotate(135 12 12)"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></g>'),
    video: svg('<path d="m22 8-6 4 6 4V8Z"/><rect x="2" y="6" width="14" height="12" rx="2"/>'),
    videoOff: svg('<path d="M10.66 6H14a2 2 0 0 1 2 2v2.34l1 1L22 8v8M16 16a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2l10 10ZM2 2l20 20"/>'),
    mic: svg('<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M19 10v1a7 7 0 0 1-14 0v-1M12 18v4"/>'),
    micOff: svg('<path d="M2 2l20 20M18.89 13.23A7 7 0 0 0 19 12v-2M5 10v2a7 7 0 0 0 12 5M15 9.34V5a3 3 0 0 0-5.68-1.33M9 9v3a3 3 0 0 0 5.12 2.12M12 19v3"/>'),
    flip: svg('<path d="M11 19H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h5M13 5h7a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-5"/><circle cx="12" cy="12" r="3"/><path d="m18 22-3-3 3-3M6 2l3 3-3 3"/>'),
    mark: svg('<path d="M10.3 6.6C8.6 4.9 5.9 5.2 4.3 7.7 2.4 11.1 4.8 15.4 12 20.2"/><path d="M13.7 6.6C15.4 4.9 18.1 5.2 19.7 7.7c1.9 3.4-.5 7.7-7.7 12.5"/><circle cx="12" cy="3.6" r="1.2" fill="currentColor" stroke="none"/>'),
  };
  const MARK = (size = 40) => `<svg width="${size}" height="${size}" viewBox="0 0 100 100" fill="none" stroke="url(#kg)" stroke-width="8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><defs><linearGradient id="kg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F2436B"/><stop offset="1" stop-color="#FF8A3D"/></linearGradient></defs><path d="M43 27.5C36 20.5 24.5 21.5 18 32c-8 14 2 32 32 52"/><path d="M57 27.5C64 20.5 75.5 21.5 82 32c8 14-2 32-32 52" stroke-opacity=".82"/><circle cx="50" cy="16" r="5" fill="#F2436B" stroke="none"/></svg>`;

  /* ---------- helpers ---------- */
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const appEl = $("#app"), sheetEl = $("#sheet"), toastEl = $("#toast");
  const label = (list, key) => (list.find(x => x[0] === key) || [])[1] || "";
  const hashCode = s => { let h = 0; for (const c of String(s)) h = (h * 31 + c.charCodeAt(0)) >>> 0; return h; };
  const pal = id => PALETTES[hashCode(id) % PALETTES.length];
  const recent = iso => iso && Date.now() - new Date(iso).getTime() < 3 * 3600e3;
  const ageOf = bd => { const b = new Date(bd + "T00:00:00"), n = new Date(); let a = n.getFullYear() - b.getFullYear(); const m = n.getMonth() - b.getMonth(); if (m < 0 || (m === 0 && n.getDate() < b.getDate())) a--; return a; };
  const maxDob = () => { const d = new Date(); d.setFullYear(d.getFullYear() - 18); return d.toISOString().slice(0, 10); };
  const validEmail = e => /^[a-z0-9._%+'-]+@[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,}$/i.test(e) && !/\.\./.test(e) && !/^\.|\.@/.test(e) && e.length <= 254;
  // Common misspellings of big email providers -> the correct domain
  const DOMAIN_TYPOS = { "gmial.com": "gmail.com", "gmai.com": "gmail.com", "gmal.com": "gmail.com", "gamil.com": "gmail.com", "gmail.co": "gmail.com", "gmail.con": "gmail.com",
    "gmail.cm": "gmail.com", "gmail.om": "gmail.com", "gmaill.com": "gmail.com", "gnail.com": "gmail.com", "gmail.comm": "gmail.com", "gmsil.com": "gmail.com", "gmali.com": "gmail.com", "gmail.cim": "gmail.com",
    "yaho.com": "yahoo.com", "yahoo.con": "yahoo.com", "yahho.com": "yahoo.com", "yahoo.co": "yahoo.com", "yhoo.com": "yahoo.com", "hotmial.com": "hotmail.com", "hotmal.com": "hotmail.com",
    "hotmail.con": "hotmail.com", "hotmai.com": "hotmail.com", "hotmil.com": "hotmail.com", "outlok.com": "outlook.com", "outlook.con": "outlook.com", "outllok.com": "outlook.com",
    "iclod.com": "icloud.com", "icloud.con": "icloud.com", "iclould.com": "icloud.com" };
  const DISPOSABLE = new Set(["mailinator.com", "yopmail.com", "10minutemail.com", "guerrillamail.com", "guerrillamail.net", "sharklasers.com", "tempmail.com", "temp-mail.org", "tempmail.net", "tempmailo.com",
    "throwawaymail.com", "trashmail.com", "getnada.com", "nada.email", "dispostable.com", "maildrop.cc", "fakeinbox.com", "mintemail.com", "emailondeck.com", "mohmal.com", "burnermail.io",
    "mailnesia.com", "mytemp.email", "tempr.email", "discard.email", "spamgourmet.com", "getairmail.com", "moakt.com", "tmail.ws", "emailfake.com", "1secmail.com", "guerrillamailblock.com",
    "mailcatch.com", "inboxkitten.com", "tempinbox.com", "dropmail.me", "fakemail.net", "byom.de", "33mail.com"]);
  const KNOWN_MAIL = new Set(["gmail.com", "googlemail.com", "yahoo.com", "ymail.com", "outlook.com", "hotmail.com", "live.com", "msn.com", "icloud.com", "me.com", "aol.com", "proton.me", "protonmail.com", "zoho.com", "yandex.com", "gmx.com"]);
  const mxCache = new Map();
  // Asks public DNS whether the domain can receive email. Never blocks sign-up if the check itself fails.
  async function domainAcceptsMail(domain) {
    if (KNOWN_MAIL.has(domain)) return true;
    if (mxCache.has(domain)) return mxCache.get(domain);
    const q = async type => {
      const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), 4000);
      try { const r = await fetch(`https://dns.google/resolve?name=${encodeURIComponent(domain)}&type=${type}`, { signal: ctl.signal }); return await r.json(); }
      finally { clearTimeout(t); }
    };
    let ok = true;
    try {
      const mx = await q("MX");
      if (mx.Status === 3) ok = false; // the domain does not exist
      else if (!(mx.Answer || []).some(a => a.type === 15)) { const a = await q("A"); ok = (a.Answer || []).length > 0; }
    } catch { ok = true; }
    mxCache.set(domain, ok);
    return ok;
  }
  // null when the email looks fine, otherwise { msg, fix } where fix is a suggested corrected address
  async function emailProblem(email) {
    if (!validEmail(email)) return { msg: "Please enter a valid email address, like name@gmail.com." };
    const [user, domain] = email.split("@");
    if (DOMAIN_TYPOS[domain]) return { msg: `Did you mean ${user}@${DOMAIN_TYPOS[domain]}?`, fix: `${user}@${DOMAIN_TYPOS[domain]}` };
    if (DISPOSABLE.has(domain)) return { msg: "Temporary email addresses can't be used on Kindred. Please use your own email." };
    if (!(await domainAcceptsMail(domain))) return { msg: `We can't find an email service at ${domain}. Please check your email address.` };
    return null;
  }
  const validName = n => /^\p{L}[\p{L} '.-]{1,39}$/u.test(n);
  const isGmail = e => /@(gmail|googlemail)\.com$/i.test(e || "");

  function fmtWhen(iso) {
    if (!iso) return "";
    const d = new Date(iso), n = new Date();
    const days = Math.floor((new Date(n.toDateString()) - new Date(d.toDateString())) / 864e5);
    if (days === 0) return d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
    if (days === 1) return "Yesterday";
    if (days < 7) return d.toLocaleDateString([], { weekday: "short" });
    return d.toLocaleDateString([], { day: "numeric", month: "short" });
  }
  function fmtDay(iso) {
    const d = new Date(iso), n = new Date();
    const days = Math.floor((new Date(n.toDateString()) - new Date(d.toDateString())) / 864e5);
    if (days === 0) return "Today";
    if (days === 1) return "Yesterday";
    return d.toLocaleDateString([], { weekday: "long", day: "numeric", month: "long" });
  }
  function seenText(iso) {
    if (!iso) return "";
    const mins = (Date.now() - new Date(iso).getTime()) / 60000;
    if (mins < 15) return "Active now";
    if (mins < 60 * 3) return "Active recently";
    if (mins < 60 * 24) return "Active today";
    return "Active " + fmtWhen(iso).toLowerCase();
  }

  function friendly(e) {
    const m = String(e?.message || e || "");
    if (/invalid login credentials/i.test(m)) return "Email or password is incorrect.";
    if (/temporary email addresses are not allowed/i.test(m)) return "Temporary email addresses can't be used on Kindred. Please use your own email.";
    if (/please use a valid email|database error saving new user/i.test(m)) return "We couldn't create an account with that email. Please check it and try again.";
    if (/real first name/i.test(m)) return "Please use your real first name, using letters only.";
    if (/user is banned|been suspended/i.test(m)) return "This account has been suspended. If you think this is a mistake, email kindred.salone@gmail.com.";
    if (/email not confirmed/i.test(m)) return "Please confirm your email first. Check your inbox (and spam folder).";
    if (/already registered|already exists/i.test(m)) return "An account with this email already exists. Try signing in instead.";
    if (/18 or older/i.test(m)) return "You must be 18 or older to use Kindred.";
    if (/failed to fetch|networkerror|load failed/i.test(m)) return "Can't reach Kindred right now. Check your data or Wi-Fi and try again.";
    if (/email rate limit|over_email_send_rate_limit|error sending (confirmation|recovery)/i.test(m)) return "We couldn't send your email just now because our email service is busy. Your details weren't saved, so please try again a little later. Sorry about that!";
    if (/rate limit|security purposes|too many/i.test(m)) return "Too many attempts. Please wait a minute and try again.";
    if (/password should be|weak password/i.test(m)) return "Please choose a stronger password (8+ characters, letters and numbers).";
    if (/same password|different from the old/i.test(m)) return "Your new password must be different from the old one.";
    if (/jwt|session|sign in again/i.test(m)) return "Your session expired. Please sign in again.";
    return m || "Something went wrong. Please try again.";
  }

  let toastTimer;
  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove("show"), 2800);
  }

  function busy(btn, on, text) {
    if (!btn) return;
    if (on) { btn.dataset.label = btn.innerHTML; btn.disabled = true; btn.innerHTML = `<span class="spinner"></span>${text ? esc(text) : ""}`; }
    else { btn.disabled = false; if (btn.dataset.label) btn.innerHTML = btn.dataset.label; }
  }
  function formError(form, msg, field) {
    const el = $(".form-error", form);
    if (el) el.textContent = msg || "";
    $$(".invalid", form).forEach(x => x.classList.remove("invalid"));
    if (field) { const inp = form.elements[field]; if (inp) { inp.classList.add("invalid"); inp.focus(); } }
  }

  /* ---------- local cache (stale-while-revalidate for the live backend) ---------- */
  const cache = {
    get(k) { if (!LIVE) return null; try { const v = JSON.parse(localStorage.getItem("kc:" + k)); return v && v.u === state.uid ? v.d : null; } catch { return null; } },
    set(k, d) { if (!LIVE) return; try { localStorage.setItem("kc:" + k, JSON.stringify({ u: state.uid, t: Date.now(), d })); } catch { /* storage full or blocked */ } },
    clear() { try { Object.keys(localStorage).filter(k => k.startsWith("kc:")).forEach(k => localStorage.removeItem(k)); } catch { /* ignore */ } },
  };
  const pref = {
    get(k, d) { try { const v = localStorage.getItem("kp:" + k); return v == null ? d : JSON.parse(v); } catch { return d; } },
    set(k, v) { try { localStorage.setItem("kp:" + k, JSON.stringify(v)); } catch { /* ignore */ } },
  };

  /* ---------- state ---------- */
  const state = {
    session: null, uid: null, me: null, recovery: false, pendingEmail: "",
    feed: [], feedLoaded: false, feedLoading: false, recycled: false, seenRound: new Set(), matches: null, draft: null, step: 0,
  };
  let cleanup = null;
  function mount(html) {
    if (cleanup) { try { cleanup(); } catch { /* ignore */ } cleanup = null; }
    appEl.innerHTML = html + (LIVE ? "" : `<div class="demo-flag">DEMO</div>`);
    appEl.scrollTop = 0;
  }

  /* ---------- avatars & art ---------- */
  function avatar(p, size = 56) {
    const st = `width:${size}px;height:${size}px`;
    if (p?.photos?.[0]) return `<img class="av ph" style="${st}" src="${esc(p.photos[0])}" alt="" loading="lazy" onload="this.classList.add('ok')">`;
    const [a, b] = pal(p?.id || p?.name);
    return `<div class="av art" style="${st};background:linear-gradient(135deg,${a},${b});font-size:${Math.round(size * .42)}px"><span>${esc((p?.name || "?")[0].toUpperCase())}</span></div>`;
  }
  function bigArt(p) {
    const [a, b] = pal(p.id || p.name);
    return `<div class="art" style="background:linear-gradient(160deg,${a},${b})"><span>${esc((p.name || "?")[0].toUpperCase())}</span></div>`;
  }

  /* ---------- sheets ---------- */
  function sheet(html, cls = "") {
    sheetEl.innerHTML = `<div class="backdrop" data-act="close-sheet"></div><div class="sheet ${cls}" role="dialog" aria-modal="true">${cls.includes("full") ? "" : '<div class="grab"></div>'}${html}</div>`;
    sheetEl.classList.add("open");
    requestAnimationFrame(() => requestAnimationFrame(() => sheetEl.classList.add("show")));
  }
  function overlay(html) {
    sheetEl.innerHTML = html;
    sheetEl.classList.add("open");
    requestAnimationFrame(() => requestAnimationFrame(() => sheetEl.classList.add("show")));
  }
  function closeSheet() {
    sheetEl.classList.remove("show");
    setTimeout(() => { if (!sheetEl.classList.contains("show")) { sheetEl.innerHTML = ""; sheetEl.classList.remove("open"); } }, 300);
  }

  /* ---------- routing ---------- */
  const PUBLIC = ["welcome", "signin", "signup", "forgot", "verify"];
  const route = () => { const [name, arg] = location.hash.replace(/^#\/?/, "").split("/"); return { name: name || "", arg: arg ? decodeURIComponent(arg) : "" }; };
  function go(path) { if (location.hash === "#/" + path) render(); else location.hash = "/" + path; }
  window.addEventListener("hashchange", () => { closeSheet(); render(); });

  function render() {
    const r = route();
    if (state.recovery || (r.name === "reset" && api.canReset())) return screens.reset();
    if (!state.session) {
      if (!PUBLIC.includes(r.name)) return go("welcome");
      return screens[r.name](r.arg);
    }
    if (!state.me) return screens.loading();
    if (!state.me.onboarded) { if (r.name !== "setup") return go("setup"); return screens.setup(); }
    if (!r.name || PUBLIC.includes(r.name) || r.name === "setup") return go("discover");
    (screens[r.name] || screens.discover)(r.arg);
  }

  function tabs(active) {
    const unread = (state.matches || []).reduce((n, m) => n + (m.unread ? 1 : 0), 0);
    const t = (id, icon, text, badge) => `<a href="#/${id}" class="${active === id ? "on" : ""}" aria-label="${text}">${icon}<span>${text}</span>${badge ? `<span class="badge">${badge}</span>` : ""}</a>`;
    return `<nav class="tabs">${t("discover", I.mark, "Discover")}${t("matches", I.chat, "Matches", unread)}${t("profile", I.user, "Profile")}</nav>`;
  }
  const offlineBar = () => (navigator.onLine ? "" : `<div class="offline">You're offline — showing saved data</div>`);

  /* ---------- screens ---------- */
  const screens = {};

  screens.loading = () => mount(`<div class="screen" style="justify-content:center;align-items:center">${MARK(64)}</div>`);

  screens.welcome = () => {
    const faces = [{ id: "a", name: "Aminata" }, { id: "b", name: "Mohamed" }, { id: "c", name: "Marie" }];
    mount(`<div class="screen welcome">
      <div class="welcome-hero" aria-hidden="true">
        ${faces.map((f, i) => `<div class="hero-card c${i + 1}">${bigArt(f)}<span class="art-name">${f.name}</span></div>`).join("")}
        <div class="hero-heart">${I.heart}</div>
      </div>
      <div class="welcome-body">
        <div class="brand-row">${MARK(38)}<span class="wordmark">kindred</span></div>
        <h1>Where Salone hearts meet</h1>
        <p class="muted">Meet genuine people across Sierra Leone — from Freetown to Kenema — who share your values.</p>
        <a class="btn primary" href="#/signup">Create account</a>
        <a class="btn ghost" href="#/signin">I already have an account</a>
        ${/iphone|ipad|ipod/i.test(navigator.userAgent) ? "" : `<a class="btn soft" href="../download/kindred.apk" download>${I.phone}Get the Android app <span class="muted sm" style="font-weight:600">· 37 MB</span></a>`}
        <p class="fine">Kindred is for adults 18+. By continuing you agree to our <a href="#" data-act="guidelines">Community Guidelines</a>.</p>
      </div>
    </div>`);
  };

  const authTop = back => `<header class="top plain"><a class="icon-btn" href="#/${back}" aria-label="Back">${I.back}</a></header>`;
  const pwField = (name, labelText, auto, strength) => `<label class="field"><span>${labelText}</span><div class="pw"><input name="${name}" type="password" autocomplete="${auto}" required ${strength ? "data-strength" : ""}><button type="button" class="pw-toggle" data-act="pw-toggle" aria-label="Show password">${I.eye}</button></div>${strength ? `<div class="meter"><i></i></div><small class="meter-label">Use 8+ characters with letters and numbers.</small>` : ""}</label>`;

  screens.signup = () => mount(`<div class="screen">${authTop("welcome")}
    <main class="scroll pad">
      <h1 class="title">Create your account</h1>
      <p class="muted">It takes less than a minute.</p>
      <form data-form="signup" novalidate>
        <label class="field"><span>First name</span><input name="name" autocomplete="given-name" maxlength="40" required></label>
        <label class="field"><span>Email</span><input name="email" type="email" autocomplete="email" inputmode="email" autocapitalize="off" required></label>
        <label class="field"><span>Date of birth</span><input name="birthdate" type="date" min="1920-01-01" max="${maxDob()}" required><small>You must be 18+. Only your age is shown, never your birthday.</small></label>
        ${pwField("password", "Password", "new-password", true)}
        <label class="check"><input type="checkbox" name="agree"><span>I'm 18 or older and I agree to the <a href="#" data-act="guidelines">Community Guidelines</a>.</span></label>
        <p class="form-error" role="alert"></p>
        <button class="btn primary" type="submit">Create account</button>
      </form>
      <p class="center muted sm" style="margin-top:20px">Already have an account? <a href="#/signin">Sign in</a></p>
    </main></div>`);

  screens.signin = () => mount(`<div class="screen">${authTop("welcome")}
    <main class="scroll pad">
      <h1 class="title">Welcome back</h1>
      <p class="muted">Sign in to see who's waiting for you.</p>
      <form data-form="signin" novalidate>
        <label class="field"><span>Email</span><input name="email" type="email" autocomplete="email" inputmode="email" autocapitalize="off" required value="${esc(state.pendingEmail)}"></label>
        ${pwField("password", "Password", "current-password")}
        <p style="text-align:right;margin:10px 4px 0"><a href="#/forgot" class="sm">Forgot password?</a></p>
        <p class="form-error" role="alert"></p>
        <button class="btn primary" type="submit">Sign in</button>
      </form>
      <p class="center muted sm" style="margin-top:20px">New to Kindred? <a href="#/signup">Create an account</a></p>
    </main></div>`);

  screens.forgot = () => mount(`<div class="screen">${authTop("signin")}
    <main class="scroll pad" id="forgot">
      <h1 class="title">Reset your password</h1>
      <p class="muted">Enter the email you signed up with and we'll send you a secure link to choose a new password.</p>
      <form data-form="forgot" novalidate>
        <label class="field"><span>Email</span><input name="email" type="email" autocomplete="email" inputmode="email" autocapitalize="off" required value="${esc(state.pendingEmail)}"></label>
        <p class="form-error" role="alert"></p>
        <button class="btn primary" type="submit">Send reset link</button>
      </form>
    </main></div>`);

  function inboxBlock(email, kind) {
    return `<div class="center">
      <div class="verify-art">${I.mail}</div>
      <h1 class="title">Check your inbox</h1>
      <p class="muted">We sent ${kind === "reset" ? "a password reset link" : "a confirmation link"} to<br><b style="color:var(--text)">${esc(email)}</b></p>
      <p class="muted sm">It can take a minute. Check Spam or Promotions if you don't see it.</p>
    </div>
    ${isGmail(email) ? `<a class="btn primary" href="https://mail.google.com/mail/u/0/#search/from%3Akindred" target="_blank" rel="noopener">${I.mail}Open Gmail</a>` : ""}
    <button class="btn ghost" data-act="resend" data-kind="${kind}" data-email="${esc(email)}">Resend email</button>
    ${!LIVE && kind === "reset" ? `<button class="btn soft" data-act="demo-reset">Open reset link (demo)</button><p class="fine">Demo mode doesn't send real emails.</p>` : ""}
    <a class="btn ghost" href="#/signin" style="border:0">Back to sign in</a>`;
  }

  screens.verify = () => {
    if (!state.pendingEmail) return go("signin");
    mount(`<div class="screen">${authTop("welcome")}<main class="scroll pad">${inboxBlock(state.pendingEmail, "signup")}
      <p class="fine">After you confirm, you'll come straight back here and finish your profile.</p></main></div>`);
  };

  screens.reset = () => mount(`<div class="screen"><header class="top plain"></header>
    <main class="scroll pad">
      <h1 class="title">Choose a new password</h1>
      <p class="muted">Make it something you don't use anywhere else.</p>
      <form data-form="reset" novalidate>
        ${pwField("password", "New password", "new-password", true)}
        ${pwField("confirm", "Confirm new password", "new-password")}
        <p class="form-error" role="alert"></p>
        <button class="btn primary" type="submit">Save new password</button>
      </form>
    </main></div>`);

  /* ---------- onboarding ---------- */
  const STEPS = ["About you", "Photos", "Basics", "Your story"];
  screens.setup = () => {
    const me = state.me;
    if (!state.draft) state.draft = { gender: me.gender, show_me: me.show_me || "everyone", birthdate: me.birthdate || "", photos: [...(me.photos || [])], city: me.city || "", job: me.job || "", looking_for: me.looking_for, religion: me.religion, bio: me.bio || "", interests: [...(me.interests || [])], languages: [...(me.languages || ["Krio", "English"])] };
    const d = state.draft, s = state.step;
    const body = [
      () => `<h1 class="title">Kushɛ, ${esc(me.name)}! 👋</h1><p class="muted">Let's set up your profile so the right people can find you.</p>
        ${me.birthdate ? "" : `<label class="field"><span>Date of birth</span><input type="date" data-draft="birthdate" min="1920-01-01" max="${maxDob()}" value="${esc(d.birthdate)}"><small>You must be 18+. It can't be changed later.</small></label>`}
        <div class="label">I am a</div>${segCtl("gender", [["woman", "Woman"], ["man", "Man"]], d.gender)}
        <div class="label">Show me</div>${segCtl("show_me", [["women", "Women"], ["men", "Men"], ["everyone", "Everyone"]], d.show_me)}`,
      () => `<h1 class="title">Add your photos</h1><p class="muted">Profiles with 3 or more clear photos get far more matches. Your first photo is your main one.</p>
        <div id="pgrid" style="margin-top:18px">${photoGrid(d.photos)}</div>
        <p class="fine" style="text-align:left">Tip: use a recent photo where your face is clear. No group photos as your main picture.</p>`,
      () => `<h1 class="title">The basics</h1>
        <label class="field"><span>City or town</span><select data-draft="city"><option value="">Choose…</option>${CITIES.map(c => `<option ${d.city === c ? "selected" : ""}>${c}</option>`).join("")}</select></label>
        <label class="field"><span>Work or study (optional)</span><input data-draft="job" maxlength="60" placeholder="e.g. Nurse, Fourah Bay College student" value="${esc(d.job)}"></label>
        <div class="label">I'm looking for</div>
        <div class="options">${LOOKING.map(([k, t, em]) => `<button type="button" class="option ${d.looking_for === k ? "on" : ""}" data-act="pick" data-key="looking_for" data-val="${k}"><span class="em">${em}</span>${t}</button>`).join("")}</div>
        <div class="label">Religion (optional)</div>${segCtl("religion", RELIGION.slice(0, 3), d.religion)}`,
      () => `<h1 class="title">Your story</h1>
        <label class="field"><span>About me</span><textarea data-draft="bio" maxlength="500" placeholder="What makes you, you? What are you hoping to find?">${esc(d.bio)}</textarea><small><span id="bioc">${d.bio.length}</span>/500</small></label>
        <div class="label"><span>Interests</span><span>${d.interests.length}/10 · pick at least 3</span></div>
        <div class="chips">${chipSet("interests", INTERESTS, d.interests)}</div>
        <div class="label">Languages I speak</div>
        <div class="chips">${chipSet("languages", LANGUAGES, d.languages)}</div>`,
    ][s]();
    mount(`<div class="screen">
      <header class="top plain">${s > 0 ? `<button class="icon-btn" data-act="step" data-dir="-1" aria-label="Back">${I.back}</button>` : `<button class="icon-btn" data-act="signout" aria-label="Sign out">${I.x}</button>`}<span class="muted sm" style="font-weight:700">Step ${s + 1} of ${STEPS.length}</span><span style="width:42px"></span></header>
      <div class="progress"><i style="width:${((s + 1) / STEPS.length) * 100}%"></i></div>
      <main class="scroll pad" style="padding-top:14px">${body}</main>
      <div class="step-foot"><button class="btn primary" data-act="step" data-dir="1">${s === STEPS.length - 1 ? "Start matching" : "Continue"}</button></div>
    </div>`);
  };
  function segCtl(key, opts, val) {
    return `<div class="seg-ctl" role="radiogroup">${opts.map(([k, t]) => `<button type="button" role="radio" aria-checked="${val === k}" class="${val === k ? "on" : ""}" data-act="pick" data-key="${key}" data-val="${k}">${t}</button>`).join("")}</div>`;
  }
  const chipSet = (key, all, picked) => all.map(t => `<button type="button" class="chip ${picked.includes(t) ? "on" : ""}" data-act="chip" data-key="${key}" data-val="${esc(t)}" aria-pressed="${picked.includes(t)}">${esc(t)}</button>`).join("");
  function photoGrid(photos) {
    return `<div class="photo-grid">${Array.from({ length: 6 }, (_, i) => photos[i]
      ? `<div class="slot filled"><img class="ph" src="${esc(photos[i])}" alt="Photo ${i + 1}" onload="this.classList.add('ok')">${i === 0 ? `<span class="main-tag">Main</span>` : `<button type="button" class="rm" style="left:6px;right:auto;top:auto;bottom:6px;width:auto;padding:0 8px;border-radius:999px;font-size:11px;font-weight:800" data-act="photo-main" data-i="${i}">Make main</button>`}<button type="button" class="rm" data-act="photo-rm" data-i="${i}" aria-label="Remove photo">${I.x}</button></div>`
      : `<label class="slot" aria-label="Add photo"><span class="plus">${I.plus}</span><input type="file" accept="image/*" data-photo></label>`).join("")}</div>`;
  }
  function validateStep(s, d) {
    if (s === 0) {
      if (!state.me.birthdate) {
        if (!d.birthdate) return "Please add your date of birth.";
        if (ageOf(d.birthdate) < 18) return "You must be 18 or older to use Kindred.";
      }
      if (!d.gender) return "Please choose whether you're a woman or a man.";
    }
    if (s === 1 && LIVE && d.photos.length < 1) return "Add at least one photo so people can see you.";
    if (s === 2) { if (!d.city) return "Please choose your city or town."; if (!d.looking_for) return "Tell people what you're looking for."; }
    if (s === 3 && d.interests.length < 3) return "Pick at least 3 interests.";
    return "";
  }

  /* ---------- discover ---------- */
  screens.discover = () => {
    mount(`<div class="screen">${offlineBar()}
      <header class="top"><div class="brand-row sm">${MARK(30)}<span class="wordmark">kindred</span></div>
        <button class="icon-btn" data-act="filters" aria-label="Discovery filters">${I.sliders}</button></header>
      <main class="deck-wrap"><div class="deck" id="deck"></div>
        <div class="deck-actions" id="deck-actions">
          <button class="round nope" data-act="swipe" data-dir="pass" aria-label="Pass">${I.x}</button>
          <button class="round super" data-act="swipe" data-dir="super" aria-label="Super like">${I.star}</button>
          <button class="round like" data-act="swipe" data-dir="like" aria-label="Like">${I.heart}</button>
        </div></main>
      ${tabs("discover")}</div>`);
    if (!state.feedLoaded) { deckSkeleton(); loadFeed(); } else drawDeck();
    if (!state.matches) refreshMatches().then(() => { const nav = $(".tabs"); if (nav && route().name === "discover") nav.outerHTML = tabs("discover"); });
    const onKey = e => {
      if (sheetEl.classList.contains("open") || /input|textarea|select/i.test(e.target.tagName)) return;
      const top = topCard(); if (!top) return;
      if (e.key === "ArrowRight") fling(top, "like"); else if (e.key === "ArrowLeft") fling(top, "pass"); else if (e.key === "ArrowUp") fling(top, "super");
    };
    document.addEventListener("keydown", onKey);
    cleanup = () => document.removeEventListener("keydown", onKey);
  };

  function deckSkeleton() {
    const deck = $("#deck"); if (!deck) return;
    deck.innerHTML = `<div class="card sk" style="cursor:default;box-shadow:none"><div style="position:absolute;left:20px;right:20px;bottom:26px">
      <div class="sk-line" style="width:55%;height:28px;background:rgba(255,255,255,.55);border-radius:10px"></div>
      <div class="sk-line" style="width:40%;background:rgba(255,255,255,.45);border-radius:8px"></div>
      <div style="display:flex;gap:8px;margin-top:14px"><div style="width:70px;height:28px;border-radius:14px;background:rgba(255,255,255,.4)"></div><div style="width:90px;height:28px;border-radius:14px;background:rgba(255,255,255,.4)"></div></div></div></div>`;
  }
  // New people first. When there's nobody new, bring back people you passed on, reshuffled,
  // so Discover never ends in a dead end. `forceRecycle` is the "Start over" button.
  async function loadFeed(silent, forceRecycle) {
    if (state.feedLoading) return;
    state.feedLoading = true;
    const city = pref.get("city", "");
    try {
      let list = forceRecycle ? [] : await api.getFeed({ city });
      let recycled = false;
      if (!list.length) { list = await api.getFeed({ city, recycle: true }); recycled = list.length > 0; }
      const have = new Set(state.feed.map(p => p.id));
      if (!silent) state.seenRound = new Set();
      state.feed = silent ? state.feed.concat(list.filter(p => !have.has(p.id) && !state.seenRound.has(p.id))) : list;
      state.feedLoaded = true;
      if (recycled && !state.recycled) toast("You've seen everyone new. Here are people you passed on, reshuffled.");
      state.recycled = recycled;
    } catch (e) { toast(friendly(e)); state.feedLoaded = true; }
    finally { state.feedLoading = false; }
    drawDeck();
  }
  const topCard = () => $$("#deck .card:not([data-gone]):not(.sk)").find(c => c.style.getPropertyValue("--i") === "0");

  function cardHtml(p) {
    const photos = p.photos || [];
    return `<article class="card" data-id="${esc(p.id)}" aria-label="${esc(p.name)}, ${p.age}">
      <div class="card-media">${photos.length ? photos.map((u, k) => `<img class="${k === 0 ? "on" : ""}" src="${esc(u)}" alt="" draggable="false" ${k ? 'loading="lazy"' : ""} onload="this.classList.add('ok')">`).join("") : bigArt(p)}</div>
      ${photos.length > 1 ? `<div class="seg">${photos.map((_, k) => `<i class="${k === 0 ? "on" : ""}"></i>`).join("")}</div>` : ""}
      <div class="stamp like">LIKE</div><div class="stamp nope">NOPE</div><div class="stamp super">SUPER</div>
      <div class="card-info">
        ${recent(p.last_active) ? `<span class="active-pill"><i></i>Recently active</span>` : ""}
        <h2>${esc(p.name)} <span>${p.age ?? ""}</span></h2>
        <p class="meta">${I.pin}${esc(p.city || "Sierra Leone")}${p.job ? ` · ${esc(p.job)}` : ""}</p>
        <div class="chips" style="padding-right:50px">${(p.interests || []).slice(0, 3).map(t => `<span class="chip glass">${esc(t)}</span>`).join("")}</div>
        <button class="info-btn" data-act="view-profile" data-id="${esc(p.id)}" aria-label="More about ${esc(p.name)}">${I.up}</button>
      </div></article>`;
  }

  function drawDeck() {
    const deck = $("#deck"); if (!deck) return;
    $$(".sk, .deck-empty", deck).forEach(x => x.remove());
    const want = state.feed.slice(0, 3);
    $$(".card:not([data-gone])", deck).forEach(el => { if (!want.some(p => p.id === el.dataset.id)) el.remove(); });
    want.forEach((p, i) => {
      let el = $$(".card:not([data-gone])", deck).find(c => c.dataset.id === p.id);
      if (!el) { const t = document.createElement("template"); t.innerHTML = cardHtml(p).trim(); el = t.content.firstChild; deck.prepend(el); }
      el.style.setProperty("--i", String(i));
      el.style.zIndex = String(10 - i);
      if (i === 0 && !el.dataset.drag) attachDrag(el);
    });
    const actions = $("#deck-actions");
    if (actions) actions.style.visibility = want.length ? "visible" : "hidden";
    if (!want.length && state.feedLoaded && !state.feedLoading) {
      const city = pref.get("city", "");
      deck.insertAdjacentHTML("beforeend", `<div class="deck-empty">
        <div class="pulse">${avatar(state.me, 76)}</div>
        <h2>You've seen everyone for now</h2>
        <p class="muted">${city ? `There's no one new in ${esc(city)} right now. Try all of Sierra Leone, or widen your age range.` : "New people join Kindred every day. Check back soon, or widen your filters."}</p>
        <button class="btn primary sm" style="width:auto" data-act="start-over">${I.refresh}Start over</button>
        <button class="btn soft sm" style="width:auto" data-act="filters">${I.sliders}Adjust filters</button>
        <button class="btn ghost sm" style="width:auto;border:0" data-act="refresh-feed">Check for new people</button></div>`);
    }
  }

  function setStamps(card, dx, dy) {
    const like = $(".stamp.like", card), nope = $(".stamp.nope", card), sup = $(".stamp.super", card);
    const up = dy < -40 && Math.abs(dx) < 80;
    like.style.opacity = up ? 0 : Math.max(0, Math.min(1, dx / 100));
    nope.style.opacity = up ? 0 : Math.max(0, Math.min(1, -dx / 100));
    sup.style.opacity = up ? Math.min(1, -dy / 120) : 0;
  }
  function attachDrag(card) {
    card.dataset.drag = "1";
    let sx = 0, sy = 0, dx = 0, dy = 0, down = false, moved = false, t0 = 0;
    card.addEventListener("pointerdown", e => {
      if (e.target.closest("button") || card.dataset.gone) return;
      down = true; moved = false; sx = e.clientX; sy = e.clientY; dx = dy = 0; t0 = performance.now();
      card.setPointerCapture(e.pointerId);
      card.style.transition = "none";
    });
    card.addEventListener("pointermove", e => {
      if (!down) return;
      dx = e.clientX - sx; dy = e.clientY - sy;
      if (Math.abs(dx) + Math.abs(dy) > 6) moved = true;
      if (!moved) return;
      card.style.transform = `translate(${dx}px, ${dy}px) rotate(${dx / 16}deg)`;
      setStamps(card, dx, dy);
    });
    const end = e => {
      if (!down) return;
      down = false;
      if (!moved) { tapPhoto(card, e); card.style.transition = ""; return; }
      const v = Math.abs(dx) / Math.max(1, performance.now() - t0);
      if (dx > 110 || (dx > 45 && v > .55)) fling(card, "like");
      else if (dx < -110 || (dx < -45 && v > .55)) fling(card, "pass");
      else if (dy < -130 && Math.abs(dx) < 90) fling(card, "super");
      else { card.style.transition = "transform .4s cubic-bezier(.2,.9,.3,1.2)"; card.style.transform = ""; setStamps(card, 0, 0); }
    };
    card.addEventListener("pointerup", end);
    card.addEventListener("pointercancel", end);
  }
  function tapPhoto(card, e) {
    const imgs = $$(".card-media img", card); if (imgs.length < 2) return;
    const r = card.getBoundingClientRect();
    if (e.clientY > r.bottom - 150) return;
    let i = imgs.findIndex(x => x.classList.contains("on"));
    i = e.clientX - r.left < r.width / 3 ? Math.max(0, i - 1) : Math.min(imgs.length - 1, i + 1);
    imgs.forEach((x, k) => x.classList.toggle("on", k === i));
    $$(".seg i", card).forEach((x, k) => x.classList.toggle("on", k === i));
  }

  async function fling(card, action) {
    if (!card || card.dataset.gone) return;
    const p = state.feed.find(x => x.id === card.dataset.id);
    if (!p) return;
    card.dataset.gone = "1";
    const w = card.offsetWidth * 1.6;
    const x = action === "like" ? w : action === "pass" ? -w : 0;
    const y = action === "super" ? -card.offsetHeight * 1.4 : 40;
    card.style.transition = "transform .45s cubic-bezier(.3,.6,.3,1), opacity .45s";
    card.style.transform = `translate(${x}px, ${y}px) rotate(${x / 22}deg)`;
    setStamps(card, action === "like" ? 200 : action === "pass" ? -200 : 0, action === "super" ? -200 : 0);
    if (navigator.vibrate) try { navigator.vibrate(action === "pass" ? 8 : 18); } catch { /* ignore */ }
    state.feed = state.feed.filter(q => q.id !== p.id);
    state.seenRound.add(p.id);
    setTimeout(() => card.remove(), 460);
    drawDeck();
    try {
      const matchId = await api.swipe(p.id, action);
      if (matchId) { shownMatch = matchId; showMatch(p, matchId); refreshMatches(); }
    } catch (e) {
      toast(friendly(e));
      state.feed.unshift(p); drawDeck();
    }
    if (state.feed.length < 4 && !state.feedLoading) loadFeed(true);
  }

  function showMatch(p, matchId) {
    const hearts = Array.from({ length: 14 }, (_, i) => `<i style="left:${(i * 7.3) % 100}%;animation-delay:${(i * .23) % 3}s;font-size:${16 + (i % 4) * 6}px">${i % 3 ? "💗" : "✨"}</i>`).join("");
    overlay(`<div class="match" role="dialog" aria-label="It's a match">
      <div class="hearts" aria-hidden="true">${hearts}</div>
      <h2>It's a match!</h2>
      <p>You and ${esc(p.name)} like each other.</p>
      <div class="pair">${avatar(state.me, 124)}${avatar(p, 124)}</div>
      <a class="btn primary" href="#/chat/${encodeURIComponent(matchId)}">${I.chat}Say hello to ${esc(p.name)}</a>
      <button class="btn ghost" data-act="close-sheet">Keep swiping</button>
    </div>`);
    if (navigator.vibrate) try { navigator.vibrate([20, 60, 30]); } catch { /* ignore */ }
  }

  function profileView(p, ctx) {
    const photos = p.photos || [];
    return `<button class="sheet-close" data-act="close-sheet" aria-label="Close">${I.x}</button>
      <div class="pv">
        <div class="pv-photo" id="pv-photo">${photos.length ? `<img class="ph" src="${esc(photos[0])}" alt="" onload="this.classList.add('ok')">` : bigArt(p)}</div>
        ${photos.length > 1 ? `<div class="pv-thumbs">${photos.map((u, i) => `<img src="${esc(u)}" class="${i === 0 ? "on" : ""}" data-act="pv-thumb" data-src="${esc(u)}" alt="Photo ${i + 1}">`).join("")}</div>` : ""}
        <h2>${esc(p.name)}, ${p.age ?? ""}</h2>
        ${p.last_active ? `<p class="muted sm" style="margin:0">${seenText(p.last_active)}</p>` : ""}
        <div class="facts">
          <div>${I.pin}${esc(p.city || "Sierra Leone")}</div>
          ${p.job ? `<div>${I.work}${esc(p.job)}</div>` : ""}
          ${p.looking_for ? `<div>${I.search}Looking for: ${esc(label(LOOKING, p.looking_for).toLowerCase())}</div>` : ""}
          ${p.religion && p.religion !== "prefer_not" ? `<div>${I.globe}${esc(label(RELIGION, p.religion))}</div>` : ""}
        </div>
        ${p.bio ? `<h4>About</h4><p class="bio">${esc(p.bio)}</p>` : ""}
        ${(p.interests || []).length ? `<h4>Interests</h4><div class="chips">${p.interests.map(t => `<span class="chip">${esc(t)}</span>`).join("")}</div>` : ""}
        ${(p.languages || []).length ? `<h4>Speaks</h4><div class="chips">${p.languages.map(t => `<span class="chip">${esc(t)}</span>`).join("")}</div>` : ""}
        ${ctx === "discover" ? `<div class="deck-actions" style="margin-top:14px"><button class="round nope" data-act="sheet-swipe" data-dir="pass" data-id="${esc(p.id)}" aria-label="Pass">${I.x}</button><button class="round super" data-act="sheet-swipe" data-dir="super" data-id="${esc(p.id)}" aria-label="Super like">${I.star}</button><button class="round like" data-act="sheet-swipe" data-dir="like" data-id="${esc(p.id)}" aria-label="Like">${I.heart}</button></div>` : ""}
        ${ctx !== "self" ? `<button class="btn ghost sm" data-act="report" data-id="${esc(p.id)}" data-name="${esc(p.name)}">${I.flag}Report ${esc(p.name)}</button>` : ""}
      </div>`;
  }

  function filtersSheet() {
    const me = state.me, city = pref.get("city", "");
    sheet(`<h3>Discovery settings</h3><p class="muted sm" style="margin:0 0 6px">Who you'd like to see on Kindred.</p>
      <form data-form="filters">
        <div class="label">Show me</div>${segCtl("f_show", [["women", "Women"], ["men", "Men"], ["everyone", "Everyone"]], me.show_me)}
        <input type="hidden" name="show_me" value="${esc(me.show_me)}">
        <div class="label"><span>Age range</span><span id="agev">${me.age_min} – ${me.age_max}</span></div>
        <div class="range-row"><span>From</span><input type="range" name="age_min" min="18" max="70" value="${me.age_min}" data-age></div>
        <div class="range-row"><span>To</span><input type="range" name="age_max" min="18" max="70" value="${Math.min(70, me.age_max)}" data-age></div>
        <label class="field"><span>Location</span><select name="city"><option value="">Anywhere in Sierra Leone</option>${CITIES.map(c => `<option ${city === c ? "selected" : ""}>${c}</option>`).join("")}</select></label>
        <button class="btn primary" type="submit">Show people</button>
      </form>`);
  }

  /* ---------- matches ---------- */
  async function refreshMatches() {
    try {
      state.matches = await api.getMatches();
      cache.set("matches", state.matches);
    } catch (e) { if (!state.matches) state.matches = cache.get("matches"); }
    return state.matches;
  }
  screens.matches = () => {
    const ask = LIVE && canNotify() && Notification.permission === "default" && !pref.get("alerts-asked", false);
    mount(`<div class="screen">${offlineBar()}<header class="top"><h1>Matches</h1></header>
      ${ask ? `<div class="alerts-ask">${I.bell}<span><b>Never miss a match</b><small>Get alerts for likes, matches, messages and calls.</small></span>
        <button class="btn primary sm" data-act="alerts-on">Turn on</button><button class="icon-btn" data-act="alerts-later" aria-label="Not now">${I.x}</button></div>` : ""}
      <main class="scroll" id="mlist"></main>${tabs("matches")}</div>`);
    const shown = state.matches || cache.get("matches");
    if (shown) drawMatches(shown); else matchesSkeleton();
    refreshMatches().then(list => { if (route().name === "matches" && list) { drawMatches(list); const nav = $(".tabs"); if (nav) nav.outerHTML = tabs("matches"); } });
  };
  function matchesSkeleton() {
    const el = $("#mlist"); if (!el) return;
    el.innerHTML = `<div class="section-title"><span class="sk" style="width:110px;height:12px;display:inline-block"></span></div>
      <div class="new-row">${Array.from({ length: 4 }, () => `<div style="width:72px;flex:none"><div class="sk sk-circle" style="width:72px;height:72px"></div><div class="sk sk-line" style="width:50px;margin:8px auto"></div></div>`).join("")}</div>
      <div class="section-title"><span class="sk" style="width:90px;height:12px;display:inline-block"></span></div>
      ${Array.from({ length: 5 }, () => `<div class="row"><div class="sk sk-circle" style="width:60px;height:60px;flex:none"></div><div class="body"><div class="sk sk-line" style="width:40%;height:14px"></div><div class="sk sk-line" style="width:75%"></div></div></div>`).join("")}`;
  }
  function drawMatches(list) {
    const el = $("#mlist"); if (!el) return;
    const fresh = list.filter(m => !m.last_message_at), convos = list.filter(m => m.last_message_at);
    if (!list.length) {
      el.innerHTML = `<div class="empty"><div class="pulse" style="margin:10px auto 0">${MARK(56)}</div><h3>No matches yet</h3><p>When someone you like likes you back, they'll show up here. Keep swiping!</p><a class="btn primary" href="#/discover" style="max-width:240px;margin:16px auto 0">Discover people</a></div>`;
      return;
    }
    el.innerHTML = `
      ${fresh.length ? `<div class="section-title">New matches <span class="badge">${fresh.length}</span></div>
        <div class="new-row">${fresh.map(m => `<a href="#/chat/${encodeURIComponent(m.id)}"><span class="ring">${avatar(m.other, 68)}</span>${esc(m.other.name)}</a>`).join("")}</div>` : ""}
      <div class="section-title">Messages</div>
      ${convos.length ? convos.map(m => `<a class="row" href="#/chat/${encodeURIComponent(m.id)}">${avatar(m.other, 60)}
          <div class="body"><div class="name">${esc(m.other.name)}${recent(m.other.last_active) ? `<span class="dot" style="background:var(--good);width:8px;height:8px"></span>` : ""}</div>
          <div class="preview ${m.unread ? "unread" : ""}">${m.last_sender === state.uid ? "You: " : ""}${esc(m.last_body || "")}</div></div>
          <div style="display:flex;flex-direction:column;align-items:flex-end;gap:6px"><span class="when">${fmtWhen(m.last_message_at)}</span>${m.unread ? `<span class="badge">${m.unread}</span>` : ""}</div></a>`).join("")
        : `<p class="empty" style="padding:20px 30px">Say hello to one of your new matches — a simple "Kushɛ!" works wonders.</p>`}`;
  }

  /* ---------- chat ---------- */
  let chatMsgs = [], chatMatch = null;
  screens.chat = async id => {
    let m = (state.matches || cache.get("matches") || []).find(x => x.id === id);
    if (!m) { screens.loading(); await refreshMatches(); m = (state.matches || []).find(x => x.id === id); }
    if (!m) { toast("This match is no longer available."); return go("matches"); }
    if (route().name !== "chat") return;
    chatMatch = m;
    const o = m.other;
    mount(`<div class="screen">${offlineBar()}
      <header class="top chat-top"><a class="icon-btn" href="#/matches" aria-label="Back">${I.back}</a>
        <button class="who" data-act="chat-profile">${avatar(o, 42)}<span><b>${esc(o.name)}</b><small>${esc(seenText(o.last_active) || o.city || "")}</small></span></button>
        ${canCall() ? `<button class="icon-btn" data-act="call-voice" aria-label="Voice call" title="Voice call">${I.call}</button><button class="icon-btn" data-act="call-video" aria-label="Video call" title="Video call">${I.video}</button>` : ""}
        <button class="icon-btn" data-act="chat-menu" aria-label="More options">${I.more}</button></header>
      <div class="msgs" id="msgs"></div>
      <div class="ice" id="ice" hidden>${ICEBREAKERS.map(t => `<button data-act="ice">${esc(t)}</button>`).join("")}</div>
      <form class="composer" data-form="send"><label class="attach" aria-label="Send a photo or video" title="Send a photo or video">${I.image}<input type="file" accept="image/*,video/*" data-chatmedia hidden></label><textarea name="body" rows="1" maxlength="2000" placeholder="Message ${esc(o.name)}…" aria-label="Message"></textarea>
        <button class="send" type="submit" aria-label="Send" disabled>${I.send}</button></form>
    </div>`);
    chatMsgs = cache.get("msgs:" + id) || []; chatCalls = [];
    if (chatMsgs.length) drawMsgs(); else $("#msgs").innerHTML = Array.from({ length: 5 }, (_, i) => `<div class="sk" style="height:40px;width:${[55, 40, 65, 35, 50][i]}%;border-radius:20px;margin:6px 0;align-self:${i % 2 ? "flex-end" : "flex-start"}"></div>`).join("");
    let typingTimer;
    const unsub = api.subscribe(id, evt => {
      if (evt.type === "typing") { const box = $("#msgs"); if (box && !$(".typing", box)) { box.insertAdjacentHTML("beforeend", `<div class="typing" aria-label="${esc(o.name)} is typing"><i></i><i></i><i></i></div>`); box.scrollTop = box.scrollHeight; } clearTimeout(typingTimer); typingTimer = setTimeout(() => $(".typing")?.remove(), 6000); return; }
      if (evt.type === "read") { api.getMessages(id).then(list => { mergeMsgs(list); drawMsgs(); }).catch(() => {}); return; }
      const msg = evt.message;
      if (msg.sender !== state.uid) { clearTimeout(typingTimer); $(".typing")?.remove(); }
      if (!chatMsgs.some(x => x.id === msg.id)) { chatMsgs = chatMsgs.filter(x => !(x._temp && x.sender === msg.sender && x.body === msg.body)); chatMsgs.push(msg); }
      drawMsgs();
      if (msg.sender !== state.uid) api.markRead(id).catch(() => {});
    });
    cleanup = () => { unsub(); clearTimeout(typingTimer); mediaNodes.clear(); };
    try {
      const list = await api.getMessages(id);
      if (route().name !== "chat" || chatMatch?.id !== id) return;
      mergeMsgs(list); drawMsgs(); loadCallLog();
      api.markRead(id).then(() => { m.unread = 0; }).catch(() => {});
    } catch (e) { toast(friendly(e)); if (!chatMsgs.length) drawMsgs(); }
  };
  function mergeMsgs(list) {
    const temps = chatMsgs.filter(x => x._temp && !list.some(y => y.sender === x.sender && y.body === x.body));
    chatMsgs = list.concat(temps);
    cache.set("msgs:" + chatMatch.id, list.slice(-80));
  }
  function drawMsgs() {
    const box = $("#msgs"); if (!box || !chatMatch) return;
    const o = chatMatch.other;
    const typing = $(".typing", box) ? `<div class="typing"><i></i><i></i><i></i></div>` : "";
    let html = `<div class="chat-intro">${avatar(o, 84)}<p>You matched with <b style="color:var(--text)">${esc(o.name)}</b> ${chatMatch.created_at ? "· " + esc(/^(Today|Yesterday)$/.test(fmtDay(chatMatch.created_at)) ? fmtDay(chatMatch.created_at).toLowerCase() : "on " + fmtDay(chatMatch.created_at)) : ""}</p>
      <div class="safety-note">${I.shield}<span><b style="color:var(--text)">Stay safe.</b> Keep chats on Kindred until you trust someone. Never send money or Orange Money / Afrimoney to someone you haven't met.</span></div></div>`;
    let lastDay = "";
    const lastMine = [...chatMsgs].reverse().find(x => x.sender === state.uid);
    const timeline = chatCalls.length ? chatMsgs.concat(chatCalls.map(c => ({ ...c, _call: true }))).sort((a, b) => new Date(a.created_at) - new Date(b.created_at)) : chatMsgs;
    timeline.forEach(msg => {
      const day = new Date(msg.created_at).toDateString();
      if (day !== lastDay) { html += `<div class="day">${esc(fmtDay(msg.created_at))}</div>`; lastDay = day; }
      if (msg._call) { html += callLogRow(msg); return; }
      const mine = msg.sender === state.uid;
      if (msg.kind === "image" || msg.kind === "video") {
        // Received media starts blurred until tapped, so nobody is shown an unwanted photo.
        const hidden = !mine && !revealed.has(msg.id);
        html += `<div class="bubble media ${mine ? "me" : "them"} ${msg._temp ? "pending" : ""} ${msg._failed ? "failed" : ""} ${hidden ? "blurred" : ""}" data-media="${esc(msg.id)}" data-kind="${msg.kind}" data-path="${esc(msg._local ? "" : msg.media_path || "")}" ${msg._local ? `data-local="${esc(msg._local)}"` : ""}>
          <div class="media-box sk"></div>
          ${hidden ? `<button class="reveal" data-act="reveal-media" data-id="${esc(msg.id)}">${msg.kind === "video" ? "🎥 Video" : "📷 Photo"}<small>Tap to view</small></button>` : ""}
          ${msg.body ? `<div class="caption">${esc(msg.body)}</div>` : ""}</div>`;
      } else {
        html += `<div class="bubble ${mine ? "me" : "them"} ${msg._temp ? "pending" : ""} ${msg._failed ? "failed" : ""}">${esc(msg.body)}</div>`;
      }
      if (msg === lastMine) html += `<div class="msg-meta me">${msg._failed ? "Not sent · tap send to retry" : msg._temp ? "Sending…" : msg.read_at ? "Seen" : "Sent " + fmtWhen(msg.created_at)}</div>`;
    });
    box.innerHTML = html + typing;
    box.scrollTop = box.scrollHeight;
    const ice = $("#ice"); if (ice) ice.hidden = chatMsgs.length > 0;
    $$(".bubble.media", box).forEach(el => fillMedia(el));
  }

  /* ---------- chat photos & videos ---------- */
  const revealed = new Set();
  // Photo/video boxes by message id. drawMsgs rebuilds the whole list, so we move the existing
  // box back in instead of re-signing and re-downloading the file on every redraw.
  const mediaNodes = new Map();
  async function fillMedia(el, retried) {
    const boxEl = $(".media-box", el); if (!boxEl) return;
    const id = el.dataset.media, path = el.dataset.path, blurred = el.classList.contains("blurred");
    const saved = path && mediaNodes.get(id);
    if (saved && saved.blurred === blurred) { boxEl.replaceWith(saved.node); return; }
    const fail = () => {
      mediaNodes.delete(id);
      boxEl.classList.remove("sk");
      boxEl.innerHTML = `<button type="button" class="media-retry">Couldn't load<small>Tap to retry</small></button>`;
      $(".media-retry", boxEl).addEventListener("click", e => { e.stopPropagation(); if (path) api.forgetMediaUrl(path); boxEl.classList.add("sk"); boxEl.innerHTML = ""; fillMedia(boxEl.closest(".bubble.media") || el); });
    };
    // A failed load is usually an expired or bad link: get a fresh one once, then offer a retry.
    const onError = () => {
      if (!boxEl.isConnected && mediaNodes.get(id)?.node !== boxEl) return;
      if (!retried && path) { mediaNodes.delete(id); api.forgetMediaUrl(path); fillMedia(boxEl.closest(".bubble.media") || el, true); } else fail();
    };
    let url = el.dataset.local;
    try { if (!url && path) url = await api.mediaUrl(path); } catch { if (el.isConnected) fail(); return; }
    if (!url || !el.isConnected || $(".media-box", el) !== boxEl) return;
    if (el.dataset.kind === "video") {
      // #t=0.1 makes iOS Safari paint the first frame as a preview.
      boxEl.innerHTML = `<video src="${esc(url)}#t=0.1" ${blurred ? "" : "controls"} playsinline preload="metadata"></video>`;
      const v = $("video", boxEl);
      v.addEventListener("loadedmetadata", () => boxEl.classList.remove("sk"), { once: true });
      v.addEventListener("error", onError, { once: true });
      setTimeout(() => boxEl.classList.remove("sk"), 3000);
    } else {
      // No loading="lazy": iOS WebKit may never start loading an unsized lazy image inside the scrolling chat.
      boxEl.innerHTML = `<img src="${esc(url)}" alt="Photo" decoding="async">`;
      const i = $("img", boxEl);
      i.addEventListener("load", () => boxEl.classList.remove("sk"), { once: true });
      i.addEventListener("error", onError, { once: true });
      if (!blurred) i.addEventListener("click", () => openMediaViewer(url));
    }
    if (path) mediaNodes.set(id, { node: boxEl, blurred });
  }
  function openMediaViewer(url) {
    overlay(`<div class="viewer" data-act="close-sheet"><img src="${esc(url)}" alt="Photo"><button class="sheet-close" data-act="close-sheet" aria-label="Close">${I.x}</button></div>`);
  }
  const videoDuration = file => new Promise(res => {
    const v = document.createElement("video"); v.preload = "metadata";
    v.onloadedmetadata = () => { URL.revokeObjectURL(v.src); res(v.duration); };
    v.onerror = () => res(null);
    v.src = URL.createObjectURL(file);
  });
  async function sendMediaFile(file) {
    if (!file || !chatMatch) return;
    const isVideo = file.type.startsWith("video/"), isImage = file.type.startsWith("image/");
    if (!isVideo && !isImage) return toast("Please choose a photo or a video.");
    let blob = file, ext, meta = {};
    try {
      if (isImage) { blob = await compress(file, 1600, .8); ext = "jpg"; }
      else {
        if (file.size > 15 * 1024 * 1024) return toast("That video is too big. Please send one under 15 MB (about a minute).");
        const d = await videoDuration(file);
        if (d && d > 65) return toast("Please send a video of 1 minute or less.");
        meta.duration = d ? Math.round(d) : null;
        ext = (file.name.split(".").pop() || "mp4").toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 5) || "mp4";
      }
    } catch (e) { return toast(friendly(e)); }
    const local = URL.createObjectURL(blob);
    const temp = { id: "t-" + Date.now(), _temp: true, _local: local, sender: state.uid, body: "", kind: isVideo ? "video" : "image", created_at: new Date().toISOString(), match_id: chatMatch.id };
    chatMsgs.push(temp); drawMsgs();
    try {
      const saved = await api.sendMedia(chatMatch.id, blob, temp.kind, ext, meta);
      chatMsgs = chatMsgs.filter(x => x !== temp);
      if (!chatMsgs.some(x => x.id === saved.id)) chatMsgs.push(saved);
      chatMatch.last_message_at = saved.created_at; chatMatch.last_body = isVideo ? "🎥 Video" : "📷 Photo"; chatMatch.last_sender = state.uid;
      cache.set("msgs:" + chatMatch.id, chatMsgs.filter(x => !x._temp).slice(-80));
    } catch (e) { temp._failed = true; temp._temp = false; toast(friendly(e)); }
    drawMsgs();
  }
  async function sendMsg(body) {
    body = body.trim(); if (!body || !chatMatch) return;
    const temp = { id: "t-" + Date.now(), _temp: true, sender: state.uid, body, created_at: new Date().toISOString(), match_id: chatMatch.id };
    chatMsgs.push(temp); drawMsgs();
    try {
      const saved = await api.sendMessage(chatMatch.id, body);
      chatMsgs = chatMsgs.filter(x => x !== temp);
      if (!chatMsgs.some(x => x.id === saved.id)) chatMsgs.push(saved);
      chatMatch.last_message_at = saved.created_at; chatMatch.last_body = saved.body; chatMatch.last_sender = state.uid;
      cache.set("msgs:" + chatMatch.id, chatMsgs.filter(x => !x._temp).slice(-80));
    } catch (e) { temp._failed = true; temp._temp = false; toast(friendly(e)); }
    drawMsgs();
  }

  /* ---------- voice & video calls ----------
     Peer-to-peer WebRTC. The caller's offer and the callee's answer (with their network candidates already
     gathered) travel through the calls table over Realtime, which is also the call history shown in chat.
     Only a public STUN server is used, so a few strict mobile networks may not connect without a TURN relay. */
  const ICE_SERVERS = [{ urls: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302", "stun:stun.cloudflare.com:3478"] }];
  const CALL_END = ["declined", "busy", "missed", "cancelled", "ended", "failed"];
  let cur = null, callsUnsub = null, ringer = null, chatCalls = [], logTimer;
  const callEl = document.createElement("div"); callEl.id = "call"; callEl.hidden = true; document.body.appendChild(callEl);
  const canCall = () => LIVE && !!api.startCall && !!window.RTCPeerConnection && !!navigator.mediaDevices?.getUserMedia;
  const fmtDur = ms => { const t = Math.max(0, Math.round(ms / 1000)), h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60, s = String(t % 60).padStart(2, "0"); return h ? `${h}:${String(m).padStart(2, "0")}:${s}` : `${m}:${s}`; };

  function watchCalls() {
    if (callsUnsub) { try { callsUnsub(); } catch { /* ignore */ } callsUnsub = null; }
    if (!state.uid || !LIVE || !api.onCalls) { teardown(); return; }
    callsUnsub = api.onCalls(onCallRow);
    api.ringingCalls().then(list => list.forEach(onCallRow)).catch(() => {});
  }
  function onCallRow(c) {
    if (!c?.id) return;
    if (c.callee === state.uid && c.status !== "ringing") callAlertDone(c);
    if (chatMatch?.id === c.match_id && route().name === "chat") { clearTimeout(logTimer); logTimer = setTimeout(loadCallLog, 400); }
    if (c.callee === state.uid && c.status === "ringing" && cur?.c?.id !== c.id) {
      if (cur) { api.updateCall(c.id, "busy").catch(() => {}); return; }
      return incoming(c);
    }
    const S = cur; if (!S || S.c?.id !== c.id) return;
    S.c = { ...S.c, ...c };
    if (c.status === "accepted" && S.role === "caller" && c.answer && !S.answered) {
      S.answered = true; stopRinger(); clearTimeout(S.ringTimer); callStatus("Connecting…");
      S.pc.setRemoteDescription({ type: "answer", sdp: c.answer }).catch(() => hangup("failed", "Couldn't connect the call."));
    } else if (CALL_END.includes(c.status)) {
      const n = S.other.name;
      teardown({ declined: `${n} declined the call`, busy: `${n} is on another call`, missed: S.role === "callee" ? `Missed call from ${n}` : `${n} didn't answer`,
        cancelled: S.role === "callee" ? `Missed call from ${n}` : "", ended: S.started ? `Call ended · ${fmtDur(Date.now() - S.started)}` : "Call ended", failed: "The call dropped" }[c.status]);
    }
  }

  function drawCall(S, status, ringingIn) {
    const o = S.other;
    callEl.hidden = false;
    callEl.className = (S.video ? "video" : "voice") + (callEl.classList.contains("show") ? " show" : "");
    callEl.innerHTML = `<video id="call-remote" autoplay playsinline></video>
      <div class="call-who">${avatar(o, 112)}<div><h2>${esc(o.name)}</h2><p id="call-status">${esc(status)}</p></div></div>
      ${S.video && S.local ? `<video id="call-local" autoplay playsinline muted></video>` : ""}
      <div class="call-bar ${ringingIn ? "ringing" : ""}">${ringingIn ? `
        <button class="cbtn end" data-act="call-decline" aria-label="Decline">${I.phoneOff}<small>Decline</small></button>
        <button class="cbtn ok" data-act="call-accept" aria-label="Accept">${S.video ? I.video : I.call}<small>Accept</small></button>` : `
        <button class="cbtn" data-act="call-mute" aria-label="Mute" aria-pressed="false">${I.mic}</button>
        ${S.video ? `<button class="cbtn" data-act="call-cam" aria-label="Turn camera off" aria-pressed="false">${I.video}</button>
        <button class="cbtn" data-act="call-flip" aria-label="Switch camera">${I.flip}</button>` : ""}
        <button class="cbtn end" data-act="call-end" aria-label="End call">${I.phoneOff}</button>`}</div>`;
    if (S.local) $("#call-local").srcObject = S.local;
    requestAnimationFrame(() => callEl.classList.add("show"));
  }
  function callStatus(t) { const el = $("#call-status"); if (el) el.textContent = t; }
  function newCall(fields) { cur = { pc: null, local: null, c: null, answered: false, started: 0, muted: false, camOff: false, facing: "user", ...fields }; return cur; }

  async function getMedia(S) {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      video: S.video ? { facingMode: S.facing, width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 24 } } : false,
    });
    if (cur !== S) { stream.getTracks().forEach(t => t.stop()); throw new Error("__gone"); }
    S.local = stream;
    if (S.video && !$("#call-local")) $(".call-bar", callEl)?.insertAdjacentHTML("beforebegin", `<video id="call-local" autoplay playsinline muted></video>`);
    const lv = $("#call-local"); if (lv) lv.srcObject = stream;
  }
  function makePc(S) {
    const pc = S.pc = new RTCPeerConnection({ iceServers: ICE_SERVERS });
    S.local.getTracks().forEach(t => pc.addTrack(t, S.local));
    // Safari on iPhone doesn't always autoplay a stream set later (voice calls hide the video), so start it explicitly
    pc.ontrack = e => { const rv = $("#call-remote"); if (rv && e.streams[0] && rv.srcObject !== e.streams[0]) { rv.srcObject = e.streams[0]; rv.play?.().catch(() => {}); } };
    pc.onconnectionstatechange = () => {
      if (cur !== S) return;
      const st = pc.connectionState;
      if (st === "connected") {
        clearTimeout(S.dropTimer);
        if (!S.started) { S.started = Date.now(); S.tick = setInterval(() => callStatus(fmtDur(Date.now() - S.started)), 1000); }
        callEl.classList.add("live"); callStatus(fmtDur(Date.now() - S.started));
      } else if (st === "disconnected") {
        callStatus("Reconnecting…"); clearTimeout(S.dropTimer);
        S.dropTimer = setTimeout(() => cur === S && pc.connectionState !== "connected" && hangup("failed", "The call dropped. The connection was lost."), 12000);
      } else if (st === "failed") {
        hangup("failed", S.started ? "The call dropped. The connection was lost." : "Couldn't connect. One of you may be on a network that blocks calls. Try Wi-Fi.");
      }
    };
    return pc;
  }
  // Send the offer/answer once network candidates are gathered (no trickle ICE needed)
  const iceDone = pc => new Promise(res => {
    if (pc.iceGatheringState === "complete") return res();
    const t = setTimeout(res, 2500);
    pc.addEventListener("icegatheringstatechange", () => { if (pc.iceGatheringState === "complete") { clearTimeout(t); res(); } });
  });
  function mediaError(e) {
    if (e?.message === "__gone") return "";
    const n = e?.name || "";
    if (n === "NotAllowedError" || n === "SecurityError") return "Kindred needs your microphone" + (cur?.video ? " and camera" : "") + " for calls. Allow access in your browser settings and try again.";
    if (n === "NotFoundError" || n === "OverconstrainedError") return "No microphone" + (cur?.video ? " or camera" : "") + " was found on this device.";
    if (n === "NotReadableError") return "Your microphone or camera is being used by another app.";
    return friendly(e);
  }

  async function startCall(video) {
    if (!chatMatch) return;
    if (!canCall()) return toast(LIVE ? "Calls aren't supported in this browser. Try Chrome or the Kindred app." : "Calls work in the live app.");
    if (cur) return toast("You're already on a call.");
    if (!navigator.onLine) return toast("You're offline.");
    const S = newCall({ role: "caller", other: chatMatch.other, video, matchId: chatMatch.id });
    drawCall(S, "Calling…");
    try {
      await getMedia(S);
      const pc = makePc(S);
      await pc.setLocalDescription(await pc.createOffer());
      await iceDone(pc);
      if (cur !== S) return;
      S.c = await api.startCall(S.matchId, video, pc.localDescription.sdp);
      if (cur !== S) { api.updateCall(S.c.id, "cancelled").catch(() => {}); return; }
      callStatus("Ringing…"); startRinger("out"); pollCall(S);
      S.ringTimer = setTimeout(() => cur === S && !S.answered && hangup("missed", `${S.other.name} didn't answer`), 45000);
    } catch (e) { if (cur === S) teardown(mediaError(e)); }
  }
  async function incoming(c) {
    const S = newCall({ role: "callee", c, other: { id: c.caller, name: "Your match" }, video: c.video, matchId: c.match_id });
    let m = (state.matches || cache.get("matches") || []).find(x => x.id === c.match_id);
    if (!m) { await refreshMatches().catch(() => {}); m = (state.matches || []).find(x => x.id === c.match_id); }
    if (cur !== S) return;
    if (m) S.other = m.other;
    drawCall(S, c.video ? "Kindred video call…" : "Kindred voice call…", true);
    startRinger("in");
    try { navigator.vibrate?.([500, 300, 500, 300, 500]); } catch { /* ignore */ }
    S.ringTimer = setTimeout(() => {
      if (cur !== S || S.answered || S.accepting) return;
      callAlertDone({ id: c.id, status: "missed" });
      teardown(`Missed call from ${S.other.name}`);
    }, 45000);
    if (document.visibilityState !== "visible") {
      rang.set(c.id, S.other.name);
      phoneAlert(`${S.other.name} is calling you`, c.video ? "Kindred video call" : "Kindred voice call", "chat/" + c.match_id, "call-" + c.id,
        { requireInteraction: true, vibrate: [500, 300, 500, 300, 500] });
    }
  }
  async function acceptCall() {
    const S = cur; if (!S || S.role !== "callee" || S.accepting) return;
    S.accepting = true; stopRinger(); clearTimeout(S.ringTimer);
    drawCall(S, "Connecting…");
    try {
      await getMedia(S);
      const pc = makePc(S);
      await pc.setRemoteDescription({ type: "offer", sdp: S.c.offer });
      await pc.setLocalDescription(await pc.createAnswer());
      await iceDone(pc);
      if (cur !== S) return;
      const row = await api.updateCall(S.c.id, "accepted", pc.localDescription.sdp);
      if (cur !== S) return;
      if (row?.status === "accepted") { S.answered = true; S.c = { ...S.c, ...row }; pollCall(S); }
      else teardown(`Missed call from ${S.other.name}`);
    } catch (e) { if (cur === S) { api.updateCall(S.c.id, "failed").catch(() => {}); teardown(mediaError(e)); } }
  }
  // Realtime can miss or delay the update carrying the other side's answer, and then the call never connects
  // (the network path opens but the encrypted handshake can't finish). So while a call is being set up, also
  // read its row every 1.5 s and act on any change.
  function pollCall(S) {
    clearInterval(S.poll);
    S.poll = setInterval(async () => {
      if (cur !== S || S.started || !S.c?.id || !api.getCall) return clearInterval(S.poll);
      try {
        const c = await api.getCall(S.c.id);
        if (cur === S && c && (c.status !== S.c.status || (c.answer && !S.c.answer))) onCallRow(c);
      } catch { /* offline: realtime or the next check */ }
    }, 1500);
  }
  function hangup(status, msg) {
    const S = cur; if (!S) return;
    const st = status || (S.answered ? "ended" : S.role === "caller" ? "cancelled" : "declined");
    if (S.c) api.updateCall(S.c.id, st).catch(() => {});
    teardown(msg ?? (S.started ? `Call ended · ${fmtDur(Date.now() - S.started)}` : ""));
  }
  function teardown(msg) {
    const S = cur; if (!S) return;
    cur = null;
    stopRinger(); clearTimeout(S.ringTimer); clearTimeout(S.dropTimer); clearInterval(S.tick); clearInterval(S.poll);
    try { S.pc?.close(); } catch { /* ignore */ }
    S.local?.getTracks().forEach(t => t.stop());
    callEl.classList.remove("show", "live");
    setTimeout(() => { if (!cur) { callEl.hidden = true; callEl.innerHTML = ""; } }, 250);
    if (msg) toast(msg);
    if (chatMatch?.id === S.matchId && route().name === "chat") loadCallLog();
  }

  function startRinger(kind) {
    stopRinger();
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)(), vol = kind === "in" ? .16 : .07;
      const tone = (f, at, len) => {
        const o = ctx.createOscillator(), g = ctx.createGain();
        o.frequency.value = f;
        g.gain.setValueAtTime(0, at); g.gain.linearRampToValueAtTime(vol, at + .03);
        g.gain.setValueAtTime(vol, at + len - .05); g.gain.linearRampToValueAtTime(0, at + len);
        o.connect(g).connect(ctx.destination); o.start(at); o.stop(at + len);
      };
      const play = () => { const t = ctx.currentTime + .05; if (kind === "in") [[880, 0], [660, .45], [880, 1.1], [660, 1.55]].forEach(([f, d]) => tone(f, t + d, .35)); else tone(425, t, 1.2); };
      play();
      ringer = { ctx, iv: setInterval(play, kind === "in" ? 3200 : 4000) };
    } catch { ringer = null; }
  }
  function stopRinger() { if (!ringer) return; clearInterval(ringer.iv); ringer.ctx.close().catch(() => {}); ringer = null; }

  async function loadCallLog() {
    if (!chatMatch || !LIVE || !api.getCalls) return;
    const id = chatMatch.id;
    try { const list = await api.getCalls(id); if (chatMatch?.id !== id || route().name !== "chat") return; chatCalls = list.filter(c => c.status !== "ringing" || cur?.c?.id === c.id); drawMsgs(); } catch { /* history is optional */ }
  }
  function callLogRow(c) {
    const mine = c.caller === state.uid, kind = c.video ? "video" : "voice", Kind = c.video ? "Video" : "Voice";
    const time = new Date(c.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    let text, missed = false;
    if (c.answered_at) text = `${Kind} call${c.ended_at ? " · " + fmtDur(new Date(c.ended_at) - new Date(c.answered_at)) : ""}`;
    else if (mine) text = `${Kind} call · ${{ declined: "Declined", busy: "Busy", missed: "No answer", cancelled: "Cancelled", failed: "Couldn't connect", ringing: "Ringing…" }[c.status] || ""}`;
    else if (c.status === "declined") text = `You declined a ${kind} call`;
    else { text = `Missed ${kind} call`; missed = true; }
    return `<div class="call-log ${missed ? "missed" : ""}">${c.video ? I.video : I.call}<span>${esc(text)}</span><time>${esc(time)}</time>${missed && canCall() ? `<button class="linkbtn" data-act="${c.video ? "call-video" : "call-voice"}">Call back</button>` : ""}</div>`;
  }

  /* ---------- profile ---------- */
  function completeness(p) {
    let s = 0;
    s += Math.min(3, (p.photos || []).length) * 12;
    if (p.bio && p.bio.length > 30) s += 20;
    if ((p.interests || []).length >= 3) s += 12;
    if (p.job) s += 8;
    if (p.city) s += 8;
    if (p.looking_for) s += 8;
    if ((p.languages || []).length) s += 8;
    return Math.min(100, s);
  }
  screens.profile = () => {
    const me = state.me, pct = completeness(me);
    const row = (act, icon, text, extra = "") => `<button class="row ${extra}" data-act="${act}">${icon}<span class="body">${text}</span>${I.chev}</button>`;
    mount(`<div class="screen">${offlineBar()}<header class="top"><h1>Profile</h1></header>
      <main class="scroll" style="padding-bottom:20px">
        <div class="me-head">
          <div class="ring" style="--p:${pct}">${avatar(me, 116)}<span class="pct">${pct}% complete</span></div>
          <h2>${esc(me.name)}, ${me.age ?? ""}</h2>
          <p class="muted sm" style="margin:0">${esc(me.city || "")}${me.job ? " · " + esc(me.job) : ""}</p>
          <div style="display:flex;gap:10px;width:100%;max-width:340px"><a class="btn primary sm" href="#/edit">${I.pencil}Edit profile</a><button class="btn soft sm" data-act="preview-self">${I.eye}Preview</button></div>
        </div>
        <div class="section-title">Discovery</div>
        <div class="card-list">${row("filters", I.sliders, "Discovery settings")}${LIVE ? row("alerts", I.bell, "Notifications") : ""}</div>
        <div class="section-title">Safety</div>
        <div class="card-list">${row("safety", I.shield, "Dating safety tips")}${row("guidelines", I.flag, "Community guidelines")}</div>
        <div class="section-title">Account</div>
        <div class="card-list">
          <div class="row" style="cursor:default">${I.mail}<span class="body"><span class="muted sm">Signed in as</span><br>${esc(state.session?.user?.email || "")}</span></div>
          ${row("change-password", I.lock, "Change password")}
          ${row("signout", I.logout, "Sign out")}
          ${row("delete-account", I.trash, "Delete account", "danger")}
        </div>
        <p class="fine">Kindred ${LIVE ? "" : "· demo mode"} · Made for Salone 🇸🇱</p>
      </main>${tabs("profile")}</div>`);
  };

  screens.edit = () => {
    const me = state.me;
    state.draft = { photos: [...(me.photos || [])], city: me.city || "", job: me.job || "", looking_for: me.looking_for, religion: me.religion, bio: me.bio || "", interests: [...(me.interests || [])], languages: [...(me.languages || [])], name: me.name, gender: me.gender };
    drawEdit();
  };
  function drawEdit() {
    const d = state.draft;
    mount(`<div class="screen"><header class="top plain"><a class="icon-btn" href="#/profile" aria-label="Back">${I.back}</a><b>Edit profile</b><button class="btn primary sm" style="width:auto;margin:0;min-height:40px;padding:0 18px" data-act="save-profile">Save</button></header>
      <main class="scroll pad">
        <div class="label">Photos</div><div id="pgrid">${photoGrid(d.photos)}</div>
        <label class="field"><span>First name</span><input data-draft="name" maxlength="40" value="${esc(d.name)}"></label>
        <div class="label">I am a</div>${segCtl("gender", [["woman", "Woman"], ["man", "Man"]], d.gender)}
        <label class="field"><span>About me</span><textarea data-draft="bio" maxlength="500">${esc(d.bio)}</textarea><small><span id="bioc">${d.bio.length}</span>/500</small></label>
        <label class="field"><span>City or town</span><select data-draft="city"><option value="">Choose…</option>${CITIES.map(c => `<option ${d.city === c ? "selected" : ""}>${c}</option>`).join("")}</select></label>
        <label class="field"><span>Work or study</span><input data-draft="job" maxlength="60" value="${esc(d.job)}"></label>
        <div class="label">Looking for</div>
        <div class="options">${LOOKING.map(([k, t, em]) => `<button type="button" class="option ${d.looking_for === k ? "on" : ""}" data-act="pick" data-key="looking_for" data-val="${k}"><span class="em">${em}</span>${t}</button>`).join("")}</div>
        <div class="label">Religion</div>${segCtl("religion", RELIGION, d.religion)}
        <div class="label"><span>Interests</span><span>${d.interests.length}/10</span></div><div class="chips">${chipSet("interests", INTERESTS, d.interests)}</div>
        <div class="label">Languages</div><div class="chips">${chipSet("languages", LANGUAGES, d.languages)}</div>
      </main></div>`);
  }
  function redrawDraft() { const sc = $(".scroll"); const top = sc ? sc.scrollTop : 0; route().name === "edit" ? drawEdit() : screens.setup(); const sc2 = $(".scroll"); if (sc2) sc2.scrollTop = top; }

  /* ---------- photos: compress on the phone before upload to save data ---------- */
  async function compress(file, max = LIVE ? 1280 : 720, q = LIVE ? .82 : .72) {
    let src;
    try { src = await createImageBitmap(file, { imageOrientation: "from-image" }); }
    catch { src = await new Promise((res, rej) => { const img = new Image(); img.onload = () => res(img); img.onerror = () => rej(new Error("That file isn't a photo we can read. Try a JPG or PNG.")); img.src = URL.createObjectURL(file); }); }
    const scale = Math.min(1, max / Math.max(src.width, src.height));
    const c = document.createElement("canvas");
    c.width = Math.round(src.width * scale); c.height = Math.round(src.height * scale);
    c.getContext("2d").drawImage(src, 0, 0, c.width, c.height);
    return await new Promise((res, rej) => c.toBlob(b => (b ? res(b) : rej(new Error("Couldn't process that photo."))), "image/jpeg", q));
  }
  async function addPhoto(input) {
    const file = input.files?.[0]; if (!file) return;
    if (!file.type.startsWith("image/")) return toast("Please choose a photo.");
    if (state.draft.photos.length >= 6) return toast("You can add up to 6 photos.");
    const slot = input.closest(".slot"); slot.classList.add("uploading");
    try {
      const blob = await compress(file);
      const url = await api.uploadPhoto(blob);
      state.draft.photos.push(url);
    } catch (e) { toast(friendly(e)); }
    const g = $("#pgrid"); if (g) g.innerHTML = photoGrid(state.draft.photos);
  }

  /* ---------- static content ---------- */
  const SAFETY = [
    ["Meet in public", "For the first few dates, meet somewhere busy in daylight — a restaurant, café or popular beach spot. Never at their home or yours."],
    ["Tell a friend", "Share who you're meeting, where and when with someone you trust. Share your live location if you can."],
    ["Get there yourself", "Arrange your own transport — your own okada, keke or taxi — so you can leave whenever you want."],
    ["Never send money", "No genuine match needs your money. Report anyone who asks for cash, Orange Money, Afrimoney, airtime or \"transport fare\"."],
    ["Protect your details", "Don't share your home address, workplace or bank details until you truly know someone."],
    ["Trust your instincts", "If something feels wrong, leave. You can unmatch, block and report anyone at any time — they won't be told who reported them."],
  ];
  const GUIDELINES = [
    ["Be real", "Use your own name, age and recent photos. Fake profiles are removed."],
    ["18+ only", "Kindred is only for adults. Report anyone who looks under 18."],
    ["Be respectful", "No harassment, hate, threats or pressure. No means no."],
    ["Keep it clean", "No nudity, violence or explicit content in photos or messages."],
    ["No scams or selling", "No asking for money, promoting businesses or sharing links to other services."],
  ];
  const tipsHtml = (title, list, intro) => `<h3>${title}</h3>${intro ? `<p class="muted sm" style="margin:0 0 6px">${intro}</p>` : ""}${list.map(([t, d], i) => `<div class="tip"><span class="badge" style="flex:none;margin-top:2px">${i + 1}</span><span><b>${t}</b>${d}</span></div>`).join("")}<button class="btn soft" data-act="close-sheet">Got it</button>`;

  /* ---------- click actions ---------- */
  const actions = {
    "close-sheet": () => closeSheet(),
    "pw-toggle": b => { const inp = b.previousElementSibling; const show = inp.type === "password"; inp.type = show ? "text" : "password"; b.innerHTML = show ? I.eyeOff : I.eye; b.setAttribute("aria-label", show ? "Hide password" : "Show password"); },
    guidelines: (_, e) => { e.preventDefault(); sheet(tipsHtml("Community guidelines", GUIDELINES, "Kindred works because members treat each other with respect.")); },
    alerts: () => alertsSheet(),
    "alerts-on": () => alertsEnable(),
    "alerts-off": () => { pref.set("alerts", false); stopPush(); closeSheet(); toast("Notifications are off."); },
    "alerts-later": () => { pref.set("alerts-asked", true); $(".alerts-ask")?.remove(); },
    safety: () => sheet(tipsHtml("Dating safety tips", SAFETY, "Most people on Kindred are genuine. These habits keep it that way.")),
    resend: async b => {
      if (b.dataset.cool) return;
      busy(b, true);
      try { b.dataset.kind === "reset" ? await api.sendPasswordReset(b.dataset.email) : await api.resendSignup(b.dataset.email); toast("Email sent again."); }
      catch (e) { toast(friendly(e)); }
      busy(b, false);
      let n = 60; b.dataset.cool = "1"; b.disabled = true;
      const t = setInterval(() => { b.textContent = `Resend in ${--n}s`; if (n <= 0) { clearInterval(t); delete b.dataset.cool; b.disabled = false; b.textContent = "Resend email"; } }, 1000);
    },
    "demo-reset": () => go("reset"),
    "call-voice": () => startCall(false),
    "call-video": () => startCall(true),
    "call-accept": () => acceptCall(),
    "call-decline": () => hangup(),
    "call-end": () => hangup(),
    "call-mute": b => {
      const S = cur; if (!S?.local) return;
      S.muted = !S.muted; S.local.getAudioTracks().forEach(t => { t.enabled = !S.muted; });
      b.classList.toggle("on", S.muted); b.setAttribute("aria-pressed", S.muted); b.setAttribute("aria-label", S.muted ? "Unmute" : "Mute"); b.innerHTML = S.muted ? I.micOff : I.mic;
    },
    "call-cam": b => {
      const S = cur; if (!S?.local) return;
      S.camOff = !S.camOff; S.local.getVideoTracks().forEach(t => { t.enabled = !S.camOff; });
      b.classList.toggle("on", S.camOff); b.setAttribute("aria-pressed", S.camOff); b.setAttribute("aria-label", S.camOff ? "Turn camera on" : "Turn camera off"); b.innerHTML = S.camOff ? I.videoOff : I.video;
      $("#call-local")?.classList.toggle("off", S.camOff);
    },
    "call-flip": async () => {
      const S = cur; if (!S?.local || !S.pc) return;
      const facing = S.facing === "user" ? "environment" : "user";
      try {
        const nt = (await navigator.mediaDevices.getUserMedia({ video: { facingMode: { exact: facing }, width: { ideal: 640 }, height: { ideal: 480 } } })).getVideoTracks()[0];
        if (cur !== S) { nt.stop(); return; }
        await S.pc.getSenders().find(x => x.track?.kind === "video")?.replaceTrack(nt);
        S.local.getVideoTracks().forEach(t => { t.stop(); S.local.removeTrack(t); });
        S.local.addTrack(nt); nt.enabled = !S.camOff; S.facing = facing;
        const lv = $("#call-local"); if (lv) { lv.srcObject = S.local; lv.classList.toggle("rear", facing === "environment"); }
      } catch { toast("This device has only one camera."); }
    },
    "reveal-media": b => { revealed.add(b.dataset.id); mediaNodes.delete(b.dataset.id); const el = b.closest(".bubble.media"); el.classList.remove("blurred"); b.remove(); fillMedia(el); },
    "use-email": b => { const f = b.closest("form"); f.elements.email.value = b.dataset.email; formError(f, ""); f.elements.email.focus(); },
    signout: async () => { await stopPush(); await api.signOut(); },
    step: async b => {
      const dir = +b.dataset.dir;
      if (dir < 0) { state.step = Math.max(0, state.step - 1); return screens.setup(); }
      const err = validateStep(state.step, state.draft);
      if (err) return toast(err);
      if (state.step < STEPS.length - 1) { state.step++; return screens.setup(); }
      busy(b, true, "Saving…");
      try {
        const { birthdate, ...rest } = state.draft;
        const patch = { ...rest, onboarded: true };
        if (!state.me.birthdate) patch.birthdate = birthdate;
        state.me = await api.saveProfile(patch);
        cache.set("me", state.me);
        state.draft = null; state.step = 0; state.feedLoaded = false; state.feed = [];
        toast("You're all set! Start discovering 💗");
        go("discover");
      } catch (e) { toast(friendly(e)); busy(b, false); }
    },
    pick: b => { state.draft[b.dataset.key] = b.dataset.val; redrawDraft(); },
    chip: b => {
      const list = state.draft[b.dataset.key], v = b.dataset.val, i = list.indexOf(v);
      if (i >= 0) list.splice(i, 1);
      else { const cap = b.dataset.key === "interests" ? 10 : 8; if (list.length >= cap) return toast(`You can pick up to ${cap}.`); list.push(v); }
      redrawDraft();
    },
    "photo-rm": b => { state.draft.photos.splice(+b.dataset.i, 1); $("#pgrid").innerHTML = photoGrid(state.draft.photos); },
    "photo-main": b => { const [p] = state.draft.photos.splice(+b.dataset.i, 1); state.draft.photos.unshift(p); $("#pgrid").innerHTML = photoGrid(state.draft.photos); },
    "save-profile": async b => {
      const d = state.draft;
      if (!d.name.trim()) return toast("Please enter your first name.");
      if (LIVE && !d.photos.length) return toast("Keep at least one photo on your profile.");
      if (d.interests.length < 3) return toast("Pick at least 3 interests.");
      busy(b, true);
      try { state.me = await api.saveProfile({ ...d, name: d.name.trim() }); cache.set("me", state.me); state.draft = null; toast("Profile saved"); go("profile"); }
      catch (e) { toast(friendly(e)); busy(b, false); }
    },
    swipe: b => { const top = topCard(); if (top) fling(top, b.dataset.dir); },
    "sheet-swipe": b => { closeSheet(); const card = $$("#deck .card:not([data-gone])").find(c => c.dataset.id === b.dataset.id); if (card) setTimeout(() => fling(card, b.dataset.dir), 250); },
    "view-profile": b => { const p = state.feed.find(x => x.id === b.dataset.id); if (p) sheet(profileView(p, "discover"), "full"); },
    "preview-self": () => sheet(profileView(state.me, "self"), "full"),
    "pv-thumb": b => { $("#pv-photo").innerHTML = `<img class="ph ok" src="${esc(b.dataset.src)}" alt="">`; $$(".pv-thumbs img").forEach(x => x.classList.toggle("on", x === b)); },
    filters: () => filtersSheet(),
    "refresh-feed": () => { state.feedLoaded = false; state.recycled = false; deckSkeleton(); loadFeed(); },
    "start-over": async () => {
      state.feedLoaded = false; deckSkeleton();
      await loadFeed(false, true);
      if (!state.feed.length) toast("There's nobody to show again yet. Everyone you've seen, you liked or matched with.");
    },
    ice: b => sendMsg(b.textContent),
    "chat-profile": () => chatMatch && sheet(profileView(chatMatch.other, "chat"), "full"),
    "chat-menu": () => {
      const o = chatMatch.other;
      sheet(`<h3>${esc(o.name)}</h3><div class="card-list" style="margin:14px 0 0">
        <button class="row" data-act="chat-profile">${I.user}<span class="body">View profile</span>${I.chev}</button>
        <button class="row" data-act="unmatch">${I.unlink}<span class="body">Unmatch</span>${I.chev}</button>
        <button class="row danger" data-act="block">${I.ban}<span class="body">Block ${esc(o.name)}</span>${I.chev}</button>
        <button class="row danger" data-act="report" data-id="${esc(o.id)}" data-name="${esc(o.name)}">${I.flag}<span class="body">Report ${esc(o.name)}</span>${I.chev}</button></div>`);
    },
    unmatch: () => confirmSheet(`Unmatch ${chatMatch.other.name}?`, "You'll both disappear from each other's matches and this chat will be deleted.", "Unmatch", async () => { await api.unmatch(chatMatch.id); afterRemoval("Unmatched"); }),
    block: () => confirmSheet(`Block ${chatMatch.other.name}?`, "They won't be able to see you or message you again. They won't be told.", "Block", async () => { await api.block(chatMatch.other.id); afterRemoval("Blocked"); }),
    report: b => {
      sheet(`<h3>Report ${esc(b.dataset.name)}</h3><p class="muted sm" style="margin:0">Your report is confidential. We'll also block them for you.</p>
        <form data-form="report" data-id="${esc(b.dataset.id)}">
          <div class="options" style="margin-top:14px">${REPORT_REASONS.map((r, i) => `<label class="option"><input type="radio" name="reason" value="${esc(r)}" ${i === 0 ? "checked" : ""} style="accent-color:var(--brand)">${esc(r)}</label>`).join("")}</div>
          <label class="field"><span>Anything else? (optional)</span><textarea name="details" maxlength="1000" style="min-height:80px"></textarea></label>
          <button class="btn danger" type="submit">Send report</button></form>`);
    },
    "change-password": () => sheet(`<h3>Change password</h3><form data-form="reset">${pwField("password", "New password", "new-password", true)}${pwField("confirm", "Confirm new password", "new-password")}<p class="form-error" role="alert"></p><button class="btn primary" type="submit">Update password</button></form>`),
    "delete-account": () => sheet(`<h3>Delete your account?</h3><p class="muted sm">This permanently deletes your profile, photos, matches and messages. It can't be undone.</p>
      <form data-form="delete"><label class="field"><span>Type DELETE to confirm</span><input name="confirm" autocomplete="off" autocapitalize="characters"></label><p class="form-error" role="alert"></p><button class="btn danger" type="submit">Delete my account</button></form>`),
  };
  function confirmSheet(title, text, btn, fn) {
    sheet(`<h3>${esc(title)}</h3><p class="muted sm">${esc(text)}</p><button class="btn danger" data-act="confirm-yes">${esc(btn)}</button><button class="btn ghost" data-act="close-sheet">Cancel</button>`);
    actions["confirm-yes"] = async b => { busy(b, true); try { await fn(); } catch (e) { toast(friendly(e)); busy(b, false); } };
  }
  function afterRemoval(msg) {
    closeSheet();
    if (chatMatch) { state.matches = (state.matches || []).filter(m => m.id !== chatMatch.id); cache.set("matches", state.matches); }
    toast(msg);
    go("matches");
  }

  /* ---------- forms ---------- */
  const forms = {
    async signup(f, btn) {
      const d = Object.fromEntries(new FormData(f));
      const email = (d.email || "").trim().toLowerCase(), name = (d.name || "").trim();
      if (!name) return formError(f, "Please enter your first name.", "name");
      if (!validName(name)) return formError(f, "Please use your real first name, using letters only.", "name");
      formError(f, "");
      busy(btn, true, "Checking…");
      const problem = await emailProblem(email);
      busy(btn, false);
      if (problem) {
        formError(f, problem.msg, "email");
        if (problem.fix) $(".form-error", f).insertAdjacentHTML("beforeend", ` <button type="button" class="linkbtn" data-act="use-email" data-email="${esc(problem.fix)}">Use ${esc(problem.fix)}</button>`);
        return;
      }
      if (!d.birthdate) return formError(f, "Please enter your date of birth.", "birthdate");
      if (ageOf(d.birthdate) < 18) return formError(f, "You must be 18 or older to use Kindred.", "birthdate");
      if (strength(d.password) < 2) return formError(f, "Use at least 8 characters with letters and numbers.", "password");
      if (!d.agree) return formError(f, "Please confirm you're 18+ and agree to the guidelines.");
      formError(f, ""); busy(btn, true, "Creating account…");
      try {
        const r = await api.signUp({ name, email, password: d.password, birthdate: d.birthdate });
        state.pendingEmail = email;
        if (r.needsVerification) go("verify");
      } catch (e) { formError(f, friendly(e)); busy(btn, false); }
    },
    async signin(f, btn) {
      const d = Object.fromEntries(new FormData(f));
      const email = (d.email || "").trim().toLowerCase();
      if (!validEmail(email)) return formError(f, "Please enter a valid email address.", "email");
      if (!d.password) return formError(f, "Please enter your password.", "password");
      formError(f, ""); busy(btn, true, "Signing in…");
      state.pendingEmail = email;
      try { await api.signIn({ email, password: d.password }); }
      catch (e) { formError(f, friendly(e)); busy(btn, false); }
    },
    async forgot(f, btn) {
      const email = (new FormData(f).get("email") || "").trim().toLowerCase();
      if (!validEmail(email)) return formError(f, "Please enter a valid email address.", "email");
      formError(f, ""); busy(btn, true, "Sending…");
      try {
        await api.sendPasswordReset(email);
        state.pendingEmail = email;
        $("#forgot").innerHTML = inboxBlock(email, "reset") + `<p class="fine">If an account exists for this email, the link will arrive shortly. It expires in 1 hour.</p>`;
      } catch (e) { formError(f, friendly(e)); busy(btn, false); }
    },
    async reset(f, btn) {
      const d = Object.fromEntries(new FormData(f));
      if (strength(d.password) < 2) return formError(f, "Use at least 8 characters with letters and numbers.", "password");
      if (d.password !== d.confirm) return formError(f, "The passwords don't match.", "confirm");
      formError(f, ""); busy(btn, true, "Saving…");
      try {
        await api.updatePassword(d.password);
        state.recovery = false; closeSheet();
        toast("Password updated");
        if (route().name === "reset") go("discover");
      } catch (e) { formError(f, friendly(e)); busy(btn, false); }
    },
    async filters(f, btn) {
      const d = Object.fromEntries(new FormData(f));
      let lo = +d.age_min, hi = +d.age_max; if (lo > hi) [lo, hi] = [hi, lo];
      busy(btn, true);
      try {
        state.me = await api.saveProfile({ show_me: d.show_me, age_min: lo, age_max: hi });
        cache.set("me", state.me);
        pref.set("city", d.city || "");
        closeSheet();
        state.feed = []; state.feedLoaded = false;
        if (route().name === "discover") { deckSkeleton(); loadFeed(); } else go("discover");
      } catch (e) { toast(friendly(e)); busy(btn, false); }
    },
    send(f) { const ta = f.elements.body; const v = ta.value; ta.value = ""; ta.style.height = ""; $(".send", f).disabled = true; sendMsg(v); ta.focus(); },
    async report(f, btn) {
      const d = Object.fromEntries(new FormData(f));
      busy(btn, true, "Sending…");
      try {
        await api.report(f.dataset.id, d.reason, (d.details || "").trim());
        state.feed = state.feed.filter(p => p.id !== f.dataset.id);
        closeSheet();
        toast("Thanks for telling us. We'll review this report.");
        if (route().name === "chat") afterRemoval("Reported and blocked"); else drawDeck();
      } catch (e) { toast(friendly(e)); busy(btn, false); }
    },
    async delete(f, btn) {
      if ((new FormData(f).get("confirm") || "").trim().toUpperCase() !== "DELETE") return formError(f, "Type DELETE to confirm.", "confirm");
      busy(btn, true, "Deleting…");
      try { await api.deleteAccount(); closeSheet(); cache.clear(); toast("Your account has been deleted."); }
      catch (e) { formError(f, friendly(e)); busy(btn, false); }
    },
  };

  function strength(pw = "") {
    let s = 0;
    if (pw.length >= 8) s++;
    if (/[a-z]/i.test(pw) && /\d/.test(pw)) s++;
    if (/[A-Z]/.test(pw) && /[a-z]/.test(pw)) s++;
    if (/[^A-Za-z0-9]/.test(pw) || pw.length >= 12) s++;
    return pw.length < 8 ? Math.min(s, 1) : s;
  }

  /* ---------- global event wiring ---------- */
  document.addEventListener("click", e => {
    const t = e.target.closest("[data-act]");
    if (!t) return;
    const fn = actions[t.dataset.act];
    if (fn) fn(t, e);
  });
  document.addEventListener("submit", e => {
    const f = e.target, fn = forms[f.dataset.form];
    if (!fn) return;
    e.preventDefault();
    fn(f, f.querySelector('[type="submit"]'));
  });
  document.addEventListener("input", e => {
    const t = e.target;
    if (t.matches("[data-strength]")) {
      const s = strength(t.value), meter = t.closest(".field").querySelector(".meter i"), lbl = t.closest(".field").querySelector(".meter-label");
      const cfg = [["8%", "#D92D4B", "Too short"], ["30%", "#D92D4B", "Weak — add letters and numbers"], ["60%", "#F59E0B", "Good"], ["80%", "#16A37B", "Strong"], ["100%", "#16A37B", "Very strong"]][t.value ? s : 0];
      meter.style.width = t.value ? cfg[0] : "0"; meter.style.background = cfg[1]; lbl.textContent = t.value ? cfg[2] : "Use 8+ characters with letters and numbers.";
    }
    if (t.matches("[data-draft]")) { state.draft[t.dataset.draft] = t.value; if (t.dataset.draft === "bio") { const c = $("#bioc"); if (c) c.textContent = t.value.length; } }
    if (t.matches("[data-age]")) { const f = t.form; const lo = +f.age_min.value, hi = +f.age_max.value; $("#agev").textContent = `${Math.min(lo, hi)} – ${Math.max(lo, hi)}${Math.max(lo, hi) >= 70 ? "+" : ""}`; }
    if (t.name === "body" && t.closest(".composer")) { t.style.height = "auto"; t.style.height = Math.min(120, t.scrollHeight) + "px"; $(".send").disabled = !t.value.trim(); }
  });
  document.addEventListener("change", e => { if (e.target.matches("[data-chatmedia]")) { const f = e.target.files?.[0]; e.target.value = ""; sendMediaFile(f); } if (e.target.matches("[data-photo]")) addPhoto(e.target); if (e.target.matches("[data-draft]")) state.draft[e.target.dataset.draft] = e.target.value; });
  document.addEventListener("keydown", e => {
    if (e.key === "Escape" && sheetEl.classList.contains("open")) closeSheet();
    if (e.key === "Enter" && !e.shiftKey && e.target.name === "body" && e.target.closest(".composer") && matchMedia("(pointer:fine)").matches) { e.preventDefault(); e.target.form.requestSubmit(); }
  });
  // segmented control inside the filters form keeps its hidden input in sync
  sheetEl.addEventListener("click", e => {
    const b = e.target.closest('[data-key="f_show"]'); if (!b) return;
    e.stopPropagation();
    $$('[data-key="f_show"]', sheetEl).forEach(x => { x.classList.toggle("on", x === b); x.setAttribute("aria-checked", x === b); });
    sheetEl.querySelector('input[name="show_me"]').value = b.dataset.val;
  }, true);
  window.addEventListener("pagehide", () => { if (cur) hangup(); });
  window.addEventListener("online", () => { toast("Back online"); render(); });
  window.addEventListener("offline", () => { toast("You're offline"); render(); });

  /* ---------- session ---------- */
  async function loadSession(session) {
    const prev = state.uid;
    state.session = session;
    state.uid = session?.user?.id || null;
    if (!session) {
      Object.assign(state, { me: null, feed: [], feedLoaded: false, matches: null, draft: null, step: 0, recovery: false });
      watchCalls(); watchAlerts();
      return;
    }
    if (prev !== state.uid) Object.assign(state, { me: null, feed: [], feedLoaded: false, matches: null, draft: null, step: 0 });
    state.me = state.me || cache.get("me");
    try { state.me = await api.getMyProfile(); cache.set("me", state.me); }
    catch (e) { if (!state.me) toast(friendly(e)); }
    api.touch().catch(() => {});
    registerDevice(prev !== state.uid).catch(() => {});
    if (prev !== state.uid || !callsUnsub) watchCalls();
    if (prev !== state.uid || !alertsUnsub) watchAlerts();
  }

  /* ---------- alerts ----------
     New likes, matches and messages arrive over Realtime (migration 017), and incoming calls come from the calls
     table. While Kindred is on screen they show as a banner; while it's in the background, as a phone
     notification if the member turned them on. A fully closed app gets nothing (that would need Web Push). */
  const alertEl = document.createElement("button");
  alertEl.id = "alert"; alertEl.type = "button"; $("#shell").appendChild(alertEl);
  let alertsUnsub = null, alertTimer, shownMatch = null;
  const rang = new Map(); // call id -> caller name, for calls we put a phone notification up for
  const canNotify = () => "Notification" in window && "serviceWorker" in navigator;
  const alertsOn = () => canNotify() && Notification.permission === "granted" && pref.get("alerts", true);
  const onScreen = () => document.visibilityState === "visible";

  function watchAlerts() {
    if (alertsUnsub) { try { alertsUnsub(); } catch { /* ignore */ } alertsUnsub = null; }
    if (!state.uid || !LIVE || !api.onNotifications) return;
    alertsUnsub = api.onNotifications(onAlert);
    startPush();
  }
  function onAlert(n) {
    if (!n?.kind) return;
    if (n.kind === "match" || n.kind === "message") refreshMatches().then(() => {
      const r = route().name;
      if (r === "matches" && state.matches) drawMatches(state.matches);
      const nav = $(".tabs"); if (nav) nav.outerHTML = tabs(r);
    });
    const link = n.match_id ? "chat/" + n.match_id : "discover";
    if (!onScreen()) return phoneAlert(n.title, n.body, link, n.match_id || n.kind);
    if (n.kind === "message" && route().name === "chat" && route().arg === n.match_id) return; // already reading it
    // The person who made the match is already looking at "It's a match!"; the alert can race the swipe reply.
    if (n.kind === "match") return setTimeout(() => { if (shownMatch !== n.match_id) banner(n.title, n.body, link); }, 1500);
    banner(n.title, n.body, link);
  }
  function banner(title, body, link) {
    alertEl.innerHTML = `${MARK(30)}<span><b>${esc(title)}</b>${body ? `<small>${esc(body)}</small>` : ""}</span>`;
    alertEl.dataset.link = link;
    alertEl.classList.add("show");
    clearTimeout(alertTimer);
    alertTimer = setTimeout(() => alertEl.classList.remove("show"), 5000);
  }
  alertEl.addEventListener("click", () => { alertEl.classList.remove("show"); go(alertEl.dataset.link); });

  // Push (migration 018): with a Web Push subscription the server alerts this device even when Kindred is closed,
  // and the service worker shows it. The page then leaves background alerts to the push, so none show twice.
  const VAPID_KEY = "BMA3_HuiJUBiGfZWwFQnNOiL66aYGSLo10kmlVePzHIRygOjgG-tvAxvSRd8JiRmIEnIsGegqps0mKHX7V6GcrY";
  let pushOn = false;
  const canPush = () => canNotify() && "PushManager" in window && LIVE && !!api.registerPush;
  async function startPush() {
    if (!canPush() || !alertsOn() || !state.uid) return;
    try {
      const reg = await navigator.serviceWorker.ready;
      const key = Uint8Array.from(atob(VAPID_KEY.replace(/-/g, "+").replace(/_/g, "/")), ch => ch.charCodeAt(0));
      const sub = (await reg.pushManager.getSubscription()) || (await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key }));
      const j = sub.toJSON();
      await api.registerPush(j.endpoint, j.keys.p256dh, j.keys.auth);
      pushOn = true;
    } catch { pushOn = false; /* blocked or unsupported: alerts still work while Kindred is open */ }
  }
  async function stopPush() {
    pushOn = false;
    if (!canPush()) return;
    try {
      const sub = await (await navigator.serviceWorker.ready).pushManager.getSubscription();
      if (sub) { await api.unregisterPush(sub.endpoint).catch(() => {}); await sub.unsubscribe(); }
    } catch { /* ignore */ }
  }

  async function phoneAlert(title, body, link, tag, extra = {}) {
    if (!alertsOn() || pushOn) return;
    try {
      const reg = await navigator.serviceWorker.ready;
      await reg.showNotification(title, { body, tag: String(tag), renotify: true, icon: "icons/icon-192.png", badge: "icons/icon-192.png", data: { link }, ...extra });
    } catch { /* this browser won't show it */ }
  }
  // A ringing call we alerted for has stopped: swap the alert for "Missed call", or clear it if it was answered.
  async function callAlertDone(c) {
    if (!rang.has(c.id)) return;
    const name = rang.get(c.id); rang.delete(c.id);
    if ((c.status === "missed" || c.status === "cancelled") && !onScreen()) return phoneAlert(`Missed call from ${name}`, "Tap to open the chat.", "chat/" + c.match_id, "call-" + c.id);
    try { (await (await navigator.serviceWorker.ready).getNotifications({ tag: "call-" + c.id })).forEach(x => x.close()); } catch { /* ignore */ }
  }
  // Tapping a phone notification: the service worker focuses this tab and tells it where to go.
  if (canNotify()) navigator.serviceWorker.addEventListener("message", e => { if (e.data?.type === "open") go(e.data.link || "discover"); });

  function alertsSheet() {
    const perm = canNotify() ? Notification.permission : "unsupported";
    const ios = /iPhone|iPad|iPod/.test(navigator.userAgent);
    sheet(`<h3>Notifications</h3><p class="muted sm" style="margin:0 0 6px">Get alerts for new likes, matches, messages and calls${canPush() ? ", even when Kindred is closed" : " while Kindred is open or running in the background"}.</p>
      ${perm === "unsupported" ? `<p class="sm">This browser can't show notifications.${ios ? " On iPhone, add Kindred to your Home Screen first (Share → Add to Home Screen), then open it from there." : ""}</p><button class="btn soft" data-act="close-sheet">OK</button>`
      : perm === "denied" ? `<p class="sm">Notifications are blocked for Kindred. Allow them in your browser's site settings, then come back here.</p><button class="btn soft" data-act="close-sheet">OK</button>`
      : alertsOn() ? `<button class="btn soft" data-act="alerts-off">Turn off notifications</button>`
      : `<button class="btn primary" data-act="alerts-on">Turn on notifications</button>`}`);
  }
  async function alertsEnable() {
    pref.set("alerts", true); pref.set("alerts-asked", true);
    if (canNotify() && Notification.permission === "default") { try { await Notification.requestPermission(); } catch { /* ignore */ } }
    closeSheet();
    $(".alerts-ask")?.remove();
    if (alertsOn()) await startPush();
    toast(alertsOn() ? "Notifications are on." : "Notifications are blocked. You can allow them in your browser's site settings.");
  }

  /* ---------- device (platform, OS, browser, model) for account security and support ---------- */
  function deviceKey() {
    try {
      let k = localStorage.getItem("k-device");
      if (!k) { k = (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2)).replace(/-/g, ""); localStorage.setItem("k-device", k); }
      return k;
    } catch { return null; }
  }
  async function deviceInfo() {
    const ua = navigator.userAgent;
    const m = (re, i = 1) => (ua.match(re) || [])[i];
    const os = /Android/.test(ua) ? `Android ${m(/Android ([\d]+)/) || ""}`.trim()
      : /iPhone|iPad|iPod/.test(ua) ? `iOS ${m(/OS (\d+)_/) || ""}`.trim()
      : /Windows NT/.test(ua) ? "Windows" : /CrOS/.test(ua) ? "ChromeOS" : /Mac OS X/.test(ua) ? "macOS" : /Linux/.test(ua) ? "Linux" : "Other";
    const browser = /Opera Mini|OPiM/.test(ua) ? "Opera Mini" : /OPR\/|Opera/.test(ua) ? "Opera" : /UCBrowser/.test(ua) ? "UC Browser"
      : /SamsungBrowser/.test(ua) ? "Samsung Internet" : /Edg\//.test(ua) ? "Edge" : /Firefox\/|FxiOS/.test(ua) ? "Firefox"
      : /CriOS|Chrome\//.test(ua) ? "Chrome" : /Safari\//.test(ua) ? "Safari" : "Other";
    const installed = matchMedia("(display-mode: standalone)").matches || navigator.standalone;
    let model = /Android/.test(ua) ? m(/Android [^;)]*; ([^;)]+?)(?: Build|\))/) : /iPhone/.test(ua) ? "iPhone" : /iPad/.test(ua) ? "iPad" : null;
    if (model === "K" || model === "wv") model = null; // Chrome hides the model in its default user agent
    try { if (navigator.userAgentData?.getHighEntropyValues) { const h = await navigator.userAgentData.getHighEntropyValues(["model"]); if (h.model) model = h.model; } } catch { /* not allowed */ }
    return { os, browser: installed ? `${browser} (home screen app)` : browser, model };
  }
  async function registerDevice(newSignIn) {
    if (!state.uid || !api.registerDevice) return;
    const key = deviceKey(); if (!key) return;
    await api.registerDevice({ key, platform: "web", ...(await deviceInfo()), app_version: null, new_sign_in: !!newSignIn });
  }

  async function boot() {
    const splash = $("#splash");
    const first = !sessionStorage.getItem("k-splash");
    const minSplash = sleep(first ? 1700 : 350);
    let booted = false;
    api.onAuth((event, session) => {
      if (event === "PASSWORD_RECOVERY") state.recovery = true;
      if (!booted || event === "TOKEN_REFRESHED" || event === "INITIAL_SESSION") { if (session) state.session = session; return; }
      // Supabase advises against awaiting its calls inside this callback, so defer.
      setTimeout(async () => {
        if (event === "SIGNED_OUT") { cache.clear(); await loadSession(null); go("welcome"); return; }
        if (event === "SIGNED_IN" || event === "USER_UPDATED" || event === "PASSWORD_RECOVERY") {
          // Supabase also re-emits SIGNED_IN when the tab regains focus; only re-render on a real change.
          if (session?.user?.id !== state.uid || !state.me) { await loadSession(session); render(); }
          else if (event === "PASSWORD_RECOVERY") render();
        }
      }, 0);
    });
    let session = null;
    try { session = await api.getSession(); } catch (e) { toast(friendly(e)); }
    await loadSession(session);
    await minSplash;
    booted = true;
    try { sessionStorage.setItem("k-splash", "1"); } catch { /* ignore */ }
    render();
    splash.classList.add("out");
    setTimeout(() => splash.remove(), 600);
  }

  if ("serviceWorker" in navigator && location.protocol !== "file:") {
    window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
  }
  boot();
})();
