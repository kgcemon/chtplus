import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/photo_gallery.dart';
import '../../models/biodata.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/save_button.dart';

/// Shows a teaser until the viewer has access, then the full record. Access is
/// bought once with coins (or covered by a subscription) and never expires.
class BiodataDetailScreen extends ConsumerWidget {
  const BiodataDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(biodataDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.biodata.biodataNo ?? 'Biodata'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SaveButton(
              targetType: 'biodata',
              targetId: id,
              light: false,
              size: 22,
            ),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const AppLoader(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(biodataDetailProvider(id)),
        ),
        data: (data) =>
            data.hasAccess ? _FullView(data: data) : _LockedView(data: data),
      ),
    );
  }
}

// --- Locked -----------------------------------------------------------------

class _LockedView extends ConsumerStatefulWidget {
  const _LockedView({required this.data});

  final BiodataDetail data;

  @override
  ConsumerState<_LockedView> createState() => _LockedViewState();
}

class _LockedViewState extends ConsumerState<_LockedView> {
  bool _busy = false;

  Future<void> _unlock({String? packageId}) async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(biodataRepositoryProvider).unlock(
            widget.data.biodata.id,
            packageId: packageId,
          );
      ref.invalidate(biodataDetailProvider(widget.data.biodata.id));
      ref.invalidate(coinBalanceProvider);
      if (mounted) AppSnackbar.success(context, 'Biodata unlocked.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'insufficient_coins') {
        AppSnackbar.error(context, 'Not enough coins. Top up to unlock.');
        context.push(Routes.coins);
      } else if (error.code == 'package_required') {
        AppSnackbar.show(context, 'Choose a package to unlock this biodata.');
      } else {
        AppSnackbar.error(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePackage() async {
    final packages = widget.data.packages;
    if (packages.isEmpty) {
      AppSnackbar.show(context, 'No unlock packages are available right now.');
      return;
    }
    final chosen = await AppDialogs.sheet<BiodataPackage>(
      context,
      child: _PackageSheet(
        packages: packages,
        coinBalance: widget.data.coinBalance,
      ),
    );
    if (chosen != null) await _unlock(packageId: chosen.id);
  }

  @override
  Widget build(BuildContext context) {
    final biodata = widget.data.biodata;
    final data = widget.data;

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        if (biodata.photos.isNotEmpty)
          PhotoCarousel(
            photos: biodata.photos,
            height: 240,
            placeholderIcon: Icons.person_outline,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    biodata.biodataNo ?? 'Biodata',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 10),
                  StatusPill(
                    label: dataLabel(biodata.gender),
                    color: biodata.isBride
                        ? const Color(0xFFC2185B)
                        : AppColors.forest,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LabeledRow(label: 'Age', value: biodata.age == null ? '—' : '${biodata.age} years'),
              LabeledRow(label: 'Height', value: biodata.height ?? '—'),
              LabeledRow(
                label: 'Marital status',
                value: dataLabel(biodata.maritalStatus),
              ),
              LabeledRow(label: 'Profession', value: biodata.profession ?? '—'),
              LabeledRow(label: 'Area', value: biodata.area ?? '—'),
              const SizedBox(height: 20),
              _UnlockPanel(
                data: data,
                busy: _busy,
                onUseWallet: () => _unlock(),
                onChoosePackage: _choosePackage,
                onSignIn: () => context.push(Routes.login),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnlockPanel extends StatelessWidget {
  const _UnlockPanel({
    required this.data,
    required this.busy,
    required this.onUseWallet,
    required this.onChoosePackage,
    required this.onSignIn,
  });

  final BiodataDetail data;
  final bool busy;
  final VoidCallback onUseWallet;
  final VoidCallback onChoosePackage;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.forestLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.forest.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.forestDark),
              SizedBox(width: 10),
              Text(
                'Full biodata is locked',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Unlock to see education, family details, expectations and the guardian\'s contact number. Once unlocked, this biodata stays open for you forever.',
            style: TextStyle(fontSize: 13, height: 1.55, color: AppColors.forestDark),
          ),
          const SizedBox(height: 16),
          if (data.loginRequired)
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign in to unlock'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            )
          else if (data.walletAvailable)
            FilledButton.icon(
              onPressed: busy ? null : onUseWallet,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text('Use 1 of your ${data.walletRemaining} remaining unlocks'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            )
          else
            FilledButton.icon(
              onPressed: busy ? null : onChoosePackage,
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              label: const Text('Choose an unlock package'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          if (!data.loginRequired) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'Your balance: ${data.coinBalance} coins',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestDark,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(Routes.coins),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Buy coins'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PackageSheet extends StatefulWidget {
  const _PackageSheet({required this.packages, required this.coinBalance});

  final List<BiodataPackage> packages;
  final int coinBalance;

  @override
  State<_PackageSheet> createState() => _PackageSheetState();
}

class _PackageSheetState extends State<_PackageSheet> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Unlock packages',
              subtitle: 'Each package opens a number of biodata, permanently.',
              trailing: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  '🪙 ${widget.coinBalance}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forestDark,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Column(
                children: [
                  for (final package in widget.packages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedId = package.id),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _selectedId == package.id
                                ? AppColors.forestLight
                                : AppColors.surface,
                            border: Border.all(
                              color: _selectedId == package.id
                                  ? AppColors.forest
                                  : AppColors.border,
                              width: _selectedId == package.id ? 1.6 : 1,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedId == package.id
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 20,
                                color: _selectedId == package.id
                                    ? AppColors.forest
                                    : AppColors.border,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      package.name,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Opens ${package.biodataCount} biodata',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '🪙 ${package.coinCost}',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: widget.coinBalance >= package.coinCost
                                          ? AppColors.forestDark
                                          : AppColors.red,
                                    ),
                                  ),
                                  if (widget.coinBalance < package.coinCost)
                                    const Text(
                                      'Not enough',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.red,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _selectedId == null
                        ? null
                        : () => Navigator.of(context).pop(
                              widget.packages
                                  .firstWhere((p) => p.id == _selectedId),
                            ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Unlock now'),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Unlocked ---------------------------------------------------------------

class _FullView extends StatelessWidget {
  const _FullView({required this.data});

  final BiodataDetail data;

  @override
  Widget build(BuildContext context) {
    final b = data.biodata;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (b.photos.isNotEmpty)
          PhotoCarousel(
            photos: b.photos,
            height: 280,
            placeholderIcon: Icons.person_outline,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            children: [
              Text(
                b.biodataNo ?? 'Biodata',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              StatusPill(
                label: dataLabel(b.gender),
                color: b.isBride ? const Color(0xFFC2185B) : AppColors.forest,
              ),
              const Spacer(),
              const StatusPill(
                label: 'Unlocked',
                color: AppColors.forest,
                icon: Icons.lock_open_rounded,
              ),
            ],
          ),
        ),
        _Section(
          title: 'General information',
          rows: [
            ('Age', b.age == null ? '' : '${b.age} years'),
            ('Date of birth', Fmt.date(b.dateOfBirth)),
            ('Marital status', dataLabel(b.maritalStatus)),
            ('Height', b.height ?? ''),
            ('Skin tone', dataLabel(b.skinTone)),
            ('Blood group', dataLabel(b.bloodGroup)),
            ('Religion', dataLabel(b.religion)),
            ('Profession type', dataLabel(b.professionType)),
            ('Profession', b.profession ?? ''),
            ('Monthly income', b.monthlyIncome ?? ''),
            ('Permanent district', b.permanentDistrict ?? ''),
            ('Permanent upazila', b.permanentUpazila ?? ''),
            ('Current district', b.currentDistrict ?? ''),
            ('Current upazila', b.currentUpazila ?? ''),
            ('Current address', b.currentAddress ?? ''),
          ],
        ),
        _Section(
          title: 'Education',
          rows: [
            ('Medium', dataLabel(b.educationMedium)),
            if (b.sscPassed) ('SSC year', b.sscYear ?? ''),
            if (b.sscPassed) ('SSC institution', b.sscInstitution ?? ''),
            if (b.sscPassed) ('SSC group', dataLabel(b.sscGroup)),
            if (b.hscPassed) ('HSC year', b.hscYear ?? ''),
            if (b.hscPassed) ('HSC institution', b.hscInstitution ?? ''),
            if (b.hscPassed) ('HSC group', dataLabel(b.hscGroup)),
            if (b.graduationPassed) ('Graduation institution', b.institutionName ?? ''),
            if (b.graduationPassed) ('Department', b.graduationDepartment ?? ''),
            if (b.graduationPassed) ('Graduation year', b.graduationYear ?? ''),
            if (b.postgraduationPassed)
              ('Postgrad institution', b.postgraduationInstitution ?? ''),
            if (b.postgraduationPassed)
              ('Postgrad department', b.postgraduationDepartment ?? ''),
            if (b.postgraduationPassed) ('Postgrad year', b.postgraduationYear ?? ''),
            ('Other education', b.otherEducation ?? ''),
          ],
        ),
        _Section(
          title: 'Family',
          rows: [
            ("Father's name", b.fatherName ?? ''),
            ("Father's profession", b.fatherProfession ?? ''),
            ("Mother's name", b.motherName ?? ''),
            ("Mother's profession", b.motherProfession ?? ''),
            ('Brothers', b.brotherCount?.toString() ?? ''),
            ('Sisters', b.sisterCount?.toString() ?? ''),
            ('Siblings', b.siblingsProfession ?? ''),
          ],
        ),
        if ((b.siblings ?? const []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                for (final sibling in b.siblings!)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              sibling.name.isEmpty ? 'Sibling' : sibling.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusPill(
                              label: dataLabel(sibling.relation),
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        if (sibling.profession.isNotEmpty ||
                            sibling.organization.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            [
                              dataLabel(sibling.profession),
                              sibling.organization,
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (sibling.maritalStatus.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            dataLabel(sibling.maritalStatus),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        _Section(
          title: 'Personal',
          rows: [
            ('Prayer habit', dataLabel(b.prayerHabit)),
            ('Health condition', b.healthCondition ?? ''),
            ('Political affiliation', b.politicalAffiliation ?? ''),
          ],
        ),
        if ((b.aboutSelf ?? '').isNotEmpty)
          _TextSection(title: 'About', body: b.aboutSelf!),
        _Section(
          title: 'Expectations',
          rows: [
            ('Maximum age', b.expectedMaxAge ?? ''),
            ('Skin tone', dataLabel(b.expectedSkinTone)),
            ('Minimum height', b.expectedMinHeight ?? ''),
            ('Education', b.expectedEducation ?? ''),
            ('Profession', b.expectedProfession ?? ''),
            ('District', b.expectedDistrict ?? ''),
            ('Marital status', dataLabel(b.expectedMaritalStatus)),
            ('Economic condition', b.expectedEconomicCondition ?? ''),
            ('Family condition', b.expectedFamilyCondition ?? ''),
            if (!b.isBride) ('Wife may study', dataLabel(b.wifeEducationPermission)),
            if (!b.isBride) ('Wife may work', dataLabel(b.wifeJobPermission)),
            if (!b.isBride) ('Where wife will live', b.whereWifeWillLive ?? ''),
            ('Dowry expectation', b.dowryExpectation ?? ''),
          ],
        ),
        if ((b.expectedQualities ?? '').isNotEmpty)
          _TextSection(title: 'Desired qualities', body: b.expectedQualities!),
        if ((b.otherRequirements ?? '').isNotEmpty)
          _TextSection(title: 'Other requirements', body: b.otherRequirements!),
        const SectionHeader(title: 'Contact'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledRow(
                  label: 'Guardian relation',
                  value: dataLabel(b.guardianRelation),
                  icon: Icons.family_restroom_outlined,
                ),
                LabeledRow(
                  label: 'Guardian phone',
                  value: b.guardianPhone ?? '—',
                  icon: Icons.phone_outlined,
                ),
                if ((b.mobileNumber ?? '').isNotEmpty)
                  LabeledRow(
                    label: 'Mobile',
                    value: b.mobileNumber!,
                    icon: Icons.smartphone_outlined,
                  ),
                if ((b.email ?? '').isNotEmpty)
                  LabeledRow(
                    label: 'Email',
                    value: b.email!,
                    icon: Icons.mail_outline_rounded,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if ((b.guardianPhone ?? '').isNotEmpty)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Launchers.call(context, b.guardianPhone),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call guardian'),
                        ),
                      ),
                    if ((b.email ?? '').isNotEmpty) ...[
                      if ((b.guardianPhone ?? '').isNotEmpty)
                        const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => Launchers.email(context, b.email),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(52, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Icon(Icons.mail_outline_rounded, size: 19),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final filled = rows.where((r) => r.$2.trim().isNotEmpty).toList();
    if (filled.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (final row in filled)
                  LabeledRow(label: row.$1, value: row.$2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              body,
              style: const TextStyle(fontSize: 13.5, height: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}
