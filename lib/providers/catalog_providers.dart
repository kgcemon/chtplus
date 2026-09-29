import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog.dart';
import 'core_providers.dart';

/// Public settings (Google client id, OneSignal app id). Read once at startup.
final appRemoteConfigProvider = FutureProvider<AppRemoteConfig>(
  (ref) => ref.watch(catalogRepositoryProvider).appConfig(),
);

final serviceBannersProvider = FutureProvider<List<BannerItem>>(
  (ref) => ref.watch(catalogRepositoryProvider).serviceBanners(),
);

final serviceCategoriesProvider =FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).serviceCategories(),
);

final marketplaceCategoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).marketplaceCategories(),
);

/// Only top-level marketplace categories, for the home grid and the nav strip.
final marketplaceTopCategoriesProvider = Provider<List<Category>>((ref) {
  final all = ref.watch(marketplaceCategoriesProvider).valueOrNull ?? const [];
  return all.where((c) => c.isTopLevel).toList();
});

/// Subcategories of a given parent.
final marketplaceSubcategoriesProvider =
    Provider.family<List<Category>, String?>((ref, parentId) {
  if (parentId == null) return const [];
  final all = ref.watch(marketplaceCategoriesProvider).valueOrNull ?? const [];
  return all.where((c) => c.parentId == parentId).toList();
});

final districtsProvider = FutureProvider<List<District>>(
  (ref) => ref.watch(catalogRepositoryProvider).districts(),
);

final upazilasProvider = FutureProvider.family<List<Upazila>, int>(
  (ref, districtId) => ref.watch(catalogRepositoryProvider).upazilas(districtId),
);

/// Upazilas looked up by the district's stored (Bengali) name, which is what
/// listings and donors are filtered by.
final upazilasByDistrictNameProvider =
    FutureProvider.family<List<Upazila>, String?>((ref, districtName) async {
  if (districtName == null || districtName.isEmpty) return const [];
  final districts = await ref.watch(districtsProvider.future);
  final match = districts.where((d) => d.filterValue == districtName).firstOrNull;
  if (match == null) return const [];
  return ref.watch(upazilasProvider(match.id).future);
});

final bannersProvider = FutureProvider<List<BannerItem>>(
  (ref) => ref.watch(catalogRepositoryProvider).banners(),
);

final welcomePopupProvider = FutureProvider<WelcomePopup?>(
  (ref) => ref.watch(catalogRepositoryProvider).welcomePopup(),
);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
