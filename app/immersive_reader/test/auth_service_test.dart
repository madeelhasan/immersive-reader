import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/auth/auth_service.dart';

/// Same fake-client pattern as vocabulary_repository_test.dart: handler
/// decides the response (or throws) for every request sent through the
/// client, no real server needed.
class _FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  _FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('register', () {
    test('completes normally when the backend returns 201', () async {
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/auth/register');
        expect(request.method, 'POST');
        final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        expect(body['email'], 'new@example.com');
        expect(body['password'], 'password123');
        final responseBody = jsonEncode({'id': 'user-1', 'email': 'new@example.com'});
        return http.StreamedResponse(Stream.value(utf8.encode(responseBody)), 201);
      });

      // No exception thrown = success.
      await AuthService(client: fakeClient).register('new@example.com', 'password123');
    });

    test('throws AuthException with the backend detail on failure', () async {
      final fakeClient = _FakeHttpClient((request) async {
        final body = jsonEncode({'detail': 'Email already registered'});
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 400);
      });

      expect(
        () => AuthService(client: fakeClient).register('dup@example.com', 'password123'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Email already registered')),
      );
    });
  });

  group('login', () {
    test('returns the access token and persists it on success', () async {
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/auth/login');
        expect(request.method, 'POST');
        final responseBody = jsonEncode({'access_token': 'jwt-abc123', 'token_type': 'bearer'});
        return http.StreamedResponse(Stream.value(utf8.encode(responseBody)), 200);
      });

      final service = AuthService(client: fakeClient);
      final token = await service.login('user@example.com', 'password123');

      expect(token, 'jwt-abc123');
      expect(await service.currentToken(), 'jwt-abc123');
      expect(await service.currentEmail(), 'user@example.com');
    });

    test('throws AuthException with the backend detail on invalid credentials', () async {
      final fakeClient = _FakeHttpClient((request) async {
        final body = jsonEncode({'detail': 'Incorrect email or password'});
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 401);
      });

      expect(
        () => AuthService(client: fakeClient).login('user@example.com', 'wrong'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Incorrect email or password')),
      );
    });

    test('does not persist a token when login fails', () async {
      final fakeClient = _FakeHttpClient((request) async {
        final body = jsonEncode({'detail': 'nope'});
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 401);
      });

      final service = AuthService(client: fakeClient);
      try {
        await service.login('user@example.com', 'wrong');
      } catch (_) {
        // expected
      }

      expect(await service.currentToken(), isNull);
    });
  });

  group('currentToken / currentEmail / logout', () {
    test('currentToken and currentEmail return null before any login', () async {
      final service = AuthService();
      expect(await service.currentToken(), isNull);
      expect(await service.currentEmail(), isNull);
    });

    test('logout clears the persisted token and email', () async {
      final fakeClient = _FakeHttpClient((request) async {
        final responseBody = jsonEncode({'access_token': 'jwt-xyz', 'token_type': 'bearer'});
        return http.StreamedResponse(Stream.value(utf8.encode(responseBody)), 200);
      });
      final service = AuthService(client: fakeClient);
      await service.login('user@example.com', 'password123');
      expect(await service.currentToken(), 'jwt-xyz');

      await service.logout();

      expect(await service.currentToken(), isNull);
      expect(await service.currentEmail(), isNull);
    });
  });
}
