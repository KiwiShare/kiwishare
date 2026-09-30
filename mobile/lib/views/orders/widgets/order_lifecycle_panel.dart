import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/map_launcher_service.dart';
import '../../../theme/app_theme.dart';

class OrderLifecyclePanel extends StatelessWidget {
  const OrderLifecyclePanel({
    super.key,
    required this.orderId,
    required this.itemTitle,
    required this.amountNzd,
    required this.isPaid,
    required this.isMeetupConfirmed,
    required this.isCompleted,
    this.scheduledAt,
    this.locationName,
    this.latitude,
    this.longitude,
    this.counterpartyName,
    this.statusLabel,
    this.itemImageUrl,
    this.actions,
    this.compact = false,
    this.showItemRow = true,
  });

  final String orderId;
  final String itemTitle;
  final String amountNzd;
  final bool isPaid;
  final bool isMeetupConfirmed;
  final bool isCompleted;
  final DateTime? scheduledAt;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? counterpartyName;
  final String? statusLabel;
  final String? itemImageUrl;
  final Widget? actions;
  final bool compact;
  final bool showItemRow;

  bool get _hasLocation =>
      locationName != null && locationName!.trim().isNotEmpty;
  bool get _hasCoordinates => latitude != null && longitude != null;

  String _dateLabel(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Future<void> _addToCalendar(BuildContext context) async {
    final start = scheduledAt;
    if (start == null) return;
    final end = start.add(const Duration(hours: 1));
    String stamp(DateTime value) {
      final utc = value.toUtc();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${utc.year}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
    }

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'KiwiShare meetup · $itemTitle',
      'dates': '${stamp(start)}/${stamp(end)}',
      'details': 'KiwiShare order #$orderId',
      if (_hasLocation) 'location': locationName!,
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open calendar.')));
    }
  }

  Widget _step(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool complete,
    required bool current,
  }) {
    final colors = Theme.of(context).colorScheme;
    final accent = complete || current ? colors.primary : colors.outline;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: compact ? 30 : 36,
            height: compact ? 30 : 36,
            decoration: BoxDecoration(
              color: complete
                  ? colors.primary
                  : current
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              complete ? Icons.check_rounded : icon,
              size: compact ? 16 : 19,
              color: complete
                  ? colors.onPrimary
                  : current
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: current || complete
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _connector(BuildContext context, bool complete) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: compact ? 18 : 30,
      height: 2,
      margin: EdgeInsets.only(bottom: compact ? 20 : 22),
      color: complete ? colors.primary : colors.outlineVariant,
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final meetupCurrent = isPaid && !isMeetupConfirmed && !isCompleted;
    final handoverCurrent = isPaid && isMeetupConfirmed && !isCompleted;

    return Column(
      key: const Key('order-lifecycle-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _step(
              context,
              icon: Icons.shopping_bag_outlined,
              label: 'Order',
              complete: true,
              current: false,
            ),
            _connector(context, true),
            _step(
              context,
              icon: Icons.payments_outlined,
              label: 'Payment',
              complete: isPaid,
              current: !isPaid && !isCompleted,
            ),
            _connector(context, isPaid),
            _step(
              context,
              icon: Icons.handshake_outlined,
              label: 'Meetup',
              complete: isMeetupConfirmed,
              current: meetupCurrent,
            ),
            _connector(context, isMeetupConfirmed),
            _step(
              context,
              icon: Icons.inventory_2_outlined,
              label: 'Handover',
              complete: isCompleted,
              current: handoverCurrent,
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              children: [
                _infoRow(
                  context,
                  icon: Icons.receipt_long_outlined,
                  label: 'Order',
                  value: '#$orderId',
                  trailing: IconButton(
                    key: const Key('order-copy-id'),
                    tooltip: 'Copy order ID',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: orderId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order ID copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ),
                if (showItemRow)
                  _infoRow(
                    context,
                    icon: Icons.sell_outlined,
                    label: 'Item',
                    value: itemTitle,
                  ),
                if (amountNzd.trim().isNotEmpty)
                  _infoRow(
                    context,
                    icon: Icons.payments_outlined,
                    label: 'Amount',
                    value: '\$$amountNzd NZD',
                  ),
                if (statusLabel != null && statusLabel!.trim().isNotEmpty)
                  _infoRow(
                    context,
                    icon: Icons.timeline_rounded,
                    label: 'Status',
                    value: statusLabel!,
                  ),
                if (counterpartyName != null &&
                    counterpartyName!.trim().isNotEmpty)
                  _infoRow(
                    context,
                    icon: Icons.person_outline_rounded,
                    label: 'With',
                    value: counterpartyName!,
                  ),
                if (scheduledAt != null)
                  _infoRow(
                    context,
                    icon: Icons.event_outlined,
                    label: 'When',
                    value: _dateLabel(context, scheduledAt!),
                    trailing: TextButton(
                      key: const Key('order-add-calendar'),
                      onPressed: () => _addToCalendar(context),
                      child: const Text('Add'),
                    ),
                  ),
              ],
            ),
          ),
          if (_hasLocation) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: Color(0xFF059669),
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meetup location',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                locationName!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('order-open-maps'),
                          onPressed: () =>
                              MapLauncherService.instance.showNavigationSheet(
                                context: context,
                                locationName: locationName!,
                                latitude: latitude,
                                longitude: longitude,
                              ),
                          icon: const Icon(Icons.near_me_rounded, size: 16),
                          label: const Text('Maps'),
                        ),
                      ],
                    ),
                  ),
                  if (_hasCoordinates)
                    ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: SizedBox(
                        key: const Key('order-meetup-map'),
                        width: double.infinity,
                        height: 190,
                        child: ClipRect(
                          child: IgnorePointer(
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(latitude!, longitude!),
                                zoom: 15.2,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('meetup'),
                                  position: LatLng(latitude!, longitude!),
                                ),
                              },
                              compassEnabled: false,
                              mapToolbarEnabled: false,
                              myLocationEnabled: false,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              liteModeEnabled: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (actions != null) ...[
            const SizedBox(height: AppSpacing.md),
            actions!,
          ],
        ],
      ],
    );
  }
}
