import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sign-up email checks, identical to the web app's. The database also rejects malformed and
/// throwaway addresses, so these checks are about giving people a clear message early.
final _emailRe = RegExp(r"^[a-z0-9._%+'-]+@[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,}$", caseSensitive: false);

bool validEmail(String e) => _emailRe.hasMatch(e) && !e.contains('..') && !e.startsWith('.') && !e.contains('.@') && e.length <= 254;

final _nameRe = RegExp(r"^\p{L}[\p{L} '.-]{1,39}$", unicode: true);
bool validName(String n) => _nameRe.hasMatch(n);

const _typos = {
  'gmial.com': 'gmail.com', 'gmai.com': 'gmail.com', 'gmal.com': 'gmail.com', 'gamil.com': 'gmail.com', 'gmail.co': 'gmail.com', 'gmail.con': 'gmail.com',
  'gmail.cm': 'gmail.com', 'gmail.om': 'gmail.com', 'gmaill.com': 'gmail.com', 'gnail.com': 'gmail.com', 'gmail.comm': 'gmail.com', 'gmsil.com': 'gmail.com',
  'gmali.com': 'gmail.com', 'gmail.cim': 'gmail.com', 'yaho.com': 'yahoo.com', 'yahoo.con': 'yahoo.com', 'yahho.com': 'yahoo.com', 'yahoo.co': 'yahoo.com',
  'yhoo.com': 'yahoo.com', 'hotmial.com': 'hotmail.com', 'hotmal.com': 'hotmail.com', 'hotmail.con': 'hotmail.com', 'hotmai.com': 'hotmail.com',
  'hotmil.com': 'hotmail.com', 'outlok.com': 'outlook.com', 'outlook.con': 'outlook.com', 'outllok.com': 'outlook.com', 'iclod.com': 'icloud.com',
  'icloud.con': 'icloud.com', 'iclould.com': 'icloud.com',
};

const _disposable = {
  'mailinator.com', 'yopmail.com', '10minutemail.com', 'guerrillamail.com', 'guerrillamail.net', 'sharklasers.com', 'tempmail.com', 'temp-mail.org',
  'tempmail.net', 'tempmailo.com', 'throwawaymail.com', 'trashmail.com', 'getnada.com', 'nada.email', 'dispostable.com', 'maildrop.cc', 'fakeinbox.com',
  'mintemail.com', 'emailondeck.com', 'mohmal.com', 'burnermail.io', 'mailnesia.com', 'mytemp.email', 'tempr.email', 'discard.email', 'spamgourmet.com',
  'getairmail.com', 'moakt.com', 'tmail.ws', 'emailfake.com', '1secmail.com', 'guerrillamailblock.com', 'mailcatch.com', 'inboxkitten.com', 'tempinbox.com',
  'dropmail.me', 'fakemail.net', 'byom.de', '33mail.com',
};

const _knownMail = {
  'gmail.com', 'googlemail.com', 'yahoo.com', 'ymail.com', 'outlook.com', 'hotmail.com', 'live.com', 'msn.com', 'icloud.com', 'me.com', 'aol.com',
  'proton.me', 'protonmail.com', 'zoho.com', 'yandex.com', 'gmx.com',
};

final _cache = <String, bool>{};

/// Asks public DNS whether the domain can receive email. Never blocks sign-up if the check itself fails.
Future<bool> domainAcceptsMail(String domain) async {
  if (_knownMail.contains(domain)) return true;
  if (_cache.containsKey(domain)) return _cache[domain]!;
  Future<Map<String, dynamic>> q(String type) async {
    final r = await http.get(Uri.https('dns.google', '/resolve', {'name': domain, 'type': type})).timeout(const Duration(seconds: 4));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  var ok = true;
  try {
    final mx = await q('MX');
    if (mx['Status'] == 3) {
      ok = false; // the domain does not exist
    } else if (!((mx['Answer'] as List?) ?? []).any((a) => a['type'] == 15)) {
      final a = await q('A');
      ok = ((a['Answer'] as List?) ?? []).isNotEmpty;
    }
  } catch (_) {
    ok = true;
  }
  _cache[domain] = ok;
  return ok;
}

class EmailProblem {
  final String message;
  final String? fix;
  const EmailProblem(this.message, [this.fix]);
}

/// null when the email looks fine.
Future<EmailProblem?> emailProblem(String email) async {
  if (!validEmail(email)) return const EmailProblem('Please enter a valid email address, like name@gmail.com.');
  final parts = email.split('@');
  final user = parts[0], domain = parts[1];
  final fixed = _typos[domain];
  if (fixed != null) return EmailProblem('Did you mean $user@$fixed?', '$user@$fixed');
  if (_disposable.contains(domain)) return const EmailProblem("Temporary email addresses can't be used on Kindred. Please use your own email.");
  if (!await domainAcceptsMail(domain)) return EmailProblem("We can't find an email service at $domain. Please check your email address.");
  return null;
}
