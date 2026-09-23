import 'package:intl/intl.dart';

class Fmt {
  const Fmt._();

  static final _taka = NumberFormat('#,##,###', 'en_IN');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _dayMonth = DateFormat('d MMM');
  static final _timeOfDay = DateFormat('h:mm a');
  static final _weekdayLong = DateFormat('EEEE, d MMMM yyyy');

  /// `৳1,20,000` — the same grouping the website uses for prices.
  static String taka(num? value) {
    if (value == null) return '৳0';
    return '৳${_taka.format(value.round())}';
  }

  static String number(num? value) {
    if (value == null) return '0';
    return _taka.format(value);
  }

  static String date(DateTime? value) =>
      value == null ? '' : _dayMonthYear.format(value);

  static String longDate(DateTime? value) =>
      value == null ? '' : _weekdayLong.format(value);

  static String shortDate(DateTime? value) =>
      value == null ? '' : _dayMonth.format(value);

  static String time(DateTime? value) =>
      value == null ? '' : _timeOfDay.format(value);

  /// `2:14 PM` for today, `Yesterday`, `12 Mar` beyond that — for chat lists.
  static String messageStamp(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(value.year, value.month, value.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return _timeOfDay.format(value);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(value);
    return _dayMonth.format(value);
  }

  /// `just now` / `5m ago` / `3h ago` / `2d ago` / date.
  static String relative(DateTime? value) {
    if (value == null) return '';
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _dayMonthYear.format(value);
  }

  /// An ISO `yyyy-MM-dd` string, which is what the booking and profile routes
  /// expect for date fields.
  static String isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String initials(String? name) {
    final text = (name ?? '').trim();
    if (text.isEmpty) return '?';
    final parts = text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.characters1();
    return '${parts.first.characters1()}${parts.last.characters1()}';
  }

  /// Blood-donor eligibility mirrors `lib/format.js` on the server: a donor is
  /// available again 120 days after their last donation.
  static bool isEligibleToDonate(DateTime? lastDonation) {
    if (lastDonation == null) return true;
    return DateTime.now().difference(lastDonation).inDays >= 120;
  }

  static String relationshipLabel(String? value) {
    switch (value) {
      case 'single':
        return 'Single';
      case 'in_relationship':
        return 'In a relationship';
      case 'married':
        return 'Married';
      case 'complicated':
        return "It's complicated";
      default:
        return '';
    }
  }

  static String privacyLabel(String? value) {
    switch (value) {
      case 'followers':
        return 'Followers';
      case 'only_me':
        return 'Only me';
      default:
        return 'Public';
    }
  }

  static String statusLabel(String? value) {
    switch (value) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Awaiting review';
      case 'rejected':
        return 'Rejected';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'active':
        return 'Active';
      case 'expired':
        return 'Expired';
      default:
        return value == null || value.isEmpty ? '' : value;
    }
  }

  /// Strips tags from the sanitized description HTML for one-line previews.
  static String plainText(String? html) {
    if (html == null || html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

extension on String {
  String characters1() => isEmpty ? '' : substring(0, 1).toUpperCase();
}
