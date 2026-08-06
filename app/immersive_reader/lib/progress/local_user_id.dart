import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _localUserIdPrefsKey = 'local_user_id';

/// A device-local placeholder for `word_progress.user_id` (SPEC.md 3.3),
/// used until Phase 3's client-side login exists. Generated once and
/// persisted, not derived from any account.
Future<String> getOrCreateLocalUserId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_localUserIdPrefsKey);
  if (existing != null) {
    return existing;
  }
  final generated = _generateId();
  await prefs.setString(_localUserIdPrefsKey, generated);
  return generated;
}

String _generateId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
