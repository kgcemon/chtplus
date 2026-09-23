import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../widgets/app_snackbar.dart';

/// Phone calls, WhatsApp, maps, external links and sharing — all guarded so a
/// device without the target app shows a message instead of throwing.
class Launchers {
  const Launchers._();

  static String normalizePhone(String raw) =>
      raw.replaceAll(RegExp(r'[^\d+]'), '');

  static Future<void> call(BuildContext context, String? phone) async {
    final number = normalizePhone(phone ?? '');
    if (number.isEmpty) {
      AppSnackbar.show(context, 'No phone number available.');
      return;
    }
    final ok = await _open(Uri(scheme: 'tel', path: number));
    if (!ok && context.mounted) {
      AppSnackbar.show(context, 'Could not start a call on this device.');
    }
  }

  static Future<void> sms(BuildContext context, String? phone) async {
    final number = normalizePhone(phone ?? '');
    if (number.isEmpty) return;
    final ok = await _open(Uri(scheme: 'sms', path: number));
    if (!ok && context.mounted) {
      AppSnackbar.show(context, 'Could not open the messaging app.');
    }
  }

  static Future<void> whatsapp(BuildContext context, String? phone, {String? text}) async {
    var number = normalizePhone(phone ?? '').replaceAll('+', '');
    if (number.isEmpty) return;
    // Local Bangladeshi numbers are stored as 01XXXXXXXXX; WhatsApp needs 880.
    if (number.startsWith('01') && number.length == 11) number = '88$number';
    final uri = Uri.parse(
      'https://wa.me/$number${text != null ? '?text=${Uri.encodeComponent(text)}' : ''}',
    );
    final ok = await _open(uri);
    if (!ok && context.mounted) {
      AppSnackbar.show(context, 'WhatsApp is not installed.');
    }
  }

  static Future<void> email(BuildContext context, String? address) async {
    final value = (address ?? '').trim();
    if (value.isEmpty) return;
    final ok = await _open(Uri(scheme: 'mailto', path: value));
    if (!ok && context.mounted) {
      AppSnackbar.show(context, 'No email app is set up on this device.');
    }
  }

  static Future<void> map(BuildContext context, String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    final ok = await _open(uri);
    if (!ok && context.mounted) {
      AppSnackbar.show(context, 'Could not open maps.');
    }
  }

  static Future<void> url(BuildContext context, String? link) async {
    final value = (link ?? '').trim();
    if (value.isEmpty) return;
    final uri = Uri.tryParse(
      value.startsWith('http') ? value : '${AppConfig.apiBase}$value',
    );
    if (uri == null) return;
    final ok = await _open(uri);
    if (!ok && context.mounted) {
      AppSnackbar.show(context, 'Could not open that link.');
    }
  }

  static Future<void> share(String text, {String? subject}) =>
      Share.share(text, subject: subject);

  /// Shares a deep link back to the matching page on the website, so anything
  /// shared from the app still opens for someone who does not have it.
  static Future<void> shareWebLink(String path, {required String title}) =>
      Share.share('$title\n${AppConfig.apiBase}$path', subject: title);

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
