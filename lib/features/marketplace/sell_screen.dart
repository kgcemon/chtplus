import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../../router.dart';
import '../widgets/form_fields.dart';
import '../widgets/site_scaffold.dart';
import '../widgets/wizard_parts.dart';

/// Post or edit a marketplace advert in the website's two steps: product
/// details (category, title, condition, place, specs, photos), then price and
/// contact. Category-specific spec fields appear once a category with extras
/// is chosen.
class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key, this.existing});

  final Listing? existing;

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  final _detailsKey = GlobalKey<FormState>();
  final _contactKey = GlobalKey<FormState>();
  int _step = 0;
  bool _submitted = false;

  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _price = TextEditingController(
    text: widget.existing == null ? '' : widget.existing!.price.round().toString(),
  );
  late final _sellerName =
      TextEditingController(text: widget.existing?.sellerName ?? '');
  late final _sellerPhone =
      TextEditingController(text: widget.existing?.sellerPhone ?? '');

  late String? _categoryId = widget.existing?.categoryId;
  late String _condition = widget.existing?.condition ?? marketplaceConditions[1];
  late String? _district = widget.existing?.district;
  late String? _area = widget.existing?.area;
  late bool _negotiable = widget.existing?.negotiable ?? false;
  late final Map<String, String> _extras = {
    for (final entry in widget.existing?.specs ?? const <MapEntry<String, String>>[])
      entry.key: entry.value,
  };
  late List<String> _keepPhotos = List.of(widget.existing?.photos ?? const []);
  List<String> _newPhotos = [];
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (!_isEdit && user != null) {
      _sellerName.text = user.name;
      _sellerPhone.text = user.phone ?? '';
      _area = user.area;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _sellerName.dispose();
    _sellerPhone.dispose();
    super.dispose();
  }

  /// Checks the first step before moving on to price & contact.
  void _next() {
    if (!(_detailsKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      AppSnackbar.error(context, 'Please choose a category.');
      return;
    }
    if (_district == null || _area == null) {
      AppSnackbar.error(context, 'Please choose a district and an area.');
      return;
    }
    if (!_isEdit && _newPhotos.isEmpty) {
      AppSnackbar.error(context, 'Please add at least one photo of the item.');
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (!(_contactKey.currentState?.validate() ?? false)) return;

    final price = num.tryParse(_price.text.trim()) ?? -1;
    setState(() => _busy = true);
    final repository = ref.read(marketplaceRepositoryProvider);

    try {
      if (_isEdit) {
        await repository.update(
          id: widget.existing!.id,
          categoryId: _categoryId!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          price: price,
          condition: _condition,
          district: _district!,
          area: _area!,
          sellerName: _sellerName.text.trim(),
          sellerPhone: _sellerPhone.text.trim(),
          negotiable: _negotiable,
          extraAttributes: _extras,
          keepPhotoUrls: _keepPhotos,
          newPhotoPaths: _newPhotos,
        );
      } else {
        await repository.create(
          categoryId: _categoryId!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          price: price,
          condition: _condition,
          district: _district!,
          area: _area!,
          sellerName: _sellerName.text.trim(),
          sellerPhone: _sellerPhone.text.trim(),
          negotiable: _negotiable,
          extraAttributes: _extras,
          photoPaths: _newPhotos,
        );
      }

      ref.invalidate(myListingsProvider);
      ref.invalidate(listingsProvider);
      ref.invalidate(homeFeedProvider);
      if (!mounted) return;

      if (_isEdit) {
        await AppDialogs.confirm(
          context,
          title: 'Product updated',
          message:
              'Your changes were saved. An admin reviews every edit before the product is public again.',
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
    return SiteScaffold(
      title: _isEdit ? 'Edit product' : 'Sell',
      subtitle: _isEdit
          ? null
          : 'Submit an ad with your product’s details; people of Khagrachari can see it after admin approval',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: _submitted
            ? [
                WizardSuccess(
                  title: 'Your ad has been submitted!',
                  message:
                      'It will be published for everyone after admin approval. You can check the status on the "My Products" page.',
                  primaryLabel: 'View my products',
                  onPrimary: () => context.pushReplacement(Routes.myListings),
                  secondaryLabel: 'Post another ad',
                  onSecondary: () => context.pushReplacement('/marketplace/sell'),
                ),
              ]
            : [
                WizardSteps(labels: const ['Product details', 'Price & contact'], current: _step),
                const SizedBox(height: 22),
                if (_step == 0) _detailsStep() else _contactStep(),
              ],
      ),
    );
  }

  Widget _detailsStep() {
    final categories = ref.watch(marketplaceCategoriesProvider).valueOrNull ?? const [];
    final selected = categories.where((c) => c.id == _categoryId).firstOrNull;
    final parentId = selected == null
        ? null
        : (selected.isTopLevel ? selected.id : selected.parentId);
    final subcategories = categories.where((c) => c.parentId == parentId).toList();
    final extraFields = extraFieldsFor(_categoryId);

    String label(String id) {
      final match = categories.firstWhere((c) => c.id == id);
      return '${match.icon ?? ''} ${match.name}'.trim();
    }

    return Form(
      key: _detailsKey,
      child: WizardCard(
        children: [
          WizardField(
            label: 'Category',
            required: true,
            child: AppDropdown(
              value: parentId,
              options: categories.where((c) => c.isTopLevel).map((c) => c.id).toList(),
              hint: 'Select',
              labelBuilder: label,
              onChanged: (value) => setState(() {
                _categoryId = value;
                _extras.clear();
              }),
            ),
          ),
          if (subcategories.isNotEmpty)
            WizardField(
              label: 'Subcategory (optional)',
              child: AppDropdown(
                value: selected != null && !selected.isTopLevel ? selected.id : null,
                options: subcategories.map((c) => c.id).toList(),
                includeEmpty: true,
                emptyLabel: '— Not specified —',
                hint: '— Not specified —',
                labelBuilder: label,
                onChanged: (value) => setState(() {
                  _categoryId = value ?? parentId;
                  _extras.clear();
                }),
              ),
            ),
          WizardField(
            label: 'Title',
            required: true,
            child: TextFormField(
              controller: _title,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Samsung Galaxy A14, good condition',
                counterText: '',
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a title' : null,
            ),
          ),
          WizardField(
            label: 'Condition',
            required: true,
            child: AppDropdown(
              value: _condition,
              options: marketplaceConditions,
              onChanged: (value) => setState(() => _condition = value ?? _condition),
            ),
          ),
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
          if (extraFields.isNotEmpty)
            WizardSubsection(
              title: 'Product details',
              children: [
                for (final field in extraFields)
                  WizardField(
                    label: field.label,
                    child: field.isSelect
                        ? AppDropdown(
                            value: _extras[field.key],
                            options: field.options,
                            includeEmpty: true,
                            emptyLabel: 'Select',
                            onChanged: (value) => setState(() {
                              if (value == null) {
                                _extras.remove(field.key);
                              } else {
                                _extras[field.key] = value;
                              }
                            }),
                          )
                        : TextFormField(
                            initialValue: _extras[field.key],
                            decoration: InputDecoration(hintText: field.placeholder),
                            onChanged: (value) {
                              final trimmed = value.trim();
                              if (trimmed.isEmpty) {
                                _extras.remove(field.key);
                              } else {
                                _extras[field.key] = trimmed;
                              }
                            },
                          ),
                  ),
              ],
            ),
          WizardField(
            label: 'Photos (max 4, the first will be the cover photo)',
            required: !_isEdit,
            child: PhotoPickerField(
              maxPhotos: 4,
              existingUrls: _keepPhotos,
              newPaths: _newPhotos,
              onExistingRemoved: (url) => setState(
                () => _keepPhotos = _keepPhotos.where((u) => u != url).toList(),
              ),
              onNewPathsChanged: (paths) => setState(() => _newPhotos = paths),
            ),
          ),
          WizardActions(nextLabel: 'Next step →', onNext: _next),
        ],
      ),
    );
  }

  Widget _contactStep() {
    return Form(
      key: _contactKey,
      child: WizardCard(
        children: [
          WizardField(
            label: 'Price (৳)',
            required: true,
            child: TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '0'),
              validator: (value) {
                final parsed = num.tryParse((value ?? '').trim());
                if (parsed == null || parsed < 0) return 'Enter a price';
                return null;
              },
            ),
          ),
          CheckboxListTile(
            value: _negotiable,
            onChanged: (value) => setState(() => _negotiable = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            activeColor: AppColors.forest,
            title: const Text('Price is negotiable', style: TextStyle(fontSize: 14)),
          ),
          WizardField(
            label: 'Description',
            required: true,
            child: TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Write in detail about the product...',
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Write a description' : null,
            ),
          ),
          WizardField(
            label: 'Your name',
            required: true,
            child: TextFormField(
              controller: _sellerName,
              maxLength: 150,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(counterText: ''),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
          ),
          WizardField(
            label: 'Phone number',
            required: true,
            child: TextFormField(
              controller: _sellerPhone,
              keyboardType: TextInputType.phone,
              maxLength: 30,
              decoration: const InputDecoration(hintText: '01XXXXXXXXX', counterText: ''),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a phone number' : null,
            ),
          ),
          WizardActions(
            nextLabel: _isEdit ? 'Save changes' : 'Submit ad',
            busyLabel: _isEdit ? 'Saving...' : 'Submitting...',
            busy: _busy,
            onNext: _submit,
            onBack: () => setState(() => _step = 0),
          ),
        ],
      ),
    );
  }
}
