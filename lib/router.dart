import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/biodata/biodata_detail_screen.dart';
import 'features/biodata/biodata_list_screen.dart';
import 'features/biodata/biodata_wizard_screen.dart';
import 'features/biodata/my_biodata_screen.dart';
import 'features/chat/chat_inbox_screen.dart';
import 'features/chat/chat_thread_screen.dart';
import 'features/coins/coins_screen.dart';
import 'features/donors/donor_detail_screen.dart';
import 'features/donors/donor_form_screen.dart';
import 'features/donors/donor_list_screen.dart';
import 'features/home/home_screen.dart';
import 'features/marketplace/listing_detail_screen.dart';
import 'features/marketplace/marketplace_screen.dart';
import 'features/marketplace/my_listings_screen.dart';
import 'features/marketplace/sell_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/follow_list_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/public_profile_screen.dart';
import 'features/saved/saved_screen.dart';
import 'features/services/my_services_screen.dart';
import 'features/services/service_detail_screen.dart';
import 'features/services/service_form_screen.dart';
import 'features/services/service_list_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/blocked_users_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'providers/auth_provider.dart';

class Routes {
  const Routes._();

  static const home = '/';
  static const services = '/services';
  static const donors = '/donors';
  static const marketplace = '/marketplace';
  static const biodata = '/biodata';

  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const onboarding = '/onboarding';

  static const profile = '/profile';
  static const chat = '/chat';
  static const notifications = '/notifications';
  static const saved = '/saved';
  static const coins = '/coins';
  static const settings = '/settings';
  static const about = '/about';

  static const myServices = '/my-services';
  static const myListings = '/my-listings';
  static const myBiodata = '/my-biodata';
  static const blockedUsers = '/settings/blocked';
}

/// Exposed so a notification tap can tell whether the navigator exists yet —
/// a cold start from a notification runs before the first frame is built.
final rootNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = rootNavigatorKey;
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Lets GoRouter re-evaluate redirects whenever the sign-in state changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // Screens that only make sense for a signed-in user. Anything else,
      // including every browse screen, stays open to visitors — the website
      // works the same way.
      const guarded = {
        Routes.profile,
        Routes.chat,
        Routes.notifications,
        Routes.saved,
        Routes.coins,
        Routes.myServices,
        Routes.myListings,
        Routes.myBiodata,
        Routes.blockedUsers,
        Routes.onboarding,
      };
      final needsAuth = guarded.any((path) => location.startsWith(path));

      if (!auth.isSignedIn && needsAuth) {
        return '${Routes.login}?next=${Uri.encodeComponent(state.uri.toString())}';
      }

      // A freshly registered user picks their interests once.
      if (auth.isSignedIn &&
          auth.user?.onboardingCompleted == false &&
          location != Routes.onboarding) {
        return Routes.onboarding;
      }

      if (auth.isSignedIn &&
          (location == Routes.login || location == Routes.register)) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.services,
                builder: (context, state) => ServiceListScreen(
                  initialCategoryId: state.uri.queryParameters['category'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.donors,
                builder: (context, state) => const DonorListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.marketplace,
                builder: (context, state) => MarketplaceScreen(
                  initialCategoryId: state.uri.queryParameters['category'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.biodata,
                builder: (context, state) => const BiodataListScreen(),
              ),
            ],
          ),
        ],
      ),

      // --- Auth -------------------------------------------------------------
      GoRoute(
        path: Routes.login,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            LoginScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: Routes.register,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            RegisterScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ForgotPasswordScreen(initialEmail: state.uri.queryParameters['email']),
      ),
      GoRoute(
        path: Routes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // --- Services ---------------------------------------------------------
      GoRoute(
        path: '/services/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ServiceFormScreen(),
      ),
      GoRoute(
        path: '/services/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ServiceDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.myServices,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyServicesScreen(),
      ),

      // --- Donors -----------------------------------------------------------
      GoRoute(
        path: '/donors/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DonorFormScreen(),
      ),
      GoRoute(
        path: '/donors/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            DonorDetailScreen(id: state.pathParameters['id']!),
      ),

      // --- Marketplace ------------------------------------------------------
      GoRoute(
        path: '/marketplace/sell',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SellScreen(),
      ),
      GoRoute(
        path: '/marketplace/listing/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ListingDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.myListings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyListingsScreen(),
      ),

      // --- Biodata ----------------------------------------------------------
      GoRoute(
        path: '/biodata/submit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BiodataWizardScreen(),
      ),
      GoRoute(
        path: '/biodata/view/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            BiodataDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.myBiodata,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyBiodataScreen(),
      ),

      // --- Account ----------------------------------------------------------
      GoRoute(
        path: Routes.profile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/follows',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => FollowListScreen(
          initialTab: state.uri.queryParameters['tab'] == 'following' ? 1 : 0,
        ),
      ),
      GoRoute(
        path: '/u/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PublicProfileScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.chat,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChatInboxScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ChatThreadScreen(
          conversationId: state.pathParameters['id']!,
          title: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.saved,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SavedScreen(),
      ),
      GoRoute(
        path: Routes.coins,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CoinsScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.blockedUsers,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: Routes.about,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('This page could not be opened.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
