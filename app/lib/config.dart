/// Same Supabase project as the web app, so web and phone users meet in one pool.
/// The publishable key is meant for clients; row level security protects the data.
const supabaseUrl = 'https://febcajqqmswcfzsawxmy.supabase.co';
const supabaseKey = 'sb_publishable_v1BYOuEAsDeRFw0xO29J7w_f-tmLRRv';

const webUrl = 'https://kindred-sl.netlify.app';

/// Email links (confirm account, reset password) open the app through this link on the phone.
/// It must be listed in Supabase → Authentication → URL Configuration → Redirect URLs.
const appRedirect = 'sl.kindred.app://login-callback/';
