import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown by [AuthService.register]/[AuthService.login] when the backend
/// rejects the request (bad credentials, duplicate email, etc.) - as
/// opposed to a network-level failure, which throws normally (whatever the
/// underlying http/timeout exception is).
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Client-side wrapper for the Phase 3 backend's /auth endpoints. Persists
/// the JWT (and the email it belongs to) via SharedPreferences so a login
/// survives app restarts. This does NOT touch the local placeholder user id
/// (lib/progress/local_user_id.dart) - migrating locally-tracked progress
/// onto a real account after login is a separate, not-yet-built concern
/// (see ../../../TODO.md).
class AuthService {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  static const _tokenPrefsKey = 'auth_token';
  static const _emailPrefsKey = 'auth_email';

  AuthService({
    http.Client? client,
    this.baseUrl = 'http://127.0.0.1:8000',
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  /// POSTs to /auth/register. Throws [AuthException] (with the backend's
  /// `detail` message) on any non-201 response. Does not log the new user
  /// in - call [login] separately afterward.
  Future<void> register(String email, String password) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      throw _authExceptionFromResponse(response);
    }
  }

  /// POSTs to /auth/login. On success, persists the token + email and
  /// returns the token. Throws [AuthException] (with the backend's
  /// `detail` message) on any non-200 response, and persists nothing in
  /// that case.
  Future<String> login(String email, String password) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw _authExceptionFromResponse(response);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefsKey, token);
    await prefs.setString(_emailPrefsKey, email);
    return token;
  }

  /// The persisted JWT, or null if never logged in / after [logout].
  Future<String?> currentToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenPrefsKey);
  }

  /// The email of the currently logged-in user, or null.
  Future<String?> currentEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailPrefsKey);
  }

  /// Clears the persisted token and email.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefsKey);
    await prefs.remove(_emailPrefsKey);
  }

  AuthException _authExceptionFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String) {
        return AuthException(detail);
      }
    } catch (_) {
      // ignore decode errors
    }
    return AuthException('Request failed with status ${response.statusCode}');
  }
}
