import 'package:flutter/material.dart';

enum ReportTargetType { user, listing, general }

enum ReportContextType { profile, listing, chat, transaction, general }

class ReportContext {
  const ReportContext({
    required this.targetType,
    required this.contextType,
    this.targetId,
    this.targetLabel,
    this.contextId,
    this.contextLabel,
  });

  const ReportContext.general()
    : targetType = ReportTargetType.general,
      contextType = ReportContextType.general,
      targetId = null,
      targetLabel = null,
      contextId = null,
      contextLabel = null;

  final ReportTargetType targetType;
  final String? targetId;
  final String? targetLabel;
  final ReportContextType contextType;
  final String? contextId;
  final String? contextLabel;

  bool get isGeneral => contextType == ReportContextType.general;
}

class ReportReason {
  const ReportReason({
    required this.code,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String code;
  final String label;
  final String description;
  final IconData icon;
}

class ReportReasonCatalog {
  static const chatUser = <ReportReason>[
    ReportReason(
      code: 'scam_or_fraud',
      label: 'Scam or fraud',
      description:
          'Deceptive offers, suspicious payments or off-platform pressure',
      icon: Icons.gpp_maybe_outlined,
    ),
    ReportReason(
      code: 'harassment_or_abusive_behaviour',
      label: 'Harassment or abusive behaviour',
      description: 'Threats, hate, bullying or unwanted contact',
      icon: Icons.record_voice_over_outlined,
    ),
    ReportReason(
      code: 'unsafe_meetup_behaviour',
      label: 'Unsafe meetup behaviour',
      description: 'Pressure to meet somewhere unsafe or concerning conduct',
      icon: Icons.location_off_outlined,
    ),
    ReportReason(
      code: 'fake_identity_or_impersonation',
      label: 'Fake identity or impersonation',
      description: 'The account may be pretending to be someone else',
      icon: Icons.person_off_outlined,
    ),
    ReportReason(
      code: 'other',
      label: 'Something else',
      description: 'A different concern about this conversation',
      icon: Icons.more_horiz,
    ),
  ];

  static const userAndTrade = <ReportReason>[
    ReportReason(
      code: 'scam_or_fraud',
      label: 'Scam or fraud',
      description: 'Deceptive requests, fake offers or attempted fraud',
      icon: Icons.gpp_maybe_outlined,
    ),
    ReportReason(
      code: 'harassment_or_abusive_behaviour',
      label: 'Harassment or abusive behaviour',
      description: 'Threats, hate, bullying or unwanted contact',
      icon: Icons.record_voice_over_outlined,
    ),
    ReportReason(
      code: 'unsafe_meetup_behaviour',
      label: 'Unsafe meetup behaviour',
      description: 'Pressure to meet somewhere unsafe or concerning conduct',
      icon: Icons.location_off_outlined,
    ),
    ReportReason(
      code: 'did_not_show_up_repeatedly',
      label: 'Repeatedly did not show up',
      description: 'Multiple agreed meetups were missed without explanation',
      icon: Icons.event_busy_outlined,
    ),
    ReportReason(
      code: 'fake_identity_or_impersonation',
      label: 'Fake identity or impersonation',
      description: 'The account may be pretending to be someone else',
      icon: Icons.person_off_outlined,
    ),
    ReportReason(
      code: 'suspicious_payment_request',
      label: 'Suspicious payment request',
      description: 'Unusual deposits, gift cards or payment links',
      icon: Icons.payments_outlined,
    ),
    ReportReason(
      code: 'off_platform_communication',
      label: 'Asked to move off KiwiShare',
      description: 'Pressure to continue the trade on another platform',
      icon: Icons.open_in_new_outlined,
    ),
    ReportReason(
      code: 'other',
      label: 'Something else',
      description: 'A different safety or conduct concern',
      icon: Icons.more_horiz,
    ),
  ];

  static const listing = <ReportReason>[
    ReportReason(
      code: 'misleading_information',
      label: 'Misleading information',
      description: 'The description, photos or condition may be inaccurate',
      icon: Icons.fact_check_outlined,
    ),
    ReportReason(
      code: 'prohibited_or_unsafe_item',
      label: 'Prohibited or unsafe item',
      description: 'The item may be dangerous or not allowed on KiwiShare',
      icon: Icons.warning_amber_outlined,
    ),
    ReportReason(
      code: 'counterfeit_item',
      label: 'Counterfeit item',
      description: 'The listing may be offering an imitation product',
      icon: Icons.content_copy_outlined,
    ),
    ReportReason(
      code: 'suspected_stolen_item',
      label: 'Suspected stolen item',
      description: 'There are signs the seller may not own the item',
      icon: Icons.policy_outlined,
    ),
    ReportReason(
      code: 'duplicate_listing_or_spam',
      label: 'Duplicate listing or spam',
      description: 'Repeated, irrelevant or promotional content',
      icon: Icons.filter_none_outlined,
    ),
    ReportReason(
      code: 'other',
      label: 'Something else',
      description: 'A different concern about this listing',
      icon: Icons.more_horiz,
    ),
  ];

  static List<ReportReason> forContext(ReportContext context) {
    if (context.targetType == ReportTargetType.listing) return listing;
    if (context.contextType == ReportContextType.chat) return chatUser;
    return userAndTrade;
  }
}

class ReportDraft {
  const ReportDraft({
    required this.context,
    required this.reason,
    required this.details,
  });

  final ReportContext context;
  final ReportReason reason;
  final String details;

  Map<String, String> toRequestMap() {
    final request = <String, String>{
      'targetType': context.targetType.name,
      'contextType': context.contextType.name,
      'reason': reason.code,
      'details': details.trim(),
    };
    if (context.targetId case final id?) request['targetId'] = id;
    if (context.contextId case final id?) request['contextId'] = id;
    return request;
  }
}

typedef ReportSubmitter = Future<void> Function(ReportDraft draft);
