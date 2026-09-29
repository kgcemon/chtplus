import '../config.dart';

/// Turns a link produced by the backend into the matching in-app route.
///
/// Notifications carry website paths (`lib/notify.js` writes them, and
/// `lib/push.js` turns them into absolute URLs like
/// `https://chtplus.xyz/chat/12`), so both forms have to be understood. Several
/// of them point at a *list* page with an `?open=` hint; the app has a real
/// detail screen for those, so they are redirected there instead.
///
/// Returns null when the link is empty or points somewhere the app has no
/// screen for — the caller decides what to do then.
String? appRouteForLink(String? link) {
  final raw = (link ?? '').trim();
  if (raw.isEmpty) return null;

  Uri? uri = Uri.tryParse(raw);
  if (uri == null) return null;

  // An absolute link is only ours if it points at the CHT Plus site; anything
  // else (an admin pasted an external campaign URL) belongs in a browser.
  if (uri.hasScheme) {
    final base = Uri.parse(AppConfig.apiBase);
    final host = uri.host.replaceFirst('www.', '');
    if (host.isNotEmpty && host != base.host.replaceFirst('www.', '')) {
      return null;
    }
  }

  // A trailing slash is the same page ("/chat/" is the inbox), so it is
  // trimmed before matching — otherwise it would fall through to null.
  var path = uri.path.isEmpty ? '/' : uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final open = uri.queryParameters['open'];

  // --- list pages that carry an ?open= id ---------------------------------
  if (path == '/donors') return open == null ? '/donors' : '/donors/$open';
  if (path == '/my-services') {
    return open == null ? '/my-services' : '/services/$open';
  }
  if (path == '/my-listings') {
    return open == null ? '/my-listings' : '/marketplace/listing/$open';
  }
  if (path == '/my-biodata') {
    return open == null ? '/my-biodata' : '/biodata/view/$open';
  }

  // --- direct matches ------------------------------------------------------
  const exact = {
    '/': '/',
    '/services': '/services',
    '/marketplace': '/marketplace',
    '/biodata': '/biodata',
    '/biodata/list': '/biodata',
    '/coins': '/coins',
    '/chat': '/chat',
    '/profile': '/profile',
    '/saved': '/saved',
  };
  final match = exact[path];
  if (match != null) return match;

  // --- detail routes the app mirrors one-to-one ---------------------------
  const prefixes = [
    '/chat/',
    '/services/',
    '/donors/',
    '/marketplace/listing/',
    '/biodata/view/',
    '/u/',
  ];
  for (final prefix in prefixes) {
    if (path.startsWith(prefix) && path.length > prefix.length) return path;
  }

  return null;
}

/// Where a notification tap should land when its link is missing or points at
/// a page the app does not have. The notification centre is always a sensible
/// destination — the item is in the list there.
const String notificationFallbackRoute = '/notifications';
