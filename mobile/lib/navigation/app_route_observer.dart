import 'package:flutter/material.dart';

final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

class ChatVisibilityTracker {
  Object? _owner;
  String? _conversationId;
  String? _sessionToken;

  void update({
    required Object owner,
    required String conversationId,
    required String sessionToken,
    required bool visible,
  }) {
    if (visible) {
      _owner = owner;
      _conversationId = conversationId;
      _sessionToken = sessionToken;
      return;
    }
    if (identical(_owner, owner)) clear(owner);
  }

  void clear(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _conversationId = null;
    _sessionToken = null;
  }

  bool isVisible({
    required String conversationId,
    required String sessionToken,
  }) =>
      _owner != null &&
      _conversationId == conversationId &&
      _sessionToken == sessionToken;
}

final ChatVisibilityTracker chatVisibilityTracker = ChatVisibilityTracker();
