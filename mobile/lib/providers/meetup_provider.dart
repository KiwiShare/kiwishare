import 'package:flutter/foundation.dart';

import '../models/meetup_model.dart';
import '../repositories/meetup_repository.dart';

class MeetupProvider extends ChangeNotifier {
  MeetupProvider({required this.repository});

  final MeetupRepository repository;

  String? _authToken;
  String? get authToken => _authToken;

  List<MeetupModel> _meetups = [];
  bool _isLoading = false;
  String? _error;
  final Map<String, MeetupModel> _meetupCache = {};

  void updateAuthToken(String? token) {
    if (_authToken == token) return;
    _authToken = token;
    if (token != null && token.isNotEmpty) {
      loadMyMeetups(token);
    } else {
      _meetups = [];
      _meetupCache.clear();
      notifyListeners();
    }
  }

  List<MeetupModel> get meetups => List.unmodifiable(_meetups);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MeetupModel> get upcomingMeetups => _meetups
      .where(
        (m) =>
            m.proposalStatus == 'confirmed' || m.proposalStatus == 'proposed',
      )
      .toList();

  List<MeetupModel> get pastMeetups => _meetups
      .where(
        (m) =>
            m.proposalStatus == 'completed' ||
            m.proposalStatus == 'declined' ||
            m.proposalStatus == 'cancelled',
      )
      .toList();

  MeetupModel? meetupById(String orderId) => _meetupCache[orderId];

  Future<void> loadMyMeetups(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _meetups = await repository.fetchMyMeetups(token: token);
      for (final m in _meetups) {
        _meetupCache[m.id] = m;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MeetupModel?> loadMeetupDetails(String orderId, String token) async {
    try {
      final meetup = await repository.fetchMeetupDetails(
        orderId: orderId,
        token: token,
      );
      _meetupCache[orderId] = meetup;
      final index = _meetups.indexWhere((m) => m.id == orderId);
      if (index >= 0) {
        _meetups[index] = meetup;
      } else {
        _meetups.insert(0, meetup);
      }
      notifyListeners();
      return meetup;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<MeetupModel?> proposeMeetup({
    required String itemId,
    String? conversationId,
    required DateTime scheduledAt,
    required String locationName,
    double? latitude,
    double? longitude,
    String? note,
    required String token,
  }) async {
    _error = null;
    try {
      final meetup = await repository.proposeMeetup(
        itemId: itemId,
        conversationId: conversationId,
        scheduledAt: scheduledAt,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        note: note,
        token: token,
      );
      _meetupCache[meetup.id] = meetup;
      _meetups.removeWhere((m) => m.id == meetup.id);
      _meetups.insert(0, meetup);
      notifyListeners();
      return meetup;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<MeetupModel?> acceptMeetup({
    required String orderId,
    required String token,
    String? messageId,
    DateTime? scheduledAt,
    String? locationName,
  }) async {
    _error = null;
    try {
      final meetup = await repository.acceptMeetup(
        orderId: orderId,
        token: token,
        messageId: messageId,
        scheduledAt: scheduledAt,
        locationName: locationName,
      );
      _meetupCache[orderId] = meetup;
      final index = _meetups.indexWhere((m) => m.id == orderId);
      if (index >= 0) {
        _meetups[index] = meetup;
      } else {
        _meetups.insert(0, meetup);
      }
      notifyListeners();
      return meetup;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> declineMeetup({
    required String orderId,
    required String token,
  }) async {
    _error = null;
    try {
      await repository.declineMeetup(orderId: orderId, token: token);
      final existing = _meetupCache[orderId];
      if (existing != null) {
        final updated = MeetupModel(
          id: existing.id,
          orderNumber: existing.orderNumber,
          itemId: existing.itemId,
          itemTitle: existing.itemTitle,
          itemPriceNzd: existing.itemPriceNzd,
          itemImageUrl: existing.itemImageUrl,
          status: 'cancelled',
          role: existing.role,
          buyerId: existing.buyerId,
          buyerName: existing.buyerName,
          buyerAvatarUrl: existing.buyerAvatarUrl,
          sellerId: existing.sellerId,
          sellerName: existing.sellerName,
          sellerAvatarUrl: existing.sellerAvatarUrl,
          scheduledAt: existing.scheduledAt,
          locationName: existing.locationName,
          latitude: existing.latitude,
          longitude: existing.longitude,
          proposalStatus: 'declined',
          proposedBy: existing.proposedBy,
          note: existing.note,
          qrToken: null,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        );
        _meetupCache[orderId] = updated;
        final index = _meetups.indexWhere((m) => m.id == orderId);
        if (index >= 0) _meetups[index] = updated;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> claimHandover({
    required String claimCode,
    String? itemId,
    required String token,
  }) async {
    final result = await repository.claimHandover(
      claimCode: claimCode,
      itemId: itemId,
      token: token,
    );
    // Reload meetups to keep local cache in sync
    await loadMyMeetups(token);
    return result;
  }

  Future<Map<String, dynamic>> confirmHandover({
    required String orderId,
    required String token,
  }) async {
    final result = await repository.confirmHandover(
      orderId: orderId,
      token: token,
    );
    // Reload meetup details and list to keep local cache in sync
    await loadMeetupDetails(orderId, token);
    await loadMyMeetups(token);
    return result;
  }
}
