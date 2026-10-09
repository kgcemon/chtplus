import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/photo_gallery.dart';
import '../../models/biodata.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../../data/moderation_repository.dart';
import '../home/widgets/home_header.dart';
import '../widgets/form_fields.dart';
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

  static bool _isUrl(String p) => p.startsWith('http://') || p.startsWith('https://');

  /// A photo URL, or a local file path while previewing an unsent biodata.
  static Widget _image(String source, double width, double height, {BorderRadius? radius}) {
    if (_isUrl(source)) {
      return AppNetworkImage(url: source, width: width, height: height, borderRadius: radius);
    }
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: Image.file(File(source), width: width, height: height, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = biodata.photos;
    void open(int i) {
      if (photos.every(_isUrl)) {
        FullScreenGallery.open(context, photos: photos, initialIndex: i);
      }
    }

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
                    child: _image(photos.first, 160, 190),
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
                    child: _image(photos[i], 48, 48, radius: BorderRadius.circular(8)),
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
  String? _error;

  /// The package picked in the dropdown; the first one to start with.
  String? _packageId;

  @override
  void initState() {
    super.initState();
    _syncPackage();
  }

  @override
  void didUpdateWidget(covariant _LockedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPackage();
  }

  void _syncPackage() {
    final packages = widget.data.packages;
    if (packages.isEmpty) {
      _packageId = null;
    } else if (!packages.any((p) => p.id == _packageId)) {
      _packageId = packages.first.id;
    }
  }

  BiodataPackage? get _selectedPackage {
    for (final p in widget.data.packages) {
      if (p.id == _packageId) return p;
    }
    return null;
  }

  Future<void> _unlock() async {
    final data = widget.data;
    final selected = _selectedPackage;
    if (!data.walletAvailable && selected != null && data.coinBalance < selected.coinCost) {
      await _showCoinPopup(selected.coinCost);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(biodataRepositoryProvider).unlock(
            data.biodata.id,
            packageId: data.walletAvailable ? null : selected?.id,
          );
      ref.invalidate(biodataDetailProvider(data.biodata.id));
      ref.invalidate(coinBalanceProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'insufficient_coins') {
        await _showCoinPopup(selected?.coinCost ?? 0);
      } else {
        setState(() => _error = 'Could not unlock, please try again');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "You don’t have enough coins" (`.coin-popup`).
  Future<void> _showCoinPopup(int cost) async {
    final config = ref.read(appRemoteConfigProvider).valueOrNull;
    final showBalance = config?.showCoinBalance ?? true;
    final canBuy = config?.coinBuyEnabled ?? true;
    final balance = widget.data.coinBalance;

    final buy = await showDialog<bool>(
      context: context,
      builder: (dialog) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 6),
              const Text(
                'You don’t have enough coins',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
                  children: [
                    const TextSpan(text: 'To buy this package you need '),
                    TextSpan(
                      text: '$cost coins',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    if (showBalance) ...[
                      const TextSpan(text: ' — you currently have '),
                      TextSpan(
                        text: '$balance coins',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                    ],
                    TextSpan(text: canBuy ? '. Add coins to continue.' : '. Please try again later.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (canBuy)
                    FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('🪙 Buy coins'),
                    ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(canBuy ? 'Cancel' : 'Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (buy == true && mounted) context.push(Routes.coins);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final b = data.biodata;
    final selected = _selectedPackage;
    final showBalance = ref.watch(appRemoteConfigProvider).valueOrNull?.showCoinBalance ?? true;
    final sub = '${dataLabel(b.gender)} · ${b.area ?? ''} · Age ${b.age ?? ''}';

    const note = TextStyle(fontSize: 13, height: 1.55, color: AppColors.textSecondary);
    const balanceStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);

    return _Document(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _Photo(biodata: b, thumbs: false)),
            const SizedBox(height: 16),
            Text(
              b.profession ?? '',
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
            // `.biodata-paywall-box`
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
                  if (data.walletAvailable)
                    Text.rich(
                      TextSpan(
                        style: note,
                        children: [
                          const TextSpan(text: 'You have unused quota ('),
                          TextSpan(
                            text: '${data.walletRemaining} biodata',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' left) — you can unlock this biodata for free.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    )
                  else if (data.packages.isNotEmpty) ...[
                    const Text(
                      'To see the full information of this biodata (address, profession, family details, expectations), you need to buy a package:',
                      textAlign: TextAlign.center,
                      style: note,
                    ),
                    const SizedBox(height: 10),
                    AppDropdown(
                      value: _packageId,
                      options: [for (final p in data.packages) p.id],
                      labelBuilder: (id) {
                        final p = data.packages.firstWhere((p) => p.id == id);
                        return '${p.name} — ${p.biodataCount} biodata, 🪙${p.coinCost}';
                      },
                      onChanged: (id) => setState(() => _packageId = id),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          style: balanceStyle.copyWith(fontWeight: FontWeight.w500),
                          children: [
                            const TextSpan(text: 'This package gives you '),
                            TextSpan(
                              text: '${selected.biodataCount} biodata',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(
                              text: ' unlocks — once unlocked, you can view it as many times as you like.',
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else
                    const Text(
                      'No subscription packages have been added yet.',
                      textAlign: TextAlign.center,
                      style: note,
                    ),
                  const SizedBox(height: 12),
                  if (data.loginRequired) ...[
                    const Text(
                      'Please log in first to view the biodata.',
                      textAlign: TextAlign.center,
                      style: balanceStyle,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push(Routes.login),
                      style: _paywallButton,
                      child: const Text('Log in / Sign up'),
                    ),
                  ] else ...[
                    if (showBalance) ...[
                      Text(
                        'Your current balance: 🪙 ${data.coinBalance} coins',
                        textAlign: TextAlign.center,
                        style: balanceStyle,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: _busy || (!data.walletAvailable && selected == null) ? null : _unlock,
                      style: _paywallButton,
                      child: Text(
                        _busy
                            ? 'Unlocking...'
                            : data.walletAvailable
                                ? 'Unlock with quota'
                                : selected != null
                                    ? '🪙 ${selected.coinCost} coins to unlock'
                                    : 'Unlock',
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.red),
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

/// The full record as the site's printed "Marriage Biodata" document.
class _FullView extends StatelessWidget {
  const _FullView({required this.data});

  final BiodataDetail data;

  @override
  Widget build(BuildContext context) => BiodataDocumentView(biodata: data.biodata);
}

/// The site's `BiodataDocument`: the printed "Marriage Biodata" layout. The
/// biodata form shows it as its preview step ([preview]: no contact block),
/// with [t] / [dl] following the form's English | বাংলা choice.
class BiodataDocumentView extends StatelessWidget {
  const BiodataDocumentView({
    super.key,
    required this.biodata,
    this.preview = false,
    this.t = _same,
    this.dl = dataLabel,
  });

  final Biodata biodata;
  final bool preview;

  /// Translates a label.
  final String Function(String) t;

  /// Labels a stored (Bengali) value.
  final String Function(String?) dl;

  static String _same(String text) => text;

  String _passed(String? year, String? institution, String? group) =>
      '${t('Passed')} (${(year ?? '').isEmpty ? '-' : year})'
      '${(group ?? '').isEmpty ? '' : ', ${dl(group)}'}'
      '${(institution ?? '').isEmpty ? '' : ', $institution'}';

  String _degree(String? institution, String? department, String? year) =>
      '${department ?? '-'}, ${institution ?? '-'} (${year ?? '-'})';

  @override
  Widget build(BuildContext context) {
    final b = biodata;
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
                Text(
                  t('Marriage Biodata'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
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
                  [dl(b.gender), b.area ?? ''].where((e) => e.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                const _DashedRule(),
                const SizedBox(height: 14),
                _Fields(
                  columns: 2,
                  rows: [
                    (t('Age'), b.age?.toString()),
                    (t('Date of birth'), Fmt.date(b.dateOfBirth)),
                    (t('Skin tone'), dl(b.skinTone)),
                    (t('Height'), b.height),
                    (t('Blood group'), b.bloodGroup),
                    (t('Religion'), dl(b.religion)),
                    (t('Marital status'), dl(b.maritalStatus)),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            icon: '📍',
            title: t('Address'),
            rows: [
              (t('Permanent district'), b.permanentDistrict),
              (t('Permanent thana'), b.permanentUpazila),
              (t('Current district'), b.currentDistrict),
              (t('Current thana'), b.currentUpazila),
              (t('Current address'), b.currentAddress),
            ],
          ),
          _Section(
            icon: '🎓',
            title: t('Education'),
            rows: [
              (t('Medium of education'), dl(b.educationMedium)),
              (t('SSC'), b.sscPassed ? _passed(b.sscYear, b.sscInstitution, b.sscGroup) : t('No')),
              (t('HSC'), b.hscPassed ? _passed(b.hscYear, b.hscInstitution, b.hscGroup) : t('No')),
              (
                t('Graduate'),
                b.graduationPassed
                    ? _degree(b.institutionName, b.graduationDepartment, b.graduationYear)
                    : t('No'),
              ),
              if (b.graduationPassed)
                (
                  t('Post-graduate'),
                  b.postgraduationPassed
                      ? _degree(
                          b.postgraduationInstitution,
                          b.postgraduationDepartment,
                          b.postgraduationYear,
                        )
                      : t('No'),
                ),
              if ((b.otherEducation ?? '').isNotEmpty) (t('Other education'), b.otherEducation),
            ],
          ),
          _Section(
            icon: '🕌',
            title: t('Personal Habits & Information'),
            rows: [
              (t('Prays five times a day?'), dl(b.prayerHabit)),
              (t('Any mental or physical illness?'), b.healthCondition),
              if (!b.isBride) ...[
                (
                  t('After marriage, will you let your wife study?'),
                  dl(b.wifeEducationPermission),
                ),
                (t('Will you let your wife work?'), dl(b.wifeJobPermission)),
                (t('Where will you keep your wife after marriage?'), b.whereWifeWillLive),
              ],
              (t('Brief information about yourself'), b.aboutSelf),
            ],
          ),
          _Section(
            icon: '💼',
            title: t('Professional Information'),
            rows: [
              (t('Profession type'), dl(b.professionType)),
              (t('Profession'), b.profession),
            ],
          ),
          _Section(
            icon: '👪',
            title: t('Family Information'),
            rows: [
              (t('Father’s name'), b.fatherName),
              (t('Father’s profession'), dl(b.fatherProfession)),
              (t('Mother’s name'), b.motherName),
              (t('Mother’s profession'), dl(b.motherProfession)),
              (t('Brothers'), b.brotherCount?.toString()),
              (t('Sisters'), b.sisterCount?.toString()),
              if (siblings.isNotEmpty)
                (
                  t('Siblings'),
                  [
                    for (var i = 0; i < siblings.length; i++)
                      '${i + 1}. ${[
                        siblings[i].name.isEmpty ? '-' : siblings[i].name,
                        dl(siblings[i].relation),
                        '${dl(siblings[i].profession)}'
                            '${siblings[i].organization.isEmpty ? '' : ' (${siblings[i].organization})'}',
                        dl(siblings[i].maritalStatus),
                      ].where((e) => e.isNotEmpty).join(' · ')}',
                  ].join('\n'),
                )
              else if ((b.siblingsProfession ?? '').isNotEmpty)
                (t('Siblings’ professions'), b.siblingsProfession),
            ],
          ),
          _Section(
            icon: '💍',
            title: t('Expected Life Partner'),
            last: preview,
            rows: [
              (t('Maximum age'), b.expectedMaxAge),
              (t('Skin tone'), dl(b.expectedSkinTone)),
              (t('Minimum height'), b.expectedMinHeight),
              (t('Education'), b.expectedEducation),
              (t('Profession'), b.expectedProfession),
              (t('Area'), b.expectedDistrict),
              (t('Marital status'), dl(b.expectedMaritalStatus)),
              (t('Economic condition'), b.expectedEconomicCondition),
              (t('Family condition'), b.expectedFamilyCondition),
              (t('Expected qualities'), b.expectedQualities),
              if ((b.otherRequirements ?? '').isNotEmpty)
                (t('Other requirements'), b.otherRequirements),
            ],
          ),
          if (!preview)
            _Section(
            icon: '📞',
            title: t('Contact'),
            last: true,
            rows: [
              (t('Guardian'), dl(b.guardianRelation)),
              (t('Guardian’s phone'), b.guardianPhone),
              if ((b.mobileNumber ?? '').isNotEmpty) (t('Mobile'), b.mobileNumber),
              if ((b.email ?? '').isNotEmpty) (t('Email'), b.email),
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
