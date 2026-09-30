import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../models/chat_conversation_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/item_model.dart';
import '../../models/meetup_model.dart';
import '../../models/order_model.dart';
import '../../models/report_draft.dart';
import '../../config/api_config.dart';
import '../../navigation/app_route_observer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/meetup_provider.dart';
import '../../providers/order_provider.dart';
import '../../repositories/item_repository.dart';
import '../../services/listing_image_picker.dart';
import '../../services/chat_voice_service.dart';
import '../../services/notification_permission_coordinator.dart';
import '../../theme/app_theme.dart';
import '../products/product_detail_screen.dart';
import '../profile/payment_checkout_screen.dart';
import '../profile/payment_methods_screen.dart';
import '../profile/public_profile_screen.dart';
import '../profile/report_screen.dart';
import '../shared/widgets/review_bottom_sheet.dart';
import 'widgets/location_bubble.dart';
import 'widgets/location_picker_sheet.dart';
import 'widgets/meetup_card_bubble.dart';
import 'widgets/schedule_meetup_sheet.dart';

class _ChatStatusFact extends StatelessWidget {
  const _ChatStatusFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  bool? _finishVoiceWhenStarted;
  Future<void> _recorderQueue = Future<void>.value();
  int _recordingSeconds = 0;
  String? _loadedToken;
  String? _currentAuthToken;
  bool _leftForeground = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  ModalRoute<dynamic>? _subscribedRoute;
  final Object _visibilityOwner = Object();
  ItemModel? _activeItem;
  String? _specialOfferPrice;
  bool _itemPaid = false;
  bool _showActionPanel = false;
  bool _voiceMode = false;

  @override
  void initState() {
    super.initState();
    _specialOfferPrice = widget.conversation.specialPrice;
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
      if (_showActionPanel) {
        setState(() => _showActionPanel = false);
      }
      _focusScrollTimer?.cancel();
      _focusScrollTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) _scrollToEnd();
      });
    }
  }

  void _toggleActionPanel() {
    if (_showActionPanel) {
      setState(() => _showActionPanel = false);
    } else {
      _messageFocusNode.unfocus();
      setState(() => _showActionPanel = true);
      _scrollToEnd();
    }
  }

  void _toggleVoiceMode() {
    if (_isRecording || _isStartingVoice || _isFinalizingVoice) return;
    final nextVoiceMode = !_voiceMode;
    if (nextVoiceMode) {
      _messageFocusNode.unfocus();
    }
    setState(() {
      _voiceMode = nextVoiceMode;
      _showActionPanel = false;
    });
    if (!nextVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _messageFocusNode.requestFocus();
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
        // Required for seller to resolve buyer from conversation
        conversationId: widget.conversation.id,
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

  Future<void> _autoReserveItem() async {
    // Status available/reserved is no longer auto-mutated in chat flow.
  }

  Future<bool> _confirmCancelPreviousMeetupIfNeeded(
    ChatMessageModel currentMessage,
  ) async {
    final messages = _chatProvider.messagesFor(widget.conversation.id);
    final hasActiveConfirmed = messages.any(
      (m) =>
          m.id != currentMessage.id &&
          m.isMeetup &&
          m.meetup != null &&
          m.meetup!.isConfirmed,
    );

    if (!hasActiveConfirmed) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cancel Previous Meetup?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'A meetup has already been confirmed. Accepting this new proposal will cancel the previously scheduled meetup.\n\nDo you want to continue and accept this one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Previous'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            child: const Text('Cancel Previous & Accept'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  OrderProvider? _getOrderProvider({bool listen = false}) {
    try {
      return Provider.of<OrderProvider>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  OrderModel? _orderForConversation(Iterable<OrderModel> orders) {
    final participantId = _effectiveParticipantId;
    if (participantId.isEmpty) return null;
    final buying = widget.conversation.direction == ChatDirection.buying;
    return orders
        .where(
          (order) =>
              order.itemId == widget.conversation.itemId &&
              order.counterparty.id == participantId &&
              (buying ? order.isBuying : order.isSelling),
        )
        .firstOrNull;
  }

  Future<void> _buyerBuyNow() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;

    final isSold = _activeItem?.status == ItemStatus.sold;
    final orders = _getOrderProvider()?.orders ?? const [];
    final conversationOrder = _orderForConversation(orders);
    final isAlreadyPaid =
        _itemPaid ||
        (conversationOrder != null &&
            (conversationOrder.isPaid || conversationOrder.isCompleted));

    if (isSold || isAlreadyPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSold
                ? 'This item has already been sold.'
                : 'You have already completed payment for this item.',
          ),
        ),
      );
      return;
    }

    final item = _activeItem;
    final priceStr = item?.isFree == true || item?.priceNzd == '0'
        ? 'FREE'
        : '\$${item?.priceNzd ?? "0"} NZD';

    // 1. Prepare order and navigate to payment checkout screen without premature chat message
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Preparing checkout...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final orderProvider = _getOrderProvider();
      if (orderProvider == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final order = await orderProvider.createOrGetOrder(
        itemId: widget.conversation.itemId,
        token: token,
      );
      if (mounted) Navigator.pop(context); // close loading dialog

      if (mounted) {
        final paymentResult = await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(
            builder: (_) => PaymentCheckoutScreen(order: order),
          ),
        );

        if (paymentResult == true && mounted) {
          setState(() {
            _itemPaid = true;
          });
          _loadItemDetails();
          final token = _currentAuthToken;
          if (token != null && token.isNotEmpty) {
            orderProvider.loadMyOrders(token);
          }
          await _chatProvider.sendText(
            conversation: widget.conversation,
            text:
                '💳 [Payment Confirmed] Payment of $priceStr confirmed! Order #${order.orderNumber}. I have completed the payment via KiwiShare Safe Pay.',
            token: token ?? '',
          );
          _scrollToEnd();
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open checkout: $e')));
      }
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
                  'Offer Special Price',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Clarify this is a per-buyer offer, NOT a product price change
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This is a private offer for this buyer only. Your listing price stays unchanged for other buyers.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
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
                          labelText: isFree
                              ? 'Free Item'
                              : 'Special Price (NZD)',
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
                    child: const Text('Send Offer to Buyer'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Only send a chat message — do NOT modify the actual listing price
    if (newPrice != null && mounted) {
      setState(() => _specialOfferPrice = newPrice);
      final priceLabel = newPrice == '0' ? 'FREE' : '\$$newPrice NZD';
      try {
        await _chatProvider.sendText(
          conversation: widget.conversation,
          text:
              '🏷️ Special offer just for you: $priceLabel (listing price unchanged for others)',
          token: token,
        );
        _scrollToEnd();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Price offer sent: $priceLabel')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send offer: $e')));
      }
    }
  }

  Future<void> _sellerToggleDelistRelist() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    final item = _activeItem;
    if (item == null || item.status == ItemStatus.sold) return;

    final isDelisted = item.status == ItemStatus.delisted;

    if (!isDelisted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delist Item?'),
          content: const Text(
            'This listing will be taken down from the marketplace. You can relist it anytime before it is sold.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delist'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      try {
        final updated = await RestItemRepository().updateItem(
          id: widget.conversation.itemId,
          token: token,
          updates: {'status': 'draft'},
        );
        setState(() => _activeItem = updated);
        await _chatProvider.sendText(
          conversation: widget.conversation,
          text: '[Seller Action] Item has been delisted from the marketplace.',
          token: token,
        );
        _scrollToEnd();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item has been delisted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delist item: $e')));
        }
      }
    } else {
      try {
        final updated = await RestItemRepository().updateItem(
          id: widget.conversation.itemId,
          token: token,
          updates: {'status': 'active'},
        );
        setState(() => _activeItem = updated);
        await _chatProvider.sendText(
          conversation: widget.conversation,
          text: '[Seller Action] Item has been relisted to the marketplace.',
          token: token,
        );
        _scrollToEnd();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item relisted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to relist item: $e')));
        }
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
    final orders = _getOrderProvider(listen: true)?.orders ?? const [];
    final conversationOrder = _orderForConversation(orders);
    final isOrderPaid =
        _itemPaid ||
        (conversationOrder != null &&
            (conversationOrder.isPaid || conversationOrder.isCompleted));

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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
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
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
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
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (_specialOfferPrice != null) ...[
                              Text(
                                _specialOfferPrice == '0'
                                    ? 'FREE'
                                    : '\$$_specialOfferPrice',
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Special Offer',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (priceText.isNotEmpty &&
                                  priceText !=
                                      (_specialOfferPrice == '0'
                                          ? 'FREE'
                                          : '\$$_specialOfferPrice'))
                                Text(
                                  priceText,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant.withOpacity(
                                      0.6,
                                    ),
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ] else ...[
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
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Top-right corner status badge
          Positioned(
            top: -2,
            right: 0,
            child: _buildCornerStatusBadge(
              isPaid: isOrderPaid,
              status: status,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerStatusBadge({
    required bool isPaid,
    required ItemStatus status,
    required bool isDark,
  }) {
    if (isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF059669),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 10, color: Colors.white),
            SizedBox(width: 3),
            Text(
              'PAID',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    if (status == ItemStatus.sold) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF475569),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'SOLD',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    if (status == ItemStatus.delisted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'DELISTED',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A22) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: const Text(
        'AVAILABLE',
        style: TextStyle(
          color: Color(0xFF059669),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _formatMeetupDateTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatMediumDate(local);
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date · $time';
  }

  Future<void> _showTransactionStatusSheet({
    required String title,
    required String subtitle,
    required bool isPaid,
    required bool hasMeetup,
    required bool isCompleted,
    OrderModel? order,
    ChatMeetupPayload? meetup,
  }) {
    final colors = Theme.of(context).colorScheme;
    final orderNumber = (order?.orderNumber ?? meetup?.orderId ?? '').trim();
    final amount =
        (order?.itemAmountNzd ??
                meetup?.agreedPriceNzd ??
                _activeItem?.priceNzd ??
                '')
            .trim();
    final location = meetup?.locationName.trim() ?? '';
    final scheduledAt = meetup?.scheduledAt;

    Widget milestone({
      required IconData icon,
      required String label,
      required bool complete,
    }) {
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: complete
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                complete ? Icons.check_rounded : icon,
                size: 20,
                color: complete ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: complete ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    Widget detailRow(IconData icon, String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            SizedBox(
              width: 76,
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  milestone(
                    icon: Icons.payments_outlined,
                    label: 'Payment',
                    complete: isPaid,
                  ),
                  Container(
                    width: 34,
                    height: 2,
                    color: (isPaid && hasMeetup)
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                  milestone(
                    icon: Icons.handshake_outlined,
                    label: 'Meetup',
                    complete: hasMeetup,
                  ),
                  Container(
                    width: 34,
                    height: 2,
                    color: isCompleted ? colors.primary : colors.outlineVariant,
                  ),
                  milestone(
                    icon: Icons.inventory_2_outlined,
                    label: 'Handover',
                    complete: isCompleted,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    detailRow(
                      Icons.receipt_long_outlined,
                      'Order',
                      orderNumber.isEmpty ? '' : '#$orderNumber',
                    ),
                    detailRow(
                      Icons.sell_outlined,
                      'Item',
                      widget.conversation.itemTitle,
                    ),
                    detailRow(
                      Icons.payments_outlined,
                      'Price',
                      amount.isEmpty ? '' : '\$$amount NZD',
                    ),
                    detailRow(
                      Icons.verified_outlined,
                      'Payment',
                      isPaid ? 'Paid' : 'Payment required',
                    ),
                    if (scheduledAt != null)
                      detailRow(
                        Icons.event_outlined,
                        'When',
                        _formatMeetupDateTime(sheetContext, scheduledAt),
                      ),
                    detailRow(Icons.place_outlined, 'Where', location),
                    detailRow(
                      Icons.local_shipping_outlined,
                      'Handover',
                      isCompleted
                          ? 'Completed'
                          : hasMeetup && isPaid
                          ? 'Ready for meetup'
                          : 'Pending',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const Key('chat_transaction_view_orders'),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/orders');
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View orders'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactionStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required bool isPaid,
    required bool hasMeetup,
    required bool isCompleted,
    OrderModel? order,
    ChatMeetupPayload? meetup,
    String? primaryLabel,
    IconData? primaryIcon,
    Key? primaryKey,
    VoidCallback? primaryAction,
    String? secondaryLabel,
    VoidCallback? secondaryAction,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final location = meetup?.locationName.trim() ?? '';
    final scheduledAt = meetup?.scheduledAt;
    final orderNumber = (order?.orderNumber ?? meetup?.orderId ?? '').trim();

    final quickFacts = <Widget>[
      if (scheduledAt != null)
        _ChatStatusFact(
          icon: Icons.event_outlined,
          text: _formatMeetupDateTime(context, scheduledAt),
        ),
      if (location.isNotEmpty)
        _ChatStatusFact(icon: Icons.place_outlined, text: location),
      if (orderNumber.isNotEmpty)
        _ChatStatusFact(
          icon: Icons.receipt_long_outlined,
          text: '#$orderNumber',
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      child: Material(
        color: isDark
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.14),
                colors.surfaceContainer,
              )
            : Color.alphaBlend(accent.withValues(alpha: 0.08), colors.surface),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('chat_transaction_status_card'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showTransactionStatusSheet(
            title: title,
            subtitle: subtitle,
            isPaid: isPaid,
            hasMeetup: hasMeetup,
            isCompleted: isCompleted,
            order: order,
            meetup: meetup,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 21, color: accent),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 21, color: accent),
                  ],
                ),
                if (quickFacts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 7, children: quickFacts),
                ],
                if (primaryAction != null || secondaryAction != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (primaryAction != null)
                        Expanded(
                          child: FilledButton.icon(
                            key: primaryKey,
                            onPressed: primaryAction,
                            icon: Icon(
                              primaryIcon ?? Icons.arrow_forward_rounded,
                              size: 17,
                            ),
                            label: Text(primaryLabel ?? 'Continue'),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      if (primaryAction != null && secondaryAction != null)
                        const SizedBox(width: 8),
                      if (secondaryAction != null)
                        TextButton(
                          onPressed: secondaryAction,
                          child: Text(secondaryLabel ?? 'Open'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderFlowCard(BuildContext context) {
    final orders = _getOrderProvider(listen: true)?.orders ?? const [];
    final order = _orderForConversation(orders);

    final messages = _chatProvider.messagesFor(widget.conversation.id);
    final latestMeetupMsg = messages.reversed
        .where((m) => m.meetup != null)
        .firstOrNull;
    final meetup = latestMeetupMsg?.meetup;

    MeetupModel? cachedMeetup;
    if (order != null) {
      try {
        cachedMeetup = context.watch<MeetupProvider>().meetupById(order.id);
      } catch (_) {}
    }

    final isBuyer = widget.conversation.direction == ChatDirection.buying;
    final isPaid =
        _itemPaid ||
        (order != null && (order.isPaid || order.isCompleted)) ||
        (cachedMeetup != null && cachedMeetup.isPaid);

    final hasActiveMeetupProposal =
        meetup != null && !meetup.isCancelled && !meetup.isDeclined;
    final isMeetupConfirmed =
        hasActiveMeetupProposal &&
        (meetup.isConfirmed || cachedMeetup?.isConfirmed == true);
    final hasMeetup = isMeetupConfirmed;
    final isCompleted =
        (order != null &&
            (order.isCompleted ||
                order.status == 'completed' ||
                order.status == 'seller_paid')) ||
        (cachedMeetup != null && cachedMeetup.isCompleted) ||
        messages.any(
          (m) =>
              m.text.contains('Transaction successfully completed') ||
              m.text.contains('[Transaction Completed]'),
        );

    if (isCompleted) {
      return _transactionStatusCard(
        title: 'Transaction completed',
        subtitle:
            'Handover is confirmed and the transaction is complete. Tap for the full status.',
        icon: Icons.celebration_rounded,
        accent: const Color(0xFF059669),
        isPaid: true,
        hasMeetup: hasMeetup,
        isCompleted: true,
        order: order,
        meetup: meetup,
        primaryLabel: 'Rate & review',
        primaryIcon: Icons.star_rounded,
        primaryKey: const Key('chat_order_leave_review_btn'),
        primaryAction: () {
          ReviewBottomSheet.show(
            context,
            targetUserId: _effectiveParticipantId,
            targetName: widget.conversation.participantName,
            targetAvatarUrl: widget.conversation.participantAvatarUrl,
            orderId: order?.id,
            itemId: widget.conversation.itemId,
            itemTitle: widget.conversation.itemTitle,
            itemImageUrl: widget.conversation.itemImageUrl,
            role: isBuyer ? 'seller' : 'buyer',
          );
        },
        secondaryLabel: isBuyer ? 'Orders' : 'Wallet',
        secondaryAction: isBuyer
            ? () => context.push('/orders')
            : () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PaymentMethodsScreen(),
                ),
              ),
      );
    }

    if (order == null && !hasMeetup && !_itemPaid) {
      return const SizedBox.shrink();
    }
    if (!isPaid && !hasMeetup) {
      return const SizedBox.shrink();
    }

    if (isPaid && !hasMeetup) {
      return _transactionStatusCard(
        title: 'Payment complete · arrange meetup',
        subtitle:
            'Payment is secured by KiwiShare. Agree on a time and place for handover.',
        icon: Icons.schedule_send_rounded,
        accent: const Color(0xFFD97706),
        isPaid: true,
        hasMeetup: false,
        isCompleted: false,
        order: order,
        meetup: meetup,
        primaryLabel: 'Schedule meetup',
        primaryIcon: Icons.handshake_outlined,
        primaryKey: const Key('chat_order_schedule_meetup_btn'),
        primaryAction: _scheduleMeetup,
      );
    }

    if (!isPaid && hasMeetup) {
      return _transactionStatusCard(
        title: isBuyer
            ? 'Meetup confirmed · payment needed'
            : 'Meetup confirmed · awaiting payment',
        subtitle: isBuyer
            ? 'Your meetup is set. Complete payment before handover.'
            : 'The meetup is set. The buyer still needs to complete payment.',
        icon: Icons.payment_rounded,
        accent: const Color(0xFF7C3AED),
        isPaid: false,
        hasMeetup: true,
        isCompleted: false,
        order: order,
        meetup: meetup,
        primaryLabel: isBuyer ? 'Pay now' : null,
        primaryIcon: isBuyer ? Icons.lock_outline_rounded : null,
        primaryKey: isBuyer ? const Key('chat_order_pay_now_btn') : null,
        primaryAction: isBuyer ? _buyerBuyNow : null,
      );
    }

    return _transactionStatusCard(
      title: 'Ready for handover',
      subtitle:
          'Payment is complete and the meetup is confirmed. Tap to review all transaction details.',
      icon: Icons.handshake_rounded,
      accent: const Color(0xFF059669),
      isPaid: true,
      hasMeetup: true,
      isCompleted: false,
      order: order,
      meetup: meetup,
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

    final isItemSold = _activeItem?.status == ItemStatus.sold;
    if (isItemSold) {
      return const SizedBox.shrink();
    }
    final orders = _getOrderProvider(listen: true)?.orders ?? const [];
    final conversationOrder = _orderForConversation(orders);
    final isOrderPaid =
        _itemPaid ||
        (conversationOrder != null &&
            (conversationOrder.isPaid || conversationOrder.isCompleted));

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
                  if (!isItemSold && !isOrderPaid) ...[
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
                  ] else if (isOrderPaid) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF047857),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Paid · Ready to Meet',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceContainerHighest.withValues(
                                alpha: 0.4,
                              )
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Item Sold',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  if (_activeItem?.status != ItemStatus.sold) ...[
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
                            color: (_activeItem?.status == ItemStatus.delisted)
                                ? const Color(0xFF059669)
                                : Colors.orange.shade700,
                          ),
                          foregroundColor:
                              (_activeItem?.status == ItemStatus.delisted)
                              ? const Color(0xFF059669)
                              : Colors.orange.shade900,
                        ),
                        onPressed: _sellerToggleDelistRelist,
                        icon: Icon(
                          (_activeItem?.status == ItemStatus.delisted)
                              ? Icons.storefront_outlined
                              : Icons.archive_outlined,
                          size: 16,
                        ),
                        label: Text(
                          (_activeItem?.status == ItemStatus.delisted)
                              ? 'Relist Item'
                              : 'Delist Item',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
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
            targetImageUrl: widget.conversation.participantAvatarUrl,
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
      final pendingFinish = _finishVoiceWhenStarted;
      _finishVoiceWhenStarted = null;
      if (pendingFinish != null) {
        await _finishVoiceRecording(send: pendingFinish);
        return;
      }
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
      _finishVoiceWhenStarted = null;
      if (mounted) setState(() => _isStartingVoice = false);
    }
  }

  Future<void> _finishVoiceRecording({required bool send}) async {
    if (_isStartingVoice && !_isRecording) {
      _finishVoiceWhenStarted = send;
      return;
    }
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

  String get _effectiveParticipantId {
    final fromCached = _chatProvider
        .conversationById(widget.conversation.id)
        ?.participantId;
    if (fromCached != null && fromCached.isNotEmpty) return fromCached;
    if (widget.conversation.participantId.isNotEmpty) {
      return widget.conversation.participantId;
    }
    final msgs = _chatProvider.messagesFor(widget.conversation.id);
    for (final m in msgs) {
      if (!m.isMine && m.senderId.isNotEmpty) return m.senderId;
    }
    return '';
  }

  void _openParticipantProfile() {
    final pid = _effectiveParticipantId;
    if (pid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Participant profile is loading, please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PublicProfileScreen(userId: pid)),
    );
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
        title: InkWell(
          key: const Key('conversation_participant_header'),
          borderRadius: BorderRadius.circular(8),
          onTap: _openParticipantProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  backgroundImage:
                      widget.conversation.participantAvatarUrl != null &&
                          widget.conversation.participantAvatarUrl!.isNotEmpty
                      ? NetworkImage(widget.conversation.participantAvatarUrl!)
                      : null,
                  child:
                      widget.conversation.participantAvatarUrl == null ||
                          widget.conversation.participantAvatarUrl!.isEmpty
                      ? Text(
                          widget.conversation.participantName.isNotEmpty
                              ? widget.conversation.participantName[0]
                                    .toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.conversation.participantName,
                        key: const Key('conversation_participant_name'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View profile',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
        bottom: false,
        child: ListenableBuilder(
          listenable: provider,
          builder: (context, _) => Column(
            children: [
              _buildXianyuProductHeader(context),
              _buildOrderFlowCard(context),
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
                voiceMode: _voiceMode,
                onToggleVoiceMode: _toggleVoiceMode,
                isRecording: _isRecording,
                recordingSeconds: _recordingSeconds,
                onStartRecording: _startVoiceRecording,
                onCancelRecording: () => _finishVoiceRecording(send: false),
                onSendRecording: () => _finishVoiceRecording(send: true),
                showActionPanel: _showActionPanel,
                onToggleActionPanel: _toggleActionPanel,
                onOpenOrders: () => context.push('/orders'),
                onScheduleMeetup: _scheduleMeetup,
                onPay: _buyerBuyNow,
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
    if (_specialOfferPrice == null) {
      for (final m in messages.reversed) {
        if (m.text.contains('Special offer just for you:')) {
          final match = RegExp(
            r'Special offer just for you:\s*(FREE|\$[0-9.]+)',
          ).firstMatch(m.text);
          if (match != null) {
            final val = match.group(1)!;
            _specialOfferPrice = val == 'FREE' ? '0' : val.replaceAll('\$', '');
            break;
          }
        }
      }
    }
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
    final auth = context.watch<AuthProvider?>();
    final myAvatarUrl = auth?.currentUser?.avatarUrl;
    final myDisplayName = auth?.currentUser?.displayName ?? 'You';
    final otherAvatarUrl = widget.conversation.participantAvatarUrl;
    final otherDisplayName = widget.conversation.participantName;

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
            onBeforeAccept: () => _confirmCancelPreviousMeetupIfNeeded(message),
            myAvatarUrl: myAvatarUrl,
            myDisplayName: myDisplayName,
            otherAvatarUrl: otherAvatarUrl,
            otherDisplayName: otherDisplayName,
            onOtherAvatarTap: _openParticipantProfile,
            onMeetupStatusChanged: () {
              final token = _currentAuthToken;
              if (token != null && token.isNotEmpty) {
                _chatProvider.loadMessages(
                  conversation: widget.conversation,
                  token: token,
                  shouldMarkRead: () => _isCurrentRoute,
                );
              }
              if (_activeItem?.status == ItemStatus.active &&
                  widget.conversation.direction == ChatDirection.selling) {
                _autoReserveItem();
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
    this.onBeforeAccept,
    this.myAvatarUrl,
    this.myDisplayName,
    this.otherAvatarUrl,
    this.otherDisplayName,
    this.onOtherAvatarTap,
  });

  final ChatMessageModel message;
  final bool showReadReceipt;
  final bool isBuyer;
  final VoidCallback? onMeetupStatusChanged;
  final Future<bool> Function()? onBeforeAccept;
  final String? myAvatarUrl;
  final String? myDisplayName;
  final String? otherAvatarUrl;
  final String? otherDisplayName;
  final VoidCallback? onOtherAvatarTap;

  @override
  Widget build(BuildContext context) {
    if (message.isMeetup && message.meetup != null) {
      return Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MeetupCardBubble(
                key: Key('chat_meetup_card_${message.id}'),
                meetup: message.meetup!,
                messageId: message.id,
                isMine: message.isMine,
                isBuyer: isBuyer,
                createdAt: message.createdAt,
                onStatusChanged: onMeetupStatusChanged,
                onBeforeAccept: onBeforeAccept,
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

    final bubbleWidget = Container(
      key: Key('chat_message_${message.id}'),
      constraints: const BoxConstraints(maxWidth: 270),
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
            _ActionOrTextMessage(text: message.text, mine: mine),
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
    );

    final counterpartAvatar = GestureDetector(
      onTap: onOtherAvatarTap,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: otherAvatarUrl != null && otherAvatarUrl!.isNotEmpty
            ? NetworkImage(otherAvatarUrl!)
            : null,
        child: otherAvatarUrl == null || otherAvatarUrl!.isEmpty
            ? Text(
                otherDisplayName != null && otherDisplayName!.isNotEmpty
                    ? otherDisplayName![0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )
            : null,
      ),
    );

    final myAvatar = CircleAvatar(
      radius: 14,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      backgroundImage: myAvatarUrl != null && myAvatarUrl!.isNotEmpty
          ? NetworkImage(myAvatarUrl!)
          : null,
      child: myAvatarUrl == null || myAvatarUrl!.isEmpty
          ? Text(
              myDisplayName != null && myDisplayName!.isNotEmpty
                  ? myDisplayName![0].toUpperCase()
                  : 'ME',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            )
          : null,
    );

    return Semantics(
      excludeSemantics: !message.isVoice,
      label: mine
          ? 'You sent $semanticContent${showReadReceipt ? ', read' : ''}'
          : 'They sent $semanticContent',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[counterpartAvatar, const SizedBox(width: 8)],
            Flexible(child: bubbleWidget),
            if (mine) ...[const SizedBox(width: 8), myAvatar],
          ],
        ),
      ),
    );
  }
}

class _ActionOrTextMessage extends StatelessWidget {
  const _ActionOrTextMessage({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSellerAction = text.contains('[Seller Action]');
    final isBuyerAction = text.contains('[Buyer Action]');
    final isPaymentConfirmed =
        text.contains('[Payment Successful]') ||
        text.contains('[Payment Confirmed]');
    final isPaymentRequest = text.contains('[Payment Request]');
    final isHandoverCompleted = text.contains('[Handover Completed]');

    if (!isSellerAction &&
        !isBuyerAction &&
        !isPaymentConfirmed &&
        !isPaymentRequest &&
        !isHandoverCompleted) {
      return Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: mine
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ),
      );
    }

    final IconData icon;
    final String badgeTitle;
    final Color badgeColor;
    final Color badgeTextColor;
    String cleanBody = text;

    if (isSellerAction) {
      icon = Icons.inventory_2_rounded;
      badgeTitle = 'Seller Action';
      badgeColor = mine
          ? Colors.white.withValues(alpha: 0.22)
          : const Color(0xFF2563EB).withValues(alpha: 0.12);
      badgeTextColor = mine ? Colors.white : const Color(0xFF1D4ED8);
      cleanBody = text
          .replaceAll('📦', '')
          .replaceAll('[Seller Action]', '')
          .trim();
    } else if (isBuyerAction) {
      icon = Icons.shopping_bag_rounded;
      badgeTitle = 'Buyer Action';
      badgeColor = mine
          ? Colors.white.withValues(alpha: 0.22)
          : const Color(0xFF059669).withValues(alpha: 0.12);
      badgeTextColor = mine ? Colors.white : const Color(0xFF047857);
      cleanBody = text
          .replaceAll('💳', '')
          .replaceAll('[Buyer Action]', '')
          .trim();
    } else if (isPaymentRequest) {
      icon = Icons.payment_rounded;
      badgeTitle = 'Payment Request';
      badgeColor = mine
          ? Colors.white.withValues(alpha: 0.25)
          : const Color(0xFFD97706).withValues(alpha: 0.15);
      badgeTextColor = mine ? Colors.white : const Color(0xFFB45309);
      cleanBody = text
          .replaceAll('💳', '')
          .replaceAll('[Payment Request]', '')
          .trim();
    } else if (isHandoverCompleted) {
      icon = Icons.handshake_rounded;
      badgeTitle = 'Handover Completed';
      badgeColor = mine
          ? Colors.white.withValues(alpha: 0.25)
          : const Color(0xFF10B981).withValues(alpha: 0.15);
      badgeTextColor = mine ? Colors.white : const Color(0xFF065F46);
      cleanBody = text
          .replaceAll('🤝', '')
          .replaceAll('[Handover Completed]', '')
          .trim();
    } else {
      icon = Icons.verified_rounded;
      badgeTitle = 'Payment Confirmed';
      badgeColor = mine
          ? Colors.white.withValues(alpha: 0.25)
          : const Color(0xFF10B981).withValues(alpha: 0.15);
      badgeTextColor = mine ? Colors.white : const Color(0xFF065F46);
      cleanBody = text
          .replaceAll('✅', '')
          .replaceAll('💳', '')
          .replaceAll('[Payment Confirmed]', '')
          .replaceAll('[Payment Successful]', '')
          .trim();
    }

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: badgeTextColor),
              const SizedBox(width: 4),
              Text(
                badgeTitle,
                style: TextStyle(
                  color: badgeTextColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        Text(
          cleanBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: mine
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Read',
          key: Key('chat_read_receipt_$messageId'),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: const Color(0xFF60AEFF)),
        ),
        const SizedBox(width: 3),
        const Icon(Icons.done_all, size: 12, color: Color(0xFF60AEFF)),
      ],
    );
  }
}

/// Returns a relative or absolute time label for a chat message.
String _messageTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  if (diff.inSeconds < 60) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m min${m == 1 ? '' : 's'} ago';
  } else if (diff.inHours < 6) {
    final h = diff.inHours;
    return '$h hr${h == 1 ? '' : 's'} ago';
  } else if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    // Same day — show time
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
  } else {
    // Different day — show date + time
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${local.day}/${local.month} $hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
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
    required this.voiceMode,
    required this.onToggleVoiceMode,
    required this.isRecording,
    required this.recordingSeconds,
    required this.onStartRecording,
    required this.onCancelRecording,
    required this.onSendRecording,
    this.showActionPanel = false,
    this.onToggleActionPanel,
    this.onOpenOrders,
    this.onScheduleMeetup,
    this.onPay,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool enabled;
  final VoidCallback onAddPhoto;
  final VoidCallback onShareLocation;
  final VoidCallback onSend;
  final bool voiceMode;
  final VoidCallback onToggleVoiceMode;
  final bool isRecording;
  final int recordingSeconds;
  final VoidCallback onStartRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendRecording;
  final bool showActionPanel;
  final VoidCallback? onToggleActionPanel;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onScheduleMeetup;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: colors.surface,
      child: SafeArea(
        key: const Key('chat_composer_safe_area'),
        top: false,
        maintainBottomViewPadding: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      key: const Key('chat_action_panel_toggle_button'),
                      tooltip: showActionPanel
                          ? 'Close actions'
                          : 'More actions',
                      onPressed: !enabled || isSending || voiceMode
                          ? null
                          : onToggleActionPanel,
                      icon: Icon(
                        showActionPanel
                            ? Icons.cancel_outlined
                            : Icons.add_circle_outline_rounded,
                        size: 24,
                        color: showActionPanel ? colors.primary : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: voiceMode
                        ? _VoiceHoldSurface(
                            enabled: enabled && !isSending,
                            recording: isRecording,
                            recordingSeconds: recordingSeconds,
                            onHoldStart: onStartRecording,
                            onHoldEnd: onSendRecording,
                            onHoldCancel: onCancelRecording,
                          )
                        : TextField(
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
                              labelText: enabled
                                  ? 'Message'
                                  : 'Conversation closed',
                              hintText: enabled ? 'Write a message' : null,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      key: Key(
                        voiceMode
                            ? 'chat_keyboard_mode_button'
                            : 'chat_record_voice_button',
                      ),
                      tooltip: voiceMode
                          ? 'Switch to keyboard'
                          : 'Voice message',
                      onPressed: enabled && !isSending && !isRecording
                          ? onToggleVoiceMode
                          : null,
                      icon: Icon(
                        voiceMode
                            ? Icons.keyboard_alt_outlined
                            : Icons.mic_none_rounded,
                        size: 24,
                        color: voiceMode ? colors.primary : null,
                      ),
                    ),
                  ),
                  if (!voiceMode) ...[
                    const SizedBox(width: AppSpacing.xs),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filled(
                        key: const Key('chat_send_button'),
                        tooltip: 'Send message',
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                        ),
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
                            : const Center(
                                child: Icon(Icons.send_rounded, size: 22),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!voiceMode && !isRecording && showActionPanel) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                color: colors.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionPanelItem(
                      key: const Key('chat_add_photo_button'),
                      icon: Icons.image_rounded,
                      label: 'Photos',
                      color: const Color(0xFF0284C7),
                      onTap: onAddPhoto,
                    ),
                    _ActionPanelItem(
                      key: const Key('chat_action_panel_orders'),
                      icon: Icons.receipt_long_rounded,
                      label: 'Orders',
                      color: const Color(0xFF6366F1),
                      onTap: () => onOpenOrders?.call(),
                    ),
                    _ActionPanelItem(
                      key: const Key('chat_action_panel_pay'),
                      icon: Icons.payment_rounded,
                      label: 'Pay',
                      color: const Color(0xFFD97706),
                      onTap: () => onPay?.call(),
                    ),
                    _ActionPanelItem(
                      key: const Key('chat_action_panel_meetup'),
                      icon: Icons.handshake_rounded,
                      label: 'Meetup',
                      color: const Color(0xFF059669),
                      onTap: () => onScheduleMeetup?.call(),
                    ),
                    _ActionPanelItem(
                      key: const Key('chat_share_location_button'),
                      icon: Icons.place_rounded,
                      label: 'Location',
                      color: const Color(0xFFEA580C),
                      onTap: onShareLocation,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoiceHoldSurface extends StatefulWidget {
  const _VoiceHoldSurface({
    required this.enabled,
    required this.recording,
    required this.recordingSeconds,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
  });

  final bool enabled;
  final bool recording;
  final int recordingSeconds;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onHoldCancel;

  @override
  State<_VoiceHoldSurface> createState() => _VoiceHoldSurfaceState();
}

class _VoiceHoldSurfaceState extends State<_VoiceHoldSurface> {
  static const double _cancelThreshold = 56;
  int? _pointerId;
  Offset? _pointerOrigin;
  bool _cancelOnRelease = false;

  void _resetPointer() {
    _pointerId = null;
    _pointerOrigin = null;
    if (_cancelOnRelease && mounted) {
      setState(() => _cancelOnRelease = false);
    } else {
      _cancelOnRelease = false;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _pointerId != null) return;
    _pointerId = event.pointer;
    _pointerOrigin = event.position;
    if (_cancelOnRelease) setState(() => _cancelOnRelease = false);
    widget.onHoldStart();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pointerId != event.pointer || _pointerOrigin == null) return;
    final shouldCancel =
        event.position.dy <= _pointerOrigin!.dy - _cancelThreshold;
    if (shouldCancel == _cancelOnRelease) return;
    setState(() => _cancelOnRelease = shouldCancel);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pointerId != event.pointer) return;
    final shouldCancel = _cancelOnRelease;
    _resetPointer();
    if (shouldCancel) {
      widget.onHoldCancel();
    } else {
      widget.onHoldEnd();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_pointerId != event.pointer) return;
    _resetPointer();
    widget.onHoldCancel();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = widget.recording || _pointerId != null;
    final cancel = active && _cancelOnRelease;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.recording
          ? (cancel
                ? 'Release to cancel voice message'
                : 'Release to send voice message')
          : 'Hold to talk. Slide up to cancel.',
      child: Listener(
        key: const Key('chat_hold_to_talk_button'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.enabled ? _handlePointerDown : null,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: AnimatedContainer(
          key: widget.recording
              ? const Key('chat_voice_recording_tab')
              : const Key('chat_voice_hold_tab'),
          duration: const Duration(milliseconds: 120),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: cancel
                ? colors.errorContainer
                : active
                ? colors.primaryContainer.withValues(alpha: 0.55)
                : colors.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: cancel
                  ? colors.error.withValues(alpha: 0.65)
                  : active
                  ? colors.primary.withValues(alpha: 0.45)
                  : colors.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                cancel
                    ? Icons.delete_outline_rounded
                    : widget.recording
                    ? Icons.graphic_eq_rounded
                    : Icons.mic_rounded,
                size: 20,
                color: cancel
                    ? colors.error
                    : active
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.recording
                      ? '${_voiceDuration(widget.recordingSeconds * 1000)} · ${cancel ? 'release to cancel' : 'release to send'}'
                      : 'Hold to Talk',
                  key: widget.recording
                      ? const Key('chat_voice_recording_timer')
                      : const Key('chat_hold_to_talk_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cancel
                        ? colors.error
                        : active
                        ? colors.primary
                        : colors.onSurface,
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

class _ActionPanelItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionPanelItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.35 : 0.2),
                  width: 1,
                ),
              ),
              child: Center(child: Icon(icon, size: 24, color: color)),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
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
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
