import 'package:flutter/material.dart';

import '../theme.dart';

class AppSnackbar {
  const AppSnackbar._();

  static void show(BuildContext context, String message) =>
      _show(context, message, AppColors.text, Icons.info_outline);

  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.forestDark, Icons.check_circle_outline);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.red, Icons.error_outline);

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
