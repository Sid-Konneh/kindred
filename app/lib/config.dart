/// Same Supabase project as the web app, so web and phone users meet in one pool.
/// The publishable key is meant for clients; row level security protects the data.
const supabaseUrl = 'https://febcajqqmswcfzsawxmy.supabase.co';
const supabaseKey = 'sb_publishable_v1BYOuEAsDeRFw0xO29J7w_f-tmLRRv';

const webUrl = 'https://kindred-sl.netlify.app';

/// Email links (confirm account, reset password) open the app through this link on the phone.
/// It must be listed in Supabase → Authentication → URL Configuration → Redirect URLs.
const appRedirect = 'sl.kindred.app://login-callback/';

/// Kindred's AdMob banner unit, shown above the tab bar (see ads.dart). The AdMob app ID is in
/// android/app/src/main/AndroidManifest.xml. For testing on your own phone, use Google's test unit
/// ca-app-pub-3940256099942544/9214589741 instead: tapping real ads yourself can get the account banned.
const admobBannerUnit = 'ca-app-pub-5424348425908005/6327936245';
