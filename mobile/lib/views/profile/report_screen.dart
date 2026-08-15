import 'package:flutter/material.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  String? _reason;
  bool _submitting = false;

  static const _reasons = <String>[
    'Scam or fraud',
    'Harassment or abusive behaviour',
    'Unsafe meetup behaviour',
    'Fake account or identity',
    'Suspicious listing',
    'Other',
  ];

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    // Repository/API integration is intentionally pending team approval of
    // the report contract documented in docs/reporting-feature-proposal.md.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _submitting = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report a safety issue')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Reports are confidential. Choose the closest reason and include details that can help us review it.',
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _reason,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              border: OutlineInputBorder(),
            ),
            items: _reasons
                .map(
                  (reason) =>
                      DropdownMenuItem(value: reason, child: Text(reason)),
                )
                .toList(),
            onChanged: (value) => setState(() => _reason = value),
            validator: (value) => value == null ? 'Choose a reason.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _details,
            minLines: 5,
            maxLines: 8,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Details',
              hintText: 'Tell us who or what was involved and what happened.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'Enter at least 10 characters.'
                : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit report'),
          ),
          const SizedBox(height: 16),
          Text(
            'If anyone is in immediate danger, call 111. KiwiShare reporting is not an emergency service.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
