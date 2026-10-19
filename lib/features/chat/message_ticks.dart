import 'package:flutter/material.dart';

/// Ticks on your own chat messages, like the site's `MessageTicks`: one tick
/// once sent, two once the other person's app/site has received it, two blue
/// ones once they have read it.
class MessageTicks extends StatelessWidget {
  const MessageTicks({
    super.key,
    required this.status,
    required this.color,
    this.readColor = const Color(0xFF1D9BF0),
    this.size = 14,
  });

  /// sent · delivered · read
  final String? status;
  final Color color;
  final Color readColor;
  final double size;

  /// Status of one of my messages from the thread's receipts.
  static String statusFor(int messageId, {required int deliveredUpTo, required int readUpTo}) {
    if (messageId <= 0) return 'sent'; // not saved yet
    if (messageId <= readUpTo) return 'read';
    if (messageId <= deliveredUpTo) return 'delivered';
    return 'sent';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tint, label) = switch (status) {
      'read' => (Icons.done_all_rounded, readColor, 'Seen'),
      'delivered' => (Icons.done_all_rounded, color, 'Delivered'),
      'sent' => (Icons.done_rounded, color, 'Sent'),
      _ => (null, color, ''),
    };
    if (icon == null) return const SizedBox.shrink();
    return Icon(icon, size: size, color: tint, semanticLabel: label);
  }
}
