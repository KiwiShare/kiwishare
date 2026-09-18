import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/order_model.dart';

class OrderRepositoryException implements Exception {
  const OrderRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class OrderRepository {
  Future<List<OrderModel>> fetchMyOrders({
    required String token,
    String? type,
    String? status,
  });

  Future<OrderModel> fetchOrderDetails({
    required String orderId,
    required String token,
  });

  Future<OrderModel> createOrGetOrder({
    required String itemId,
    required String token,
  });

  Future<OrderModel> refundOrder({
    required String orderId,
    required String token,
    String? reason,
  });
}

class RestOrderRepository implements OrderRepository {
  RestOrderRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  @override
  Future<List<OrderModel>> fetchMyOrders({
    required String token,
    String? type,
    String? status,
  }) async {
    final query = <String, String>{};
    if (type != null) query['type'] = type;
    if (status != null) query['status'] = status;

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/orders/my',
    ).replace(queryParameters: query.isNotEmpty ? query : null);

    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw OrderRepositoryException(
        'Failed to fetch orders (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['orders'] as List<dynamic>? ?? [];
    return list
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderModel> fetchOrderDetails({
    required String orderId,
    required String token,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/orders/$orderId');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw OrderRepositoryException(
        'Failed to fetch order details (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> createOrGetOrder({
    required String itemId,
    required String token,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/orders');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'itemId': itemId}),
    );

    // 200 = existing order returned, 201 = new order created
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw OrderRepositoryException(
        'Failed to create order (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final orderJson = data['order'] ?? data;
    return OrderModel.fromJson(orderJson as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> refundOrder({
    required String orderId,
    required String token,
    String? reason,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/orders/$orderId/refund');
    final payload = <String, dynamic>{};
    if (reason != null) payload['reason'] = reason;
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
      throw OrderRepositoryException(
        errorBody?['message'] as String? ??
            'Failed to refund order (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final orderJson = data['order'] ?? data;
    return OrderModel.fromJson(orderJson as Map<String, dynamic>);
  }
}
