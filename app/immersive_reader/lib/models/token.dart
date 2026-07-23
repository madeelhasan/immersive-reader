// lib/models/token.dart

class Token {
  final String tokenId;
  final String text;
  final bool isWord;
  final int positionIndex;

  Token({
    required this.tokenId,
    required this.text,
    required this.isWord,
    required this.positionIndex,
  });
}
