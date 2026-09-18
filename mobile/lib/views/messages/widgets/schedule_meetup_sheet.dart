import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/meetup_provider.dart';
import '../../../utils/campus_locations.dart';

class ScheduleMeetupSheet extends StatefulWidget {
  const ScheduleMeetupSheet({
    super.key,
    required this.itemId,
    this.itemTitle,
    this.conversationId,
    this.counterpartId,
    this.counterpartName,
    this.onMeetupScheduled,
    this.onProposed,
  });

  final String itemId;
  final String? itemTitle;
  final String? conversationId;
  final String? counterpartId;
  final String? counterpartName;
  final VoidCallback? onMeetupScheduled;
  final ValueChanged<dynamic>? onProposed;

  @override
  State<ScheduleMeetupSheet> createState() => _ScheduleMeetupSheetState();
}

class _ScheduleMeetupSheetState extends State<ScheduleMeetupSheet> {
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  final TextEditingController _locationController = TextEditingController(
    text: 'UoA Student Hub (Alfred Nathan House)',
  );
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _locationSuggestions = [
    'UoA Student Hub (Alfred Nathan House)',
    'UoA General Library (5 Alfred St)',
    'UoA Engineering Quad',
    'Britomart Transport Centre',
    'Newmarket Westfield (Broadway)',
  ];

  @override
  void dispose() {
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitProposal() async {
    final location = _locationController.text.trim();
    if (location.isEmpty) {
      setState(
        () => _errorMessage = 'Please enter or select a meetup location.',
      );
      return;
    }

    final scheduled = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'Please sign in to schedule a meetup.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final meetupProvider = context.read<MeetupProvider>();
      final proposed = await meetupProvider.proposeMeetup(
        itemId: widget.itemId,
        conversationId: widget.conversationId,
        scheduledAt: scheduled,
        locationName: location,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        token: token,
      );

      if (mounted) {
        Navigator.pop(context, true);
        widget.onMeetupScheduled?.call();
        widget.onProposed?.call(proposed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final formattedDate =
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    final formattedTime = _selectedTime.format(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    color: colors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Schedule In-Person Meetup',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (widget.itemTitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.itemTitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),

              // Date & Time pickers
              Text(
                'When to meet',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(formattedDate),
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(formattedTime),
                      onPressed: _pickTime,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Meetup location
              Text(
                'Meetup Location',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _locationController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return CampusLocations.search(textEditingValue.text);
                },
                onSelected: (String selection) {
                  setState(() => _locationController.text = selection);
                },
                fieldViewBuilder:
                    (
                      BuildContext context,
                      TextEditingController fieldTextEditingController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      fieldTextEditingController.addListener(() {
                        _locationController.text =
                            fieldTextEditingController.text;
                      });
                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. UoA General Library, Newmarket Westfield',
                          prefixIcon: const Icon(Icons.place_outlined),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest.withOpacity(
                            0.5,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      );
                    },
              ),
              const SizedBox(height: 8),

              // Suggestion chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _locationSuggestions.map((suggestion) {
                  final isSelected = _locationController.text == suggestion;
                  return ChoiceChip(
                    label: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _locationController.text = suggestion);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Optional note
              Text(
                'Note for other party (optional)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. I will be wearing a black backpack',
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: colors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitProposal,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Proposing...' : 'Send Meetup Proposal',
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
