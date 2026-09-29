# Publishing Kindred on Google Play

Everything Google asks for is already prepared in this `play/` folder. A few steps can only be done by the account owner in Play Console, because Google doesn't allow them through its API. Those steps are marked **(you)**. Everything marked **(me)** I do with the upload script.

Your developer account is a **personal account**. For new personal accounts, Google requires a **closed test with at least 12 testers who stay opted in for 14 days in a row** before the app can be published to everyone. Plan for about 3 weeks from first upload to public listing.

---

## What's ready

| Item | File |
|---|---|
| App bundle (.aab), signed with the Kindred release key | `app/build/app/outputs/bundle/release/app-release.aab` |
| App icon 512×512 | `play/graphics/app-icon-512.png` |
| Feature graphic 1024×500 | `play/graphics/feature-graphic-1024x500.png` |
| 8 phone screenshots, 1080×1920 | `play/graphics/screenshots/` |
| Title, short and full description | `play/listing/en-US/` |
| Privacy policy | https://kindred-sl.netlify.app/privacy.html |
| Account deletion page | https://kindred-sl.netlify.app/delete-account.html |
| Reviewer test accounts | `play/review-accounts.txt` (git-ignored) |

---

## Step 1 — Create the app (you, 2 minutes)
Play Console → **Create app**
- App name: **Kindred: Dating in Salone**
- Default language: **English (United States) – en-US**
- App or game: **App** · Free or paid: **Free**
- Tick the declarations → **Create app**

## Step 2 — Upload the first bundle by hand (you, 3 minutes)
Google does not let the API make an app's very first upload.
1. **Test and release → Testing → Internal testing → Create new release**.
2. If asked about **Play App Signing**, accept the default (Google manages the app signing key; our file becomes the "upload key").
3. Drag in `app-release.aab` (I also put a copy on your Desktop as `Kindred-1.0.0.aab`).
4. Release name `1 (1.0.0)`. Release notes: paste `play/release_notes.txt` → **Next → Save**. You don't need to roll it out yet.

## Step 3 — Give me upload access with a service account (you, 10 minutes)
This key can only manage Kindred on Play. It can't see your Google account, email or passwords.
1. Open https://console.cloud.google.com/ → create a project named **kindred-play** (any project is fine).
2. **APIs & Services → Library** → search **Google Play Android Developer API** → **Enable**.
3. **IAM & Admin → Service accounts → Create service account**, name **kindred-publisher**. Skip the optional role steps → **Done**.
4. Open the new account → **Keys → Add key → Create new key → JSON**. A `.json` file downloads.
5. Save that file as **`C:\Users\user1\kindred\play\service-account.json`**. Don't email it or paste its contents into chat; it's a password. Git already ignores it.
6. Play Console → **Users and permissions → Invite new users** → paste the service account's email (it looks like `kindred-publisher@kindred-play.iam.gserviceaccount.com`).
   - **App permissions → Add app → Kindred**, and tick: *View app information*, *Manage store presence*, *Release apps to testing tracks*. Add *Release to production* later if you want me to handle the final release too.
   - **Invite user**.
7. Tell me it's done. I'll run `node publish.js listing` (text, icon, feature graphic, screenshots) and `node publish.js release alpha` (closed-testing release).

## Step 4 — App content declarations (you, about 20 minutes, exact answers below)
Play Console → **Policy and programs → App content**. Google only allows these through the website.

**Privacy policy:** `https://kindred-sl.netlify.app/privacy.html`

**App access:** *All or some functionality is restricted* → **Add instructions**
- Name: `Reviewer account`
- Username / password: from `play/review-accounts.txt` (account A)
- Other information: *"Sign in with reviewer account A. The Discover tab shows reviewer account B, who has already liked A. Tap the heart to match, then open the chat. You can sign in as B on a second device to reply. Both accounts are in a separate test pool and never shown to real members."*

**Ads:** *Yes, my app contains ads* (AdMob banners on the main tabs). Data safety: declare **Device or other IDs** (advertising ID), collected and shared with Google for advertising.

**Content rating:** start the questionnaire, email = the Kindred Gmail, category **Social / Communication (includes dating)**.
- Violence, sexuality, language, controlled substances, gambling, crude humour: **No** to all
- *Does the app allow users to interact or exchange content?* **Yes**
- *Does the app share the user's current physical location with other users?* **No** (members type a town name; the app never reads GPS)
- *Can users purchase digital goods?* **No**
- *Is this a web browser or search engine?* **No**

**Target audience and content:** age group **18 and over only**. *Could the app appeal to children?* **No**.

**Data safety:** answer as follows.
- *Does your app collect or share any of the required user data types?* **Yes**
- *Is all user data encrypted in transit?* **Yes**
- *Do you provide a way for users to request that their data is deleted?* **Yes** → URL `https://kindred-sl.netlify.app/delete-account.html`
- *Shared with third parties?* **No** for every type. Supabase and Netlify are service providers acting for us, which Google does not count as sharing.
- Data types **collected**. For every one: *not processed ephemerally*, *not optional* unless noted, purpose **App functionality** (+ **Account management** where marked):

| Category | Data type | Required? | Purposes |
|---|---|---|---|
| Personal info | Name | Required | App functionality, Account management |
| Personal info | Email address | Required | Account management |
| Personal info | User IDs | Required | App functionality, Account management |
| Personal info | Other info (date of birth, gender, town, job, bio, interests, languages) | Required | App functionality |
| Personal info | Sexual orientation (the "show me women/men/everyone" setting) | Required | App functionality |
| Personal info | Religious or philosophical beliefs | **Optional** | App functionality |
| Photos and videos | Photos (profile photos and photos sent in chat) | Required | App functionality |
| Photos and videos | Videos (sent in chat) | **Optional** | App functionality |
| Messages | Other in-app messages | Required | App functionality |
| App activity | App interactions (likes, passes, matches, blocks, reports, call history: who called, when, how long) | Required | App functionality |
| App activity | Other user-generated content (bio) | Required | App functionality |
| Device or other IDs | Device or other IDs (a random ID the app creates, plus phone model, Android version, app version) | Required | App functionality, Fraud prevention, security and compliance |

Not collected: location, contacts, financial info, health, crash logs, analytics. **Audio / voice recordings: not collected.** Voice and video calls go directly between the two phones, encrypted end to end by WebRTC; nothing is recorded or passes through our servers, which Google does not count as collection. The app asks for the **microphone and camera** only when a call starts; no extra Play declaration is needed for these permissions.

**Government apps:** No. **Financial features:** None. **Health:** None. **News app:** No.

## Step 5 — Store listing (me, once step 3 is done)
The script fills in **Grow users → Store presence → Main store listing**. You then set:
- **App category:** *Dating* · **Tags:** Dating, Social
- **Contact details:** the Kindred Gmail and website `https://kindred-sl.netlify.app`

## Step 6 — Closed test with 12 testers for 14 days (you + your testers)
1. **Testing → Closed testing → Alpha → Testers**: create an email list with **at least 12** Gmail addresses of people who agree to test (friends, family, colleagues). More than 12 is safer, in case someone drops out.
2. **Countries/regions:** Sierra Leone (add others where your testers live).
3. Roll out the closed-testing release (I upload it in step 3). Share the **opt-in link** with the testers. Each one opens it, taps **Become a tester**, then installs Kindred from Play and uses it.
4. Keep at least 12 testers opted in for **14 continuous days**. Their feedback helps. Google asks about it when you apply.

## Step 7 — Apply for production (you, after 14 days)
**Dashboard → Apply for production**. Google asks how testing went and what changed. After approval (usually a few days), release to production. I can upload the production release for you if the service account has *Release to production*.

---

### Updating the app later
1. Increase `version:` in `app/pubspec.yaml`, e.g. `1.0.1+2`. The number after `+` must go up every time.
2. `cd app && flutter build appbundle --release`
3. `cd ../play && node publish.js release alpha` (or `production`)

### Keep safe
- `app/android/kindred-release.jks` + `app/android/key.properties`: the upload key. If it's lost, Google can reset it (you ask through Play Console, because Play App Signing is on). Still, keep a backup.
- `play/service-account.json`: delete the key in Google Cloud if it ever leaks.
