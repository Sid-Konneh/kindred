"use strict";
/* ============ demo backend ============
   Implements the same interface as backend-live.js so the app runs with no server.
   Everyone here is fictional and has no photo. Data lives only in this browser's localStorage.
   Passwords are hashed, but this is still a demo: never reuse a real password here. */
window.KindredDemo = function () {
  const KEY = "kindred-demo-v1", SESSION = "kindred-demo-session";
  const Y = new Date().getFullYear();
  const newId = () => (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2));
  const nowIso = () => new Date().toISOString();
  const wait = (ms = 300) => new Promise(r => setTimeout(r, ms + Math.random() * 300));
  const clone = x => JSON.parse(JSON.stringify(x));
  const ageOf = bd => { const b = new Date(bd + "T00:00:00"), n = new Date(); let a = n.getFullYear() - b.getFullYear(); const m = n.getMonth() - b.getMonth(); if (m < 0 || (m === 0 && n.getDate() < b.getDate())) a--; return a; };
  const fail = msg => { const e = new Error(msg); throw e; };
  async function hash(s) {
    const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("kindred-demo:" + s));
    return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, "0")).join("");
  }

  // name, gender, age, city, job, looking_for, religion, likes you, interests, languages, bio
  const PEOPLE = [
    ["Aminata", "woman", 26, "Freetown", "Nurse at Connaught", "relationship", "muslim", 1, ["Afrobeats", "Cooking", "Beach days", "Gospel & worship"], ["Krio", "English", "Temne"], "Night shifts, big heart. My perfect Sunday is jollof at home and a walk on Lumley Beach. Looking for someone kind and serious."],
    ["Fatmata", "woman", 24, "Bo", "Accounting student, Njala", "relationship", "muslim", 1, ["Reading", "Fashion", "Entrepreneurship"], ["Mende", "Krio", "English"], "Final year student with a small tailoring business on the side. I like people who can make me laugh and plan ahead."],
    ["Marie", "woman", 29, "Freetown", "Secondary school teacher", "marriage", "christian", 0, ["Church choir", "Reading", "Travel", "Cooking"], ["Krio", "English"], "Wilberforce girl. I sing in the choir, teach literature and bake on weekends. Ready for something real that leads to marriage."],
    ["Isatu", "woman", 27, "Makeni", "Microfinance officer", "relationship", "muslim", 1, ["Football", "Dancing", "Volunteering"], ["Temne", "Krio", "English", "Limba"], "Arsenal fan (yes, still). I work with women traders around Makeni and love what I do."],
    ["Hawa", "woman", 31, "Kenema", "Pharmacist", "marriage", "christian", 1, ["Nature", "Cooking", "Movies"], ["Mende", "Krio", "English"], "Calm, family-oriented and honest. I'd love to meet a man who respects women and knows what he wants."],
    ["Kadiatu", "woman", 23, "Freetown", "Graphic designer", "not_sure", "muslim", 0, ["Photography", "Fashion", "Afrobeats", "Tech"], ["Fula", "Krio", "English"], "Designer, sneaker collector, amateur photographer. Show me your favourite spot in Freetown."],
    ["Zainab", "woman", 28, "Lungi", "Airport customer service", "relationship", "muslim", 1, ["Travel", "Fitness", "Movies"], ["Temne", "Krio", "English", "French"], "I meet people from everywhere at work, but I'm still looking for my person. Gym in the morning, series at night."],
    ["Adama", "woman", 34, "Waterloo", "Runs a provisions shop", "marriage", "muslim", 1, ["Entrepreneurship", "Cooking", "Gospel & worship"], ["Krio", "Temne", "English"], "Hard-working businesswoman and a proud aunty. Looking for a responsible partner to build a home with."],
    ["Mariama", "woman", 25, "Port Loko", "Community health worker", "friendship", "muslim", 0, ["Volunteering", "Nature", "Dancing"], ["Temne", "Krio"], "New in town for work. Would love to meet genuine people and make friends first."],
    ["Mohamed", "man", 29, "Freetown", "Software developer", "relationship", "muslim", 1, ["Tech", "Football", "Afrobeats", "Gaming"], ["Krio", "English", "Temne"], "I build apps by day and play five-a-side at Siaka Stevens on weekends. Looking for a best friend and partner."],
    ["Ibrahim", "man", 32, "Bo", "Civil engineer", "marriage", "muslim", 1, ["Football", "Travel", "Reading"], ["Mende", "Krio", "English"], "Building roads across the south. Family means everything to me. Serious about finding a wife."],
    ["Samuel", "man", 27, "Freetown", "Banker", "relationship", "christian", 0, ["Fitness", "Church choir", "Movies", "Cooking"], ["Krio", "English"], "Gym, church, work, repeat. I make the best pepper soup in Freetown and I can prove it."],
    ["Alusine", "man", 30, "Koidu", "Mining geologist", "relationship", "muslim", 1, ["Nature", "Photography", "Football"], ["Kono", "Krio", "English"], "I spend a lot of time outdoors in Kono. Honest, patient and I love a good conversation."],
    ["Joseph", "man", 26, "Kenema", "Radio presenter", "not_sure", "christian", 1, ["Afrobeats", "Poetry", "Dancing"], ["Mende", "Krio", "English"], "You might have heard my voice on the evening show. Off air I'm quieter than you'd think."],
    ["Musa", "man", 35, "Makeni", "Secondary school principal", "marriage", "muslim", 1, ["Reading", "Farming", "Volunteering"], ["Temne", "Limba", "Krio", "English"], "Educator and farmer at heart. Looking for a kind woman who values faith, family and learning."],
    ["Emmanuel", "man", 28, "Freetown", "Chef", "relationship", "christian", 0, ["Cooking", "Travel", "Afrobeats"], ["Krio", "English", "French"], "I run a kitchen in Aberdeen. First date? I'll cook. Cassava leaves or groundnut soup, your choice."],
    ["Osman", "man", 24, "Kabala", "Agronomy graduate", "friendship", "muslim", 1, ["Farming", "Nature", "Football"], ["Limba", "Fula", "Krio"], "Just moved to Freetown from Kabala. Would like to meet new people and see where it goes."],
    ["Abu", "man", 33, "Lungi", "Logistics manager", "relationship", "muslim", 1, ["Travel", "Fitness", "Entrepreneurship"], ["Temne", "Krio", "English"], "Organised, loyal and a big believer in good manners. Let's grab a coffee by the ferry."],
  ];
  const REPLIES = [
    "Kushɛ! Aw di bodi? 😊",
    "Haha I like that. What do you usually do on weekends?",
    "That's nice! Have you been to River No. 2 beach? It's my favourite place.",
    "Tenki, you seem really genuine 🙏 Tell me more about your work.",
    "I'm free to chat more later this evening. Talk soon!",
  ];

  function seed() {
    const profiles = {};
    PEOPLE.forEach(([name, gender, age, city, job, looking_for, religion, likesYou, interests, languages, bio], i) => {
      const id = "p-" + (i + 1);
      profiles[id] = {
        id, name, gender, city, job, looking_for, religion, interests, languages, bio,
        birthdate: `${Y - age - 1}-${String((i % 12) + 1).padStart(2, "0")}-${String((i % 27) + 1).padStart(2, "0")}`,
        show_me: gender === "woman" ? "men" : "women", photos: [], age_min: 18, age_max: 60, onboarded: true,
        last_active: new Date(Date.now() - (i % 5) * 37 * 60000 - (i % 3) * 86400000).toISOString(),
        _likesYou: !!likesYou,
      };
    });
    return { users: {}, profiles, swipes: {}, matches: [], messages: [], blocks: [], reports: [], recovery: null, autoReplies: {} };
  }

  let db;
  try { db = JSON.parse(localStorage.getItem(KEY)) || seed(); } catch { db = seed(); }
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(db)); }
    catch { fail("Your browser storage is full. Remove a photo and try again."); }
  }
  let session = null;
  try { session = JSON.parse(localStorage.getItem(SESSION)); } catch { session = null; }
  if (session && !db.profiles[session.user.id]) session = null;
  const authSubs = new Set(), msgSubs = new Map();
  const setSession = (s, event) => {
    session = s;
    try { s ? localStorage.setItem(SESSION, JSON.stringify(s)) : localStorage.removeItem(SESSION); } catch { /* private mode */ }
    authSubs.forEach(cb => cb(event, s));
  };
  const uid = () => session?.user?.id || fail("Please sign in again.");
  const pub = p => {
    const { _likesYou, birthdate, ...rest } = p;
    return { ...clone(rest), age: birthdate ? ageOf(birthdate) : null };
  };
  const self = p => ({ ...clone(p), age: p.birthdate ? ageOf(p.birthdate) : null });
  const blockedBetween = (a, b) => db.blocks.some(x => (x.blocker === a && x.blocked === b) || (x.blocker === b && x.blocked === a));
  const wants = (viewer, p) => viewer.show_me === "everyone" || (viewer.show_me === "women" && p.gender === "woman") || (viewer.show_me === "men" && p.gender === "man");
  const other = (m, me) => (m.user_a === me ? m.user_b : m.user_a);
  const emit = (matchId, evt) => (msgSubs.get(matchId) || new Set()).forEach(cb => cb(evt));

  async function newAccount(email, password, meta) {
    const id = "u-" + newId();
    db.users[email] = { id, email, pw: password ? await hash(password) : null };
    db.profiles[id] = {
      id, name: meta.name, birthdate: meta.birthdate || null, gender: null, show_me: "everyone", city: null, job: null, bio: "",
      interests: [], languages: [], looking_for: null, religion: null, photos: [], age_min: 18, age_max: 45, onboarded: false, last_active: nowIso(),
    };
    save();
    return id;
  }

  function scheduleReply(matchId, otherId) {
    const n = db.autoReplies[matchId] || 0;
    if (n >= REPLIES.length) return;
    db.autoReplies[matchId] = n + 1; save();
    setTimeout(() => emit(matchId, { type: "typing" }), 900);
    setTimeout(() => {
      if (!db.matches.find(m => m.id === matchId)) return;
      const msg = { id: newId(), match_id: matchId, sender: otherId, body: REPLIES[n], created_at: nowIso(), read_at: null };
      db.messages.push(msg);
      db.matches.find(m => m.id === matchId).last_message_at = msg.created_at;
      save();
      emit(matchId, { type: "message", message: clone(msg) });
    }, 2600 + Math.random() * 1400);
  }

  return {
    mode: "demo",
    onAuth(cb) { authSubs.add(cb); return () => authSubs.delete(cb); },
    async getSession() { return session; },
    async signUp({ name, email, password, birthdate }) {
      await wait(500);
      if (db.users[email]) fail("User already registered");
      if (ageOf(birthdate) < 18) fail("You must be 18 or older to use Kindred.");
      const id = await newAccount(email, password, { name, birthdate });
      setSession({ user: { id, email } }, "SIGNED_IN");
      return { needsVerification: false };
    },
    async signIn({ email, password }) {
      await wait(450);
      const u = db.users[email];
      if (!u || !u.pw || u.pw !== await hash(password)) fail("Invalid login credentials");
      setSession({ user: { id: u.id, email } }, "SIGNED_IN");
    },
    async resendSignup() { await wait(); },
    async sendPasswordReset(email) { await wait(600); if (db.users[email]) { db.recovery = email; save(); } },
    canReset() { return !!db.recovery || !!session; },
    async updatePassword(password) {
      await wait(500);
      const email = session?.user?.email || db.recovery;
      if (!email || !db.users[email]) fail("This reset link has expired. Request a new one.");
      db.users[email].pw = await hash(password);
      db.recovery = null; save();
      if (!session) setSession({ user: { id: db.users[email].id, email } }, "SIGNED_IN");
    },
    async signOut() { setSession(null, "SIGNED_OUT"); },

    async getMyProfile() { await wait(150); return self(db.profiles[uid()]); },
    async saveProfile(patch) {
      await wait(350);
      const me = db.profiles[uid()];
      if (patch.birthdate && me.birthdate) delete patch.birthdate;
      if (patch.birthdate && ageOf(patch.birthdate) < 18) fail("You must be 18 or older to use Kindred.");
      Object.assign(me, clone(patch));
      save();
      return self(me);
    },
    async uploadPhoto(blob) {
      await wait(500);
      return await new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = rej; r.readAsDataURL(blob); });
    },
    async touch() { const me = db.profiles[session?.user?.id]; if (me) { me.last_active = nowIso(); save(); } },

    async getFeed({ city, recycle } = {}) {
      await wait(700);
      const me = db.profiles[uid()];
      const seen = db.swipes[me.id] || {};
      const matched = id => db.matches.some(m => (m.user_a === me.id && m.user_b === id) || (m.user_b === me.id && m.user_a === id));
      const list = Object.values(db.profiles)
        .filter(p => p.id !== me.id && p.onboarded && p.birthdate && !blockedBetween(me.id, p.id) && !matched(p.id))
        .filter(p => recycle ? seen[p.id] === "pass" : !seen[p.id])
        .filter(p => wants(me, p) && (!me.gender || wants(p, me)))
        .filter(p => { const a = ageOf(p.birthdate); return a >= me.age_min && a <= me.age_max; })
        .filter(p => !city || p.city === city);
      if (recycle) list.sort(() => Math.random() - .5);
      else list.sort((a, b) => (b._likesYou - a._likesYou) || (a.last_active < b.last_active ? 1 : -1));
      return list.slice(0, 20).map(pub);
    },
    async swipe(targetId, action) {
      await wait(120);
      const me = uid();
      (db.swipes[me] = db.swipes[me] || {})[targetId] = action;
      const t = db.profiles[targetId];
      let matchId = null;
      if (action !== "pass" && t && t._likesYou && !blockedBetween(me, targetId)) {
        const [a, b] = [me, targetId].sort();
        let m = db.matches.find(x => x.user_a === a && x.user_b === b);
        if (!m) { m = { id: "m-" + newId(), user_a: a, user_b: b, created_at: nowIso(), last_message_at: null }; db.matches.push(m); }
        matchId = m.id;
      }
      save();
      return matchId;
    },
    async getMatches() {
      await wait(500);
      const me = uid();
      return db.matches
        .filter(m => (m.user_a === me || m.user_b === me) && !blockedBetween(m.user_a, m.user_b))
        .map(m => {
          const msgs = db.messages.filter(x => x.match_id === m.id);
          const last = msgs[msgs.length - 1];
          return {
            id: m.id, created_at: m.created_at, last_message_at: m.last_message_at,
            last_body: last?.body || null, last_sender: last?.sender || null,
            unread: msgs.filter(x => x.sender !== me && !x.read_at).length,
            other: pub(db.profiles[other(m, me)]),
          };
        })
        .sort((x, y) => ((y.last_message_at || y.created_at) > (x.last_message_at || x.created_at) ? 1 : -1));
    },
    async getMessages(matchId) {
      await wait(300);
      return clone(db.messages.filter(x => x.match_id === matchId));
    },
    async sendMessage(matchId, body) {
      await wait(250);
      const me = uid();
      const m = db.matches.find(x => x.id === matchId) || fail("This match is no longer available.");
      const msg = { id: newId(), match_id: matchId, sender: me, body, created_at: nowIso(), read_at: null };
      db.messages.push(msg);
      m.last_message_at = msg.created_at;
      save();
      scheduleReply(matchId, other(m, me));
      setTimeout(() => { msg.read_at = nowIso(); const s = db.messages.find(x => x.id === msg.id); if (s) { s.read_at = msg.read_at; save(); emit(matchId, { type: "read" }); } }, 2200);
      return clone(msg);
    },
    async markRead(matchId) {
      const me = session?.user?.id;
      let changed = false;
      db.messages.forEach(x => { if (x.match_id === matchId && x.sender !== me && !x.read_at) { x.read_at = nowIso(); changed = true; } });
      if (changed) save();
    },
    subscribe(matchId, cb) {
      if (!msgSubs.has(matchId)) msgSubs.set(matchId, new Set());
      msgSubs.get(matchId).add(cb);
      return () => msgSubs.get(matchId)?.delete(cb);
    },
    async unmatch(matchId) {
      await wait();
      db.matches = db.matches.filter(m => m.id !== matchId);
      db.messages = db.messages.filter(m => m.match_id !== matchId);
      save();
    },
    async block(userId) {
      await wait();
      const me = uid();
      db.blocks.push({ blocker: me, blocked: userId, created_at: nowIso() });
      db.matches = db.matches.filter(m => !(m.user_a === me && m.user_b === userId) && !(m.user_b === me && m.user_a === userId));
      save();
    },
    async report(userId, reason, details) {
      await wait();
      db.reports.push({ reporter: uid(), reported: userId, reason, details, created_at: nowIso() });
      save();
      await this.block(userId);
    },
    async deleteAccount() {
      await wait(600);
      const me = uid();
      const email = session.user.email;
      delete db.users[email];
      delete db.profiles[me];
      delete db.swipes[me];
      db.matches = db.matches.filter(m => m.user_a !== me && m.user_b !== me);
      save();
      setSession(null, "SIGNED_OUT");
    },
  };
};
