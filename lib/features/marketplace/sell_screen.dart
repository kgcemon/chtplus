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
import '../widgets/form_fields.dart';

/// Post or edit a marketplace advert. Category-specific spec fields appear once
/// a subcategory with extras is chosen, matching the website's sell wizard.
class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key, this.existing});

  final Listing? existing;

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_isEdit && _newPhotos.isEmpty) {
      AppSnackbar.error(context, 'Please add at least one photo of the item.');
      return;
    }

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

      await AppDialogs.confirm(
        context,
        title: _isEdit ? 'Advert updated' : 'Advert submitted',
        message: _isEdit
            ? 'Your changes were saved. An admin reviews every edit before the advert is public again.'
            : 'Thanks! An admin will review your advert and publish it shortly. Track it under "My adverts".',
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
    final categories = ref.watch(marketplaceCategoriesProvider).valueOrNull ?? const [];
    final selected = categories.where((c) => c.id == _categoryId).firstOrNull;
    final parentId = selected == null
        ? null
        : (selected.isTopLevel ? selected.id : selected.parentId);
    final subcategories =
        categories.where((c) => c.parentId == parentId).toList();
    final extraFields = extraFieldsFor(_categoryId);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit advert' : 'Sell an item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.forestLight,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.forestDark),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'An admin reviews every advert before it goes live. Clear photos and an honest description get approved fastest.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppColors.forestDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FormRowField(
              label: 'Category',
              required: true,
              child: AppDropdown(
                value: parentId,
                options:
                    categories.where((c) => c.isTopLevel).map((c) => c.id).toList(),
                hint: 'Choose a category',
                labelBuilder: (id) {
                  final match = categories.firstWhere((c) => c.id == id);
                  return '${match.icon ?? ''} ${match.name}'.trim();
                },
                onChanged: (value) => setState(() {
                  _categoryId = value;
                  _extras.clear();
                }),
              ),
            ),
            if (subcategories.isNotEmpty)
              FormRowField(
                label: 'Subcategory',
                required: true,
                child: AppDropdown(
                  value: selected != null && !selected.isTopLevel ? selected.id : null,
                  options: subcategories.map((c) => c.id).toList(),
                  hint: 'Choose a subcategory',
                  labelBuilder: (id) =>
                      subcategories.firstWhere((c) => c.id == id).name,
                  onChanged: (value) => setState(() {
                    _categoryId = value;
                    _extras.clear();
                  }),
                ),
              ),
            FormRowField(
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
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a title' : null,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormRowField(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormRowField(
                    label: 'Condition',
                    required: true,
                    child: AppDropdown(
                      value: _condition,
                      options: marketplaceConditions,
                      onChanged: (value) =>
                          setState(() => _condition = value ?? _condition),
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              value: _negotiable,
              onChanged: (value) => setState(() => _negotiable = value),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Price is negotiable',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              activeThumbColor: AppColors.forest,
            ),
            const SizedBox(height: 8),
            if (extraFields.isNotEmpty) ...[
              const Text(
                'Specifications',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final field in extraFields)
                FormRowField(
                  label: field.label,
                  child: field.isSelect
                      ? AppDropdown(
                          value: _extras[field.key],
                          options: field.options,
                          includeEmpty: true,
                          emptyLabel: 'Not specified',
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
            FormRowField(
              label: 'Description',
              required: true,
              hint: 'Age of the item, any faults, what is included, why you are selling.',
              child: TextFormField(
                controller: _description,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Describe the item…'),
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
              label: 'Your name',
              required: true,
              child: TextFormField(
                controller: _sellerName,
                maxLength: 150,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(counterText: ''),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter your name' : null,
              ),
            ),
            FormRowField(
              label: 'Contact number',
              required: true,
              child: TextFormField(
                controller: _sellerPhone,
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
              required: !_isEdit,
              hint: 'Up to 4 photos. The first one becomes the cover.',
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
