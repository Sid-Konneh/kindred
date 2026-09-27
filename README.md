# Kindred

A dating app for Sierra Leone. It works in any phone browser and can be installed to the home screen on Android and iOS (it's a Progressive Web App). It is built with plain HTML/CSS/JS and has no build step. Supabase provides auth, the database, realtime chat and photo storage, and Netlify hosts it.

## Features

- **Accounts:** sign up with email, sign in, forgot/reset password, email confirmation, and Continue with Google. Everyone must be 18+, which is enforced in the database.
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
2. SQL Editor → run `supabase/migrations/001_schema.sql`, then `002_harden.sql`.
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

### 3. Continue with Google
1. In Google Cloud Console, create an OAuth client (Web application).
2. Authorised redirect URI: `https://<your-project>.supabase.co/auth/v1/callback`.
3. Supabase → Authentication → Providers → Google: paste the client ID and secret.

Google sign-ups don't include a birthdate, so the app asks for it in onboarding and it can't be changed afterwards.

### 4. Netlify
```
netlify deploy --prod
```
Or connect the GitHub repo in Netlify; `netlify.toml` already publishes `public/`.

## App stores
The PWA installs from the browser today: Android shows "Install app", and on iOS use Share → Add to Home Screen. To publish in Google Play and the App Store, wrap `public/` with Capacitor (`npx cap add android` / `ios`). Store review for dating apps requires in-app reporting, blocking and account deletion, and Kindred already has all three. You'll also need a privacy policy URL and a moderation plan for reports.

## Before a public launch
- **Moderation:** reports land in the `reports` table. Someone has to review them every day (Supabase Table Editor works to start with).
- **Photo moderation:** photos are not screened automatically yet.
- **Privacy policy and terms:** these are required for app stores and for handling personal data.
- **Phone-number sign-in (SMS OTP):** many people in Sierra Leone use phone numbers more than email. Supabase supports this with an SMS provider such as Twilio or Africa's Talking. This is worth adding next.
- **Rate limiting:** swipes and messages are not rate limited yet.
