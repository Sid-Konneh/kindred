// Uploads Kindred's store listing, graphics and app bundle to Google Play through the official
// Android Publisher API.
//
//   node publish.js listing                 text, icon, feature graphic, screenshots
//   node publish.js release <track>         upload the .aab to a track: internal | alpha (closed) | production
//   node publish.js status                  show what Play currently has
//
// Needs play/service-account.json (a Google Cloud service-account key that has been invited in Play Console).
// That file is a password: it is git-ignored and must never be shared or committed.
const fs = require("fs");
const path = require("path");
const { google } = require("googleapis");

const PACKAGE = "sl.kindred.app";
const LANG = "en-US";
const DIR = __dirname;
const KEY = path.join(DIR, "service-account.json");
const AAB = path.join(DIR, "..", "app", "build", "app", "outputs", "bundle", "release", "app-release.aab");
const read = f => fs.readFileSync(path.join(DIR, f), "utf8").trim();

async function client() {
  if (!fs.existsSync(KEY)) throw new Error(`Missing ${KEY}. See PLAY_STORE_GUIDE.md, step 3.`);
  const auth = new google.auth.GoogleAuth({ keyFile: KEY, scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
  return google.androidpublisher({ version: "v3", auth });
}

async function withEdit(fn) {
  const api = await client();
  const { data: edit } = await api.edits.insert({ packageName: PACKAGE });
  const ctx = { api, editId: edit.id, packageName: PACKAGE };
  try {
    await fn(ctx);
    // A brand-new app that has never been reviewed only accepts changes that are not yet sent for review.
    try {
      await api.edits.commit({ ...ctx, changesNotSentForReview: true });
    } catch (e) {
      if (!/changesNotSentForReview/i.test(e.message)) throw e;
      await api.edits.commit(ctx);
    }
    console.log("✔ Saved to Play Console. Review and send it for review there.");
  } catch (e) {
    await api.edits.delete(ctx).catch(() => {});
    throw e;
  }
}

async function upload(ctx, imageType, file) {
  await ctx.api.edits.images.upload({ ...ctx, language: LANG, imageType, media: { mimeType: "image/png", body: fs.createReadStream(file) } });
  console.log(`  uploaded ${imageType}: ${path.basename(file)}`);
}

async function listing() {
  await withEdit(async ctx => {
    await ctx.api.edits.details.update({ ...ctx, requestBody: {
      defaultLanguage: LANG,
      contactEmail: read("contact_email.txt"),
      contactWebsite: "https://kindred-sl.netlify.app",
    } });
    await ctx.api.edits.listings.update({ ...ctx, language: LANG, requestBody: {
      language: LANG,
      title: read(`listing/${LANG}/title.txt`),
      shortDescription: read(`listing/${LANG}/short_description.txt`),
      fullDescription: read(`listing/${LANG}/full_description.txt`),
    } });
    console.log("  listing text updated");
    for (const t of ["icon", "featureGraphic", "phoneScreenshots"]) await ctx.api.edits.images.deleteall({ ...ctx, language: LANG, imageType: t });
    await upload(ctx, "icon", path.join(DIR, "graphics", "app-icon-512.png"));
    await upload(ctx, "featureGraphic", path.join(DIR, "graphics", "feature-graphic-1024x500.png"));
    const shots = fs.readdirSync(path.join(DIR, "graphics", "screenshots")).filter(f => f.endsWith(".png")).sort();
    for (const s of shots) await upload(ctx, "phoneScreenshots", path.join(DIR, "graphics", "screenshots", s));
  });
}

async function release(track) {
  if (!["internal", "alpha", "beta", "production"].includes(track)) throw new Error("Track must be internal, alpha (closed testing), beta or production.");
  if (!fs.existsSync(AAB)) throw new Error(`Build the bundle first: cd app && flutter build appbundle --release (expected ${AAB})`);
  await withEdit(async ctx => {
    const { data: bundle } = await ctx.api.edits.bundles.upload({ ...ctx, media: { mimeType: "application/octet-stream", body: fs.createReadStream(AAB) } });
    console.log(`  uploaded bundle, versionCode ${bundle.versionCode}`);
    const notes = read("release_notes.txt");
    await ctx.api.edits.tracks.update({ ...ctx, track, requestBody: { track, releases: [{
      name: `${bundle.versionCode}`,
      versionCodes: [String(bundle.versionCode)],
      // Draft until the app has passed its first review; Play refuses anything else before then.
      status: "draft",
      releaseNotes: [{ language: LANG, text: notes }],
    }] } });
    console.log(`  release ${bundle.versionCode} placed on the "${track}" track as a draft`);
  });
}

async function status() {
  const api = await client();
  const { data: edit } = await api.edits.insert({ packageName: PACKAGE });
  const ctx = { editId: edit.id, packageName: PACKAGE };
  const { data: tracks } = await api.edits.tracks.list(ctx);
  for (const t of tracks.tracks || []) console.log(t.track, JSON.stringify(t.releases || []));
  const { data: l } = await api.edits.listings.get({ ...ctx, language: LANG }).catch(() => ({ data: {} }));
  console.log("title:", l.title || "(none)");
  await api.edits.delete(ctx);
}

const [cmd, arg] = process.argv.slice(2);
({ listing, release: () => release(arg), status }[cmd] || (() => { console.log("Usage: node publish.js listing | release <track> | status"); }))()
  .catch(e => {
    const msg = e.errors?.[0]?.message || e.message;
    console.error("✖", msg);
    if (/not found|does not exist|Package not found/i.test(msg)) console.error("  → Create the app in Play Console and upload the first .aab by hand (PLAY_STORE_GUIDE.md, step 2). Google does not let the API do the very first upload.");
    if (/permission|forbidden|403/i.test(msg)) console.error("  → Invite the service account in Play Console → Users and permissions, and give it access to Kindred (step 3).");
    process.exit(1);
  });
