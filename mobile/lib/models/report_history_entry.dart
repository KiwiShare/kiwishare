class ReportHistoryEntry {
  const ReportHistoryEntry({
    required this.id,
    required this.targetType,
    required this.contextType,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  factory ReportHistoryEntry.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    final targetType = _requiredString(json, 'targetType');
    final contextType = _requiredString(json, 'contextType');
    final reason = _requiredString(json, 'reason');
    final details = _requiredString(json, 'details');
    final status = _requiredString(json, 'status');
    final createdAt = DateTime.tryParse(_requiredString(json, 'createdAt'));

    if (createdAt == null) {
      throw const FormatException('Invalid report date.');
    }

    return ReportHistoryEntry(
      id: id,
      targetType: targetType,
      contextType: contextType,
      reason: reason,
      details: details,
      status: status,
      createdAt: createdAt,
    );
  }

  final String id;
  final String targetType;
  final String contextType;
  final String reason;
  final String details;
  final String status;
  final DateTime createdAt;

  String get typeLabel => switch ((targetType, contextType)) {
    ('listing', _) => 'Listing report',
    ('user', 'chat') => 'Chat report',
    ('user', 'transaction') => 'Transaction report',
    ('user', _) => 'User report',
    _ => 'Safety report',
  };

  String get reasonLabel => switch (reason) {
    'scam_or_fraud' => 'Scam or fraud',
    'harassment_or_abusive_behaviour' => 'Harassment or abusive behaviour',
    'unsafe_meetup_behaviour' => 'Unsafe meetup behaviour',
    'did_not_show_up_repeatedly' => 'Repeatedly did not show up',
    'fake_identity_or_impersonation' => 'Fake identity or impersonation',
    'suspicious_payment_request' => 'Suspicious payment request',
    'off_platform_communication' => 'Asked to move off KiwiShare',
    'misleading_information' => 'Misleading information',
    'prohibited_or_unsafe_item' => 'Prohibited or unsafe item',
    'counterfeit_item' => 'Counterfeit item',
    'suspected_stolen_item' => 'Suspected stolen item',
    'duplicate_listing_or_spam' => 'Duplicate listing or spam',
    'other' => 'Something else',
    _ => _humanise(reason),
  };

  String get statusLabel => switch (status) {
    'pending' || 'submitted' => 'Submitted',
    'reviewed' => 'Reviewed',
    'dismissed' => 'Closed',
    _ => 'Status unavailable',
  };

  String get statusDescription => switch (status) {
    'pending' || 'submitted' => 'Waiting for review',
    'reviewed' => 'Review completed',
    'dismissed' => 'Review closed',
    _ => 'No status update is available',
  };

  String get shortReference {
    final compact = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compact.length <= 8) return compact.toUpperCase();
    return compact.substring(compact.length - 8).toUpperCase();
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing report field: $key.');
    }
    return value.trim();
  }

  static String _humanise(String value) {
    final words = value.split('_').where((word) => word.isNotEmpty).join(' ');
    if (words.isEmpty) return 'Other';
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}
