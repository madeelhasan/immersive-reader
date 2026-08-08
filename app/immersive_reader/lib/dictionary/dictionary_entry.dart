/// One sense/entry for a headword, as extracted from FreeDict's eng-deu
/// dictd release (see DictionaryRepository). [definition] is the raw
/// multi-line entry text (German translation, plus any part-of-speech
/// tags, usage notes, synonyms, and cross-references FreeDict included) -
/// shown close to as-is rather than parsed into separate structured
/// fields, since the source formatting is informative on its own and not
/// worth the risk of losing information to an imperfect parse.
class DictionaryEntry {
  final String headword;
  final String definition;

  const DictionaryEntry({required this.headword, required this.definition});
}
