import 'package:flutter/material.dart';

import '../../core/theme.dart';

// Pieces of the website's step-by-step forms (sell, add a service, buy
// coins): numbered step chips, the white form card, the back / next buttons
// and the "submitted" screen.

/// Numbered step chips (`.sell-steps`, `.wizard-stepper`); steps before
/// [current] are done (✓ once there are more than two), [current] is active.
/// [current] counts from 0. With more than two steps the number sits above
/// the label so four fit on a phone.
class WizardSteps extends StatelessWidget {
  const WizardSteps({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    final stacked = labels.length > 2;

    Widget badge(int i) => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i <= current ? AppColors.forest : AppColors.border,
          ),
          alignment: Alignment.center,
          child: Text(
            stacked && i < current ? '✓' : '${i + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        );

    Widget label(int i) => Text(
          labels[i],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: stacked ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: stacked ? 11 : 13,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: i == current ? AppColors.forestDark : AppColors.textSecondary,
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) SizedBox(width: stacked ? 6 : 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: stacked ? 10 : 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: i == current ? AppColors.forest : AppColors.border),
              ),
              child: stacked
                  ? Column(children: [badge(i), const SizedBox(height: 6), label(i)])
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [badge(i), const SizedBox(width: 8), Flexible(child: label(i))],
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The white rounded card a step's fields sit in (`.sell-form`), with
/// [gap] between them.
class WizardCard extends StatelessWidget {
  const WizardCard({super.key, required this.children, this.gap = 18});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0D14281E), blurRadius: 14, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A caption over a field, "Title*" style, as the site labels its inputs.
class WizardField extends StatelessWidget {
  const WizardField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          required ? '$label*' : label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        const SizedBox(height: 6),
        child,
        if ((hint ?? '').isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(hint!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// A dashed-top sub-section inside a step, e.g. "Product details"
/// (`.sell-extra-fields`).
class WizardSubsection extends StatelessWidget {
  const WizardSubsection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Dashes(),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.forestDark,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          children[i],
        ],
      ],
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          for (var i = 0; i < (constraints.maxWidth / 8).floor(); i++)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                color: AppColors.border,
              ),
            ),
        ],
      ),
    );
  }
}

/// "← Previous step" (outlined) and the primary button (`.form-actions`).
class WizardActions extends StatelessWidget {
  const WizardActions({
    super.key,
    required this.nextLabel,
    required this.onNext,
    this.onBack,
    this.backLabel = '← Previous step',
    this.busy = false,
    this.busyLabel = 'Submitting...',
  });

  final String nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String backLabel;
  final bool busy;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    const text = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (onBack != null)
          OutlinedButton(
            onPressed: busy ? null : onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest,
              side: const BorderSide(color: AppColors.forest),
              padding: padding,
              textStyle: text,
              shape: shape,
            ),
            child: Text(backLabel),
          ),
        FilledButton(
          onPressed: busy ? null : onNext,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forest,
            padding: padding,
            textStyle: text,
            shape: shape,
          ),
          child: Text(busy ? busyLabel : nextLabel),
        ),
      ],
    );
  }
}

/// The "✅ submitted" screen shown after a wizard finishes (`.sell-success`).
class WizardSuccess extends StatelessWidget {
  const WizardSuccess({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return WizardCard(
      children: [
        const Text('✅', textAlign: TextAlign.center, style: TextStyle(fontSize: 44)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.textSecondary),
        ),
        Center(
          child: WizardActions(
            nextLabel: primaryLabel,
            onNext: onPrimary,
            onBack: onSecondary,
            backLabel: secondaryLabel ?? '',
          ),
        ),
      ],
    );
  }
}

/// A titled group of fields with a rule underneath (`.form-section`); the
/// [last] one has no rule.
class WizardSection extends StatelessWidget {
  const WizardSection({
    super.key,
    required this.title,
    required this.children,
    this.last = false,
  });

  final String title;
  final List<Widget> children;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : 20),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.forestDark,
            ),
          ),
          for (final child in children) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}
