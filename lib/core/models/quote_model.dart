import 'package:hive/hive.dart';

part 'quote_model.g.dart';

@HiveType(typeId: 3)
class MotivationalQuote {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  @HiveField(2)
  final String author;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final DateTime dateAdded;

  @HiveField(5)
  bool isFavorite;

  MotivationalQuote({
    required this.id,
    required this.text,
    required this.author,
    this.category = 'motivation',
    required this.dateAdded,
    this.isFavorite = false,
  });

  factory MotivationalQuote.fromJson(Map<String, dynamic> json) {
    return MotivationalQuote(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['q'] ?? 'No quote text',
      author: json['a'] ?? 'Unknown',
      category: json['c'] ?? 'motivation',
      dateAdded: DateTime.now(),
    );
  }
}
