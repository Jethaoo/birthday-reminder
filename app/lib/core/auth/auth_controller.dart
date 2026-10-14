import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/app_user.dart';
import '../api/api_exception.dart';
import '../providers.dart';
import 'session_store.dart';

enum AuthStatus { restoring, signedOut, signedIn }

class AuthState {
  const AuthState({required this.status, this.user, this.offline = false});

  const AuthState.restoring() : this(status: AuthStatus.restoring);

  const AuthState.signedOut() : this(status: AuthStatus.signedOut);

  final AuthStatus status;
  final AppUser? user;

  /// True when the session was restored from cache and the server is unreachable.
  final bool offline;

  bool get isSignedIn => status == AuthStatus.signedIn;
  bool get isRestoring => status == AuthStatus.restoring;

  AuthState copyWith({AuthStatus? status, AppUser? user, bool? offline}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        offline: offline ?? this.offline,
      );
}

/// Owns the session: restore, sign in, sign up, sign out and timezone sync.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // An expired or revoked token anywhere in the app ends the session, rather
    // than leaving screens to fall back to stale cached data.
    ref.read(apiProvider).onUnauthorized = () {
      if (state.isSignedIn) signOut(notifyServer: false);
    };
    Future.microtask(restore);
    return const AuthState.restoring();
  }

  SessionStore get _sessions => ref.read(sessionStoreProvider);

  bool _signingOut = false;

  /// Restores a stored session and refreshes it against the API when possible.
  Future<void> restore() async {
    String? token;
    AppUser? cachedUser;
    try {
      token = await _sessions.readToken();
      cachedUser = token == null ? null : await _sessions.readUser();
    } catch (_) {
      // Secure storage that cannot be decrypted (for example restored from a
      // backup onto another device) must not leave the app stuck restoring.
      await _sessions.wipe();
      state = const AuthState.signedOut();
      return;
    }

    if (token == null) {
      state = const AuthState.signedOut();
      return;
    }

    final api = ref.read(apiProvider);
    api.setAuthToken(token);

    if (cachedUser != null) {
      state = AuthState(status: AuthStatus.signedIn, user: cachedUser, offline: true);
    }

    try {
      final user = await api.me();
      state = AuthState(status: AuthStatus.signedIn, user: user);
      await _sessions.save(token: token, user: user);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await signOut(notifyServer: false);
      } else if (cachedUser != null) {
        state = AuthState(status: AuthStatus.signedIn, user: cachedUser, offline: true);
      } else {
        await signOut(notifyServer: false);
      }
    } catch (_) {
      if (cachedUser == null) await signOut(notifyServer: false);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final session = await ref.read(apiProvider).login(
          email: email.trim(),
          password: password,
          timezone: await ref.read(deviceTimezoneProvider.future),
        );
    await _applySession(session.user, session.accessToken);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String confirmation,
  }) async {
    final session = await ref.read(apiProvider).register(
          name: name.trim(),
          email: email.trim(),
          password: password,
          confirmation: confirmation,
          timezone: await ref.read(deviceTimezoneProvider.future),
        );
    await _applySession(session.user, session.accessToken);
  }

  Future<void> _applySession(AppUser user, String token) async {
    ref.read(apiProvider).setAuthToken(token);
    await _sessions.save(token: token, user: user);
    state = AuthState(status: AuthStatus.signedIn, user: user);
  }

  /// Ends the session. When [notifyServer] is true the token is still valid, so
  /// this device's push registration is removed first; it is false when the
  /// server has already rejected the token.
  Future<void> signOut({bool notifyServer = true}) async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      final api = ref.read(apiProvider);
      if (notifyServer) {
        try {
          final deviceId = await _sessions.readDeviceId();
          if (deviceId != null) await api.unregisterDevice(deviceId);
        } catch (_) {
          // The token is deleted below, so the old registration stops working anyway.
        }
        try {
          await api.logout();
        } catch (_) {
          // Signing out locally must succeed even when the network does not.
        }
      }
      // A fresh FCM token for the next account; the server deactivates the old one
      // the next time it is used.
      await ref.read(pushServiceProvider).deleteToken();
      api.setAuthToken(null);
      await _sessions.clear();
      await ref.read(cacheStoreProvider).clear();
      state = const AuthState.signedOut();
    } finally {
      _signingOut = false;
    }
  }

  Future<void> refreshUser() async {
    if (!state.isSignedIn) return;
    try {
      final user = await ref.read(apiProvider).me();
      state = state.copyWith(user: user, offline: false);
    } on ApiException catch (error) {
      if (error.isUnauthorized) await signOut(notifyServer: false);
    }
  }

  /// Applies a user returned by another screen's API call (for example the
  /// account screen) without re-fetching it.
  Future<void> applyUser(AppUser user) async {
    state = state.copyWith(user: user, offline: false);
    final token = await _sessions.readToken();
    if (token != null) await _sessions.save(token: token, user: user);
  }

  /// Pushes the device timezone to the server when it has changed.
  Future<void> syncTimezone({bool force = false}) async {
    final user = state.user;
    if (user == null) return;

    final current = await ref.read(deviceTimezoneProvider.future);
    if (!force && current == user.timezone) return;

    try {
      final updated = await ref.read(apiProvider).updateMe(timezone: current);
      state = state.copyWith(user: updated, offline: false);
      await _sessions.save(token: await _sessions.readToken() ?? '', user: updated);
    } catch (_) {
      // Timezone sync retries on the next resume.
    }
  }
}
