import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../repositories/user_repository.dart';

class ReviewBottomSheet extends StatefulWidget {
  final String targetUserId;
  final String targetName;
  final String? targetAvatarUrl;
  final String? orderId;
  final String? itemId;
  final String? itemTitle;
  final String? itemImageUrl;
  final String role; // 'seller' or 'buyer' (the role of the TARGET user)
  final VoidCallback? onReviewSubmitted;

  const ReviewBottomSheet({
    super.key,
    required this.targetUserId,
    required this.targetName,
    this.targetAvatarUrl,
    this.orderId,
    this.itemId,
    this.itemTitle,
    this.itemImageUrl,
    this.role = 'seller',
    this.onReviewSubmitted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String targetUserId,
    required String targetName,
    String? targetAvatarUrl,
    String? orderId,
    String? itemId,
    String? itemTitle,
    String? itemImageUrl,
    String role = 'seller',
    VoidCallback? onReviewSubmitted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReviewBottomSheet(
        targetUserId: targetUserId,
        targetName: targetName,
        targetAvatarUrl: targetAvatarUrl,
        orderId: orderId,
        itemId: itemId,
        itemTitle: itemTitle,
        itemImageUrl: itemImageUrl,
        role: role,
        onReviewSubmitted: onReviewSubmitted,
      ),
    );
  }

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  List<String> get _availableTags {
    if (widget.role == 'seller') {
      return const [
        'Punctual',
        'Item as described',
        'Fast response',
        'Friendly',
        'Great packaging',
        'Fair price',
      ];
    } else {
      return const [
        'Punctual',
        'Friendly',
        'Prompt payment',
        'Smooth meetup',
        'Great communication',
        'Polite',
      ];
    }
  }

  String get _ratingLabel {
    switch (_rating) {
      case 5:
        return 'Outstanding! Highly recommended';
      case 4:
        return 'Very good, smooth transaction';
      case 3:
        return 'Average experience';
      case 2:
        return 'Could be better';
      case 1:
        return 'Disappointing';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      setState(() => _errorMessage = 'Please write a brief comment.');
      return;
    }

    final auth = context.read<AuthProvider?>();
    final token = auth?.jwtToken;
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'Please sign in to submit a review.');
      return;
    }

    UserRepository? repo;
    try {
      repo = context.read<UserRepository>();
    } catch (_) {
      repo = auth?.userRepository;
    }

    if (repo == null) {
      setState(() => _errorMessage = 'Unable to connect to review service.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await repo.submitReview(
        targetUserId: widget.targetUserId,
        rating: _rating,
        comment: comment,
        tags: _selectedTags.toList(),
        orderId: widget.orderId,
        itemId: widget.itemId,
        role: widget.role,
        itemTitle: widget.itemTitle,
        itemImageUrl: widget.itemImageUrl,
        token: token,
      );

      if (!mounted) return;
      widget.onReviewSubmitted?.call();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content: Text(
            'Review submitted! It is now visible on their profile.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      widget.targetAvatarUrl != null &&
                          widget.targetAvatarUrl!.isNotEmpty
                      ? NetworkImage(widget.targetAvatarUrl!)
                      : null,
                  child:
                      widget.targetAvatarUrl == null ||
                          widget.targetAvatarUrl!.isEmpty
                      ? Text(
                          widget.targetName.isNotEmpty
                              ? widget.targetName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate & Review ${widget.targetName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.itemTitle != null &&
                          widget.itemTitle!.isNotEmpty)
                        Text(
                          'For: ${widget.itemTitle}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      final isSelected = starNum <= _rating;
                      return IconButton(
                        iconSize: 36,
                        splashRadius: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: Icon(
                          isSelected
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isSelected
                              ? const Color(0xFFF59E0B)
                              : Colors.grey.shade400,
                        ),
                        onPressed: () => setState(() => _rating = starNum),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ratingLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Highlights (tap to select)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                  selectedColor: const Color(0xFF059669),
                  checkmarkColor: Colors.white,
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText:
                    'Share details of your experience (e.g. communication, item condition, punctuality)...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF059669),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
