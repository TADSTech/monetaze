import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:monetaze/core/models/quote_model.dart';

class QuoteService {
  static const String _baseUrl = 'https://zenquotes.io/api';
  final Box<MotivationalQuote> quotesBox;

  QuoteService(this.quotesBox);

  Future<MotivationalQuote> fetchRandomQuote() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/random'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final quote = MotivationalQuote.fromJson(data[0]);
          await _cacheQuote(quote);
          return quote;
        }
      }
      return _getFallbackQuote();
    } catch (e) {
      print('Error fetching quote: $e');
      return _getFallbackQuote();
    }
  }

  Future<List<MotivationalQuote>> fetchQuotesByTheme(String theme) async {
    try {
      // ZenQuotes doesn't support theme filtering, so we'll filter locally
      final response = await http
          .get(
            Uri.parse('$_baseUrl/quotes'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<MotivationalQuote> quotes =
            data
                .map((json) => MotivationalQuote.fromJson(json))
                .where((quote) => quote.text.toLowerCase().contains(theme))
                .toList();

        if (quotes.isNotEmpty) {
          await _cacheQuotes(quotes);
          return quotes;
        }
      }
      return [_getFallbackQuote()];
    } catch (e) {
      print('Error fetching themed quotes: $e');
      return [_getFallbackQuote()];
    }
  }

  Future<void> _cacheQuote(MotivationalQuote quote) async {
    try {
      await quotesBox.put(quote.id, quote);
      // Keep only the last 20 quotes to avoid too much storage usage
      if (quotesBox.length > 20) {
        final keys =
            quotesBox.keys.toList()..sort(
              (a, b) => quotesBox
                  .get(b)!
                  .dateAdded
                  .compareTo(quotesBox.get(a)!.dateAdded),
            );
        for (var key in keys.skip(20)) {
          await quotesBox.delete(key);
        }
      }
    } catch (e) {
      print('Error caching quote: $e');
    }
  }

  Future<void> _cacheQuotes(List<MotivationalQuote> quotes) async {
    for (final quote in quotes) {
      await _cacheQuote(quote);
    }
  }

  MotivationalQuote _getFallbackQuote() {
    return MotivationalQuote(
      id: 'fallback',
      text: 'Saving money is the first step to financial freedom.',
      author: 'Anonymous',
      category: 'savings',
      dateAdded: DateTime.now(),
    );
  }

  Future<List<MotivationalQuote>> getSavedQuotes() async {
    try {
      final quotes =
          quotesBox.values.toList()
            ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      return quotes;
    } catch (e) {
      print('Error getting saved quotes: $e');
      return [];
    }
  }

  Future<void> toggleFavorite(String quoteId) async {
    try {
      final quote = quotesBox.get(quoteId);
      if (quote != null) {
        quote.isFavorite = !quote.isFavorite;
        await quotesBox.put(quoteId, quote);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }
}
