import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/doctor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/form_fields.dart';

/// Two-step booking: pick an open date, then enter the patient's details.
/// The server re-validates the date, so one taken in the meantime is rejected
/// rather than double-booked.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    required this.doctorId,
    required this.chamberId,
  });

  final String doctorId;
  final String chamberId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientName = TextEditingController();
  final _patientPhone = TextEditingController();
  final _patientAge = TextEditingController();
  final _note = TextEditingController();

  String? _selectedDate;
  String? _gender;
  int _step = 0;
  bool _busy = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _patientName.dispose();
    _patientPhone.dispose();
    _patientAge.dispose();
    _note.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_prefilled) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    _prefilled = true;
    _patientName.text = user.name;
    _patientPhone.text = user.phone ?? '';
  }

  Future<void> _book() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final date = _selectedDate;
    if (date == null) {
      setState(() => _step = 0);
      AppSnackbar.error(context, 'Please choose an appointment date.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(doctorRepositoryProvider).bookSerial(
            chamberId: widget.chamberId,
            date: date,
            patientName: _patientName.text.trim(),
            patientPhone: _patientPhone.text.trim(),
            patientAge: int.tryParse(_patientAge.text.trim()),
            patientGender: _gender,
            note: _note.text,
          );

      ref.invalidate(myAppointmentsProvider);
      ref.invalidate(doctorDetailProvider(widget.doctorId));
      ref.invalidate(
        chamberAvailabilityProvider(
          (doctorId: widget.doctorId, chamberId: widget.chamberId),
        ),
      );
      if (!mounted) return;
      await _showConfirmation(date);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'date_unavailable') {
        setState(() {
          _selectedDate = null;
          _step = 0;
        });
        ref.invalidate(
          chamberAvailabilityProvider(
            (doctorId: widget.doctorId, chamberId: widget.chamberId),
          ),
        );
      }
      AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showConfirmation(String date) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.forest),
            SizedBox(width: 10),
            Text('Request sent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Your serial request for ${Fmt.longDate(DateTime.tryParse(date))} has been sent. '
          'The chamber will confirm it and your serial number will appear under "My appointments".',
          style: const TextStyle(fontSize: 14, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
              context.push(Routes.myAppointments);
            },
            child: const Text('View appointments'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    final availability = ref.watch(
      chamberAvailabilityProvider(
        (doctorId: widget.doctorId, chamberId: widget.chamberId),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a serial'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _step == 0 ? 0.5 : 1,
            minHeight: 4,
            backgroundColor: AppColors.forest.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
      body: _step == 0
          ? _DateStep(
              availability: availability,
              selected: _selectedDate,
              onSelect: (date) => setState(() => _selectedDate = date),
              onRetry: () => ref.invalidate(
                chamberAvailabilityProvider(
                  (doctorId: widget.doctorId, chamberId: widget.chamberId),
                ),
              ),
            )
          : _DetailsStep(
              formKey: _formKey,
              patientName: _patientName,
              patientPhone: _patientPhone,
              patientAge: _patientAge,
              note: _note,
              gender: _gender,
              onGenderChanged: (value) => setState(() => _gender = value),
              selectedDate: _selectedDate,
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                if (_step == 1) ...[
                  OutlinedButton(
                    onPressed: _busy ? null : () => setState(() => _step = 0),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : _step == 0
                            ? (_selectedDate == null
                                ? null
                                : () => setState(() => _step = 1))
                            : _book,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_step == 0 ? 'Continue' : 'Confirm booking'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateStep extends StatelessWidget {
  const _DateStep({
    required this.availability,
    required this.selected,
    required this.onSelect,
    required this.onRetry,
  });

  final AsyncValue<List<AvailableDate>> availability;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return availability.when(
      loading: () => const AppLoader(),
      error: (error, _) => ErrorView(message: '$error', onRetry: onRetry),
      data: (dates) {
        if (dates.isEmpty) {
          return const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No open dates',
            message:
                'This chamber has no bookable dates in the next 30 days. Try another chamber or check back later.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            const Text(
              'Choose a date',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Only dates with seats left are shown.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final date in dates)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DateTile(
                  date: date,
                  selected: selected == date.date,
                  onTap: () => onSelect(date.date),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final AvailableDate date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsed = date.dateTime;
    final almostFull = date.remainingCapacity <= 3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.forestLight : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.forest : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    parsed == null ? '' : '${parsed.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.text,
                    ),
                  ),
                  Text(
                    parsed == null ? '' : Fmt.shortDate(parsed).split(' ').last,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.longDate(parsed),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (date.timeRange.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      date.timeRange,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            StatusPill(
              label: '${date.remainingCapacity} left',
              color: almostFull ? AppColors.amber : AppColors.forest,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.formKey,
    required this.patientName,
    required this.patientPhone,
    required this.patientAge,
    required this.note,
    required this.gender,
    required this.onGenderChanged,
    required this.selectedDate,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController patientName;
  final TextEditingController patientPhone;
  final TextEditingController patientAge;
  final TextEditingController note;
  final String? gender;
  final ValueChanged<String?> onGenderChanged;
  final String? selectedDate;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.forestLight,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    size: 18, color: AppColors.forestDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    Fmt.longDate(DateTime.tryParse(selectedDate ?? '')),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FormRowField(
            label: "Patient's name",
            required: true,
            child: TextFormField(
              controller: patientName,
              maxLength: 150,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(counterText: ''),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? "Enter the patient's name" : null,
            ),
          ),
          FormRowField(
            label: 'Contact number',
            required: true,
            child: TextFormField(
              controller: patientPhone,
              keyboardType: TextInputType.phone,
              maxLength: 30,
              decoration: const InputDecoration(
                hintText: '01XXXXXXXXX',
                counterText: '',
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a contact number' : null,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FormRowField(
                  label: 'Age',
                  child: TextFormField(
                    controller: patientAge,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      hintText: 'Years',
                      counterText: '',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormRowField(
                  label: 'Gender',
                  child: AppDropdown(
                    value: gender,
                    options: const ['male', 'female', 'other'],
                    includeEmpty: true,
                    emptyLabel: 'Not specified',
                    hint: 'Select',
                    labelBuilder: (value) => switch (value) {
                      'male' => 'Male',
                      'female' => 'Female',
                      _ => 'Other',
                    },
                    onChanged: onGenderChanged,
                  ),
                ),
              ),
            ],
          ),
          FormRowField(
            label: 'Note for the doctor',
            hint: 'Symptoms, previous conditions or anything else worth knowing.',
            child: TextFormField(
              controller: note,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
          ),
        ],
      ),
    );
  }
}
