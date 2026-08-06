import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/vocabulary_entry.dart';

/// Loads the vocabulary dataset from the Phase 3 backend when reachable,
/// falling back to the bundled asset otherwise (SPEC.md 3.2: "server-served,
/// bundled locally as fallback"). The backend isn't deployed anywhere yet,
/// so on a normal install this always falls through to the bundled copy -
/// the API path only activates for a locally-running backend today.
class VocabularyRepository {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  VocabularyRepository({
    http.Client? client,
    this.baseUrl = 'http://127.0.0.1:8000',
    this.timeout = const Duration(seconds: 2),
  }) : _client = client ?? http.Client();

  Future<Map<String, VocabularyEntry>> load() async {
    final jsonList = await _tryLoadFromApi() ?? await _loadBundled();
    return _toMap(jsonList);
  }

  Future<List<dynamic>?> _tryLoadFromApi() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/vocabulary')).timeout(timeout);
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as List<dynamic>;
    } catch (_) {
      // Backend unreachable, timed out, or returned something unparseable -
      // any of these fall back to the bundled dataset rather than erroring.
      return null;
    }
  }

  Future<List<dynamic>> _loadBundled() async {
    final String data = await rootBundle.loadString('assets/vocab/en_de_starter.json');
    return jsonDecode(data) as List<dynamic>;
  }

  Map<String, VocabularyEntry> _toMap(List<dynamic> jsonList) {
    final Map<String, VocabularyEntry> result = {};
    for (final dynamic item in jsonList) {
      final entry = VocabularyEntry.fromJson(item as Map<String, dynamic>);
      result[entry.en.toLowerCase()] = entry;
    }
    return result;
  }
}
