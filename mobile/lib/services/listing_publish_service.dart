import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/item_model.dart';
import 'r2_upload_service.dart';

class ListingPhotoDraft {
  const ListingPhotoDraft({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class ListingDraft {
  const ListingDraft({
    required this.title,
    required this.priceNzd,
    required this.locationLabel,
    required this.category,
    required this.condition,
    required this.description,
    required this.photos,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String priceNzd;
  final String locationLabel;
  final String category;
  final String condition;
  final String description;
  final List<ListingPhotoDraft> photos;
  final double? latitude;
  final double? longitude;
}

class ListingPublishException implements Exception {
  const ListingPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ListingPublishService {
  Future<ItemModel> publish({
    required ListingDraft draft,
    required String authToken,
  });
}

class RestListingPublishService implements ListingPublishService {
  RestListingPublishService({
    http.Client? client,
    ListingPhotoUploader? photoUploader,
  }) : _client = client ?? http.Client(),
       _photoUploader = photoUploader ?? R2UploadService(client: client);

  final http.Client _client;
  final ListingPhotoUploader _photoUploader;

  @override
  Future<ItemModel> publish({
    required ListingDraft draft,
    required String authToken,
  }) async {
    if (authToken.trim().isEmpty) {
      throw const ListingPublishException(
        'Please sign in before publishing an item.',
      );
    }

    final imageUrls = <String>[];
    try {
      for (final photo in draft.photos) {
        imageUrls.add(
          await _photoUploader.uploadImage(
            bytes: photo.bytes,
            fileName: photo.fileName,
            contentType: photo.contentType,
            authToken: authToken,
          ),
        );
      }
    } on ListingPhotoUploadException catch (error) {
      throw ListingPublishException(error.message);
    } catch (_) {
      throw const ListingPublishException(
        'A photo could not be uploaded. Please try again.',
      );
    }

    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/usedItems'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
        'x-client-platform': 'mobile',
      },
      body: jsonEncode({
        'title': draft.title.trim(),
        'priceNzd': draft.priceNzd.trim(),
        'category': draft.category,
        'condition': _conditionValue(draft.condition),
        'description': draft.description.trim(),
        'images': [
          for (var index = 0; index < imageUrls.length; index++)
            {
              'url': imageUrls[index],
              'thumbnailUrl': imageUrls[index],
              'sortOrder': index,
            },
        ],
        'location': _locationPayload(draft),
      }),
    );

    final data = _decodeResponse(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ListingPublishException(
        'Your session has expired. Please sign in again.',
      );
    }
    if (response.statusCode != 201) {
      throw ListingPublishException(
        _responseMessage(
          data,
          fallback: 'Your item could not be published. Please try again.',
        ),
      );
    }

    final item = data?['item'];
    if (item is! Map) {
      throw const ListingPublishException(
        'The server returned an invalid listing response.',
      );
    }
    return ItemModel.fromJson(Map<String, dynamic>.from(item));
  }

  Map<String, dynamic> _locationPayload(ListingDraft draft) {
    final parts = draft.locationLabel
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return {
      'city': parts.isEmpty ? draft.locationLabel.trim() : parts.last,
      'suburb': parts.length > 1 ? parts.first : '',
      if (draft.latitude != null) 'latitude': draft.latitude,
      if (draft.longitude != null) 'longitude': draft.longitude,
    };
  }

  String _conditionValue(String condition) {
    return condition.trim().toLowerCase().replaceAll(' ', '_');
  }

  Map<String, dynamic>? _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _responseMessage(
    Map<String, dynamic>? data, {
    required String fallback,
  }) {
    final message = data?['message'];
    return message is String && message.trim().isNotEmpty
        ? message.trim()
        : fallback;
  }
}
