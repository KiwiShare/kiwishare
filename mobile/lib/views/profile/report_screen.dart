import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/report_repository.dart';

import '../../models/report_draft.dart';
import '../../theme/app_theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    this.reportContext = const ReportContext.general(),
    this.onSubmit,
  });

  final ReportContext reportContext;
  final ReportSubmitter? onSubmit;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _submitting = false;
  String? _submissionError;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _submissionError = null;
    });

    final draft = ReportDraft(
      context: widget.reportContext,
      reason: _reason!,
      details: _details.text,
    );

    try {
      if (widget.onSubmit case final submit?) {
        await submit(draft);
      } else {
        final token = context.read<AuthProvider>().jwtToken;
        if (token == null) throw StateError('Please sign in to report.');
        await ReportRepository().submit(draft, token: token);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submissionError =
            'We could not submit your report. Check your connection and try again.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Report submitted'),
        content: const Text(
          'Thanks for helping keep KiwiShare safe. We’ll review your report.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String get _screenTitle => switch (widget.reportContext.contextType) {
    ReportContextType.chat => 'Report user',
    ReportContextType.transaction => 'Report a trade concern',
    ReportContextType.listing => 'Report listing',
    _ => 'Report a safety issue',
  };

  @override
  Widget build(BuildContext context) {
    final reasons = ReportReasonCatalog.forContext(widget.reportContext);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _SafetyNotice(color: colors.primaryContainer),
              if (!widget.reportContext.isGeneral) ...[
                const SizedBox(height: AppSpacing.xl),
                _ReportTargetCard(reportContext: widget.reportContext),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Choose a reason',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<ReportReason>(
                key: const Key('report_reason_field'),
                initialValue: _reason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  prefixIcon: Icon(Icons.report_outlined),
                ),
                items: reasons
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(
                          reason.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (_) => reasons
                    .map(
                      (reason) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          reason.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _reason = value),
                validator: (value) => value == null ? 'Choose a reason.' : null,
              ),
              if (_reason case final reason?) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(reason.icon, size: 20, color: colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        reason.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Tell us what happened',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('report_details_field'),
                controller: _details,
                enabled: !_submitting,
                minLines: 5,
                maxLines: 8,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText:
                      'Describe what happened and include useful dates or messages.',
                  helperText:
                      'Do not include passwords, payment details or private addresses.',
                  helperMaxLines: 2,
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Enter at least 10 characters.'
                    : null,
              ),
              if (_submissionError case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                _SubmissionError(message: error),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const Key('submit_report_button'),
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shield_outlined),
                label: Text(_submitting ? 'Submitting…' : 'Submit report'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                label:
                    'Emergency advice. If anyone is in immediate danger, call 111.',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.emergency_outlined,
                      size: 20,
                      color: colors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'If anyone is in immediate danger, call 111. KiwiShare reporting is not an emergency service.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.large),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.privacy_tip_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Text(
            'Your report is confidential. Choose the closest reason and share only details that help us review the concern.',
          ),
        ),
      ],
    ),
  );
}

class _ReportTargetCard extends StatelessWidget {
  const _ReportTargetCard({required this.reportContext});

  final ReportContext reportContext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final targetIcon = switch (reportContext.targetType) {
      ReportTargetType.listing => Icons.inventory_2_outlined,
      ReportTargetType.user => Icons.person_outline,
      ReportTargetType.general => Icons.shield_outlined,
    };
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              child: Icon(targetIcon),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're reporting",
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    reportContext.targetLabel ?? 'Safety concern',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (reportContext.contextLabel case final contextLabel?)
                    Text(
                      contextLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.lock_outline, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _SubmissionError extends StatelessWidget {
  const _SubmissionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
