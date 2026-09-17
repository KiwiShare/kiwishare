import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_history_entry.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/report_repository.dart';
import '../../theme/app_theme.dart';

typedef ReportHistoryLoader = Future<List<ReportHistoryEntry>> Function();

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, this.loadReports});

  final ReportHistoryLoader? loadReports;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<ReportHistoryEntry>? _reports;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadReports);
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    final auth = widget.loadReports == null
        ? context.read<AuthProvider>()
        : null;
    final token = auth?.jwtToken;

    try {
      final reports = widget.loadReports != null
          ? await widget.loadReports!()
          : token == null
          ? throw const ReportAuthenticationException()
          : await ReportRepository().fetchHistory(token: token);
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } on ReportAuthenticationException catch (error) {
      if (auth != null && auth.jwtToken == token) {
        await auth.clearSession();
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    } on ReportRepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'We could not load your reports. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(
        child: Semantics(
          label: 'Loading your reports',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage case final message?) {
      return _ReportHistoryState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load reports',
        message: message,
        action: FilledButton.icon(
          key: const Key('retry-report-history'),
          onPressed: _loadReports,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
        onRefresh: _loadReports,
      );
    }

    final reports = _reports ?? const <ReportHistoryEntry>[];
    if (reports.isEmpty) {
      return _ReportHistoryState(
        icon: Icons.shield_outlined,
        title: 'No reports yet',
        message:
            'Reports you submit to KiwiShare will appear here with their review status.',
        onRefresh: _loadReports,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.separated(
        key: const Key('report-history-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: reports.length + 1,
        separatorBuilder: (_, index) =>
            SizedBox(height: index == 0 ? AppSpacing.lg : AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) return const _ReportPrivacyNotice();
          return _ReportHistoryCard(report: reports[index - 1]);
        },
      ),
    );
  }
}

class _ReportPrivacyNotice extends StatelessWidget {
  const _ReportPrivacyNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: colors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Your reports stay confidential. Status updates show review progress, not actions taken against another member.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHistoryCard extends StatelessWidget {
  const _ReportHistoryCard({required this.report});

  final ReportHistoryEntry report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = _statusColor(context, report.status);

    return Semantics(
      container: true,
      label:
          '${report.typeLabel}. ${report.reasonLabel}. ${report.statusLabel}. Submitted ${_formatDate(report.createdAt)}.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline.withValues(alpha: 0.42)),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LabelChip(
                    icon: _typeIcon(report.targetType),
                    label: report.typeLabel,
                    foreground: colors.primary,
                    background: colors.primaryContainer.withValues(alpha: 0.5),
                  ),
                  _LabelChip(
                    icon: _statusIcon(report.status),
                    label: report.statusLabel,
                    foreground: statusColor,
                    background: statusColor.withValues(alpha: 0.1),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                report.reasonLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(report.details, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Divider(height: 1, color: colors.outline.withValues(alpha: 0.25)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: [
                  _Metadata(
                    icon: Icons.calendar_today_outlined,
                    label: 'Submitted ${_formatDate(report.createdAt)}',
                  ),
                  _Metadata(
                    icon: Icons.schedule_outlined,
                    label: report.statusDescription,
                  ),
                  _Metadata(
                    icon: Icons.tag_rounded,
                    label: 'Reference ${report.shortReference}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(String targetType) => switch (targetType) {
    'listing' => Icons.inventory_2_outlined,
    'user' => Icons.person_outline_rounded,
    _ => Icons.health_and_safety_outlined,
  };

  static IconData _statusIcon(String status) => switch (status) {
    'reviewed' => Icons.task_alt_rounded,
    'dismissed' => Icons.check_circle_outline_rounded,
    _ => Icons.hourglass_top_rounded,
  };

  static Color _statusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    if (status == 'reviewed') return theme.colorScheme.primary;
    if (status == 'dismissed') return theme.colorScheme.onSurfaceVariant;
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.primary
        : AppColors.warning;
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ReportHistoryState extends StatelessWidget {
  const _ReportHistoryState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRefresh,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onRefresh;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 32, color: colors.primary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (action case final action?) ...[
                      const SizedBox(height: AppSpacing.lg),
                      action,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
