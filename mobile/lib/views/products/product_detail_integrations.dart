import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/item_model.dart';
import '../../models/report_draft.dart';
import '../profile/report_screen.dart';

typedef ProductDetailAction =
    FutureOr<void> Function(BuildContext context, ItemModel item);

Future<void> openListingReport(BuildContext context, ItemModel item) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ReportScreen(
        reportContext: ReportContext(
          targetType: ReportTargetType.listing,
          targetId: item.id,
          targetLabel: item.title,
          contextType: ReportContextType.listing,
          contextId: item.id,
          contextLabel: item.location.isEmpty
              ? item.title
              : 'Listing in ${item.location}',
        ),
      ),
    ),
  );
}

/// Optional bridges owned by neighbouring modules.
///
/// Product detail passes the current database-backed listing to these hooks
/// without depending on report, messaging, transaction, or profile screens.
/// Each module can connect its route/repository when its public contract is
/// merged into `pre`.
class ProductDetailIntegrations {
  final ProductDetailAction? onReportListing;
  final ProductDetailAction? onContactSeller;
  final ProductDetailAction? onStartTrade;
  final ProductDetailAction? onViewSeller;

  const ProductDetailIntegrations({
    this.onReportListing,
    this.onContactSeller,
    this.onStartTrade,
    this.onViewSeller,
  });
}
