import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/storage/token_store.dart';
import '../models/user.dart';
import 'core_providers.dart';

class AuthState {
  const AuthState({this.user, this.restoring = true});

  /// Null means signed out.
  final AuthUser? user;

  /// True until the stored token has been read and verified at startup.
  final bool restoring;

  bool get isSignedIn => user != null;

  AuthState copyWith({AuthUser? user, bool? restoring, bool clearUser = false}) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        restoring: restoring ?? this.restoring,
      );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Anything the server rejects as unauthorized signs the app out, so a
    // token that expired or belongs to a deleted account cannot get stuck.
    ref.read(apiClientProvider).onUnauthorized = () {
      if (state.isSignedIn) signOut();
    };
    return const AuthState();
  }

  /// Reads the saved token and shows the cached profile immediately, then
  /// confirms it against `/api/me` without blocking the first frame.
  Future<void> restore() async {
    await TokenStore.instance.load();
    if (!TokenStore.instance.hasToken) {
      state = const AuthState(restoring: false);
      return;
    }

    final repository = ref.read(authRepositoryProvider);
    state = AuthState(user: repository.cachedUser(), restoring: false);

    try {
      final profile = await ref.read(meRepositoryProvider).profile();
      final refreshed = AuthUser(
        id: profile.id,
        name: profile.name,
        email: profile.email,
        phone: profile.phone,
        area: profile.area,
        photoUrl: profile.photoUrl,
        onboardingCompleted: state.user?.onboardingCompleted ?? true,
        homeInterests: state.user?.homeInterests ?? const [],
        blueBadge: profile.blueBadge,
      );
      await repository.cacheUser(refreshed);
      state = AuthState(user: refreshed, restoring: false);
    } on ApiException catch (error) {
      // Only a rejected token signs the user out; a flaky network keeps the
      // cached session so the app still works offline.
      if (error.isUnauthorized) await signOut();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final result = await ref.read(authRepositoryProvider).login(
          email: email,
          password: password,
        );
    state = AuthState(user: result.user, restoring: false);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? area,
  }) async {
    final result = await ref.read(authRepositoryProvider).register(
          name: name,
          email: email,
          password: password,
          phone: phone,
          area: area,
        );
    state = AuthState(user: result.user, restoring: false);
  }

  Future<void> signInWithGoogle(String credential) async {
    final result = await ref.read(authRepositoryProvider).googleSignIn(credential);
    state = AuthState(user: result.user, restoring: false);
  }

  Future<void> completeReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final result = await ref.read(authRepositoryProvider).resetPassword(
          email: email,
          code: code,
          newPassword: newPassword,
        );
    state = AuthState(user: result.user, restoring: false);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(restoring: false);
    ref.invalidate(meProfileProvider);
  }

  /// Keeps the header avatar and name in step after a profile edit.
  Future<void> updateLocalUser(AuthUser user) async {
    await ref.read(authRepositoryProvider).cacheUser(user);
    state = state.copyWith(user: user);
  }

  Future<void> markOnboardingComplete(List<String> interests) async {
    final current = state.user;
    if (current == null) return;
    await updateLocalUser(
      current.copyWith(onboardingCompleted: true, homeInterests: interests),
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider =
    Provider<AuthUser?>((ref) => ref.watch(authControllerProvider).user);

final isSignedInProvider =
    Provider<bool>((ref) => ref.watch(authControllerProvider).isSignedIn);

/// The signed-in user's full profile. Kept alive across screen changes (the
/// profile tab, the "my ..." screens and the drawer all read it) and
/// invalidated explicitly after an edit.
final meProfileProvider = FutureProvider<MeProfile?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  return ref.watch(meRepositoryProvider).profile();
});
