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
}
