import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import '../repositories/order_repository.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider({required this.repository});

  final OrderRepository repository;

  String? _authToken;
  String? get authToken => _authToken;

  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;

  void updateAuthToken(String? token) {
    if (_authToken == token) return;
    _authToken = token;
    if (token != null && token.isNotEmpty) {
      loadMyOrders(token);
    } else {
      _orders = [];
      notifyListeners();
    }
  }

  List<OrderModel> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<OrderModel> get buyingOrders =>
      _orders.where((o) => o.isBuying).toList();

  List<OrderModel> get sellingOrders =>
      _orders.where((o) => o.isSelling).toList();

  Future<void> loadMyOrders(
    String token, {
    String? type,
    String? status,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await repository.fetchMyOrders(
        token: token,
        type: type,
        status: status,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<OrderModel> createOrGetOrder({
    required String itemId,
    required String token,
  }) async {
    final order = await repository.createOrGetOrder(
      itemId: itemId,
      token: token,
    );
    // Ensure local list is updated
    final existing = _orders.indexWhere((o) => o.id == order.id);
    if (existing >= 0) {
      _orders[existing] = order;
    } else {
      _orders.insert(0, order);
    }
    notifyListeners();
    return order;
  }
}
