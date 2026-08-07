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

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'text': text,
        'isWord': isWord,
        'positionIndex': positionIndex,
      };

  factory Token.fromJson(Map<String, dynamic> json) => Token(
        tokenId: json['tokenId'] as String,
        text: json['text'] as String,
        isWord: json['isWord'] as bool,
        positionIndex: json['positionIndex'] as int,
      );
}
