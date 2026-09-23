import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/donor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../widgets/form_fields.dart';

/// Register as a blood donor, or update the profile already attached to this
/// account — the endpoint handles both cases.
class DonorFormScreen extends ConsumerStatefulWidget {
  const DonorFormScreen({super.key});

  @override
  ConsumerState<DonorFormScreen> createState() => _DonorFormScreenState();
}

class _DonorFormScreenState extends ConsumerState<DonorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  String? _bloodGroup;
  String? _district;
  String? _area;
  String? _lastDonationDate;
  bool _busy = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Fills the form from the existing donor row (or the account) the first time
  /// the profile arrives.
  void _prefill() {
    if (_prefilled) return;
    final profile = ref.read(meProfileProvider).valueOrNull;
    if (profile == null) return;
    _prefilled = true;

    final donor = profile.donor;
    _name.text = profile.name;
    _phone.text = donor?.phone ?? profile.phone ?? '';
    _bloodGroup = donor?.bloodGroup;
    _district = donor?.district;
    _area = donor?.area ?? profile.area;
    _lastDonationDate = donor?.lastDonationDate == null
        ? null
        : donor!.lastDonationDate!.toIso8601String().split('T').first;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_bloodGroup == null) {
      AppSnackbar.error(context, 'Please choose your blood group.');
      return;
    }
    if (_area == null) {
      AppSnackbar.error(context, 'Please choose your area.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(donorRepositoryProvider).saveMyProfile(
            name: _name.text.trim(),
            bloodGroup: _bloodGroup!,
            phone: _phone.text.trim(),
            area: _area!,
            district: _district,
            lastDonationDate: _lastDonationDate,
          );
      ref.invalidate(donorsProvider);
      ref.invalidate(meProfileProvider);
      ref.invalidate(homeFeedProvider);
      if (!mounted) return;
      AppSnackbar.success(context, 'Your donor profile is live. Thank you!');
      context.pop(true);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(meProfileProvider);
    if (profile.hasValue) _prefill();

    final isUpdate = profile.valueOrNull?.donor != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isUpdate ? 'Update donor profile' : 'Become a blood donor'),
      ),
      body: profile.isLoading
          ? const AppLoader()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.favorite_rounded, size: 18, color: AppColors.red),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your name, area and phone number become visible to anyone searching for a donor, so they can reach you in an emergency.',
                            style: TextStyle(fontSize: 12.5, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FormRowField(
                    label: 'Your name',
                    required: true,
                    child: TextFormField(
                      controller: _name,
                      maxLength: 150,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(counterText: ''),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Enter your name' : null,
                    ),
                  ),
                  FormRowField(
                    label: 'Blood group',
                    required: true,
                    child: AppDropdown(
                      value: _bloodGroup,
                      options: bloodGroups,
                      hint: 'Choose your blood group',
                      onChanged: (value) => setState(() => _bloodGroup = value),
                    ),
                  ),
                  FormRowField(
                    label: 'Phone number',
                    required: true,
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 30,
                      decoration: const InputDecoration(
                        hintText: '01XXXXXXXXX',
                        counterText: '',
                      ),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Enter a phone number' : null,
                    ),
                  ),
                  FormRowField(
                    label: 'District',
                    child: DistrictPicker(
                      value: _district,
                      includeEmpty: false,
                      onChanged: (value) => setState(() {
                        _district = value;
                        _area = null;
                      }),
                    ),
                  ),
                  FormRowField(
                    label: 'Area (thana)',
                    required: true,
                    child: UpazilaPicker(
                      districtName: _district,
                      value: _area,
                      includeEmpty: false,
                      onChanged: (value) => setState(() => _area = value),
                    ),
                  ),
                  FormRowField(
                    label: 'Last donation date',
                    hint:
                        'Leave empty if you have never donated. You become available again 120 days after donating.',
                    child: DateField(
                      value: _lastDonationDate,
                      hint: 'Never donated',
                      onChanged: (value) =>
                          setState(() => _lastDonationDate = value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isUpdate ? 'Save changes' : 'Register as a donor'),
                  ),
                ],
              ),
            ),
    );
  }
}
