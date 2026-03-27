import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stream of the currently signed-in user (null when signed out).
final authUserProvider = StreamProvider<User?>((ref) {
  try {
    return Supabase.instance.client.auth.onAuthStateChange
        .map((e) => e.session?.user);
  } catch (_) {
    return const Stream.empty();
  }
});

/// Auth action notifier: sign in, register, sign out, reset password.
class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    try {
      await Supabase.instance.client.auth
          .signUp(email: email, password: password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await Supabase.instance.client.auth.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<void>>(AuthNotifier.new);
