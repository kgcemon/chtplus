import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../data/billing_repository.dart';
import '../data/biodata_repository.dart';
import '../data/catalog_repository.dart';
import '../data/chat_repository.dart';
import '../data/doctor_repository.dart';
import '../data/donor_repository.dart';
import '../data/marketplace_repository.dart';
import '../data/me_repository.dart';
import '../data/review_repository.dart';
import '../data/service_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final catalogRepositoryProvider =
    Provider<CatalogRepository>((ref) => CatalogRepository(ref.watch(apiClientProvider)));

final serviceRepositoryProvider =
    Provider<ServiceRepository>((ref) => ServiceRepository(ref.watch(apiClientProvider)));

final doctorRepositoryProvider =
    Provider<DoctorRepository>((ref) => DoctorRepository(ref.watch(apiClientProvider)));

final donorRepositoryProvider =
    Provider<DonorRepository>((ref) => DonorRepository(ref.watch(apiClientProvider)));

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>(
    (ref) => MarketplaceRepository(ref.watch(apiClientProvider)));

final biodataRepositoryProvider =
    Provider<BiodataRepository>((ref) => BiodataRepository(ref.watch(apiClientProvider)));

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

final meRepositoryProvider =
    Provider<MeRepository>((ref) => MeRepository(ref.watch(apiClientProvider)));

final reviewRepositoryProvider =
    Provider<ReviewRepository>((ref) => ReviewRepository(ref.watch(apiClientProvider)));

final billingRepositoryProvider =
    Provider<BillingRepository>((ref) => BillingRepository(ref.watch(apiClientProvider)));
