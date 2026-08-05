import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/vocabulary_entry.dart';

class VocabularyRepository {
  Future<Map<String, VocabularyEntry>> load() async {
    final String data = await rootBundle.loadString('assets/vocab/en_de_starter.json');
    final List<dynamic> jsonList = jsonDecode(data) as List<dynamic>;
    final Map<String, VocabularyEntry> result = {};

    for (final dynamic item in jsonList) {
      final Map<String, dynamic> jsonMap = item as Map<String, dynamic>;
      final VocabularyEntry entry = VocabularyEntry.fromJson(jsonMap);
      result[entry.en.toLowerCase()] = entry;
    }

    return result;
  }
}
