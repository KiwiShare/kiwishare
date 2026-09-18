import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../models/chat_conversation_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/item_model.dart';
import '../../models/report_draft.dart';
import '../../config/api_config.dart';
import '../../navigation/app_route_observer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../repositories/item_repository.dart';
import '../../services/listing_image_picker.dart';
import '../../services/chat_voice_service.dart';
import '../../services/notification_permission_coordinator.dart';
import '../../theme/app_theme.dart';
import '../products/product_detail_screen.dart';
import '../profile/report_screen.dart';
import 'widgets/location_bubble.dart';
import 'widgets/location_picker_sheet.dart';
import 'widgets/meetup_card_bubble.dart';
import 'widgets/schedule_meetup_sheet.dart';

enum _ChatConversationAction { reportUser }

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversation,
    this.chatProvider,
    this.authToken,
    this.imagePicker,
    this.voiceRecorder,
    this.permissionCoordinator,
    this.enablePolling = false,
    this.pollingInterval,
  });

  final ChatConversationModel conversation;
  final ChatProvider? chatProvider;
  final String? authToken;
  final ListingImagePicker? imagePicker;
  final ChatVoiceRecorder? voiceRecorder;
  final NotificationPermissionCoordinator? permissionCoordinator;
  final bool? enablePolling;
  final Duration? pollingInterval;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver, RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  late final ListingImagePicker _imagePicker;
  late final ChatVoiceRecorder _voiceRecorder;
  Timer? _recordingTimer;
  Timer? _conversationPollTimer;
  Timer? _focusScrollTimer;
  bool _isRecording = false;
  bool _isStartingVoice = false;
  bool _isFinalizingVoice = false;
  Future<void> _recorderQueue = Future<void>.value();
  int _recordingSeconds = 0;
  String? _loadedToken;
  String? _currentAuthToken;
  bool _leftForeground = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  ModalRoute<dynamic>? _subscribedRoute;
  final Object _visibilityOwner = Object();
  ItemModel? _activeItem;

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(_handleFocusChange);
    _imagePicker = widget.imagePicker ?? DeviceListingImagePicker();
    _voiceRecorder = widget.voiceRecorder ?? DeviceChatVoiceRecorder();
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverLostPhoto();
      _loadItemDetails();
    });
  }

  void _handleFocusChange() {
    if (_messageFocusNode.hasFocus) {
      _focusScrollTimer?.cancel();
      _focusScrollTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) _scrollToEnd();
      });
    }
  }

  void _startConversationPolling() {
    _conversationPollTimer?.cancel();
    if (!(widget.enablePolling ?? false) ||
        !_isCurrentRoute ||
        _lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final interval = widget.pollingInterval ?? const Duration(seconds: 3);
    _conversationPollTimer = Timer.periodic(interval, (_) async {
      if (!mounted ||
          !_isCurrentRoute ||
          _lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final token = _currentAuthToken;
      if (token == null ||
          token.isEmpty ||
          _chatProvider.isLoadingMessages(widget.conversation.id)) {
        return;
      }
      final previousCount = _chatProvider
          .messagesFor(widget.conversation.id)
          .length;
      await _chatProvider.loadMessages(
        conversation: widget.conversation,
        token: token,
        queueIfBusy: true,
        shouldMarkRead: () => _isCurrentRoute,
      );
      if (!mounted) return;
      final currentCount = _chatProvider
          .messagesFor(widget.conversation.id)
          .length;
      if (currentCount > previousCount) {
        _scrollToEnd();
      }
    });
  }

  void _stopConversationPolling() {
    _conversationPollTimer?.cancel();
    _conversationPollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncVisibility();
    if (state != AppLifecycleState.resumed) {
      _leftForeground = true;
      _stopConversationPolling();
      return;
    }
    if (!_leftForeground) return;
    _leftForeground = false;
    unawaited(_refreshAfterResume());
    _startConversationPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<dynamic>(context);
    if (identical(route, _subscribedRoute)) return;
    appRouteObserver.unsubscribe(this);
    _subscribedRoute = route;
    if (route != null) appRouteObserver.subscribe(this, route);
    _syncVisibility();
  }

  @override
  void didPushNext() {
    _syncVisibility();
    _stopConversationPolling();
  }

  @override
  void didPopNext() {
    _syncVisibility();
    unawaited(_refreshAfterResume());
    _startConversationPolling();
  }

  Future<void> _refreshAfterResume() async {
    final token = _currentAuthToken;
    if (!_isCurrentRoute || token == null || token.isEmpty) return;
    await _chatProvider.loadMessages(
      conversation: widget.conversation,
      token: token,
      queueIfBusy: true,
      shouldMarkRead: () => _isCurrentRoute,
    );
    if (mounted) _scrollToEnd();
  }

  bool get _isCurrentRoute =>
      mounted &&
      _lifecycleState == AppLifecycleState.resumed &&
      (ModalRoute.of<dynamic>(context)?.isCurrent ?? false);

  void _syncVisibility() {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) {
      chatVisibilityTracker.clear(_visibilityOwner);
      return;
    }
    chatVisibilityTracker.update(
      owner: _visibilityOwner,
      conversationId: widget.conversation.id,
      sessionToken: token,
      visible: _isCurrentRoute,
    );
  }

  ChatProvider get _chatProvider =>
      widget.chatProvider ?? context.read<ChatProvider>();
  void _ensureLoaded(String? token) {
    _currentAuthToken = token;
    _syncVisibility();
    if (token == null || token.isEmpty) {
      _loadedToken = null;
      _stopConversationPolling();
      return;
    }
    if (token != _loadedToken) {
      _loadedToken = token;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _chatProvider.loadMessages(
          conversation: widget.conversation,
          token: token,
          shouldMarkRead: () => _isCurrentRoute,
        );
        _scrollToEnd();
        _startConversationPolling();
      });
    }
  }

  @override
  void dispose() {
    _focusScrollTimer?.cancel();
    _stopConversationPolling();
    _messageFocusNode.removeListener(_handleFocusChange);
    _messageFocusNode.dispose();
    chatVisibilityTracker.clear(_visibilityOwner);
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    if (_isRecording || _isStartingVoice) {
      unawaited(_queueRecorder(_voiceRecorder.cancel));
    }
    unawaited(_queueRecorder(_voiceRecorder.dispose));
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<T> _queueRecorder<T>(Future<T> Function() operation) {
    final result = _recorderQueue.then((_) => operation());
    _recorderQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> _retry() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    await _chatProvider.loadMessages(
      conversation: widget.conversation,
      token: token,
      shouldMarkRead: () => _isCurrentRoute,
    );
    _scrollToEnd();
  }

  Future<void> _retryMarkRead() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    await _chatProvider.markConversationRead(
      conversation: widget.conversation,
      token: token,
      shouldMarkRead: () => _isCurrentRoute,
    );
  }

  Future<void> _offerNotificationPermissionAfterAction() async {
    if (!mounted) return;
    await offerContextualNotificationPermission(
      context,
      coordinator: widget.permissionCoordinator,
    );
  }

  void _requestNotificationPermissionAfterAction() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_offerNotificationPermissionAfterAction());
    });
  }

  Future<void> _send() async {
    final token = _currentAuthToken;
    final text = _messageController.text;
    if (token == null || token.isEmpty || text.trim().isEmpty) return;
    final sent = await _chatProvider.sendText(
      conversation: widget.conversation,
      text: text,
      token: token,
    );
    if (!mounted) return;
    if (sent) {
      _messageController.clear();
      _scrollToEnd();
      _requestNotificationPermissionAfterAction();
    }
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<_ChatPhotoSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => const _ChatPhotoSourceSheet(),
    );
    if (source == null || !mounted) return;

    try {
      final XFile? file;
      if (source == _ChatPhotoSource.camera) {
        file = await _imagePicker.takePhoto();
      } else {
        final files = await _imagePicker.chooseFromGallery(limit: 1);
        file = files.isEmpty ? null : files.first;
      }
      if (file == null || !mounted) return;
      await _sendPhoto(file);
    } on PlatformException {
      _showPhotoPickerError(
        'Camera or photo access is unavailable. Check the app permissions and try again.',
      );
    } catch (_) {
      _showPhotoPickerError(
        'That photo could not be opened. Please try again.',
      );
    }
  }

  Future<void> _recoverLostPhoto() async {
    try {
      final files = await _imagePicker.recoverLostPhotos();
      if (files.isEmpty || !mounted) return;
      await _sendPhoto(files.first, offerPermission: false);
    } on PlatformException {
      _showPhotoPickerError(
        'The selected photo could not be restored. Please choose it again.',
      );
    } catch (_) {
      _showPhotoPickerError(
        'The selected photo could not be restored. Please choose it again.',
      );
    }
  }

  Future<void> _sendPhoto(XFile file, {bool offerPermission = true}) async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty || !mounted) return;
    final contentType = _photoContentType(file);
    final sent = await _chatProvider.sendPhoto(
      conversation: widget.conversation,
      bytes: await file.readAsBytes(),
      fileName: file.name.isEmpty
          ? 'chat_photo_${DateTime.now().millisecondsSinceEpoch}.${_photoExtension(contentType)}'
          : file.name,
      contentType: contentType,
      token: token,
    );
    if (sent && mounted) {
      _scrollToEnd();
      if (offerPermission) _requestNotificationPermissionAfterAction();
    }
  }

  Future<void> _shareLocation() async {
    final selection = await showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const LocationPickerSheet(),
    );
    if (selection == null || !mounted) return;
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;

    final sent = await _chatProvider.sendLocation(
      conversation: widget.conversation,
      name: selection.name,
      latitude: selection.latitude,
      longitude: selection.longitude,
      token: token,
    );
    if (sent && mounted) {
      _scrollToEnd();
      _requestNotificationPermissionAfterAction();
    }
  }

  Future<void> _scheduleMeetup() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ScheduleMeetupSheet(
        itemId: widget.conversation.itemId,
        itemTitle: widget.conversation.itemTitle,
        counterpartId: widget.conversation.participantId,
        counterpartName: widget.conversation.participantName,
        onProposed: (meetup) {
          if (mounted && token.isNotEmpty) {
            _chatProvider.loadMessages(
              conversation: widget.conversation,
              token: token,
              shouldMarkRead: () => _isCurrentRoute,
            );
            _scrollToEnd();
          }
        },
      ),
    );
  }

  Future<void> _loadItemDetails() async {
    if (widget.conversation.itemId.isEmpty) return;
    try {
      final item = await RestItemRepository().fetchItemById(
        widget.conversation.itemId,
      );
      if (mounted && item != null) {
        setState(() {
          _activeItem = item;
        });
      }
    } catch (_) {}
  }

  Future<void> _buyerBuyNow() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    final item = _activeItem;
    final priceStr = item?.isFree == true || item?.priceNzd == '0'
        ? 'FREE'
        : '\$${item?.priceNzd ?? "0"} NZD';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm Purchase Intent',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Item: ${item?.title ?? widget.conversation.itemTitle}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Price: $priceStr',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will notify the seller that you intend to purchase and pick up this item.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Send Intent'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      await _chatProvider.sendText(
        conversation: widget.conversation,
        text:
            '💳 I want to purchase this item ($priceStr). When would be convenient to meet or pick up?',
        token: token,
      );
      _scrollToEnd();
      _requestNotificationPermissionAfterAction();
    }
  }

  Future<void> _sellerModifyPrice() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    final currentPrice = _activeItem?.priceNzd ?? '';
    final controller = TextEditingController(text: currentPrice);
    bool isFree = currentPrice == '0';

    final newPrice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Adjust Price',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Update the listing price. The buyer will see the updated price.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: !isFree,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: isFree ? 'Free Item' : 'New Price (NZD)',
                          prefixText: isFree ? '' : '\$ ',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Free'),
                      selected: isFree,
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green.shade800,
                      onSelected: (val) {
                        setModalState(() {
                          isFree = val;
                          if (val) controller.text = '0';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      final val = isFree ? '0' : controller.text.trim();
                      if (val.isEmpty) return;
                      Navigator.of(context).pop(val);
                    },
                    child: const Text('Confirm Price Update'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (newPrice != null && mounted) {
      try {
        final updated = await RestItemRepository().updateItem(
          id: widget.conversation.itemId,
          token: token,
          updates: {'priceNzd': newPrice},
        );
        setState(() => _activeItem = updated);
        final priceLabel = newPrice == '0' ? 'FREE' : '\$$newPrice NZD';
        await _chatProvider.sendText(
          conversation: widget.conversation,
          text: '🏷️ [Seller Action] Price updated to $priceLabel',
          token: token,
        );
        _scrollToEnd();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Price updated to $priceLabel')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update price: $e')));
      }
    }
  }

  Future<void> _sellerChangeStatus() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change Item Status',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: const Text('Active (Available)'),
                subtitle: const Text('Item is available for other buyers'),
                onTap: () => Navigator.of(context).pop('active'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline,
                  color: Colors.amber,
                ),
                title: const Text('Reserved'),
                subtitle: const Text('Holding for this buyer'),
                onTap: () => Navigator.of(context).pop('reserved'),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.grey),
                title: const Text('Sold'),
                subtitle: const Text('Transaction completed'),
                onTap: () => Navigator.of(context).pop('sold'),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      try {
        final updated = await RestItemRepository().updateItem(
          id: widget.conversation.itemId,
          token: token,
          updates: {'status': selected},
        );
        setState(() => _activeItem = updated);
        final statusLabel = selected == 'active'
            ? 'Active'
            : selected == 'reserved'
            ? 'Reserved'
            : 'Sold';
        await _chatProvider.sendText(
          conversation: widget.conversation,
          text: '📦 [Seller Action] Item status updated to $statusLabel',
          token: token,
        );
        _scrollToEnd();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $statusLabel')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<void> _sendQuickMessage(String text) async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    await _chatProvider.sendText(
      conversation: widget.conversation,
      text: text,
      token: token,
    );
    _scrollToEnd();
    _requestNotificationPermissionAfterAction();
  }

  Widget _buildXianyuProductHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final title = _activeItem?.title ?? widget.conversation.itemTitle;
    final imageUrl = _activeItem?.imageUrl ?? widget.conversation.itemImageUrl;
    final isFree =
        _activeItem?.isFree == true ||
        _activeItem?.priceNzd == '0' ||
        (_activeItem?.priceNzd != null &&
            double.tryParse(_activeItem!.priceNzd) == 0);
    final priceText = isFree
        ? 'FREE'
        : _activeItem != null
        ? '\$${_activeItem!.priceNzd}'
        : '';

    final status = _activeItem?.status ?? ItemStatus.active;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceContainerHighest.withOpacity(0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? colors.outline.withOpacity(0.2)
              : colors.outline.withOpacity(0.12),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    itemId: widget.conversation.itemId,
                    item: _activeItem,
                  ),
                ),
              )
              .then((_) => _loadItemDetails());
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colors.surfaceContainerHighest,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isFree)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else if (priceText.isNotEmpty)
                        Text(
                          priceText,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (status != ItemStatus.active) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: status == ItemStatus.reserved
                                ? Colors.amber.shade800
                                : Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status == ItemStatus.reserved ? 'RESERVED' : 'SOLD',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: colors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXianyuActionStrip(BuildContext context) {
    final isBuyer = widget.conversation.direction == ChatDirection.buying;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final quickChips = isBuyer
        ? const [
            'Is it available?',
            'Is price negotiable?',
            'When can I pick up?',
            'Any more photos?',
          ]
        : const [
            'Yes, available for pickup',
            'Price is firm',
            'When are you free to meet?',
            'Item in great condition',
          ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surface : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark
                ? colors.outline.withOpacity(0.15)
                : colors.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                if (isBuyer) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: colors.primary.withOpacity(0.5),
                        ),
                      ),
                      onPressed: _scheduleMeetup,
                      icon: const Icon(Icons.location_on_outlined, size: 16),
                      label: const Text(
                        'Meetup Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _buyerBuyNow,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: const Text(
                        'Buy Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: colors.primary.withOpacity(0.5),
                        ),
                      ),
                      onPressed: _sellerModifyPrice,
                      icon: const Icon(Icons.price_change_outlined, size: 16),
                      label: const Text(
                        'Edit Price',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: colors.primary.withOpacity(0.5),
                        ),
                      ),
                      onPressed: _scheduleMeetup,
                      icon: const Icon(Icons.handshake_outlined, size: 16),
                      label: const Text(
                        'Propose Meetup',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _sellerChangeStatus,
                      icon: const Icon(Icons.sell_outlined, size: 16),
                      label: const Text(
                        'Item Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: quickChips.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final chipText = quickChips[index];
                return ActionChip(
                  label: Text(
                    chipText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? colors.onSurface
                          : const Color(0xFF334155),
                    ),
                  ),
                  backgroundColor: isDark
                      ? colors.surfaceContainerHighest.withOpacity(0.5)
                      : const Color(0xFFEDF2F7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => _sendQuickMessage(chipText),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _reportUser() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReportScreen(
          reportContext: ReportContext(
            targetType: ReportTargetType.user,
            targetId: widget.conversation.participantId,
            targetLabel: widget.conversation.participantName,
            contextType: ReportContextType.chat,
            contextId: widget.conversation.id,
            contextLabel: 'Chat about ${widget.conversation.itemTitle}',
          ),
        ),
      ),
    );
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording ||
        _isStartingVoice ||
        _isFinalizingVoice ||
        _chatProvider.isSending(widget.conversation.id)) {
      return;
    }
    setState(() => _isStartingVoice = true);
    try {
      await _queueRecorder(_voiceRecorder.start);
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }
        setState(() => _recordingSeconds += 1);
        // Keep one second of headroom so timer scheduling jitter cannot push
        // the native recording beyond the server's hard 60-second limit.
        if (_recordingSeconds >= 59) {
          timer.cancel();
          unawaited(_finishVoiceRecording(send: true));
        }
      });
    } on ChatVoiceException catch (error) {
      _showComposerError(error.message);
    } on PlatformException {
      _showComposerError(
        'Microphone access is unavailable. Check the app permissions and try again.',
      );
    } catch (_) {
      _showComposerError(
        'Voice recording could not be started. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isStartingVoice = false);
    }
  }

  Future<void> _finishVoiceRecording({required bool send}) async {
    if (!_isRecording || _isFinalizingVoice) return;
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isFinalizingVoice = true;
    });

    try {
      if (!send) {
        await _queueRecorder(_voiceRecorder.cancel);
        return;
      }
      final recording = await _queueRecorder(_voiceRecorder.stop);
      final token = _currentAuthToken;
      if (recording == null || token == null || token.isEmpty || !mounted) {
        return;
      }
      final sent = await _chatProvider.sendVoice(
        conversation: widget.conversation,
        bytes: recording.bytes,
        fileName: recording.fileName,
        contentType: recording.contentType,
        durationMs: recording.durationMs,
        token: token,
      );
      if (sent && mounted) {
        _scrollToEnd();
        _requestNotificationPermissionAfterAction();
      }
    } on ChatVoiceException catch (error) {
      _showComposerError(error.message);
    } catch (_) {
      _showComposerError(
        'The voice message could not be prepared. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFinalizingVoice = false;
          _recordingSeconds = 0;
        });
      }
    }
  }

  void _showPhotoPickerError(String message) {
    _showComposerError(message);
  }

  void _showComposerError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _chatProvider;
    final token = widget.authToken ?? context.watch<AuthProvider?>()?.jwtToken;
    _ensureLoaded(token);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          widget.conversation.participantName,
          key: const Key('conversation_participant_name'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            key: const Key('chat_schedule_meetup_action'),
            tooltip: 'Schedule Meetup',
            icon: const Icon(Icons.handshake_outlined),
            onPressed:
                widget.conversation.isActive &&
                    (_currentAuthToken?.isNotEmpty ?? false)
                ? _scheduleMeetup
                : null,
          ),
          PopupMenuButton<_ChatConversationAction>(
            key: const Key('chat_more_actions'),
            tooltip: 'More chat actions',
            enabled: _currentAuthToken?.isNotEmpty ?? false,
            onSelected: (action) {
              switch (action) {
                case _ChatConversationAction.reportUser:
                  _reportUser();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_ChatConversationAction>(
                key: const Key('chat_report_user_action'),
                value: _ChatConversationAction.reportUser,
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Report user',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: provider,
          builder: (context, _) => Column(
            children: [
              _buildXianyuProductHeader(context),
              Expanded(child: _buildHistory(provider)),
              if (provider.messageReadErrorFor(widget.conversation.id) != null)
                _InlineChatError(
                  key: const Key('conversation_read_error'),
                  message: provider.messageReadErrorFor(
                    widget.conversation.id,
                  )!,
                  actionLabel: 'Retry',
                  onAction: _retryMarkRead,
                ),
              if (provider.messageSendErrorFor(widget.conversation.id) != null)
                _InlineChatError(
                  key: const Key('conversation_inline_error'),
                  message: provider.messageSendErrorFor(
                    widget.conversation.id,
                  )!,
                ),
              if (widget.conversation.isActive &&
                  (_currentAuthToken?.isNotEmpty ?? false))
                _buildXianyuActionStrip(context),
              _MessageComposer(
                controller: _messageController,
                focusNode: _messageFocusNode,
                isSending:
                    provider.isSending(widget.conversation.id) ||
                    _isStartingVoice ||
                    _isFinalizingVoice,
                enabled:
                    widget.conversation.isActive &&
                    (_currentAuthToken?.isNotEmpty ?? false),
                onAddPhoto: _addPhoto,
                onShareLocation: _shareLocation,
                onSend: _send,
                isRecording: _isRecording,
                recordingSeconds: _recordingSeconds,
                onStartRecording: _startVoiceRecording,
                onCancelRecording: () => _finishVoiceRecording(send: false),
                onSendRecording: () => _finishVoiceRecording(send: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(ChatProvider provider) {
    if (_currentAuthToken == null || _currentAuthToken!.isEmpty) {
      return const _ConversationState(
        key: Key('conversation_signed_out_state'),
        icon: Icons.lock_outline,
        message: 'Sign in to view this conversation.',
      );
    }
    if (provider.isLoadingMessages(widget.conversation.id) &&
        provider.messagesFor(widget.conversation.id).isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('conversation_loading_indicator'),
        ),
      );
    }
    final error = provider.messageLoadErrorFor(widget.conversation.id);
    final messages = provider.messagesFor(widget.conversation.id);
    if (error != null && messages.isEmpty) {
      return _ConversationState(
        key: const Key('conversation_error_state'),
        icon: Icons.cloud_off_outlined,
        message: error,
        actionLabel: 'Try again',
        onAction: _retry,
      );
    }
    if (messages.isEmpty) {
      return const _ConversationState(
        key: Key('conversation_empty_state'),
        icon: Icons.waving_hand_outlined,
        message: 'No messages yet. Say hello and ask about the item.',
      );
    }
    final latestSentIndex = messages.lastIndexWhere(
      (message) => message.isMine,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _messageFocusNode.unfocus(),
      child: ListView.builder(
        key: const Key('conversation_message_list'),
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return _MessageBubble(
            message: message,
            isBuyer: widget.conversation.direction == ChatDirection.buying,
            showReadReceipt:
                index == latestSentIndex && message.status == 'read',
            onMeetupStatusChanged: () {
              final token = _currentAuthToken;
              if (token != null && token.isNotEmpty) {
                _chatProvider.loadMessages(
                  conversation: widget.conversation,
                  token: token,
                  shouldMarkRead: () => _isCurrentRoute,
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showReadReceipt,
    this.isBuyer = false,
    this.onMeetupStatusChanged,
  });

  final ChatMessageModel message;
  final bool showReadReceipt;
  final bool isBuyer;
  final VoidCallback? onMeetupStatusChanged;

  @override
  Widget build(BuildContext context) {
    if (message.isMeetup && message.meetup != null) {
      return Align(
        alignment: message.isMine
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              MeetupCardBubble(
                key: Key('chat_meetup_card_${message.id}'),
                meetup: message.meetup!,
                isMine: message.isMine,
                isBuyer: isBuyer,
                createdAt: message.createdAt,
                onStatusChanged: onMeetupStatusChanged,
              ),
              if (showReadReceipt) _ReadReceipt(messageId: message.id),
            ],
          ),
        ),
      );
    }

    if (message.isLocation && message.location != null) {
      return Align(
        alignment: message.isMine
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              LocationBubble(
                key: Key('chat_location_${message.id}'),
                location: message.location!,
                isMine: message.isMine,
                createdAt: message.createdAt,
              ),
              if (showReadReceipt) _ReadReceipt(messageId: message.id),
            ],
          ),
        ),
      );
    }

    final mine = message.isMine;
    final semanticContent = message.isImage
        ? 'a photo'
        : message.isVoice
        ? 'a voice message'
        : message.text;
    return Semantics(
      excludeSemantics: !message.isVoice,
      label: mine
          ? 'You sent $semanticContent${showReadReceipt ? ', read' : ''}'
          : 'They sent $semanticContent',
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: Key('chat_message_${message.id}'),
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: mine
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.medium),
              topRight: const Radius.circular(AppRadius.medium),
              bottomLeft: Radius.circular(mine ? AppRadius.medium : 4),
              bottomRight: Radius.circular(mine ? 4 : AppRadius.medium),
            ),
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Image.network(
                    _resolvedChatImageUrl(message.imageUrl!),
                    key: Key('chat_message_image_${message.id}'),
                    width: 220,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, _) => SizedBox(
                      width: 220,
                      height: 120,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: mine
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else if (message.isVoice)
                _VoiceMessageBubble(
                  messageId: message.id,
                  audioUrl: _resolvedChatAssetUrl(message.audioUrl!),
                  durationMs: message.durationMs!,
                  mine: mine,
                )
              else
                Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mine
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                _messageTime(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mine
                      ? Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.78)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (showReadReceipt)
                Text(
                  'Read',
                  key: Key('chat_read_receipt_${message.id}'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.78),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Read',
      key: Key('chat_read_receipt_$messageId'),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _messageTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.enabled,
    required this.onAddPhoto,
    required this.onShareLocation,
    required this.onSend,
    required this.isRecording,
    required this.recordingSeconds,
    required this.onStartRecording,
    required this.onCancelRecording,
    required this.onSendRecording,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool enabled;
  final VoidCallback onAddPhoto;
  final VoidCallback onShareLocation;
  final VoidCallback onSend;
  final bool isRecording;
  final int recordingSeconds;
  final VoidCallback onStartRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendRecording;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: isRecording
            ? _RecordingComposer(
                seconds: recordingSeconds,
                onCancel: onCancelRecording,
                onSend: onSendRecording,
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      key: const Key('chat_add_photo_button'),
                      tooltip: 'Add photo',
                      onPressed: enabled && !isSending ? onAddPhoto : null,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      key: const Key('chat_share_location_button'),
                      tooltip: 'Share location',
                      onPressed: enabled && !isSending ? onShareLocation : null,
                      icon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      key: const Key('chat_message_input'),
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled && !isSending,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: enabled ? 'Message' : 'Conversation closed',
                        hintText: enabled ? 'Write a message' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      key: const Key('chat_record_voice_button'),
                      tooltip: 'Record voice message',
                      onPressed: enabled && !isSending
                          ? onStartRecording
                          : null,
                      icon: const Icon(Icons.mic_none_rounded),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton.filled(
                      key: const Key('chat_send_button'),
                      tooltip: 'Send message',
                      onPressed: enabled && !isSending ? onSend : null,
                      icon: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RecordingComposer extends StatelessWidget {
  const _RecordingComposer({
    required this.seconds,
    required this.onCancel,
    required this.onSend,
  });

  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('chat_cancel_voice_button'),
          tooltip: 'Cancel recording',
          onPressed: onCancel,
          icon: const Icon(Icons.delete_outline),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(Icons.mic_rounded, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Recording ${_voiceDuration(seconds * 1000)} / 1:00',
            key: const Key('chat_voice_recording_timer'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton.filled(
          key: const Key('chat_send_voice_button'),
          tooltip: 'Send voice message',
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({
    required this.messageId,
    required this.audioUrl,
    required this.durationMs,
    required this.mine,
  });

  final String messageId;
  final String audioUrl;
  final int durationMs;
  final bool mine;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _isPlaying = false;
  bool _isLoading = false;

  Future<void> _toggle() async {
    if (_isLoading) return;
    final player = _player ??= AudioPlayer();
    _stateSubscription ??= player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        _isLoading =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
    });
    try {
      if (player.playing) {
        await player.pause();
      } else {
        if (player.audioSource == null) {
          setState(() => _isLoading = true);
          await player.setUrl(widget.audioUrl);
        } else if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        await player.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('This voice message could not be played.'),
            ),
          );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.mine
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('chat_voice_play_${widget.messageId}'),
          tooltip: _isPlaying ? 'Pause voice message' : 'Play voice message',
          color: foreground,
          onPressed: _toggle,
          icon: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
        ),
        Icon(Icons.graphic_eq_rounded, color: foreground),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _voiceDuration(widget.durationMs),
          key: Key('chat_voice_duration_${widget.messageId}'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: foreground),
        ),
      ],
    );
  }
}

String _voiceDuration(int durationMs) {
  final totalSeconds = (durationMs / 1000).ceil().clamp(0, 60);
  return '${totalSeconds ~/ 60}:${(totalSeconds % 60).toString().padLeft(2, '0')}';
}

enum _ChatPhotoSource { camera, gallery }

class _ChatPhotoSourceSheet extends StatelessWidget {
  const _ChatPhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send a photo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              key: const Key('chat_take_photo_option'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              subtitle: const Text('Open your device camera'),
              onTap: () => Navigator.pop(context, _ChatPhotoSource.camera),
            ),
            ListTile(
              key: const Key('chat_choose_photo_option'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Select an existing photo'),
              onTap: () => Navigator.pop(context, _ChatPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

String _photoContentType(XFile file) {
  final reported = file.mimeType?.trim().toLowerCase();
  if (reported != null && reported.startsWith('image/')) return reported;
  final extension = file.name.split('.').last.toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    _ => 'image/jpeg',
  };
}

String _photoExtension(String contentType) => switch (contentType) {
  'image/png' => 'png',
  'image/webp' => 'webp',
  'image/heic' => 'heic',
  _ => 'jpg',
};

String _resolvedChatAssetUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme) return value;
  final path = value.startsWith('/') ? value : '/$value';
  return '${ApiConfig.baseUrl}$path';
}

String _resolvedChatImageUrl(String value) => _resolvedChatAssetUrl(value);

class _InlineChatError extends StatelessWidget {
  const _InlineChatError({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _ConversationState extends StatelessWidget {
  const _ConversationState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
