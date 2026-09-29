import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/photo_gallery.dart';
import '../../models/biodata.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../../data/moderation_repository.dart';
import '../home/widgets/home_header.dart';
import '../widgets/moderation.dart';

/// Shows a teaser until the viewer has access, then the full record, both
/// drawn like the site's biodata page: the paywall card, then the printed
/// "Marriage Biodata" document. Access is bought once and never expires.
class BiodataDetailScreen extends ConsumerWidget {
  const BiodataDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(biodataDetailProvider(id));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(biodataDetailProvider(id));
          await ref.read(biodataDetailProvider(id).future);
        },
        child: CustomScrollView(
          slivers: [
            const HomeHeader(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              sliver: SliverToBoxAdapter(
                child: detail.when(
                  loading: () => const _Document(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Loading...',
                        style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  error: (error, _) => ErrorView(
                    message: '$error',
                    onRetry: () => ref.invalidate(biodataDetailProvider(id)),
                  ),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      data.hasAccess ? _FullView(data: data) : _LockedView(data: data),
                      const SizedBox(height: 12),
                      ReportLink(target: ReportTarget.biodata, targetId: id, what: 'biodata'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The white rounded sheet every biodata view sits on (`.cvd-document`).
class _Document extends StatelessWidget {
  const _Document({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 40, offset: Offset(0, 12)),
        ],
      ),
      child: child,
    );
  }
}

/// Main photo (160×190) with small thumbnails, or a 👰 / 🤵 placeholder.
class _Photo extends StatelessWidget {
  const _Photo({required this.biodata, this.thumbs = true});

  final Biodata biodata;
  final bool thumbs;

  @override
  Widget build(BuildContext context) {
    final photos = biodata.photos;
    void open(int i) => FullScreenGallery.open(context, photos: photos, initialIndex: i);

    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 190,
            decoration: BoxDecoration(
              color: AppColors.forestLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.forestLight, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: photos.isEmpty
                ? Center(
                    child: Text(
                      biodata.isBride ? '👰' : '🤵',
                      style: const TextStyle(fontSize: 56),
                    ),
                  )
                : GestureDetector(
                    onTap: () => open(0),
                    child: AppNetworkImage(url: photos.first, width: 160, height: 190),
                  ),
          ),
          if (thumbs && photos.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 1; i < photos.length; i++)
                  GestureDetector(
                    onTap: () => open(i),
                    child: AppNetworkImage(
                      url: photos[i],
                      width: 48,
                      height: 48,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
          ],
        ],
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
    final data = widget.data;
    final b = data.biodata;
    final sub = [
      dataLabel(b.gender),
      b.area ?? '',
      if (b.age != null) 'Age ${b.age}',
    ].where((e) => e.isNotEmpty).join(' · ');

    final button = data.loginRequired
        ? FilledButton(
            onPressed: () => context.push(Routes.login),
            style: _paywallButton,
            child: const Text('Log in / Sign up'),
          )
        : data.walletAvailable
            ? FilledButton(
                onPressed: _busy ? null : () => _unlock(),
                style: _paywallButton,
                child: Text(_busy ? 'Unlocking...' : 'Unlock with quota'),
              )
            : FilledButton(
                onPressed: _busy || data.packages.isEmpty ? null : _choosePackage,
                style: _paywallButton,
                child: Text(_busy ? 'Unlocking...' : '🪙 Choose a package to unlock'),
              );

    return _Document(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _Photo(biodata: b, thumbs: false)),
            const SizedBox(height: 16),
            Text(
              b.profession ?? b.biodataNo ?? 'Biodata',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('🔒', textAlign: TextAlign.center, style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 6),
                  const Text(
                    'Unlock required to see the full biodata',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.walletAvailable
                        ? 'You have unused quota (${data.walletRemaining} biodata left) — you can unlock this biodata for free.'
                        : data.packages.isNotEmpty
                            ? 'To see the full information of this biodata (address, profession, family details, expectations), you need to buy a package.'
                            : 'No subscription packages have been added yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.loginRequired
                        ? 'Please log in first to view the biodata.'
                        : 'Your current balance: 🪙 ${data.coinBalance} coins',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  button,
                  if (!data.loginRequired) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => context.push(Routes.coins),
                      child: const Text('🪙 Buy coins'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _paywallButton = FilledButton.styleFrom(
    backgroundColor: AppColors.forest,
    minimumSize: const Size.fromHeight(46),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
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

/// The full record as the site's printed "Marriage Biodata" document.
class _FullView extends StatelessWidget {
  const _FullView({required this.data});

  final BiodataDetail data;

  String _passed(String? year, String? institution, String? group) =>
      'Passed (${year ?? '-'})'
      '${(group ?? '').isEmpty ? '' : ', ${dataLabel(group)}'}'
      '${(institution ?? '').isEmpty ? '' : ', $institution'}';

  String _degree(String? institution, String? department, String? year) =>
      '${department ?? '-'}, ${institution ?? '-'} (${year ?? '-'})';

  @override
  Widget build(BuildContext context) {
    final b = data.biodata;
    final siblings = b.siblings ?? const [];

    return _Document(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Green header with the amber rule underneath.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.forestDark, AppColors.forest],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(bottom: BorderSide(color: AppColors.amber, width: 4)),
            ),
            child: Column(
              children: [
                const Text(
                  '🌄 CHT Plus',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Marriage Biodata',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    b.biodataNo ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Photo and summary.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Photo(biodata: b),
                const SizedBox(height: 18),
                Text(
                  b.profession ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  [dataLabel(b.gender), b.area ?? ''].where((e) => e.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                const _DashedRule(),
                const SizedBox(height: 14),
                _Fields(
                  columns: 2,
                  rows: [
                    ('Age', b.age?.toString()),
                    ('Date of birth', Fmt.date(b.dateOfBirth)),
                    ('Skin tone', dataLabel(b.skinTone)),
                    ('Height', b.height),
                    ('Blood group', b.bloodGroup),
                    ('Religion', dataLabel(b.religion)),
                    ('Marital status', dataLabel(b.maritalStatus)),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            icon: '📍',
            title: 'Address',
            rows: [
              ('Permanent district', b.permanentDistrict),
              ('Permanent thana', b.permanentUpazila),
              ('Current district', b.currentDistrict),
              ('Current thana', b.currentUpazila),
              ('Current address', b.currentAddress),
            ],
          ),
          _Section(
            icon: '🎓',
            title: 'Education',
            rows: [
              ('Medium of education', dataLabel(b.educationMedium)),
              ('SSC', b.sscPassed ? _passed(b.sscYear, b.sscInstitution, b.sscGroup) : 'No'),
              ('HSC', b.hscPassed ? _passed(b.hscYear, b.hscInstitution, b.hscGroup) : 'No'),
              (
                'Graduate',
                b.graduationPassed
                    ? _degree(b.institutionName, b.graduationDepartment, b.graduationYear)
                    : 'No',
              ),
              if (b.graduationPassed)
                (
                  'Post-graduate',
                  b.postgraduationPassed
                      ? _degree(
                          b.postgraduationInstitution,
                          b.postgraduationDepartment,
                          b.postgraduationYear,
                        )
                      : 'No',
                ),
              if ((b.otherEducation ?? '').isNotEmpty) ('Other education', b.otherEducation),
            ],
          ),
          _Section(
            icon: '🕌',
            title: 'Personal Habits & Information',
            rows: [
              ('Prays five times a day?', dataLabel(b.prayerHabit)),
              ('Any mental or physical illness?', b.healthCondition),
              if (!b.isBride) ...[
                (
                  'After marriage, will you let your wife study?',
                  dataLabel(b.wifeEducationPermission),
                ),
                ('Will you let your wife work?', dataLabel(b.wifeJobPermission)),
                ('Where will you keep your wife after marriage?', b.whereWifeWillLive),
              ],
              ('Brief information about yourself', b.aboutSelf),
            ],
          ),
          _Section(
            icon: '💼',
            title: 'Professional Information',
            rows: [
              ('Profession type', dataLabel(b.professionType)),
              ('Profession', b.profession),
            ],
          ),
          _Section(
            icon: '👪',
            title: 'Family Information',
            rows: [
              ('Father’s name', b.fatherName),
              ('Father’s profession', dataLabel(b.fatherProfession)),
              ('Mother’s name', b.motherName),
              ('Mother’s profession', dataLabel(b.motherProfession)),
              ('Brothers', b.brotherCount?.toString()),
              ('Sisters', b.sisterCount?.toString()),
              if (siblings.isNotEmpty)
                (
                  'Siblings',
                  [
                    for (var i = 0; i < siblings.length; i++)
                      '${i + 1}. ${[
                        siblings[i].name.isEmpty ? '-' : siblings[i].name,
                        dataLabel(siblings[i].relation),
                        '${dataLabel(siblings[i].profession)}'
                            '${siblings[i].organization.isEmpty ? '' : ' (${siblings[i].organization})'}',
                        dataLabel(siblings[i].maritalStatus),
                      ].where((e) => e.isNotEmpty).join(' · ')}',
                  ].join('\n'),
                )
              else if ((b.siblingsProfession ?? '').isNotEmpty)
                ('Siblings’ professions', b.siblingsProfession),
            ],
          ),
          _Section(
            icon: '💍',
            title: 'Expected Life Partner',
            rows: [
              ('Maximum age', b.expectedMaxAge),
              ('Skin tone', dataLabel(b.expectedSkinTone)),
              ('Minimum height', b.expectedMinHeight),
              ('Education', b.expectedEducation),
              ('Profession', b.expectedProfession),
              ('Area', b.expectedDistrict),
              ('Marital status', dataLabel(b.expectedMaritalStatus)),
              ('Economic condition', b.expectedEconomicCondition),
              ('Family condition', b.expectedFamilyCondition),
              ('Expected qualities', b.expectedQualities),
              if ((b.otherRequirements ?? '').isNotEmpty)
                ('Other requirements', b.otherRequirements),
            ],
          ),
          _Section(
            icon: '📞',
            title: 'Contact',
            last: true,
            rows: [
              ('Guardian', dataLabel(b.guardianRelation)),
              ('Guardian’s phone', b.guardianPhone),
              if ((b.mobileNumber ?? '').isNotEmpty) ('Mobile', b.mobileNumber),
              if ((b.email ?? '').isNotEmpty) ('Email', b.email),
            ],
            footer: (b.guardianPhone ?? '').isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FilledButton(
                      onPressed: () => Launchers.call(context, b.guardianPhone),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('📞 Call guardian'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A titled block of the document with a round emoji badge (`.cvd-section`).
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.rows,
    this.footer,
    this.last = false,
  });

  final String icon;
  final String title;
  final List<(String, String?)> rows;
  final Widget? footer;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.forestLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forestDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Fields(rows: rows),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// Label-over-value fields, [columns] per row (`.cvd-fields-grid`). Empty
/// values show as "-", as on the site.
class _Fields extends StatelessWidget {
  const _Fields({required this.rows, this.columns = 1});

  final List<(String, String?)> rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    Widget field((String, String?) row) {
      final value = (row.$2 ?? '').trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.$1, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i += columns) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: 20),
                Expanded(
                  child: i + c < rows.length ? field(rows[i + c]) : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One-pixel dashed line (`border-top: 1px dashed`).
class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 8).floor();
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  color: AppColors.border,
                ),
              ),
          ],
        );
      },
    );
  }
}
