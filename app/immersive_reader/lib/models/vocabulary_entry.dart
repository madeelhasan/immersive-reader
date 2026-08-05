class VocabularyEntry {
  final String en;
  final String de;
  final String cefrLevel;
  final String partOfSpeech;

  VocabularyEntry({
    required this.en,
    required this.de,
    required this.cefrLevel,
    required this.partOfSpeech,
  });

  factory VocabularyEntry.fromJson(Map<String, dynamic> json) {
    return VocabularyEntry(
      en: json['en'] as String,
      de: json['de'] as String,
      cefrLevel: json['cefr_level'] as String,
      partOfSpeech: json['part_of_speech'] as String,
    );
  }
}
