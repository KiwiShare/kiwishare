import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/order_model.dart';

abstract class OrderRepository {
  Future<List<SafeZoneModel>> getSafeZones();
  Future<Map<String, dynamic>> checkout({
    required String itemId,
    required Map<String, dynamic> meetingLocation,
    String? scheduledAt,
    String? token,
    String? userId,
  });
  Future<Map<String, dynamic>> payOrder(
    String orderId, {
    String? token,
    String? userId,
  });
  Future<List<OrderModel>> getOrders({
    String role = 'all',
    String? token,
    String? userId,
  });
  Future<Map<String, dynamic>> getOrderById(
    String orderId, {
    String? token,
    String? userId,
  });
  Future<Map<String, dynamic>> verifyHandover(
    String orderId, {
    String? qrToken,
    String? claimCode,
    String? token,
    String? userId,
  });
  Future<Map<String, dynamic>> activateTurboBoost({
    String plan = 'monthly',
    String? token,
    String? userId,
  });
}

class RestOrderRepository implements OrderRepository {
  final http.Client _client;

  RestOrderRepository({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String? token, {String? userId}) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId != null && userId.isNotEmpty) 'x-user-id': userId,
      };

  @override
  Future<List<SafeZoneModel>> getSafeZones() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConfig.safeZonesUrl),
        headers: _headers(null),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((e) => SafeZoneModel.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching safe zones: $e');
    }
    return const [];
  }

  @override
  Future<Map<String, dynamic>> checkout({
    required String itemId,
    required Map<String, dynamic> meetingLocation,
    String? scheduledAt,
    String? token,
    String? userId,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.ordersCheckoutUrl),
      headers: _headers(token, userId: userId),
      body: jsonEncode({
        'itemId': itemId,
        'meetingLocation': meetingLocation,
        'scheduledAt': scheduledAt,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201 && data['status'] == 'success') {
      return data;
    }
    throw Exception(data['message'] ?? 'Checkout failed.');
  }

  @override
  Future<Map<String, dynamic>> payOrder(
    String orderId, {
    String? token,
    String? userId,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.orderPayUrl(orderId)),
      headers: _headers(token, userId: userId),
      body: jsonEncode({}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data;
    }
    throw Exception(data['message'] ?? 'Payment authorization failed.');
  }

  @override
  Future<List<OrderModel>> getOrders({
    String role = 'all',
    String? token,
    String? userId,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.ordersUrl}?role=$role'),
        headers: _headers(token, userId: userId),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['orders'] as List<dynamic>?) ?? [];
        return list.map((e) => OrderModel.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    }
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getOrderById(
    String orderId, {
    String? token,
    String? userId,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.orderDetailUrl(orderId)),
      headers: _headers(token, userId: userId),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to load order.');
  }

  @override
  Future<Map<String, dynamic>> verifyHandover(
    String orderId, {
    String? qrToken,
    String? claimCode,
    String? token,
    String? userId,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.orderVerifyUrl(orderId)),
      headers: _headers(token, userId: userId),
      body: jsonEncode({
        if (qrToken != null) 'qrToken': qrToken,
        if (claimCode != null) 'claimCode': claimCode,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data;
    }
    throw Exception(data['message'] ?? 'Handover verification failed.');
  }

  @override
  Future<Map<String, dynamic>> activateTurboBoost({
    String plan = 'monthly',
    String? token,
    String? userId,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.turboBoostUrl),
      headers: _headers(token, userId: userId),
      body: jsonEncode({'plan': plan}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to activate Turbo Boost.');
  }
}
