# Kindred

A dating app for Sierra Leone. It works in any phone browser and can be installed to the home screen on Android and iOS (it's a Progressive Web App). It is built with plain HTML/CSS/JS and has no build step. Supabase provides auth, the database, realtime chat and photo storage, and Netlify hosts it.

## Features

- **Accounts:** sign up with email, sign in, forgot/reset password and email confirmation. Everyone must be 18+, which is enforced in the database.
- **Onboarding:** 4 steps covering gender and who you want to see, photos (compressed on the phone before upload to save data), city, what you're looking for, bio, interests and languages.
- **Discover:** a swipe deck (drag, or use the buttons or arrow keys) with like, pass and super like. You can tap through photos and open a full profile. Filters cover age range, city and who you want to see.
- **Matches and chat:** "It's a match!" screen, new-matches row, conversations with unread badges, realtime messages, read receipts, icebreakers and a safety notice.
- **Safety:** block, report (reporting also blocks), unmatch, safety tips, community guidelines and account deletion.
- **Performance:** splash screen, silver shimmer skeletons while loading, a service worker cache (the app opens offline and on slow 3G), cached profile photos, and a local stale-while-revalidate cache for matches and messages.

## Run it locally

```
npx serve public
```

Open the address it prints. With `public/config.js` left empty the app runs in **demo mode**: 18 fictional profiles, no server, and data kept only in your browser. Demo profiles deliberately have no photos. They use colour art with initials instead, so no real person's picture is presented as a dating profile.

## Go live

### 1. Supabase
1. Create a project at supabase.com. Pick the region closest to West Africa, e.g. `eu-west-2` (London) or `eu-central-1`.
2. SQL Editor → run the files in `supabase/migrations/` in order (001 → 012).
3. Project Settings → API: copy the URL and **publishable** key into `public/config.js`.
4. Authentication → URL Configuration: set Site URL to your Netlify URL, and add it under Redirect URLs.
5. Authentication → Providers → Email: keep **Confirm email** on and set the minimum password length to 8.

### 2. Send auth emails from Gmail
Supabase's built-in email sender is for testing only (a few emails per hour). To send confirmation and reset emails from your Gmail account:

1. Turn on 2-Step Verification for the Google account.
2. Create an app password at <https://myaccount.google.com/apppasswords>.
3. Supabase → Authentication → Emails → SMTP Settings → enable custom SMTP:
   - Host `smtp.gmail.com`, port `587`
   - Username: the full Gmail address
   - Password: the 16-character app password
   - Sender name `Kindred`, sender email: the same Gmail address
4. Optionally, edit the email templates (Authentication → Emails → Templates) so they say "Kindred".

**Limits:** a personal Gmail account can send roughly 500 emails a day. Messages sent this way can land in spam, and your personal address is exposed as the sender. For launch, use Google Workspace on your own domain (e.g. `hello@kindred.sl`), or a transactional provider such as Resend or Brevo, with SPF/DKIM set up.

### 3. Netlify
```
netlify deploy --prod --dir public
```
If Netlify answers `Forbidden` to a production deploy, deploy a draft and publish it:
```
netlify deploy --dir public          # prints a deploy id
netlify api restoreSiteDeploy --data '{"site_id":"0610f7a3-bff5-40f1-91fe-0c1a80c3edb3","deploy_id":"<deploy id>"}'
```

## App stores
The PWA installs from the browser today: Android shows "Install app", and on iOS use Share → Add to Home Screen. To publish in Google Play and the App Store, wrap `public/` with Capacitor (`npx cap add android` / `ios`). Store review for dating apps requires in-app reporting, blocking and account deletion, and Kindred already has all three. You'll also need a privacy policy URL and a moderation plan for reports.

## Before a public launch
- **Moderation:** reports land in the `reports` table. Someone has to review them every day (Supabase Table Editor works to start with).
- **Photo moderation:** photos are not screened automatically yet.
- **Privacy policy and terms:** these are required for app stores and for handling personal data.
- **Phone-number sign-in (SMS OTP):** many people in Sierra Leone use phone numbers more than email. Supabase supports this with an SMS provider such as Twilio or Africa's Talking. This is worth adding next.
- **Rate limiting:** swipes and messages are not rate limited yet.

## Flutter app (Android & iOS)
`app/` is a native Flutter app on the same Supabase project, so phone and web users see and match each other.

- **Download (Android):** <https://kindred-sl.netlify.app/download/kindred.apk>. On the phone, open the link, allow "Install unknown apps" for your browser when asked, then install.
- **Build:** `cd app && flutter build apk --release --target-platform android-arm,android-arm64`, then copy `build/app/outputs/flutter-apk/app-release.apk` to `public/download/kindred.apk` and deploy the site.
- **Play Store:** `flutter build appbundle --release` gives the `.aab` file that Google Play wants.
- **iOS:** needs a Mac with Xcode and an Apple Developer account ($99/year): `flutter build ipa`.
- **Signing key:** `app/android/kindred-release.jks` and `app/android/key.properties` are *not* in git. Back both up somewhere safe. If you lose them, you can never publish an update to the same Play Store listing.
- Email links (confirm account, reset password) open the website. People then sign in in the app with the same email and password.

## Admin console
<https://kindred-sl.netlify.app/admin/>. Sign in with a normal Kindred account that is on the admin team.

- **Moderators:** overview stats, the reports queue (with the chat evidence captured when the report was sent), searching members, suspending and unsuspending, and removing photos.
- **Super admins:** everything moderators can do, plus adding and removing team members, deleting accounts and marking test accounts.
- **Scam alerts:** messages that mention money (Orange Money, Afrimoney, airtime, Leones) or move to WhatsApp or a phone number are flagged automatically.
- **Insights:** match rate, conversation and reply stats, retention by sign-up week, an activity heatmap, profile quality, interests and languages, safety stats and leaderboards.
- **Photo review**, daily activity charts (30 or 90 days), a sign-up funnel, private notes on members, and CSV export of members and reports (super admins only).
- **Devices:** which device each member signs in with (app or website, phone model, operating system, browser, app version, first and last used), in each member panel and as stats on Insights.
- Every action is written to the activity log.
- **First super admin:** they sign up in the app first, then you run this once in the Supabase SQL editor:
  `insert into public.admins (user_id, role) select id, 'super_admin' from auth.users where email = 'you@example.com';`
- Suspending a member blocks their sign-in, ends their sessions and hides them from every feed and chat.
