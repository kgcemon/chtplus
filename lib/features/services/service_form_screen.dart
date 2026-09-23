import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../widgets/form_fields.dart';

/// Add or edit a service. Both land the row as `pending`, so it only becomes
/// public once an admin approves it — same as the website.
class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.existing});

  final ServiceItem? existing;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _providerName =
      TextEditingController(text: widget.existing?.providerName ?? '');
  late final _description = TextEditingController(
    text: Fmt.plainText(widget.existing?.description),
  );
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');

  late String? _categoryId = widget.existing?.categoryId;
  late String? _district = widget.existing?.district;
  late String? _area = widget.existing?.area;
  late List<String> _keepPhotos = List.of(widget.existing?.allPhotos ?? const []);
  List<String> _newPhotos = [];
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill the contact details from the account so the form is mostly done.
    final user = ref.read(currentUserProvider);
    if (!_isEdit && user != null) {
      if (_phone.text.isEmpty) _phone.text = user.phone ?? '';
      _area ??= user.area;
    }
  }

  @override
  void dispose() {
    _providerName.dispose();
    _description.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      AppSnackbar.error(context, 'Please choose a category.');
      return;
    }
    if (_district == null || _area == null) {
      AppSnackbar.error(context, 'Please choose a district and an area.');
      return;
    }

    setState(() => _busy = true);
    final repository = ref.read(serviceRepositoryProvider);
    try {
      if (_isEdit) {
        await repository.update(
          id: widget.existing!.id,
          categoryId: _categoryId!,
          providerName: _providerName.text.trim(),
          description: _description.text.trim(),
          district: _district!,
          area: _area!,
          phone: _phone.text.trim(),
          keepPhotoUrls: _keepPhotos,
          newPhotoPaths: _newPhotos,
        );
      } else {
        await repository.create(
          categoryId: _categoryId!,
          providerName: _providerName.text.trim(),
          description: _description.text.trim(),
          district: _district!,
          area: _area!,
          phone: _phone.text.trim(),
          photoPaths: _newPhotos,
        );
      }

      ref.invalidate(myServicesProvider);
      ref.invalidate(servicesProvider);
      ref.invalidate(homeFeedProvider);
      if (!mounted) return;

      await AppDialogs.confirm(
        context,
        title: _isEdit ? 'Service updated' : 'Service submitted',
        message: _isEdit
            ? 'Your changes were saved. An admin reviews edits before they appear publicly.'
            : 'Thanks! An admin will review your service and publish it shortly. You can track it under "My services".',
        confirmLabel: 'Done',
        cancelLabel: 'Close',
      );
      if (mounted) context.pop(true);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(serviceCategoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit service' : 'Add a service')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            const _Notice(
              text:
                  'Every service is checked by an admin before it goes live. Give clear, honest details so yours is approved quickly.',
            ),
            const SizedBox(height: 18),
            FormRowField(
              label: 'Category',
              required: true,
              child: AppDropdown(
                value: _categoryId,
                options: categories.map((c) => c.id).toList(),
                hint: 'Choose a category',
                labelBuilder: (id) {
                  final match = categories.firstWhere((c) => c.id == id);
                  return '${match.icon ?? ''} ${match.name}'.trim();
                },
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ),
            FormRowField(
              label: 'Business or provider name',
              required: true,
              child: TextFormField(
                controller: _providerName,
                maxLength: 150,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Hill Track Electric Services',
                  counterText: '',
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
            ),
            FormRowField(
              label: 'Description',
              required: true,
              hint: 'What you offer, your experience, pricing, working hours.',
              child: TextFormField(
                controller: _description,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe your service…',
                ),
                validator: (value) => (value ?? '').trim().length < 20
                    ? 'Write at least 20 characters'
                    : null,
              ),
            ),
            FormRowField(
              label: 'District',
              required: true,
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
              label: 'Contact number',
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
                    (value ?? '').trim().isEmpty ? 'Enter a contact number' : null,
              ),
            ),
            FormRowField(
              label: 'Photos',
              hint: 'Up to 2 photos. The first one is used as the cover.',
              child: PhotoPickerField(
                maxPhotos: 2,
                existingUrls: _keepPhotos,
                newPaths: _newPhotos,
                onExistingRemoved: (url) =>
                    setState(() => _keepPhotos = _keepPhotos.where((u) => u != url).toList()),
                onNewPathsChanged: (paths) => setState(() => _newPhotos = paths),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
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
                  : Text(_isEdit ? 'Save changes' : 'Submit for review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.forestLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.forestDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.forestDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
