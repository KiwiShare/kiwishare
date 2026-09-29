import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/listing_category_config.dart';

final listingSuggestionCategories = listingCategoryNames;

const listingSuggestionConditions = <String>['New', 'Like new', 'Good', 'Fair'];

class ListingSuggestionInput {
  const ListingSuggestionInput({
    this.title,
    this.description,
    this.category,
    this.condition,
    this.location,
    this.imageBase64,
    this.imageMimeType,
    this.attributes = const {},
  });

  final String? title;
  final String? description;
  final String? category;
  final String? condition;
  final String? location;
  final String? imageBase64;
  final String? imageMimeType;
  final Map<String, String> attributes;

  Map<String, Object> toJson() => {
    'title': ?_nonEmpty(title),
    'description': ?_nonEmpty(description),
    'category': ?_nonEmpty(category),
    'condition': ?_nonEmpty(condition),
    'location': ?_nonEmpty(location),
    'imageBase64': ?_nonEmpty(imageBase64),
    'imageMimeType': ?_nonEmpty(imageMimeType),
    if (attributes.isNotEmpty) 'attributes': attributes,
  };

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class ListingSuggestion {
  const ListingSuggestion({
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.priceNzd,
    this.attributes = const {},
  });

  final String title;
  final String description;
  final String category;
  final String condition;
  final String priceNzd;
  final Map<String, String> attributes;

  factory ListingSuggestion.fromJson(Map<String, dynamic> json) {
    final title = _requiredText(json['title'], 'title', 120);
    if (title.length < 3) {
      throw const ListingSuggestionException(
        'The server returned an invalid AI suggestion.',
      );
    }
    final description = _requiredText(
      json['description'],
      'description',
      2000,
      allowLineBreaks: true,
    );
    final category = _requiredText(json['category'], 'category', 50);
    final condition = _requiredText(json['condition'], 'condition', 20);
    final priceNzd = _requiredText(json['priceNzd'], 'price', 10);
    if (!listingSuggestionCategories.contains(category) ||
        !listingSuggestionConditions.contains(condition) ||
        !RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(priceNzd) ||
        (double.tryParse(priceNzd) ?? 0) <= 0) {
      throw const ListingSuggestionException(
        'The server returned an invalid AI suggestion.',
      );
    }

    final attributes = <String, String>{};
    final definition = listingCategoryDefinition(category);
    final allowedKeys = {
      for (final field
          in definition?.attributes ?? const <ListingAttributeField>[])
        field.key,
    };
    final rawAttributes = json['attributes'];
    if (rawAttributes is Map) {
      for (final entry in rawAttributes.entries) {
        final key = entry.key.toString();
        final value = entry.value?.toString().trim() ?? '';
        if (allowedKeys.contains(key) &&
            value.isNotEmpty &&
            value.length <= 120) {
          attributes[key] = value;
        }
      }
    }

    return ListingSuggestion(
      title: title,
      description: description,
      category: category,
      condition: condition,
      priceNzd: priceNzd,
      attributes: attributes,
    );
  }

  static String _requiredText(
    Object? value,
    String fieldName,
    int maximumLength, {
    bool allowLineBreaks = false,
  }) {
    if (value is! String) {
      throw ListingSuggestionException('AI suggestion $fieldName is missing.');
    }
    final text = value.trim();
    if (text.isEmpty ||
        text.length > maximumLength ||
        _hasUnsafeText(text, allowLineBreaks: allowLineBreaks)) {
      throw ListingSuggestionException('AI suggestion $fieldName is invalid.');
    }
    return text;
  }

  static bool _hasUnsafeText(String text, {required bool allowLineBreaks}) {
    for (final rune in text.runes) {
      if ((rune <= 0x1f &&
              !(allowLineBreaks && (rune == 0x09 || rune == 0x0a))) ||
          (rune >= 0x7f && rune <= 0x9f) ||
          (rune >= 0x200b && rune <= 0x200f) ||
          (rune >= 0x202a && rune <= 0x202e) ||
          rune == 0x2060 ||
          (rune >= 0x2066 && rune <= 0x2069)) {
        return true;
      }
    }
    return RegExp(
      r'(?:https?://|www\.|\b[^\s@]+@[^\s@]+\.[^\s@]+\b)',
      caseSensitive: false,
    ).hasMatch(text);
  }
}

class ListingSuggestionException implements Exception {
  const ListingSuggestionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ListingSuggestionAuthenticationException
    extends ListingSuggestionException {
  const ListingSuggestionAuthenticationException()
    : super('Your session has expired. Please sign in again.');
}

abstract interface class ListingSuggestionService {
  Future<ListingSuggestion> suggest({
    required ListingSuggestionInput input,
    required String authToken,
  });
}

class RestListingSuggestionService implements ListingSuggestionService {
  RestListingSuggestionService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<ListingSuggestion> suggest({
    required ListingSuggestionInput input,
    required String authToken,
  }) async {
    if (authToken.trim().isEmpty) {
      throw const ListingSuggestionAuthenticationException();
    }

    late http.Response response;
    var usedCategoryCompatibilityFallback = false;
    try {
      response = await _postSuggestion(
        payload: input.toJson(),
        authToken: authToken,
      );

      // Production can briefly lag behind a mobile rollout that introduces a
      // new listing category. Older servers reject the new category before
      // Gemini is called. Retry without the category so AI Help Me Write still
      // produces title/description/condition/price, then preserve the category
      // the seller explicitly selected on the client.
      final firstData = _decodeObject(response.body);
      final serverMessage = firstData?['message'];
      final categoryRejected =
          response.statusCode == 400 &&
          serverMessage is String &&
          serverMessage.trim().toLowerCase() == 'category is not allowed.';
      if (categoryRejected &&
          input.category != null &&
          input.category!.trim().isNotEmpty) {
        final fallbackPayload = Map<String, Object>.from(input.toJson())
          ..remove('category')
          ..remove('attributes');
        response = await _postSuggestion(
          payload: fallbackPayload,
          authToken: authToken,
        );
        usedCategoryCompatibilityFallback = true;
      }
    } on TimeoutException {
      throw const ListingSuggestionException(
        'AI suggestions took too long. Please try again.',
      );
    } catch (error) {
      if (error is ListingSuggestionException) rethrow;
      throw const ListingSuggestionException(
        'AI suggestions could not be reached. Please try again.',
      );
    }

    final data = _decodeObject(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ListingSuggestionAuthenticationException();
    }
    if (response.statusCode != 200) {
      final message = data?['message'];
      throw ListingSuggestionException(
        message is String && message.trim().isNotEmpty
            ? message.trim()
            : 'AI suggestions are temporarily unavailable. Please try again.',
      );
    }

    final suggestion = data?['suggestion'];
    if (suggestion is! Map) {
      throw const ListingSuggestionException(
        'The server returned an invalid AI suggestion.',
      );
    }
    final parsed = ListingSuggestion.fromJson(
      Map<String, dynamic>.from(suggestion),
    );
    if (usedCategoryCompatibilityFallback &&
        input.category != null &&
        listingSuggestionCategories.contains(input.category)) {
      return ListingSuggestion(
        title: parsed.title,
        description: parsed.description,
        category: input.category!,
        condition: parsed.condition,
        priceNzd: parsed.priceNzd,
        attributes: const {},
      );
    }
    return parsed;
  }

  Future<http.Response> _postSuggestion({
    required Map<String, Object> payload,
    required String authToken,
  }) {
    return _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/listing-suggestions'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
            'x-client-platform': 'mobile',
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);
  }

  Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
