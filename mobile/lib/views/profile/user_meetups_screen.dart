import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/meetup_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meetup_provider.dart';
import '../../theme/app_theme.dart';

class UserMeetupsScreen extends StatefulWidget {
  const UserMeetupsScreen({super.key});

  @override
  State<UserMeetupsScreen> createState() => _UserMeetupsScreenState();
}

class _UserMeetupsScreenState extends State<UserMeetupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeetups());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMeetups() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null || token.isEmpty) return;
    await context.read<MeetupProvider>().loadMyMeetups(token);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final provider = context.watch<MeetupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetups & QR Codes'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurfaceVariant,
          indicatorColor: colors.primary,
          tabs: [
            Tab(
              text: 'Upcoming (${provider.upcomingMeetups.length})',
            ),
            Tab(
              text: 'Past (${provider.pastMeetups.length})',
            ),
          ],
        ),
      ),
      body: provider.isLoading && provider.meetups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _MeetupList(
                  key: const Key('upcoming_meetups_list'),
                  meetups: provider.upcomingMeetups,
                  emptyMessage: 'No upcoming meetups scheduled.',
                  onRefresh: _loadMeetups,
                ),
                _MeetupList(
                  key: const Key('past_meetups_list'),
                  meetups: provider.pastMeetups,
                  emptyMessage: 'No past meetups found.',
                  onRefresh: _loadMeetups,
                ),
              ],
            ),
    );
  }
}

class _MeetupList extends StatelessWidget {
  const _MeetupList({
    super.key,
    required this.meetups,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final List<MeetupModel> meetups;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (meetups.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 48,
                    color: colors.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: meetups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final meetup = meetups[index];
          return _MeetupItemCard(meetup: meetup);
        },
      ),
    );
  }
}

class _MeetupItemCard extends StatelessWidget {
  const _MeetupItemCard({required this.meetup});

  final MeetupModel meetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final date = meetup.scheduledAt.toLocal();
    final formattedDate =
        '${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final isConfirmed = meetup.isConfirmed;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: isConfirmed
              ? (isDark ? const Color(0xFF059669) : const Color(0xFF10B981))
              : colors.outline.withOpacity(0.18),
          width: isConfirmed ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: () => context.push('/meetups/${meetup.id}/qr', extra: meetup),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: meetup.itemImageUrl.isNotEmpty
                        ? Image.network(
                            meetup.itemImageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 56,
                              height: 56,
                              color: colors.surfaceContainerHighest,
                              child: const Icon(Icons.inventory_2_outlined),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: colors.surfaceContainerHighest,
                            child: const Icon(Icons.inventory_2_outlined),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: meetup.isBuying
                                    ? colors.primaryContainer
                                    : colors.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                meetup.isBuying ? 'Buying' : 'Selling',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: meetup.isBuying
                                      ? colors.onPrimaryContainer
                                      : colors.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isConfirmed
                                    ? (isDark
                                        ? const Color(0xFF064E3B).withOpacity(0.5)
                                        : const Color(0xFFD1FAE5))
                                    : colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isConfirmed
                                    ? 'Confirmed'
                                    : meetup.isProposed
                                        ? 'Pending'
                                        : 'Ended',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isConfirmed
                                      ? (isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF047857))
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meetup.itemTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '\$${meetup.itemPriceNzd} NZD',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.event, size: 13, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 13,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      meetup.locationName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => context.push(
                      '/meetups/${meetup.id}/qr',
                      extra: meetup,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'QR Code',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
