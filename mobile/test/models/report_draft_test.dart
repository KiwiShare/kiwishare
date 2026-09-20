import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/report_draft.dart';

void main() {
  test('listing draft sends only the report contract fields', () {
    const context = ReportContext(
      targetType: ReportTargetType.listing,
      targetId: 'listing-id',
      targetLabel: 'Office chair',
      contextType: ReportContextType.listing,
      contextId: 'listing-id',
      contextLabel: 'Product details',
    );
    const draft = ReportDraft(
      context: context,
      reason: ReportReason(
        code: 'misleading_information',
        label: 'Misleading information',
        description: 'Inaccurate details',
        icon: Icons.fact_check_outlined,
      ),
      details: '  The item photos do not match the description.  ',
    );

    expect(draft.toRequestMap(), {
      'targetType': 'listing',
      'targetId': 'listing-id',
      'contextType': 'listing',
      'contextId': 'listing-id',
      'reason': 'misleading_information',
      'details': 'The item photos do not match the description.',
    });
  });

  test('chat draft identifies the participant and conversation separately', () {
    final draft = ReportDraft(
      context: const ReportContext(
        targetType: ReportTargetType.user,
        targetId: 'other-user-id',
        contextType: ReportContextType.chat,
        contextId: 'conversation-id',
      ),
      reason: ReportReasonCatalog.chatUser[1],
      details: 'The other member sent threatening messages.',
    );

    expect(draft.toRequestMap(), {
      'targetType': 'user',
      'targetId': 'other-user-id',
      'contextType': 'chat',
      'contextId': 'conversation-id',
      'reason': 'harassment_or_abusive_behaviour',
      'details': 'The other member sent threatening messages.',
    });
  });

  test('context-specific reasons stay within the approved API catalogue', () {
    final listingCodes = ReportReasonCatalog.forContext(
      const ReportContext(
        targetType: ReportTargetType.listing,
        contextType: ReportContextType.listing,
      ),
    ).map((reason) => reason.code).toList();
    final chatCodes = ReportReasonCatalog.forContext(
      const ReportContext(
        targetType: ReportTargetType.user,
        contextType: ReportContextType.chat,
      ),
    ).map((reason) => reason.code).toList();

    expect(listingCodes, [
      'misleading_information',
      'prohibited_or_unsafe_item',
      'counterfeit_item',
      'suspected_stolen_item',
      'duplicate_listing_or_spam',
      'other',
    ]);
    expect(chatCodes, [
      'scam_or_fraud',
      'harassment_or_abusive_behaviour',
      'unsafe_meetup_behaviour',
      'fake_identity_or_impersonation',
      'other',
    ]);
    expect(listingCodes.toSet(), hasLength(listingCodes.length));
    expect(chatCodes.toSet(), hasLength(chatCodes.length));
  });
}
