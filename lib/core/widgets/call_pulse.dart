import 'package:flutter/material.dart';

import '../theme.dart';

/// A soft ring that keeps spreading out from a Call button so it is easy to
/// spot — the app's version of the site's `call-pulse` animation. Doesn't
/// change the button's size or layout; off when the phone asks for reduced
/// motion.
class CallPulse extends StatefulWidget {
  const CallPulse({
    super.key,
    required this.child,
    this.color = AppColors.forest,
    this.radius = 8,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  State<CallPulse> createState() => _CallPulseState();
}

class _CallPulseState extends State<CallPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Spread over the first 70% of the cycle, then rest — like the CSS.
        final t = (_controller.value / 0.7).clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                spreadRadius: 10 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
