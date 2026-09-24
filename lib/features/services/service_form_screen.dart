import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../../router.dart';
import '../widgets/form_fields.dart';
import '../widgets/site_scaffold.dart';
import '../widgets/wizard_parts.dart';

/// Add or edit a service, laid out like the site's form: Identity, Address &
/// contact, Service description and Photos sections in one card. Both land
/// the row as `pending`, so it only becomes public once an admin approves it.
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
  bool _submitted = false;

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

      if (_isEdit) {
        await AppDialogs.confirm(
          context,
          title: 'Service updated',
          message: 'Your changes were saved. An admin reviews edits before they appear publicly.',
          confirmLabel: 'Done',
          cancelLabel: 'Close',
        );
        if (mounted) context.pop(true);
      } else {
        setState(() => _submitted = true);
      }
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(serviceCategoriesProvider).valueOrNull ?? const [];

    return SiteScaffold(
      title: _isEdit ? 'Edit service' : 'Add a service',
      subtitle: _isEdit ? null : 'Submit your service’s details; the people of Khagrachari will find it',
      body: _submitted
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                WizardSuccess(
                  title: 'Your service has been submitted!',
                  message:
                      'It will be published for everyone after admin approval. You can check the status on the "My Services" page.',
                  primaryLabel: 'View my services',
                  onPrimary: () => context.pushReplacement(Routes.myServices),
                  secondaryLabel: 'Go to the service list',
                  onSecondary: () => context.go(Routes.services),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  WizardCard(
                    gap: 20,
                    children: [
                      WizardSection(
                        title: '🗂️ Identity',
                        children: [
                          WizardField(
                            label: 'Category',
                            required: true,
                            child: AppDropdown(
                              value: _categoryId,
                              options: categories.map((c) => c.id).toList(),
                              hint: 'Select',
                              labelBuilder: (id) {
                                final match = categories.firstWhere((c) => c.id == id);
                                return '${match.icon ?? ''} ${match.name}'.trim();
                              },
                              onChanged: (value) => setState(() => _categoryId = value),
                            ),
                          ),
                          WizardField(
                            label: 'Name/Organization name',
                            required: true,
                            child: TextFormField(
                              controller: _providerName,
                              maxLength: 150,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(counterText: ''),
                              validator: (value) =>
                                  (value ?? '').trim().isEmpty ? 'Enter a name' : null,
                            ),
                          ),
                        ],
                      ),
                      WizardSection(
                        title: '📍 Address & contact',
                        children: [
                          WizardField(
                            label: 'District',
                            required: true,
                            child: DistrictPicker(
                              value: _district,
                              includeEmpty: false,
                              onChanged: (value) => setState(() {
                                _district = value;
                                // The old thana belongs to the previous district.
                                _area = null;
                              }),
                            ),
                          ),
                          WizardField(
                            label: 'Thana/Area',
                            required: true,
                            child: UpazilaPicker(
                              districtName: _district,
                              value: _area,
                              includeEmpty: false,
                              onChanged: (value) => setState(() => _area = value),
                            ),
                          ),
                          WizardField(
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
                        ],
                      ),
                      WizardSection(
                        title: '📝 Service description',
                        children: [
                          TextFormField(
                            controller: _description,
                            maxLines: 4,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Write in detail about your service...',
                            ),
                            validator: (value) =>
                                (value ?? '').trim().isEmpty ? 'Write a description' : null,
                          ),
                        ],
                      ),
                      WizardSection(
                        title: '🖼️ Photos (optional, max 2)',
                        last: true,
                        children: [
                          PhotoPickerField(
                            maxPhotos: 2,
                            existingUrls: _keepPhotos,
                            newPaths: _newPhotos,
                            onExistingRemoved: (url) => setState(
                              () => _keepPhotos = _keepPhotos.where((u) => u != url).toList(),
                            ),
                            onNewPathsChanged: (paths) => setState(() => _newPhotos = paths),
                          ),
                        ],
                      ),
                      WizardActions(
                        nextLabel: _isEdit ? 'Save changes' : 'Submit service',
                        busyLabel: _isEdit ? 'Saving...' : 'Submitting...',
                        busy: _busy,
                        onNext: _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
