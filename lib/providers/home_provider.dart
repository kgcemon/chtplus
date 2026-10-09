import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/donor_repository.dart';
import '../data/marketplace_repository.dart';
import '../data/service_repository.dart';
import '../models/biodata.dart';
import '../models/catalog.dart';
import '../models/donor.dart';
import '../models/listing.dart';
import '../models/service.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// Everything the home screen shows, gathered in one place.
///
/// The website builds this on the server in a single render; here the same
/// lists are fetched in parallel and each one is individually cached, so a
/// warm start paints instantly and only the network refresh happens after.
class HomeFeed {
  const HomeFeed({
    this.banners = const [],
    this.serviceCategories = const [],
    this.sponsoredServices = const [],
    this.services = const [],
    this.donors = const [],
    this.marketplaceCategories = const [],
    this.listings = const [],
    this.biodata = const [],
  });

  final List<BannerItem> banners;
  final List<Category> serviceCategories;
  final List<ServiceItem> sponsoredServices;
  final List<ServiceItem> services;
  final List<Donor> donors;
  final List<Category> marketplaceCategories;
  final List<Listing> listings;
  final List<Biodata> biodata;

  /// Sponsored providers first, then the rest — the ordering the site uses.
  List<ServiceItem> get topServices {
    final sponsoredIds = sponsoredServices.map((s) => s.id).toSet();
    return [
      ...sponsoredServices.take(4),
      ...services.where((s) => !sponsoredIds.contains(s.id)).take(8),
    ];
  }
}

/// The order of sections on the home screen. A signed-in user who picked
/// interests during onboarding sees those first. Blood donors always come last.
final homeSectionOrderProvider = Provider<List<String>>((ref) {
  const all = ['biodata', 'services', 'marketplace'];
  final interests = ref.watch(currentUserProvider)?.homeInterests ?? const [];
  final picked = interests.where(all.contains).toList();
  return [...picked, ...all.where((s) => !picked.contains(s)), 'donors'];
});

final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final catalog = ref.watch(catalogRepositoryProvider);
  final services = ref.watch(serviceRepositoryProvider);
  final donors = ref.watch(donorRepositoryProvider);
  final marketplace = ref.watch(marketplaceRepositoryProvider);
  final biodata = ref.watch(biodataRepositoryProvider);

  // Fired together so the whole screen is limited by the slowest single call
  // rather than the sum of them.
  final results = await Future.wait([
    catalog.banners(),
    catalog.serviceCategories(),
    services.list(const ServiceFilters(paidOnly: true)),
    services.list(const ServiceFilters()),
    donors.list(const DonorFilters()),
    catalog.marketplaceCategories(),
    marketplace.list(const ListingFilters()),
    biodata.list(),
  ]);

  return HomeFeed(
    banners: results[0] as List<BannerItem>,
    serviceCategories: results[1] as List<Category>,
    sponsoredServices: results[2] as List<ServiceItem>,
    services: results[3] as List<ServiceItem>,
    donors: (results[4] as List<Donor>).take(10).toList(),
    marketplaceCategories:
        (results[5] as List<Category>).where((c) => c.isTopLevel).take(8).toList(),
    listings: (results[6] as List<Listing>).take(12).toList(),
    biodata: (results[7] as List<Biodata>).take(10).toList(),
  );
});
