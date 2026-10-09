/// Static configuration for the CHT Plus app.
///
/// Everything an admin can change (Google client id, OneSignal app id) comes
/// from `/api/app-config` at startup instead of being compiled in here.
class AppConfig {
  const AppConfig._();

  /// Live site. Override at build time with
  /// `flutter build apk --dart-define=CHT_API_BASE=https://staging.example.com`.
  static const String apiBase = String.fromEnvironment(
    'CHT_API_BASE',
    defaultValue: 'https://chtplus.xyz',
  );

  static const String appName = 'CHT Plus';
  static const String privacyPolicyUrl = '$apiBase/privacy-policy';
  static const String aboutUrl = '$apiBase/about';
  static const String termsUrl = '$apiBase/terms';
  static const String websiteUrl = apiBase;

  /// The app's Play Store page (package `com.chtplus.bd`), sent by "Share app".
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.chtplus.bd';

  /// Shown in the home footer and its "Contact" call to action, matching the
  /// contact block the site renders there.
  static const String supportPhone = '01828820222';
  static const String supportWhatsappUrl = 'https://wa.me/8801828820222';
  static const String officeAddress = 'Khagrachari Sadar, Khagrachari';
  static const String tagline =
      'The local services platform for Khagrachari, Rangamati and Bandarban.';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 25);

  /// Turns a `/uploads/...` path from the API into a full URL.
  static String? absoluteUrl(String? path) {
    if (path == null) return null;
    final value = path.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return value.startsWith('/') ? '$apiBase$value' : '$apiBase/$value';
  }
}
