class FlashCard {
  final int id;
  final String image;
  final String questionText;
  final int order;

  FlashCard({
    required this.id,
    required this.image,
    required this.questionText,
    required this.order,
  });

  factory FlashCard.fromJson(Map<String, dynamic> json) {
    return FlashCard(
      id: json['id'],
      image: json['image'] ?? '',
      questionText: json['question_text'] ?? '',
      order: json['order'] ?? 0,
    );
  }
}

class FlashCardDeck {
  final int id;
  final String title;
  final String description;
  final bool isDefault;
  final int order;
  final List<FlashCard> cards;

  FlashCardDeck({
    required this.id,
    required this.title,
    required this.description,
    required this.isDefault,
    required this.order,
    required this.cards,
  });

  factory FlashCardDeck.fromJson(Map<String, dynamic> json) {
    var list = json['cards'] as List? ?? [];
    List<FlashCard> cardsList = list.map((i) => FlashCard.fromJson(i)).toList();

    return FlashCardDeck(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isDefault: json['is_default'] ?? false,
      order: json['order'] ?? 0,
      cards: cardsList,
    );
  }
}
