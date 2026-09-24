import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/doctor.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/site_scaffold.dart';

class MyAppointmentsScreen extends ConsumerWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(myAppointmentsProvider);

    return SiteScaffold(
      title: 'My Serials',
      subtitle: 'View your serial requests and their status',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myAppointmentsProvider);
          await ref.read(myAppointmentsProvider.future);
        },
        child: appointments.when(
          loading: () => const AppLoader(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(myAppointmentsProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'No appointments yet',
                    message:
                        'Book a serial with a doctor and it will show up here with its status and serial number.',
                    actionLabel: 'Find a doctor',
                    onAction: () => context.push(Routes.doctors),
                  ),
                ],
              );
            }

            final upcoming = items.where((s) => s.isUpcoming).toList();
            final past = items.where((s) => !s.isUpcoming).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const _GroupLabel(label: 'Upcoming'),
                  for (final serial in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AppointmentCard(serial: serial),
                    ),
                ],
                if (past.isNotEmpty) ...[
                  const _GroupLabel(label: 'Past & cancelled'),
                  for (final serial in past)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AppointmentCard(serial: serial),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({required this.serial});

  final Serial serial;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Cancel this appointment?',
      message:
          'Your serial request with ${serial.doctorName ?? 'this doctor'} on '
          '${Fmt.date(serial.appointmentDate)} will be cancelled.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(doctorRepositoryProvider).cancelAppointment(serial.id);
      ref.invalidate(myAppointmentsProvider);
      if (context.mounted) AppSnackbar.success(context, 'Appointment cancelled.');
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serial.doctorName ?? 'Doctor',
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    if ((serial.specialty ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        serial.specialty!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.forestDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              StatusPill.forStatus(serial.status),
            ],
          ),
          const SizedBox(height: 12),
          LabeledRow(
            label: 'Date',
            value: Fmt.longDate(serial.appointmentDate),
            icon: Icons.event_outlined,
          ),
          if (serial.serialNumber != null)
            LabeledRow(
              label: 'Serial number',
              value: '#${serial.serialNumber}',
              icon: Icons.confirmation_number_outlined,
            ),
          LabeledRow(
            label: 'Chamber',
            value: serial.organizationName ?? '—',
            icon: Icons.local_hospital_outlined,
          ),
          LabeledRow(
            label: 'Patient',
            value: serial.patientName ?? '—',
            icon: Icons.person_outline_rounded,
          ),
          if ((serial.note ?? '').isNotEmpty)
            LabeledRow(
              label: 'Note',
              value: serial.note!,
              icon: Icons.sticky_note_2_outlined,
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if ((serial.organizationPhone ?? '').isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Launchers.call(context, serial.organizationPhone),
                    icon: const Icon(Icons.call_rounded, size: 17),
                    label: const Text('Call chamber'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  ),
                ),
              if (serial.canCancel) ...[
                if ((serial.organizationPhone ?? '').isNotEmpty)
                  const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancel(context, ref),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
