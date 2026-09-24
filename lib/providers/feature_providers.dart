import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../data/doctor_repository.dart';
import '../data/donor_repository.dart';
import '../data/marketplace_repository.dart';
import '../data/service_repository.dart';
import '../models/biodata.dart';
import '../models/billing.dart';
import '../models/doctor.dart';
import '../models/donor.dart';
import '../models/engagement.dart';
import '../models/listing.dart';
import '../models/public_profile.dart';
import '../models/service.dart';
import '../models/user.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

// --- Services ---------------------------------------------------------------

final serviceFiltersProvider =
    StateProvider<ServiceFilters>((ref) => const ServiceFilters());

final servicesProvider = FutureProvider.autoDispose<List<ServiceItem>>((ref) {
  final filters = ref.watch(serviceFiltersProvider);
  return ref.watch(serviceRepositoryProvider).list(filters);
});

final serviceDetailProvider =
    FutureProvider.autoDispose.family<ServiceItem, String>((ref, id) {
  return ref.watch(serviceRepositoryProvider).detail(id);
});

final myServicesProvider = FutureProvider.autoDispose<List<ServiceItem>>(
  (ref) => ref.watch(serviceRepositoryProvider).mine(),
);

// --- Doctors ----------------------------------------------------------------

final doctorFiltersProvider =
    StateProvider<DoctorFilters>((ref) => const DoctorFilters());

final doctorsProvider = FutureProvider.autoDispose<List<DoctorSummary>>((ref) {
  final filters = ref.watch(doctorFiltersProvider);
  return ref.watch(doctorRepositoryProvider).list(filters);
});

final doctorDetailProvider =
    FutureProvider.autoDispose.family<DoctorDetail, String>((ref, id) {
  return ref.watch(doctorRepositoryProvider).detail(id);
});

final chamberAvailabilityProvider = FutureProvider.autoDispose
    .family<List<AvailableDate>, ({String doctorId, String chamberId})>((ref, args) {
  return ref.watch(doctorRepositoryProvider).availability(
        doctorId: args.doctorId,
        chamberId: args.chamberId,
      );
});

final myAppointmentsProvider = FutureProvider.autoDispose<List<Serial>>(
  (ref) => ref.watch(doctorRepositoryProvider).myAppointments(),
);

// --- Donors -----------------------------------------------------------------

final donorFiltersProvider = StateProvider<DonorFilters>((ref) => const DonorFilters());

final donorsProvider = FutureProvider.autoDispose<List<Donor>>((ref) {
  final filters = ref.watch(donorFiltersProvider);
  return ref.watch(donorRepositoryProvider).list(filters);
});

final donorDetailProvider =
    FutureProvider.autoDispose.family<Donor, String>((ref, id) {
  return ref.watch(donorRepositoryProvider).detail(id);
});

// --- Marketplace ------------------------------------------------------------

final listingFiltersProvider =
    StateProvider<ListingFilters>((ref) => const ListingFilters());

final listingsProvider = FutureProvider.autoDispose<List<Listing>>((ref) {
  final filters = ref.watch(listingFiltersProvider);
  return ref.watch(marketplaceRepositoryProvider).list(filters);
});

final promotedListingsProvider = FutureProvider.autoDispose<List<Listing>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).promoted(),
);

final listingDetailProvider =
    FutureProvider.autoDispose.family<Listing, String>((ref, id) {
  return ref.watch(marketplaceRepositoryProvider).detail(id);
});

final myListingsProvider = FutureProvider.autoDispose<List<Listing>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).mine(),
);

// --- Biodata ----------------------------------------------------------------

/// Client-side filters for the matrimony list. The public biodata endpoint
/// takes no query parameters, so the list is narrowed here rather than by
/// inventing a new server route.
class BiodataFilters {
  const BiodataFilters({
    this.gender,
    this.maritalStatus,
    this.district,
    this.area,
    this.minAge,
    this.maxAge,
    this.search,
  });

  final String? gender;
  final String? maritalStatus;
  final String? district;
  final String? area;
  final int? minAge;
  final int? maxAge;
  final String? search;

  bool get hasActiveFilters =>
      gender != null ||
      maritalStatus != null ||
      district != null ||
      area != null ||
      minAge != null ||
      maxAge != null ||
      (search != null && search!.isNotEmpty);

  bool matches(Biodata item) {
    if (gender != null && item.gender != gender) return false;
    if (maritalStatus != null && item.maritalStatus != maritalStatus) return false;
    if (district != null &&
        item.currentDistrict != district &&
        item.permanentDistrict != district) {
      return false;
    }
    if (area != null && item.area != area) return false;
    final age = item.age;
    if (minAge != null && (age == null || age < minAge!)) return false;
    if (maxAge != null && (age == null || age > maxAge!)) return false;

    final term = search?.trim().toLowerCase();
    if (term != null && term.isNotEmpty) {
      final haystack = [
        item.biodataNo,
        item.profession,
        item.area,
        item.currentDistrict,
        item.permanentDistrict,
        item.educationMedium,
      ].whereType<String>().join(' ').toLowerCase();
      if (!haystack.contains(term)) return false;
    }
    return true;
  }

  BiodataFilters copyWith({
    Object? gender = _unset,
    Object? maritalStatus = _unset,
    Object? district = _unset,
    Object? area = _unset,
    Object? minAge = _unset,
    Object? maxAge = _unset,
    Object? search = _unset,
  }) =>
      BiodataFilters(
        gender: gender == _unset ? this.gender : gender as String?,
        maritalStatus:
            maritalStatus == _unset ? this.maritalStatus : maritalStatus as String?,
        district: district == _unset ? this.district : district as String?,
        area: area == _unset ? this.area : area as String?,
        minAge: minAge == _unset ? this.minAge : minAge as int?,
        maxAge: maxAge == _unset ? this.maxAge : maxAge as int?,
        search: search == _unset ? this.search : search as String?,
      );

  static const _unset = Object();
}

final biodataFiltersProvider =
    StateProvider<BiodataFilters>((ref) => const BiodataFilters());

final biodataListProvider = FutureProvider.autoDispose<List<Biodata>>((ref) async {
  final all = await ref.watch(biodataRepositoryProvider).list();
  final filters = ref.watch(biodataFiltersProvider);
  if (!filters.hasActiveFilters) return all;
  return all.where(filters.matches).toList();
});

final biodataDetailProvider =
    FutureProvider.autoDispose.family<BiodataDetail, String>((ref, id) {
  return ref.watch(biodataRepositoryProvider).detail(id);
});

final myBiodataProvider = FutureProvider.autoDispose<List<Biodata>>(
  (ref) => ref.watch(biodataRepositoryProvider).mine(),
);

final biodataPackagesProvider = FutureProvider<List<BiodataPackage>>(
  (ref) => ref.watch(biodataRepositoryProvider).packages(),
);

// --- Chat -------------------------------------------------------------------

final chatInboxProvider = FutureProvider.autoDispose<List<Conversation>>(
  (ref) => ref.watch(chatRepositoryProvider).inbox(),
);

final chatUnreadCountProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(isSignedInProvider)) return 0;
  return ref.watch(chatRepositoryProvider).unreadCount();
});

final chatSettingsProvider =
    FutureProvider.autoDispose<({bool chatEnabled, bool noticeSeen})>(
  (ref) => ref.watch(chatRepositoryProvider).settings(),
);

// --- Notifications, saved, social ------------------------------------------

// Both of these are watched by the home header on every screen, so they check
// the sign-in state first rather than firing a request that can only 401 for a
// guest browsing the app.
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return const [];
  return ref.watch(meRepositoryProvider).notifications();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return items.where((n) => !n.read).length;
});

final savedItemsProvider = FutureProvider.autoDispose<List<SavedItem>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return const [];
  return ref.watch(meRepositoryProvider).saved();
});

/// Fast membership test for the bookmark buttons.
final savedKeysProvider = Provider.autoDispose<Set<String>>((ref) {
  final items = ref.watch(savedItemsProvider).valueOrNull ?? const [];
  return items.map((i) => '${i.targetType}:${i.targetId}').toSet();
});

final myReviewsProvider = FutureProvider.autoDispose<List<Review>>(
  (ref) => ref.watch(meRepositoryProvider).myReviews(),
);

final followListsProvider = FutureProvider.autoDispose<FollowLists>(
  (ref) => ref.watch(meRepositoryProvider).follows(),
);

final publicProfileProvider =
    FutureProvider.autoDispose.family<PublicProfile, String>((ref, id) {
  return ref.watch(meRepositoryProvider).publicProfile(id);
});

final userAboutProvider =
    FutureProvider.autoDispose.family<UserAbout, String>((ref, id) {
  return ref.watch(meRepositoryProvider).about(id);
});

final isFollowingProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  if (!ref.watch(isSignedInProvider)) return false;
  return ref.watch(meRepositoryProvider).isFollowing(id);
});

// --- Reviews ----------------------------------------------------------------

final reviewsProvider = FutureProvider.autoDispose
    .family<List<Review>, ({String targetType, String targetId})>((ref, args) {
  return ref.watch(reviewRepositoryProvider).list(
        targetType: args.targetType,
        targetId: args.targetId,
      );
});

final reviewRepliesProvider =
    FutureProvider.autoDispose.family<List<ReviewReply>, int>((ref, reviewId) {
  return ref.watch(reviewRepositoryProvider).replies(reviewId);
});

// --- Billing ----------------------------------------------------------------

final coinBalanceProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(isSignedInProvider)) return 0;
  return ref.watch(billingRepositoryProvider).coinBalance();
});

final coinPackagesProvider = FutureProvider<List<CoinPackage>>(
  (ref) => ref.watch(billingRepositoryProvider).coinPackages(),
);

final coinRequestsProvider = FutureProvider.autoDispose<List<CoinPurchaseRequest>>(
  (ref) => ref.watch(billingRepositoryProvider).coinRequests(),
);

final subscriptionProvider = FutureProvider.autoDispose<SubscriptionRequest?>(
  (ref) => ref.watch(billingRepositoryProvider).subscription(),
);

final serviceSponsorPackagesProvider = FutureProvider<List<SponsorPackage>>(
  (ref) => ref.watch(billingRepositoryProvider).servicePackages(),
);

final marketplaceSponsorPackagesProvider = FutureProvider<List<SponsorPackage>>(
  (ref) => ref.watch(billingRepositoryProvider).marketplacePackages(),
);
